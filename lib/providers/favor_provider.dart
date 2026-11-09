import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/favor_model.dart';
import '../services/cloudinary_service.dart';
import '../services/favor_service.dart';
import '../services/perfil_service.dart';
import '../utils/favor_load_failure.dart';

final favorSesionUsuarioProvider = StreamProvider.autoDispose<User?>((ref) {
  return FirebaseAuth.instance.authStateChanges();
});

/// Provider del servicio de Cloudinary
final cloudinaryServiceProvider = Provider<CloudinaryService>((ref) {
  return CloudinaryService();
});

/// Solo lee los datos del propio usuario para el encabezado del feed.
final perfilServiceProvider = Provider<PerfilService>((ref) {
  return PerfilService();
});

final resumenFavoresUsuarioProvider = StreamProvider.autoDispose
    .family<Map<String, dynamic>?, String>((ref, usuarioId) {
      return ref.watch(perfilServiceProvider).observarPerfil(usuarioId);
    });

/// Provider del servicio principal de Favores
final favorServiceProvider = Provider<FavorService>((ref) {
  return FavorService(cloudinaryService: ref.watch(cloudinaryServiceProvider));
});

/// Estado para el feed paginado de favores (RNF02)
class FavoresFeedState {
  final List<FavorModel> favores;
  final DocumentSnapshot? lastDocument;
  final bool isLoading;
  final bool hasMore;
  final String? error;
  final FavorLoadFailure? fallo;
  final String filtroTipo;

  FavoresFeedState({
    this.favores = const [],
    this.lastDocument,
    this.isLoading = false,
    this.hasMore = true,
    this.error,
    this.fallo,
    this.filtroTipo = 'Todos',
  });

  FavoresFeedState copyWith({
    List<FavorModel>? favores,
    DocumentSnapshot? lastDocument,
    bool? isLoading,
    bool? hasMore,
    String? error,
    FavorLoadFailure? fallo,
    String? filtroTipo,
  }) {
    return FavoresFeedState(
      favores: favores ?? this.favores,
      lastDocument: lastDocument ?? this.lastDocument,
      isLoading: isLoading ?? this.isLoading,
      hasMore: hasMore ?? this.hasMore,
      error: error,
      fallo: fallo,
      filtroTipo: filtroTipo ?? this.filtroTipo,
    );
  }
}

/// StateNotifier para la carga incremental y paginada del feed de favores (RNF02)
class FavoresFeedNotifier extends StateNotifier<FavoresFeedState> {
  final FavorService _favorService;
  int _generacion = 0;

  FavoresFeedNotifier(this._favorService) : super(FavoresFeedState()) {
    cargarInicial();
  }

  /// Carga inicial o recarga por pull-to-refresh
  Future<void> cargarInicial() async {
    final generacion = ++_generacion;
    // Una recarga descarta el cursor anterior, incluso si llega una página vacía.
    state = FavoresFeedState(filtroTipo: state.filtroTipo, isLoading: true);
    try {
      final snapshot = await _favorService.obtenerFavoresPaginados(
        limit: 10,
        filtroTipo: state.filtroTipo,
      );
      if (!mounted || generacion != _generacion) return;

      final nuevosFavores = snapshot.docs
          .map(
            (doc) =>
                FavorModel.fromMap(doc.data() as Map<String, dynamic>, doc.id),
          )
          .toList();

      final lastDoc = snapshot.docs.isNotEmpty ? snapshot.docs.last : null;

      state = state.copyWith(
        favores: nuevosFavores,
        lastDocument: lastDoc,
        isLoading: false,
        hasMore: snapshot.docs.length >= 10,
      );
    } catch (e, stack) {
      if (!mounted || generacion != _generacion) return;
      final fallo = FavorLoadFailure.from(e);
      registrarErrorCargaFavor('feed.inicial', e, stack);
      state = state.copyWith(
        isLoading: false,
        error: fallo.message,
        fallo: fallo,
      );
    }
  }

