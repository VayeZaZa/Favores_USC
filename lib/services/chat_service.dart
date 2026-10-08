import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import '../models/chat_model.dart';
import '../models/mensaje_model.dart';

/// Servicio de Firestore para Chat en Tiempo Real 1-a-1 (RF07)
class ChatService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> get _chatsCol =>
      _firestore.collection('chats');

  /// 1. Obtener o crear una sala de chat exclusiva para los 2 usuarios involucrados (RF07)
  Future<ChatModel> obtenerOCrearChat1a1({
    required String idReferencia,
    required String tipoReferencia,
    required String tituloReferencia,
    required String usuarioAId,
    required String usuarioANombre,
    required String usuarioBId,
    required String usuarioBNombre,
  }) async {
    // Buscar si ya existe un chat para este objeto/favor entre estos dos participantes
    final query = await _chatsCol
        .where('idReferencia', isEqualTo: idReferencia)
        .where('tipoReferencia', isEqualTo: tipoReferencia)
        .where('participantes', arrayContains: usuarioAId)
        .get();

    for (final doc in query.docs) {
      final chat = ChatModel.fromMap(doc.data(), doc.id);
      if (chat.participantes.contains(usuarioBId)) {
        return chat;
      }
    }

    // Si no existe, crear la sala exclusiva 1-a-1
    final nuevoDoc = _chatsCol.doc();
    final nuevoChat = ChatModel(
      id: nuevoDoc.id,
      idReferencia: idReferencia,
      tituloReferencia: tituloReferencia,
      participantes: [usuarioAId, usuarioBId],
      nombresParticipantes: {
        usuarioAId: usuarioANombre,
        usuarioBId: usuarioBNombre,
      },
      soloLectura: false,
      tipoReferencia: tipoReferencia,
      ultimoMensaje: 'Chat iniciado',
      fechaUltimoMensaje: DateTime.now(),
    );

    await nuevoDoc.set(nuevoChat.toMap());
    return nuevoChat;
  }

  /// 2. Stream en tiempo real de los mensajes de una sala (RF07)
  Stream<List<MensajeModel>> obtenerMensajesStream(String chatId) {
    return _chatsCol
        .doc(chatId)
        .collection('mensajes')
        .orderBy('timestamp', descending: false)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs
          .map((doc) => MensajeModel.fromMap(doc.data(), doc.id))
          .toList();
    });
  }

  /// 3. Stream en tiempo real del estado de la sala (para modo solo lectura en vivo)
  Stream<ChatModel?> obtenerChatStream(String chatId) {
    return _chatsCol.doc(chatId).snapshots().map((doc) {
      if (!doc.exists || doc.data() == null) return null;
      return ChatModel.fromMap(doc.data()!, doc.id);
    });
  }

  /// 4. Enviar mensaje con validación estricta de emisor y modo solo lectura (RF07)
  Future<void> enviarMensaje({
    required String chatId,
    required String idEmisor,
    required String nombreEmisor,
    required String texto,
    String? urlFoto,
    bool esSistema = false,
  }) async {
    final chatDoc = await _chatsCol.doc(chatId).get();
    if (!chatDoc.exists || chatDoc.data() == null) {
      throw Exception('La sala de chat no existe.');
    }

    final chat = ChatModel.fromMap(chatDoc.data()!, chatDoc.id);

    // Validación estricta de emisor (RF07): Solo los 2 participantes autorizados pueden escribir
    if (!chat.participantes.contains(idEmisor)) {
      throw Exception(
        'Acceso denegado: El usuario no pertenece a esta sala de chat privada (RF07).',
      );
    }

    // Validación de modo Solo Lectura cuando el caso se cierra (RF07)
    if (chat.soloLectura) {
      throw Exception(
        'Este caso ha sido cerrado. El chat se encuentra en modo solo lectura (RF07).',
      );
    }

    final mensajesCol = _chatsCol.doc(chatId).collection('mensajes');
    final nuevoMsgDoc = mensajesCol.doc();

    final mensaje = MensajeModel(
      id: nuevoMsgDoc.id,
      chatId: chatId,
      idEmisor: idEmisor,
      nombreEmisor: nombreEmisor,
      texto: texto.trim(),
      urlFoto: urlFoto,
      timestamp: DateTime.now(),
      esSistema: esSistema,
      leido: false,
    );

    // Guardar mensaje y actualizar último mensaje del chat
    final batch = _firestore.batch();
    batch.set(nuevoMsgDoc, mensaje.toMap());
    batch.update(_chatsCol.doc(chatId), {
      'ultimoMensaje': urlFoto != null && urlFoto.isNotEmpty
          ? '📷 Foto adjunta'
          : texto.trim(),
      'fechaUltimoMensaje': FieldValue.serverTimestamp(),
    });

    await batch.commit();
  }

  /// 5. Cierra la sala cambiando a modo solo lectura cuando el caso culmina (RF07)
  Future<void> cerrarChatDeReferencia({
    required String idReferencia,
    required String tipoReferencia,
  }) async {
    try {
      final query = await _chatsCol
          .where('idReferencia', isEqualTo: idReferencia)
          .where('tipoReferencia', isEqualTo: tipoReferencia)
          .get();

      for (final doc in query.docs) {
        await doc.reference.update({
          'soloLectura': true,
        });
      }
    } catch (e) {
      debugPrint('Error cerrando chats de referencia: $e');
    }
  }
}
