import 'package:cloud_firestore/cloud_firestore.dart';

class ChatModel {
  const ChatModel({
    required this.id,
    required this.idReferencia,
    required this.participantes,
    required this.soloLectura,
    required this.tipoReferencia,
    required this.ultimoMensaje,
  });

  final String id;
  final String idReferencia;
  final List<String> participantes;
  final bool soloLectura;
  final String tipoReferencia;
  final String ultimoMensaje;

  Map<String, dynamic> toMap() {
    final users = FirebaseFirestore.instance.collection('users');
    return {
      'idReferencia': idReferencia,
      'participantes': participantes.map(users.doc).toList(),
      'soloLectura': soloLectura,
      'tipoReferencia': tipoReferencia,
      'ultimoMensaje': ultimoMensaje,
    };
  }

  factory ChatModel.fromMap(Map<String, dynamic> map, String id) {
    final rawParticipantes = map['participantes'];
    final participantes = rawParticipantes is List
        ? rawParticipantes.map((participante) {
            if (participante is DocumentReference) return participante.id;
            if (participante is String) return participante.split('/').last;
            throw FormatException(
              'Tipo de participante no válido en el chat $id.',
            );
          }).toList()
        : <String>[];

    return ChatModel(
      id: id,
      idReferencia: map['idReferencia'] as String? ?? '',
      participantes: participantes,
      soloLectura: map['soloLectura'] as bool? ?? false,
      tipoReferencia: map['tipoReferencia'] as String? ?? '',
      ultimoMensaje: map['ultimoMensaje'] as String? ?? '',
    );
  }
}
