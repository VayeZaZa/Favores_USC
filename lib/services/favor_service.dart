import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../utils/favor_validators.dart';
import '../models/favor_model.dart';
import '../models/calificacion_model.dart';
import '../models/reporte_model.dart';
import 'cloudinary_service.dart';

/// Servicio principal para la gestión del módulo de Favores (RF03, RF04, RF05, RF08, RF09, RF16, RNF02, RNF04)
class FavorService {
  final FirebaseFirestore _firestore;
  final CloudinaryService _cloudinaryService;
  final String? Function() _usuarioActualId;

  void _verificarSesion(String idUsuario) {
    if (idUsuario.isEmpty || _usuarioActualId() != idUsuario) {
      throw Exception(
        'Debes iniciar sesión con la cuenta que realiza esta acción.',
      );
    }
  }

  static String chatId(String favorId) => 'favor_$favorId';

  static String _nombrePerfil(Map<String, dynamic> datos) =>
      datos['display_name'] as String? ?? datos['nombre'] as String? ?? '';

  static String calificacionId(String favorId, String usuarioId) =>
      '${favorId}_$usuarioId';

  FavorService({
    FirebaseFirestore? firestore,
    CloudinaryService? cloudinaryService,
    String? Function()? usuarioActualId,
  }) : _firestore = firestore ?? FirebaseFirestore.instance,
       _cloudinaryService = cloudinaryService ?? CloudinaryService(),
       _usuarioActualId =
           usuarioActualId ?? (() => FirebaseAuth.instance.currentUser?.uid);

  CollectionReference get _favoresRef => _firestore.collection('favores');
  CollectionReference get _usuariosRef => _firestore.collection('usuarios');
  CollectionReference get _calificacionesRef =>
      _firestore.collection('calificaciones');
  CollectionReference get _reportesRef => _firestore.collection('reportes');

  // ==========================================
  // RF03 & RF04: PUBLICACIÓN DE FAVORES
  // ==========================================
  /// Publica un nuevo favor tras validar los datos de negocio
  Future<String> crearFavor({
    required String idAutor,
    required String titulo,
    required String tipo,
    required String descripcion,
    required String ubicacion,
    required int pago,
    List<File> imagenesLocales = const [],
  }) async {
    _verificarSesion(idAutor);
    FavorValidators.validarPublicacion(
      idAutor: idAutor,
      tituloFavor: titulo,
      descripcionFavor: descripcion,
      tipoFavor: tipo,
      ubicacionFavor: ubicacion,
      pagoFavor: pago,
      cantidadFotos: imagenesLocales.length,
    );
    final perfil = await _usuariosRef.doc(idAutor).get();
    if (!perfil.exists) {
      throw Exception('No se encontró tu perfil de estudiante.');
    }
    final datosAutor = perfil.data() as Map<String, dynamic>;
    // 4. Subida de imágenes a Cloudinary (máximo 3, RF04)
    List<String> urlFotos = [];
    if (imagenesLocales.isNotEmpty) {
      urlFotos = await _cloudinaryService.subirImagenesFavores(imagenesLocales);
    }

    // 5. Creación del documento en Firestore
    final newDoc = _favoresRef.doc();
    final favor = FavorModel(
      id: newDoc.id,
      idAutor: idAutor,
      nombreAutor: _nombrePerfil(datosAutor),
      fotoAutor: datosAutor['fotoPerfil'] as String? ?? '',
      tipoServicio: tipo,
      titulo: titulo.trim(),
      descripcion: descripcion.trim(),
      ubicacion: ubicacion,
      pago: pago,
      estado: 'Publicado',
      urlFotos: urlFotos,
      fechaCreacion: DateTime.now(),
      yaAvisado24h: false,
      calificacionHabilitada: false,
    );

    _verificarSesion(idAutor);
    await newDoc.set({
      ...favor.toMap(),
      'fechaCreacion': FieldValue.serverTimestamp(),
    });
    return newDoc.id;
  }

