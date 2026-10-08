import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/chat_model.dart';
import '../models/mensaje_model.dart';
import '../services/chat_service.dart';

/// Provider del servicio de Chat
final chatServiceProvider = Provider<ChatService>((ref) {
  return ChatService();
});

/// Stream en tiempo real de mensajes de una sala de chat (RF07)
final chatMensajesStreamProvider =
    StreamProvider.autoDispose.family<List<MensajeModel>, String>((ref, chatId) {
  final service = ref.watch(chatServiceProvider);
  return service.obtenerMensajesStream(chatId);
});

/// Stream en tiempo real del estado de la sala (para detectar cierre y modo solo lectura: RF07)
final chatEstadoStreamProvider =
    StreamProvider.autoDispose.family<ChatModel?, String>((ref, chatId) {
  final service = ref.watch(chatServiceProvider);
  return service.obtenerChatStream(chatId);
});
