import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/objeto_model.dart';

import 'package:firebase_auth/firebase_auth.dart';

import '../models/chat_model.dart';
import '../models/mensaje_model.dart';
import 'cloudinary_service.dart';

/// Servicio de Firestore para la gestión del ciclo de vida de Objetos (RF07, RF10, RF11, RF12, RF13)
class ObjetoService {
  final FirebaseFirestore _firestore;
  final CloudinaryService _cloudinaryService;
  final String? Function() _usuarioActual;

  ObjetoService({
    FirebaseFirestore? firestore,
    CloudinaryService? cloudinaryService,
    String? Function()? usuarioActual,
  }) : _firestore = firestore ?? FirebaseFirestore.instance,
       _cloudinaryService = cloudinaryService ?? CloudinaryService(),
       _usuarioActual =
           usuarioActual ?? (() => FirebaseAuth.instance.currentUser?.uid);

  CollectionReference<Map<String, dynamic>> get _objetosCol =>
      _firestore.collection('objetos');

  /// 1. Publicar un nuevo objeto perdido o encontrado (RF10)
  /// - Valida obligatoriedad de foto para objetos 'encontrados'
  /// - Foto opcional para objetos 'perdidos'
  /// - Compresión y subida a Cloudinary
  /// - Etiquetado por colores
  Future<ObjetoModel> publicarObjeto({
    required String idDueno,
    required String nombreDueno,
    required String titulo,
    required String descripcion,
    required String tipo, // 'perdido' o 'encontrado'
    required String etiquetaColor,
    required String lugarCampus,
    File? imagenArchivo,
  }) async {
    final tipoNormalizado = tipo.toLowerCase().trim();

    // Validación RF10: Obligatoriedad de foto para objetos "encontrados"
    if (tipoNormalizado == 'encontrado' && imagenArchivo == null) {
      throw ArgumentError(
        'La foto es obligatoria para reportar un objeto encontrado (RF10).',
      );
    }

    String urlFoto = '';
    if (imagenArchivo != null) {
      final subida = await _cloudinaryService.subirImagenObjeto(
        imagenArchivo,
        folder: 'objetos_fotos',
      );
      if (subida != null) {
        urlFoto = subida;
      } else if (tipoNormalizado == 'encontrado') {
        throw Exception(
          'No se pudo subir la foto obligatoria a Cloudinary. Revisa tu conexión.',
        );
      }
    }

    final docRef = _objetosCol.doc();
    final nuevoObjeto = ObjetoModel(
      id: docRef.id,
      idDueno: idDueno,
      nombreDueno: nombreDueno,
      titulo: titulo.trim(),
      descripcion: descripcion.trim(),
      tipo: tipoNormalizado,
      etiquetaColor: etiquetaColor,
      lugarCampus: lugarCampus,
      urlFoto: urlFoto,
      estadoActual: EstadoObjeto.publicado.valor,
      fechaReporte: DateTime.now(),
      soloLectura: false,
    );

    await docRef.set(nuevoObjeto.toMap());
    return nuevoObjeto;
  }

  /// 2. Stream en tiempo real de objetos filtrados por tipo (RF10)
  Stream<List<ObjetoModel>> obtenerObjetosStream({String? filtroTipo}) {
    Query<Map<String, dynamic>> query = _objetosCol;

    if (filtroTipo != null &&
        filtroTipo.isNotEmpty &&
        filtroTipo.toLowerCase() != 'todos') {
      query = query.where('tipo', isEqualTo: filtroTipo.toLowerCase().trim());
    }

    return query.orderBy('fechaReporte', descending: true).snapshots().map((
      snapshot,
    ) {
      return snapshot.docs
          .map((doc) => ObjetoModel.fromMap(doc.data(), doc.id))
          .toList();
    });
  }

  /// 3. Obtener un objeto específico por ID
  Future<ObjetoModel?> obtenerObjetoPorId(String id) async {
    final doc = await _objetosCol.doc(id).get();
    if (!doc.exists || doc.data() == null) return null;
    return ObjetoModel.fromMap(doc.data()!, doc.id);
  }

  Stream<ObjetoModel?> observarObjeto(String id) => _objetosCol
      .doc(id)
      .snapshots()
      .map(
        (doc) => doc.exists && doc.data() != null
            ? ObjetoModel.fromMap(doc.data()!, doc.id)
            : null,
      );