  // ==========================================
  // RF05: ACEPTAR UN FAVOR (TRANSACCIONAL)
  // ==========================================
  /// Acepta un favor garantizando control de concurrencia estricto en Firestore mediante transacciones
  Future<void> aceptarFavor({
    required String favorId,
    required String idAyudante,
  }) async {
    _verificarSesion(idAyudante);
    final favorRef = _favoresRef.doc(favorId);
    // Cada aceptación tiene una sala propia, incluso si vuelve el mismo ayudante.
    final salaRef = _firestore.collection('chats').doc();
    await _firestore.runTransaction((tx) async {
      final snapshot = await tx.get(favorRef);
      if (!snapshot.exists) throw Exception('El favor no existe.');
      final favor = FavorModel.fromMap(
        snapshot.data() as Map<String, dynamic>,
        snapshot.id,
      );
      if (favor.idAutor.isEmpty) {
        throw Exception('El favor no tiene un autor válido.');
      }
      if (favor.idAutor == idAyudante) {
        throw Exception('No puedes aceptar un favor publicado por ti mismo.');
      }
      if (!favor.esPublicado || (favor.idAyudante?.isNotEmpty ?? false)) {
        throw Exception('Este favor ya fue tomado o no está disponible.');
      }
      final ayudante = await tx.get(_usuariosRef.doc(idAyudante));
      if (!ayudante.exists) {
        throw Exception('No encontramos tu perfil de estudiante.');
      }
      final ayudanteData = ayudante.data() as Map<String, dynamic>;
      final nombreAyudante = _nombrePerfil(ayudanteData);
      final fotoAyudante = ayudanteData['fotoPerfil'] as String? ?? '';
      tx.update(favorRef, {
        'estado': 'Aceptado',
        'idAyudante': idAyudante,
        'nombreAyudante': nombreAyudante,
        if (fotoAyudante.isNotEmpty) 'fotoAyudante': fotoAyudante,
        'idChat': salaRef.id,
        'fechaAceptacion': FieldValue.serverTimestamp(),
      });
      tx.set(salaRef, {
        'idReferencia': favorId,
        'tipoReferencia': 'favor',
        'tituloReferencia': favor.titulo,
        'participantes': [favor.idAutor, idAyudante],
        'nombresParticipantes': {
          favor.idAutor: favor.nombreAutor,
          idAyudante: nombreAyudante,
        },
        'soloLectura': false,
        'ultimoMensaje': 'Favor aceptado. Coordinen la entrega aquí.',
        'fechaUltimoMensaje': FieldValue.serverTimestamp(),
      });
    });
  }

  Future<void> cancelarAceptacion({
    required String favorId,
    required String idAyudante,
  }) async {
    _verificarSesion(idAyudante);
    final referencia = _favoresRef.doc(favorId);
    final salas = await _salasFavor(favorId, idAyudante);

    await _firestore.runTransaction((tx) async {
      final snapshot = await tx.get(referencia);
      if (!snapshot.exists) throw Exception('El favor ya no está disponible.');
      final datos = snapshot.data() as Map<String, dynamic>;
      final favor = FavorModel.fromMap(datos, favorId);
      if (!favor.puedeCancelarAceptacion(idAyudante)) {
        throw Exception(
          'Solo quien aceptó el favor puede cancelar la aceptación.',
        );
      }
      final salaActual = datos['idChat'] as String?;
      if (salaActual != null && salaActual.isNotEmpty) {
        final chat = _firestore.collection('chats').doc(salaActual);
        tx.update(chat, {'soloLectura': true});
      } else {
        for (final sala in salas) {
          final chat = sala.data();
          final participantes = chat['participantes'] as List? ?? [];
          if (chat['soloLectura'] != true &&
              participantes.length == 2 &&
              participantes.contains(favor.idAutor)) {
            tx.update(sala.reference, {'soloLectura': true});
          }
        }
      }
      tx.update(referencia, {
        'estado': 'Publicado',
        'idAyudante': null,
        'nombreAyudante': FieldValue.delete(),
        'fotoAyudante': FieldValue.delete(),
        'idChat': FieldValue.delete(),
        'fechaAceptacion': FieldValue.delete(),
      });
    });
  }