  /// Carga la siguiente página de favores (Paginación RNF02)
  Future<void> cargarMas() async {
    if (state.isLoading || !state.hasMore || state.lastDocument == null) return;
    final generacion = _generacion;

    state = state.copyWith(isLoading: true);
    try {
      final snapshot = await _favorService.obtenerFavoresPaginados(
        lastDocument: state.lastDocument,
        limit: 10,
        filtroTipo: state.filtroTipo,
      );
      if (!mounted || generacion != _generacion) return;

      final masFavores = snapshot.docs
          .map(
            (doc) =>
                FavorModel.fromMap(doc.data() as Map<String, dynamic>, doc.id),
          )
          .toList();

      final lastDoc = snapshot.docs.isNotEmpty
          ? snapshot.docs.last
          : state.lastDocument;

      state = state.copyWith(
        favores: [...state.favores, ...masFavores],
        lastDocument: lastDoc,
        isLoading: false,
        hasMore: snapshot.docs.length >= 10,
      );
    } catch (e, stack) {
      if (!mounted || generacion != _generacion) return;
      final fallo = FavorLoadFailure.from(e);
      registrarErrorCargaFavor('feed.pagina', e, stack);
      state = state.copyWith(
        isLoading: false,
        error: fallo.message,
        fallo: fallo,
      );
    }
  }

  /// Cambia el filtro por tipo de favor y reinicia la paginación
  Future<void> cambiarFiltro(String nuevoTipo) async {
    if (state.filtroTipo == nuevoTipo) return;
    state = FavoresFeedState(filtroTipo: nuevoTipo);
    await cargarInicial();
  }
}

/// Provider global para acceder al estado del feed de favores paginado
final favoresFeedProvider =
    StateNotifierProvider<FavoresFeedNotifier, FavoresFeedState>((ref) {
      final favorService = ref.watch(favorServiceProvider);
      return FavoresFeedNotifier(favorService);
    });

final favoresCalificadosProvider = StreamProvider.autoDispose
    .family<Set<String>, String>((ref, uid) {
      return FirebaseFirestore.instance
          .collection('calificaciones')
          .where('idAutor', isEqualTo: uid)
          .snapshots()
          .map(
            (snapshot) => {
              for (final doc in snapshot.docs)
                if (doc.data()['idFavor'] case final String id) id,
            },
          );
    });

final _favoresParticipadosProvider = StreamProvider.autoDispose
    .family<List<FavorModel>, String>((ref, uid) {
      return FirebaseFirestore.instance
          .collection('favores')
          .where(
            Filter.or(
              Filter('idAutor', isEqualTo: uid),
              Filter('idAyudante', isEqualTo: uid),
            ),
          )
          .snapshots()
          .map(
            (snapshot) => [
              for (final doc in snapshot.docs)
                FavorModel.fromMap(doc.data(), doc.id),
            ],
          );
    });

final seguimientoFavorProvider = Provider.autoDispose
    .family<FavorModel?, String>((ref, uid) {
      final favores = ref.watch(_favoresParticipadosProvider(uid)).valueOrNull;
      final calificados = ref
          .watch(favoresCalificadosProvider(uid))
          .valueOrNull;
      if (favores == null) return null;

      int prioridad(FavorModel favor) => switch (favor.estado) {
        'Aceptado' => 3,
        'Publicado' => 2,
        'Entregado'
            when favor.puedeCalificar(uid) &&
                calificados != null &&
                !calificados.contains(favor.id) =>
          1,
        _ => 0,
      };

      FavorModel? seguimiento;
      for (final favor in favores) {
        final actual = seguimiento;
        if (prioridad(favor) == 0) continue;
        if (actual == null ||
            prioridad(favor) > prioridad(actual) ||
            (prioridad(favor) == prioridad(actual) &&
                favor.fechaCreacion.isAfter(actual.fechaCreacion))) {
          seguimiento = favor;
        }
      }
      return seguimiento;
    });

/// StreamProvider para ver los detalles en tiempo real de un favor en particular
final favorDetailStreamProvider = StreamProvider.family<FavorModel?, String>((
  ref,
  favorId,
) {
  return FirebaseFirestore.instance
      .collection('favores')
      .doc(favorId)
      .snapshots()
      .map((snapshot) {
        if (!snapshot.exists || snapshot.data() == null) return null;
        return FavorModel.fromMap(snapshot.data()!, snapshot.id);
      });
});

/// FutureProvider para revisar favores sin aceptar pasadas 24 horas del usuario (RF16)
final favoresExpiradosProvider =
    FutureProvider.family<List<FavorModel>, String>((ref, idAutor) async {
      final favorService = ref.watch(favorServiceProvider);
      return await favorService.obtenerFavoresExpiradosAutor(idAutor);
    });