  /// 4. Reclamación de objeto: "Yo tengo el objeto" / "Es mío" (RF11, RF12)
  /// - Exige obligatoriamente foto de prueba para continuar.
  /// - Cambia de estado a "Pendiente" para bloquear las solicitudes de otros usuarios.
  /// - Sube la foto de prueba a Cloudinary.
  /// - Crea sala de chat 1-a-1 e inserta mensaje inicial con la foto.
  Future<void> reclamarObjeto({
    required String idObjeto,
    required String idReclamante,
    required String nombreReclamante,
    required File fotoPrueba,
    String? mensajeAdicional,
  }) async {
    if (_usuarioActual() != idReclamante) {
      throw StateError('Debes iniciar sesión con la cuenta reclamante.');
    }
    // Validación de foto de prueba obligatoria
    final urlPrueba = await _cloudinaryService.subirImagenObjeto(
      fotoPrueba,
      folder: 'objetos_pruebas',
    );

    if (urlPrueba == null || urlPrueba.isEmpty) {
      throw Exception(
        'Es obligatorio adjuntar una foto de prueba válida para continuar (RF11).',
      );
    }

    final chatRef = _firestore.collection('chats').doc();
    final mensajeRef = chatRef.collection('mensajes').doc();
    // Transacción atómica en Firestore para garantizar bloqueo y evitar condiciones de carrera
    await _firestore.runTransaction((transaction) async {
      final docRef = _objetosCol.doc(idObjeto);
      final snapshot = await transaction.get(docRef);

      if (!snapshot.exists || snapshot.data() == null) {
        throw Exception('El objeto reportado ya no existe.');
      }

      final objeto = ObjetoModel.fromMap(snapshot.data()!, snapshot.id);

      if (objeto.idDueno == idReclamante) {
        throw Exception('No puedes reclamar tu propia publicación.');
      }

      // Validar que esté en 'Publicado' para poder bloquear a los demás
      if (objeto.estadoActual != EstadoObjeto.publicado.valor) {
        throw Exception(
          'Este objeto ya no está disponible para reclamar (Estado: ${objeto.estadoActual}).',
        );
      }

      transaction.set(
        chatRef,
        ChatModel(
          id: chatRef.id,
          idReferencia: idObjeto,
          tipoReferencia: 'objeto',
          tituloReferencia: objeto.titulo,
          participantes: [objeto.idDueno, idReclamante],
          nombresParticipantes: {
            objeto.idDueno: objeto.nombreDueno,
            idReclamante: nombreReclamante,
          },
          ultimoMensaje: 'Foto de prueba pendiente de confirmación',
        ).toMap(),
      );
      transaction.set(
        mensajeRef,
        MensajeModel(
          id: mensajeRef.id,
          chatId: chatRef.id,
          idEmisor: idReclamante,
          nombreEmisor: nombreReclamante,
          texto: 'Foto de prueba. ${mensajeAdicional?.trim() ?? ""}',
          urlFoto: urlPrueba,
          timestamp: DateTime.now(),
          esSistema: true,
        ).toMap()..['timestamp'] = FieldValue.serverTimestamp(),
      );
      // Máquina de estados: Publicado -> Pendiente
      transaction.update(docRef, {
        'estadoActual': EstadoObjeto.pendiente.valor,
        'chatId': chatRef.id,
        'idReclamante': idReclamante,
        'nombreReclamante': nombreReclamante,
        'fotoPruebaUrl': urlPrueba,
        'fechaActualizacion': FieldValue.serverTimestamp(),
      });
    });
  }

  /// 7. Control estricto de la máquina de estados del objeto (RF13)
  /// Secuencia: Publicado -> Pendiente -> Confirmado -> Entregado
  /// Retrocesos permitidos: únicamente a 'Publicado' por rechazo o no entrega
  Future<void> cambiarEstadoObjeto({
    required String idObjeto,
    required String nuevoEstadoStr,
    required String idUsuarioAccion,
    required String chatIdEsperado,
    required String estadoEsperado,
    bool esRechazo = false,
  }) async {
    if (_usuarioActual() != idUsuarioAccion) {
      throw StateError('La sesión no coincide con el usuario de la acción.');
    }
    const estados = ['Publicado', 'Pendiente', 'Confirmado', 'Entregado'];
    if (!estados.contains(nuevoEstadoStr)) throw StateError('Estado inválido.');
    final docRef = _objetosCol.doc(idObjeto);
    await _firestore.runTransaction((tx) async {
      final snapshot = await tx.get(docRef);
      if (!snapshot.exists) throw StateError('El objeto ya no existe.');
      if (snapshot.data()!['estadoActual'] != estadoEsperado) {
        throw StateError(
          'El estado cambió. Revisa el caso antes de continuar.',
        );
      }
      if (snapshot.data()!['chatId'] != null &&
          snapshot.data()!['chatId'] != chatIdEsperado) {
        throw StateError('Este reclamo cambió. Abre la conversación actual.');
      }
      final objeto = ObjetoModel.fromMap(snapshot.data()!, snapshot.id);
      if (objeto.idDueno != idUsuarioAccion) {
        throw StateError(
          'Solo el dueño de la publicación puede gestionar la entrega.',
        );
      }
      if (!objeto.permiteAccion(
        idUsuarioAccion,
        nuevoEstadoStr,
        esRechazo: esRechazo,
      )) {
        throw StateError(
          'Transición no permitida desde ${objeto.estadoActual}.',
        );
      }
      final cambios = <String, dynamic>{
        'estadoActual': nuevoEstadoStr,
        'fechaActualizacion': FieldValue.serverTimestamp(),
        'soloLectura': nuevoEstadoStr == 'Entregado',
      };
      if (nuevoEstadoStr == 'Publicado') {
        cambios.addAll({
          'idReclamante': null,
          'nombreReclamante': null,
          'fotoPruebaUrl': null,
          'chatId': null,
        });
      }
      tx.update(docRef, cambios);
      final chatId = snapshot.data()!['chatId'] as String?;
      if (chatId != null) {
        tx.update(_firestore.collection('chats').doc(chatId), {
          'soloLectura':
              nuevoEstadoStr == 'Publicado' || nuevoEstadoStr == 'Entregado',
        });
      }
    });
  }
}