  /// Abre la sala existente y recupera conversaciones de versiones anteriores.
  Future<String> prepararChatFavor(
    String favorId, {
    required String idUsuario,
  }) async {
    _verificarSesion(idUsuario);
    final snapshot = await _favoresRef.doc(favorId).get();
    if (!snapshot.exists) throw Exception('El favor no existe.');
    final datos = snapshot.data() as Map<String, dynamic>;
    final favor = FavorModel.fromMap(datos, favorId);
    if (!favor.puedeAbrirChat(idUsuario)) {
      throw Exception('Solo los participantes pueden abrir el chat del favor.');
    }
    final chatGuardado = datos['idChat'] as String?;
    if (chatGuardado != null && chatGuardado.isNotEmpty) return chatGuardado;

    final salas = await _salasFavor(favorId, idUsuario);
    for (final sala in salas) {
      final participantes = sala.data()['participantes'] as List? ?? [];
      if ((favor.esAceptado && sala.data()['soloLectura'] == true) ||
          participantes.length != 2 ||
          !participantes.contains(favor.idAutor) ||
          !participantes.contains(favor.idAyudante)) {
        continue;
      }
      if (favor.esEntregado && sala.data()['soloLectura'] != true) {
        await sala.reference.update({'soloLectura': true});
      }
      return sala.id;
    }

    final salaRef = _firestore.collection('chats').doc(chatId(favorId));
    await salaRef.set({
      'idReferencia': favorId,
      'tipoReferencia': 'favor',
      'tituloReferencia': favor.titulo,
      'participantes': [favor.idAutor, favor.idAyudante],
      'nombresParticipantes': {
        favor.idAutor: favor.nombreAutor,
        favor.idAyudante!: favor.nombreAyudante,
      },
      'soloLectura': favor.esEntregado,
      'ultimoMensaje': '',
      'fechaUltimoMensaje': FieldValue.serverTimestamp(),
    });
    return salaRef.id;
  }

  Future<List<QueryDocumentSnapshot<Map<String, dynamic>>>> _salasFavor(
    String favorId,
    String idUsuario,
  ) async {
    final salas = await _firestore
        .collection('chats')
        .where('participantes', arrayContains: idUsuario)
        .get();
    return salas.docs.where((sala) {
      final datos = sala.data();
      return datos['idReferencia'] == favorId &&
          (datos['tipoReferencia'] as String?)?.toLowerCase() == 'favor';
    }).toList();
  }

  // ==========================================
  // RF08: CONFIRMACIÓN DE PAGO Y ENTREGA
  // ==========================================
  /// El ayudante confirma el pago recibido y el favor cambia a "Entregado"
  Future<void> confirmarPagoYEntregar({
    required String favorId,
    required String idAyudante,
  }) async {
    _verificarSesion(idAyudante);
    final favorRef = _favoresRef.doc(favorId);
    // Incluye salas de versiones anteriores sin perder su historial.
    final salas = await _salasFavor(favorId, idAyudante);
    await _firestore.runTransaction((tx) async {
      final snapshot = await tx.get(favorRef);
      if (!snapshot.exists) throw Exception('El favor no existe.');
      final favor = FavorModel.fromMap(
        snapshot.data() as Map<String, dynamic>,
        snapshot.id,
      );
      if (favor.idAyudante != idAyudante) {
        throw Exception(
          'Solo el ayudante asignado puede confirmar el pago recibido.',
        );
      }
      if (!favor.esAceptado) {
        throw Exception('El favor debe estar Aceptado para entregar.');
      }
      final usuarioRef = _usuariosRef.doc(idAyudante);
      final usuario = await tx.get(usuarioRef);
      if (!usuario.exists) {
        throw Exception('No se encontró el perfil del ayudante.');
      }
      tx.update(favorRef, {
        'estado': 'Entregado',
        'soloLectura': true,
        'calificacionHabilitada': true,
        'fechaEntrega': FieldValue.serverTimestamp(),
      });
      tx.update(usuarioRef, {'favoresCompletados': FieldValue.increment(1)});
      for (final chat in salas) {
        tx.update(chat.reference, {'soloLectura': true});
      }
    });
  }

