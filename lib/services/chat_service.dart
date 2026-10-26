import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/favor_model.dart';
import '../models/objeto_model.dart';
import '../models/chat_model.dart';
import '../models/chat_access.dart';
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
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null || (uid != usuarioAId && uid != usuarioBId) ||
        usuarioAId.isEmpty || usuarioBId.isEmpty || usuarioAId == usuarioBId) {
      throw StateError('No tienes acceso a esta conversación.');
    }
    if (tipoReferencia != 'favor' && tipoReferencia != 'objeto') {
      throw StateError('Referencia de chat inválida.');
    }
    final referencia = await _firestore.collection(
      tipoReferencia == 'favor' ? 'favores' : 'objetos',
    ).doc(idReferencia).get();
    if (!referencia.exists) throw StateError('La publicación ya no existe.');
    final data = referencia.data()!;
    final participantes = tipoReferencia == 'favor'
        ? [FavorModel.fromMap(data, referencia.id).idAutor,
           FavorModel.fromMap(data, referencia.id).idAyudante]
        : [ObjetoModel.fromMap(data, referencia.id).idDueno,
           ObjetoModel.fromMap(data, referencia.id).idReclamante];
    if (!participantes.contains(usuarioAId) || !participantes.contains(usuarioBId)) {
      throw StateError('Solo los participantes asignados pueden abrir el chat.');
    }
    if (tipoReferencia == 'favor' && data['estado'] == 'Publicado') {
      throw StateError('Primero debes aceptar el favor.');
    }
    final actualChatId = data['chatId'] as String?;
    if (actualChatId != null) {
      final actual = await _chatsCol.doc(actualChatId).get();
      if (!actual.exists) throw StateError('No se encontró el chat de este caso.');
      final chat = ChatModel.fromMap(actual.data()!, actual.id);
      if (!chat.participantes.contains(usuarioAId) ||
          !chat.participantes.contains(usuarioBId)) {
        throw StateError('Los participantes del chat no coinciden.');
      }
      return chat;
    }
    // Compatibilidad con publicaciones anteriores que todavía no guardan chatId.
    final query = await _chatsCol
        .where('idReferencia', isEqualTo: idReferencia)
        .where('tipoReferencia', isEqualTo: tipoReferencia).get();
    for (final doc in query.docs) {
      final chat = ChatModel.fromMap(doc.data(), doc.id);
      if (chat.participantes.contains(usuarioAId) &&
          chat.participantes.contains(usuarioBId)) return chat;
    }

    // Si no existe, crear la sala exclusiva 1-a-1
    final ids = [usuarioAId, usuarioBId]..sort();
    final nuevoDoc = _chatsCol.doc(Uri.encodeComponent('$tipoReferencia|$idReferencia|${ids.join('|')}'));
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

    return _firestore.runTransaction((tx) async {
      final source = await tx.get(referencia.reference);
      if (!source.exists) throw StateError('La publicación ya no existe.');
      final current = source.data()!;
      final miembros = tipoReferencia == 'favor'
          ? [FavorModel.fromMap(current, source.id).idAutor,
             FavorModel.fromMap(current, source.id).idAyudante]
          : [ObjetoModel.fromMap(current, source.id).idDueno,
             ObjetoModel.fromMap(current, source.id).idReclamante];
      if (!miembros.contains(usuarioAId) || !miembros.contains(usuarioBId) ||
          current['chatId'] != null) {
        throw StateError('La publicación cambió. Vuelve a abrir el chat.');
      }
      final actual = await tx.get(nuevoDoc);
      if (actual.exists) return ChatModel.fromMap(actual.data()!, actual.id);
      tx.set(nuevoDoc, nuevoChat.toMap());
      tx.update(referencia.reference, {'chatId': nuevoDoc.id});
      return nuevoChat;
    });
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
    if (FirebaseAuth.instance.currentUser?.uid != idEmisor) {
      throw StateError('El emisor no coincide con la sesión actual.');
    }
    if (esSistema) throw StateError('Los mensajes de prueba se crean con el reclamo.');
    if (texto.trim().isEmpty && (urlFoto == null || urlFoto.isEmpty)) return;
    final chatRef = _chatsCol.doc(chatId);
    await _firestore.runTransaction((tx) async {
      final chatDoc = await tx.get(chatRef);
      if (!chatDoc.exists) throw StateError('La sala de chat no existe.');
      final chat = ChatModel.fromMap(chatDoc.data()!, chatDoc.id);
      if (!chat.participantes.contains(idEmisor) || chat.soloLectura) {
        throw StateError('No puedes escribir en esta conversación.');
      }
      final ref = _firestore.collection(
        chat.tipoReferencia == 'favor' ? 'favores' : 'objetos',
      ).doc(chat.idReferencia);
      final source = await tx.get(ref);
      if (!source.exists) throw StateError('La publicación ya no existe.');
      final data = source.data()!;
      if (!ChatAccess.puedeEscribir(
        chat: chat, usuarioId: idEmisor, chatActualId: data['chatId'] as String?,
        favor: chat.tipoReferencia == 'favor'
            ? FavorModel.fromMap(data, source.id) : null,
        objeto: chat.tipoReferencia == 'objeto'
            ? ObjetoModel.fromMap(data, source.id) : null,
      )) {
        throw StateError('El caso está cerrado o la prueba aún no está confirmada.');
      }
      final msg = chatRef.collection('mensajes').doc();
      tx.set(msg, MensajeModel(
        id: msg.id, chatId: chatId, idEmisor: idEmisor,
        nombreEmisor: nombreEmisor, texto: texto.trim(), urlFoto: urlFoto,
        timestamp: DateTime.now(),
      ).toMap()..['timestamp'] = FieldValue.serverTimestamp());
      tx.update(chatRef, {
        'ultimoMensaje': urlFoto != null ? 'Foto adjunta' : texto.trim(),
        'fechaUltimoMensaje': FieldValue.serverTimestamp(),
      });
    });
  }

  /// 5. Cierra la sala cambiando a modo solo lectura cuando el caso culmina (RF07)
  Future<void> cerrarChatDeReferencia({
    required String idReferencia,
    required String tipoReferencia,
  }) async {
      final query = await _chatsCol
          .where('idReferencia', isEqualTo: idReferencia)
          .where('tipoReferencia', isEqualTo: tipoReferencia)
          .get();

      for (final doc in query.docs) {
        await doc.reference.update({
          'soloLectura': true,
        });
      }
  }
}
