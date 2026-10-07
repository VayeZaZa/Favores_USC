import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import '../config/app_constants.dart';
import '../models/favor_model.dart';
import '../models/calificacion_model.dart';
import '../models/reporte_model.dart';
import 'cloudinary_service.dart';

/// Servicio principal para la gestión del módulo de Favores (RF03, RF04, RF05, RF08, RF09, RF16, RNF02, RNF04)
class FavorService {
  final FirebaseFirestore _firestore;
  final CloudinaryService _cloudinaryService;

  FavorService({
    FirebaseFirestore? firestore,
    CloudinaryService? cloudinaryService,
  })  : _firestore = firestore ?? FirebaseFirestore.instance,
        _cloudinaryService = cloudinaryService ?? CloudinaryService();

  CollectionReference get _favoresRef => _firestore.collection('favores');
  CollectionReference get _usuariosRef => _firestore.collection('usuarios');
  CollectionReference get _calificacionesRef => _firestore.collection('calificaciones');
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
    // 1. Validación de pago mínimo (RF03)
    if (pago < AppConstants.minPagoFavor) {
      throw Exception(
        'El pago mínimo para un favor debe ser de \$${AppConstants.minPagoFavor} COP.',
      );
    }

    // 2. Validación de ubicación fija en el campus (RF03, RNF04: Sin GPS)
    if (!AppConstants.puntosCampus.contains(ubicacion)) {
      throw Exception(
        'La ubicación seleccionada debe ser un punto fijo válido dentro del campus USC.',
      );
    }

