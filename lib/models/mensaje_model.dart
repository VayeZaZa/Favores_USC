import 'package:cloud_firestore/cloud_firestore.dart';

/// Modelo de Mensaje para Chat en Tiempo Real (RF07, RF11, RF12)
class MensajeModel {
  const MensajeModel({
    required this.id,
    required this.chatId,
    required this.idEmisor,
    this.nombreEmisor = '',
    required this.texto,
    this.urlFoto,
    required this.timestamp,
    this.esSistema = false,
    this.leido = false,
  });

  final String id;
  final String chatId;
  final String idEmisor;
  final String nombreEmisor;
  final String texto;
  final String? urlFoto;
  final DateTime timestamp;
  final bool esSistema;
  final bool leido;

  Map<String, dynamic> toMap() {
    return {
      'chatId': chatId,
      'idEmisor': idEmisor,
      'nombreEmisor': nombreEmisor,
      'texto': texto,
      'urlFoto': urlFoto,
      'timestamp': Timestamp.fromDate(timestamp),
      'esSistema': esSistema,
      'leido': leido,
    };
  }

  factory MensajeModel.fromMap(Map<String, dynamic> map, String id) {
    final rawTimestamp = map['timestamp'];
    DateTime parseFecha(dynamic raw) {
      if (raw is Timestamp) return raw.toDate();
      if (raw is DateTime) return raw;
      return DateTime.now();
    }

    return MensajeModel(
      id: id,
      chatId: map['chatId'] as String? ?? '',
      idEmisor: map['idEmisor'] as String? ?? '',
      nombreEmisor: map['nombreEmisor'] as String? ?? '',
      texto: map['texto'] as String? ?? '',
      urlFoto: map['urlFoto'] as String?,
      timestamp: parseFecha(rawTimestamp),
      esSistema: map['esSistema'] as bool? ?? false,
      leido: map['leido'] as bool? ?? false,
    );
  }
}
