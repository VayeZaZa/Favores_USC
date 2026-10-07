import 'package:cloud_firestore/cloud_firestore.dart';

/// Modelo de Calificación para FAVORES USC (RF09)
class CalificacionModel {
  final String id;
  final String idFavor;
  final String idAutor; // Quien realiza la calificación (ej. Autor del favor)
  final String idDestinatario; // Quien recibe la calificación (ej. Ayudante)
  final int estrellas; // 1 a 5 estrellas
  final String comentario; // Comentario corto opcional
  final DateTime fechaCreacion;

  CalificacionModel({
    required this.id,
    required this.idFavor,
    required this.idAutor,
    required this.idDestinatario,
    required this.estrellas,
    required this.comentario,
    required this.fechaCreacion,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'idFavor': idFavor,
      'idAutor': idAutor,
      'idDestinatario': idDestinatario,
      'estrellas': estrellas,
      'comentario': comentario,
      'fechaCreacion': Timestamp.fromDate(fechaCreacion),
    };
  }

  factory CalificacionModel.fromMap(Map<String, dynamic> map, String id) {
    return CalificacionModel(
      id: id,
      idFavor: map['idFavor'] ?? '',
      idAutor: map['idAutor'] ?? '',
      idDestinatario: map['idDestinatario'] ?? '',
      estrellas: (map['estrellas'] as num?)?.toInt() ?? 5,
      comentario: map['comentario'] ?? '',
      fechaCreacion: map['fechaCreacion'] != null
          ? (map['fechaCreacion'] as Timestamp).toDate()
          : DateTime.now(),
    );
  }
}