    // 3. Validación de tipo de favor (RF03)
    if (!AppConstants.tiposFavores.contains(tipo)) {
      throw Exception('Debe seleccionar un tipo de favor válido de la lista.');
    }

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
      tipoServicio: tipo,
      titulo: titulo,
      descripcion: descripcion,
      ubicacion: ubicacion,
      pago: pago,
      estado: 'Publicado',
      urlFotos: urlFotos,
      fechaCreacion: DateTime.now(),
      yaAvisado24h: false,
      calificacionHabilitada: false,
    );

    await newDoc.set(favor.toMap());
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
    final favorDocRef = _favoresRef.doc(favorId);

    await _firestore.runTransaction((transaction) async {
      final snapshot = await transaction.get(favorDocRef);

      if (!snapshot.exists) {
        throw Exception('El favor que intentas tomar no existe.');
      }

      final data = snapshot.data() as Map<String, dynamic>;
      final estadoActual = data['estado'] ?? 'Publicado';
      final idAutor = data['idAutor'] ?? '';

      // Regla de Negocio: El autor no puede aceptar su propio favor (RF05)
      if (idAutor == idAyudante) {
        throw Exception('No puedes aceptar un favor publicado por ti mismo.');
      }

      // Control de Concurrencia (RF05): Verificar estado en la transacción
      if (estadoActual != 'Publicado') {
        throw Exception(
          '¡Ups! Este favor ya fue aceptado por otro estudiante o no está disponible.',
        );
      }

      // Actualización atómica del favor
      transaction.update(favorDocRef, {
        'estado': 'Aceptado',
        'idAyudante': idAyudante,
      });
    });
  }

  // ==========================================
  // RF08: CONFIRMACIÓN DE PAGO Y ENTREGA
  // ==========================================
  /// El ayudante confirma el pago recibido y el favor cambia a "Entregado"
  Future<void> confirmarPagoYEntregar({
    required String favorId,
    required String idAyudante,
  }) async {
    final favorDocRef = _favoresRef.doc(favorId);

    await _firestore.runTransaction((transaction) async {
      final snapshot = await transaction.get(favorDocRef);

      if (!snapshot.exists) {
        throw Exception('El favor especificado no existe.');
      }

      final data = snapshot.data() as Map<String, dynamic>;
      final favorAyudanteDoc = data['idAyudante'];
      final estadoActual = data['estado'];

      if (favorAyudanteDoc != idAyudante) {
        throw Exception('Solo el ayudante asignado a este favor puede confirmar el pago.');
      }

      if (estadoActual != 'Aceptado') {
        throw Exception('El favor debe estar en estado "Aceptado" para entregar.');
      }

      // Cambiar estado a "Entregado" y habilitar calificación (RF08)
      transaction.update(favorDocRef, {
        'estado': 'Entregado',
        'calificacionHabilitada': true,
      });

      // Incrementar contador de favores completados del ayudante (RF14)
      final ayudanteRef = _usuariosRef.doc(idAyudante);
      transaction.update(ayudanteRef, {
        'favoresCompletados': FieldValue.increment(1),
      });
    });
  }

  // ==========================================
  // RF09: SISTEMA DE CALIFICACIÓN Y REPORTES
  // ==========================================
  /// Registra una calificación (1 a 5 estrellas) y recalcula el promedio del usuario calificado
  Future<void> calificarUsuario({
    required String favorId,
    required String idAutorCalificador,
    required String idDestinatario,
    required int estrellas,
    required String comentario,
  }) async {
    if (estrellas < 1 || estrellas > 5) {
      throw Exception('La calificación debe ser entre 1 y 5 estrellas.');
    }

    final newDoc = _calificacionesRef.doc();
    final calificacion = CalificacionModel(
      id: newDoc.id,
      idFavor: favorId,
      idAutor: idAutorCalificador,
      idDestinatario: idDestinatario,
      estrellas: estrellas,
      comentario: comentario,
      fechaCreacion: DateTime.now(),
    );

    // Guardar la calificación y recalcular el promedio del destinatario en transacción
    await _firestore.runTransaction((transaction) async {
      final destinatarioRef = _usuariosRef.doc(idDestinatario);
      final destinatarioSnap = await transaction.get(destinatarioRef);

      if (destinatarioSnap.exists) {
        // Consultar todas las calificaciones de este usuario para sacar el nuevo promedio
        final prevCalificacionesQuery = await _calificacionesRef
            .where('idDestinatario', isEqualTo: idDestinatario)
            .get();

        int totalEstrellas = estrellas;
        int totalConteo = 1;

        for (var doc in prevCalificacionesQuery.docs) {
          final data = doc.data() as Map<String, dynamic>;
          totalEstrellas += (data['estrellas'] as num).toInt();
          totalConteo++;
        }

        final nuevoPromedio = double.parse((totalEstrellas / totalConteo).toStringAsFixed(1));

        transaction.set(newDoc, calificacion.toMap());
        transaction.update(destinatarioRef, {
          'promedio': nuevoPromedio,
        });
      }
    });
  }

  /// Registra un reporte hacia un usuario o favor para el panel de administración
  Future<void> crearReporte({
    required String favorId,
    required String idReportante,
    required String idReportado,
    required String motivo,
    required String descripcion,
  }) async {
    final newDoc = _reportesRef.doc();
    final reporte = ReporteModel(
      id: newDoc.id,
      idFavor: favorId,
      idReportante: idReportante,
      idReportado: idReportado,
      motivo: motivo,
      descripcion: descripcion,
      estado: 'Pendiente',
      fechaCreacion: DateTime.now(),
    );

    await newDoc.set(reporte.toMap());
  }

  // ==========================================
  // RF16: EXPIRACIÓN Y NOTIFICACIÓN 24H
  // ==========================================
  /// Obtiene favores publicados por un usuario que lleven más de 24 horas sin aceptar y no hayan sido avisados
  Future<List<FavorModel>> obtenerFavoresExpiradosAutor(String idAutor) async {
    final hace24Horas = DateTime.now().subtract(const Duration(hours: 24));
    
    final query = await _favoresRef
        .where('idAutor', isEqualTo: idAutor)
        .where('estado', isEqualTo: 'Publicado')
        .where('yaAvisado', isEqualTo: false)
        .where('fechaCreacion', isLessThan: Timestamp.fromDate(hace24Horas))
        .get();

    return query.docs
        .map((doc) => FavorModel.fromMap(doc.data() as Map<String, dynamic>, doc.id))
        .toList();
  }

  /// Marca un favor como avisado para no duplicar alertas de 24h
  Future<void> marcarFavorAvisado(String favorId) async {
    await _favoresRef.doc(favorId).update({'yaAvisado': true});
  }

  /// Republica un favor reiniciando su temporizador de 24h (RF16)
  Future<void> republicarFavor(String favorId) async {
    await _favoresRef.doc(favorId).update({
      'fechaCreacion': Timestamp.fromDate(DateTime.now()),
      'yaAvisado': false,
      'estado': 'Publicado',
    });
  }

  /// Elimina un favor de Firestore (RF16)
  Future<void> eliminarFavor(String favorId) async {
    await _favoresRef.doc(favorId).delete();
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
      query = query.where('tipo', isEqualTo: filtroTipo);
    }

    if (lastDocument != null) {
      query = query.startAfterDocument(lastDocument);
    }

    return await query.limit(limit).get();
  }
}
