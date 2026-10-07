import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/favor_model.dart';
import '../services/cloudinary_service.dart';
import '../services/favor_service.dart';

/// Provider del servicio de Cloudinary
final cloudinaryServiceProvider = Provider<CloudinaryService>((ref) {
  return CloudinaryService();
});

/// Provider del servicio principal de Favores
final favorServiceProvider = Provider<FavorService>((ref) {
  return FavorService(
    cloudinaryService: ref.watch(cloudinaryServiceProvider),
  );
});

/// Estado para el feed paginado de favores (RNF02)
class FavoresFeedState {
  final List<FavorModel> favores;
  final DocumentSnapshot? lastDocument;
  final bool isLoading;
  final bool hasMore;
  final String? error;
  final String filtroTipo;

  FavoresFeedState({
    this.favores = const [],
    this.lastDocument,
    this.isLoading = false,
    this.hasMore = true,
    this.error,
    this.filtroTipo = 'Todos',
  });

  FavoresFeedState copyWith({
    List<FavorModel>? favores,
    DocumentSnapshot? lastDocument,
    bool? isLoading,
    bool? hasMore,
    String? error,
    String? filtroTipo,
  }) {
    return FavoresFeedState(
      favores: favores ?? this.favores,
      lastDocument: lastDocument ?? this.lastDocument,
      isLoading: isLoading ?? this.isLoading,
      hasMore: hasMore ?? this.hasMore,
      error: error,
      filtroTipo: filtroTipo ?? this.filtroTipo,
    );
  }
}

/// StateNotifier para la carga incremental y paginada del feed de favores (RNF02)
class FavoresFeedNotifier extends StateNotifier<FavoresFeedState> {
  final FavorService _favorService;

  FavoresFeedNotifier(this._favorService) : super(FavoresFeedState()) {
    cargarInicial();
  }

  /// Carga inicial o recarga por pull-to-refresh
  Future<void> cargarInicial() async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final snapshot = await _favorService.obtenerFavoresPaginados(
        limit: 10,
        filtroTipo: state.filtroTipo,
      );

      final nuevosFavores = snapshot.docs
          .map((doc) => FavorModel.fromMap(doc.data() as Map<String, dynamic>, doc.id))
          .toList();

      final lastDoc = snapshot.docs.isNotEmpty ? snapshot.docs.last : null;

      state = state.copyWith(
        favores: nuevosFavores,
        lastDocument: lastDoc,
        isLoading: false,
        hasMore: snapshot.docs.length >= 10,
      );
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  /// Carga la siguiente página de favores (Paginación RNF02)
  Future<void> cargarMas() async {
    if (state.isLoading || !state.hasMore || state.lastDocument == null) return;

    state = state.copyWith(isLoading: true);
    try {
      final snapshot = await _favorService.obtenerFavoresPaginados(
        lastDocument: state.lastDocument,
        limit: 10,
        filtroTipo: state.filtroTipo,
      );

      final masFavores = snapshot.docs
          .map((doc) => FavorModel.fromMap(doc.data() as Map<String, dynamic>, doc.id))
          .toList();

      final lastDoc = snapshot.docs.isNotEmpty ? snapshot.docs.last : state.lastDocument;

      state = state.copyWith(
        favores: [...state.favores, ...masFavores],
        lastDocument: lastDoc,
        isLoading: false,
        hasMore: snapshot.docs.length >= 10,
      );
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
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

/// StreamProvider para ver los detalles en tiempo real de un favor en particular
final favorDetailStreamProvider =
    StreamProvider.family<FavorModel?, String>((ref, favorId) {
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
