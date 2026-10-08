import 'package:cloud_firestore/cloud_firestore.dart';

/// Modelo de Sala de Chat 1-a-1 vinculado a Objetos o Favores (RF07)
class ChatModel {
  const ChatModel({
    required this.id,
    required this.idReferencia,
    this.tituloReferencia = '',
    required this.participantes,
    this.nombresParticipantes = const {},
    this.soloLectura = false,
    required this.tipoReferencia, // 'objeto' | 'favor'
    this.ultimoMensaje = '',
    this.fechaUltimoMensaje,
  });

  final String id;
  final String idReferencia;
  final String tituloReferencia;
  final List<String> participantes; // Exactamente 2 participantes (RF07)
  final Map<String, String> nombresParticipantes;
  final bool soloLectura; // Bloquea envío cuando el caso se cierra (RF07)
  final String tipoReferencia;
  final String ultimoMensaje;
  final DateTime? fechaUltimoMensaje;

  Map<String, dynamic> toMap() {
    return {
      'idReferencia': idReferencia,
      'tituloReferencia': tituloReferencia,
      'participantes': participantes,
      'nombresParticipantes': nombresParticipantes,
      'soloLectura': soloLectura,
      'tipoReferencia': tipoReferencia,
      'ultimoMensaje': ultimoMensaje,
      'fechaUltimoMensaje': fechaUltimoMensaje != null
          ? Timestamp.fromDate(fechaUltimoMensaje!)
          : FieldValue.serverTimestamp(),
    };
  }

  factory ChatModel.fromMap(Map<String, dynamic> map, String id) {
    final rawParticipantes = map['participantes'];
    final List<String> participantes = [];
    if (rawParticipantes is List) {
      for (final p in rawParticipantes) {
        if (p is DocumentReference) {
          participantes.add(p.id);
        } else if (p is String) {
          participantes.add(p.split('/').last);
        }
      }
    }

    final rawNombres = map['nombresParticipantes'];
    final Map<String, String> nombresMap = {};
    if (rawNombres is Map) {
      rawNombres.forEach((key, value) {
        nombresMap[key.toString()] = value.toString();
      });
    }

    final rawFecha = map['fechaUltimoMensaje'];
    DateTime? fecha;
    if (rawFecha is Timestamp) {
      fecha = rawFecha.toDate();
    } else if (rawFecha is DateTime) {
      fecha = rawFecha;
    }

    return ChatModel(
      id: id,
      idReferencia: map['idReferencia'] as String? ?? '',
      tituloReferencia: map['tituloReferencia'] as String? ?? '',
      participantes: participantes,
      nombresParticipantes: nombresMap,
      soloLectura: map['soloLectura'] as bool? ?? false,
      tipoReferencia: map['tipoReferencia'] as String? ?? 'objeto',
      ultimoMensaje: map['ultimoMensaje'] as String? ?? '',
      fechaUltimoMensaje: fecha,
    );
  }
}