  // ==========================================
  // RF09: SISTEMA DE CALIFICACIÓN Y REPORTES
  // ==========================================
  /// Registra una calificación. El perfil calcula el promedio desde estas notas.
  Future<void> calificarUsuario({
    required String favorId,
    required String idAutorCalificador,
    required String idDestinatario,
    required int estrellas,
    required String comentario,
  }) async {
    _verificarSesion(idAutorCalificador);
    if (idDestinatario.isEmpty || idDestinatario == idAutorCalificador) {
      throw Exception('Debes calificar al otro participante del favor.');
    }
    if (estrellas < 1 || estrellas > 5) {
      throw Exception('Elige entre 1 y 5 estrellas.');
    }
    if (comentario.trim().length > 300) {
      throw Exception('El comentario admite máximo 300 caracteres.');
    }
    // Compatibilidad de lectura con calificaciones antiguas de ID aleatorio.
    final anteriores = await _calificacionesRef
        .where('idFavor', isEqualTo: favorId)
        .where('idAutor', isEqualTo: idAutorCalificador)
        .limit(1)
        .get();
    if (anteriores.docs.isNotEmpty) {
      throw Exception('Ya calificaste este favor.');
    }
    final calificacionRef = _calificacionesRef.doc(
      calificacionId(favorId, idAutorCalificador),
    );
    await _firestore.runTransaction((tx) async {
      final favorSnap = await tx.get(_favoresRef.doc(favorId));
      final existente = await tx.get(calificacionRef);
      if (!favorSnap.exists) throw Exception('El favor no existe.');
      final favor = FavorModel.fromMap(
        favorSnap.data() as Map<String, dynamic>,
        favorId,
      );
      if (!favor.esEntregado || !favor.calificacionHabilitada) {
        throw Exception('Solo puedes calificar un favor entregado.');
      }
      final otro = idAutorCalificador == favor.idAutor
          ? favor.idAyudante
          : idAutorCalificador == favor.idAyudante
          ? favor.idAutor
          : null;
      if (otro == null || otro != idDestinatario) {
        throw Exception(
          'Solo los dos participantes pueden calificarse entre sí.',
        );
      }
      if (existente.exists) throw Exception('Ya calificaste este favor.');
      if (favor.calificadoPor.contains(idAutorCalificador)) {
        throw Exception('Ya calificaste este favor.');
      }
      final calificacion = CalificacionModel(
        id: calificacionRef.id,
        idFavor: favorId,
        idAutor: idAutorCalificador,
        idDestinatario: idDestinatario,
        estrellas: estrellas,
        comentario: comentario.trim(),
        fechaCreacion: DateTime.now(),
      );
      tx.set(calificacionRef, {
        ...calificacion.toMap(),
        'fechaCreacion': FieldValue.serverTimestamp(),
      });
    });
  }

  Future<void> crearReporte({
    required String favorId,
    required String idReportante,
    required String idReportado,
    required String motivo,
    required String descripcion,
  }) async {
    _verificarSesion(idReportante);
    if (motivo.trim().isEmpty ||
        descripcion.trim().length > 1000 ||
        idReportado.isEmpty ||
        idReportante == idReportado) {
      throw Exception(
        'Revisa el destinatario, el motivo y los detalles del reporte.',
      );
    }
    final newDoc = _reportesRef.doc();
    await _firestore.runTransaction((tx) async {
      final snapshot = await tx.get(_favoresRef.doc(favorId));
      if (!snapshot.exists) throw Exception('El favor no existe.');
      final favor = FavorModel.fromMap(
        snapshot.data() as Map<String, dynamic>,
        favorId,
      );
      final otro = idReportante == favor.idAutor
          ? favor.idAyudante
          : idReportante == favor.idAyudante
          ? favor.idAutor
          : null;
      if (!favor.esEntregado || otro != idReportado) {
        throw Exception(
          'El reporte requiere un favor entregado entre ambos participantes.',
        );
      }
      final reporte = ReporteModel(
        id: newDoc.id,
        idFavor: favorId,
        idReportante: idReportante,
        idReportado: idReportado,
        motivo: motivo.trim(),
        descripcion: descripcion.trim(),
        estado: 'Pendiente',
        fechaCreacion: DateTime.now(),
      );
      tx.set(newDoc, {
        ...reporte.toMap(),
        'fechaCreacion': FieldValue.serverTimestamp(),
      });
    });
  }

  // ==========================================
  // RF16: EXPIRACIÓN Y NOTIFICACIÓN 24H
  // ==========================================
  /// Obtiene favores publicados por un usuario que lleven más de 24 horas sin aceptar y no hayan sido avisados
  Future<List<FavorModel>> obtenerFavoresExpiradosAutor(String idAutor) async {
    _verificarSesion(idAutor);
    final hace24Horas = DateTime.now().subtract(const Duration(hours: 24));

    final query = await _favoresRef
        .where('idAutor', isEqualTo: idAutor)
        .where('estado', isEqualTo: 'Publicado')
        .where('fechaCreacion', isLessThan: Timestamp.fromDate(hace24Horas))
        .get();

    return query.docs
        .map(
          (doc) =>
              FavorModel.fromMap(doc.data() as Map<String, dynamic>, doc.id),
        )
        .toList();
  }

  Future<void> republicarFavor(String favorId, {required String idAutor}) =>
      _gestionarPublicado(favorId, idAutor: idAutor, retirar: false);

  /// Retira del feed conservando el registro y su historial en Firestore.
  Future<void> retirarFavor(String favorId, {required String idAutor}) =>
      _gestionarPublicado(favorId, idAutor: idAutor, retirar: true);

  Future<void> eliminarFavor(String favorId, {required String idAutor}) async {
    _verificarSesion(idAutor);
    final documento = _favoresRef.doc(favorId);
    await _firestore.runTransaction((tx) async {
      final snapshot = await tx.get(documento);
      if (!snapshot.exists) return;
      final favor = FavorModel.fromMap(
        snapshot.data() as Map<String, dynamic>,
        snapshot.id,
      );
      if (!favor.puedeEliminar(idAutor)) {
        throw Exception(
          'Solo puedes borrar tus favores publicados o retirados.',
        );
      }
      tx.delete(documento);
    });
  }

  Future<void> _gestionarPublicado(
    String favorId, {
    required String idAutor,
    required bool retirar,
  }) async {
    _verificarSesion(idAutor);
    final favorRef = _favoresRef.doc(favorId);
    await _firestore.runTransaction((tx) async {
      final snapshot = await tx.get(favorRef);
      if (!snapshot.exists) throw Exception('El favor no existe.');
      final favor = FavorModel.fromMap(
        snapshot.data() as Map<String, dynamic>,
        favorId,
      );
      if (favor.idAutor != idAutor ||
          !favor.esPublicado ||
          (favor.idAyudante?.isNotEmpty ?? false)) {
        throw Exception(
          'Solo el autor puede gestionar su favor mientras está publicado.',
        );
      }
      if (!retirar &&
          DateTime.now().difference(favor.fechaCreacion) <
              const Duration(hours: 24)) {
        throw Exception(
          'Puedes republicar cuando pasen 24 horas sin ser aceptado.',
        );
      }
      tx.update(
        favorRef,
        retirar
            ? {
                'estado': 'Cancelado',
                'soloLectura': true,
                'fechaCancelacion': FieldValue.serverTimestamp(),
              }
            : {
                'fechaCreacion': FieldValue.serverTimestamp(),
                'yaAvisado': false,
                'yaAvisado24h': false,
              },
      );
    });
  }

  // ==========================================
  // RNF02: FEED PAGINADO DE FAVORES (<2 Segundos)
  // ==========================================
  /// Obtiene los favores publicados paginados mediante cursores de Firestore (RNF02)
  Future<QuerySnapshot> obtenerFavoresPaginados({
    DocumentSnapshot? lastDocument,
    int limit = 10,
    String? filtroTipo,
  }) async {
    Query query = _favoresRef
        .where('estado', isEqualTo: 'Publicado')
        .orderBy('fechaCreacion', descending: true);

    if (filtroTipo != null && filtroTipo.isNotEmpty && filtroTipo != 'Todos') {
      query = query.where('tipoServicio', isEqualTo: filtroTipo);
    }

    if (lastDocument != null) {
      query = query.startAfterDocument(lastDocument);
    }

    return await query.limit(limit).get();
  }

  Future<QuerySnapshot> obtenerActividadPaginada({
    required String idUsuario,
    required String filtro,
    DocumentSnapshot? lastDocument,
    int limit = 10,
  }) async {
    _verificarSesion(idUsuario);
    Query query = _favoresRef;
    switch (filtro) {
      case 'Mis favores':
        query = query.where('idAutor', isEqualTo: idUsuario);
      case 'Ayudando':
        query = query.where('idAyudante', isEqualTo: idUsuario);
      case 'Finalizados':
        query = query
            .where(
              Filter.or(
                Filter('idAutor', isEqualTo: idUsuario),
                Filter('idAyudante', isEqualTo: idUsuario),
              ),
            )
            .where('estado', whereIn: ['Entregado', 'Cancelado']);
      default:
        throw ArgumentError('Filtro de actividad no válido.');
    }
    query = query.orderBy('fechaCreacion', descending: true);
    if (lastDocument != null) query = query.startAfterDocument(lastDocument);
    return query.limit(limit).get();
  }
}
