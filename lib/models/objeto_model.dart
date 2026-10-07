import 'package:cloud_firestore/cloud_firestore.dart';

class ObjetoModel {
  const ObjetoModel({
    required this.id,
    required this.descripcion,
    required this.estadoActual,
    required this.fechaReporte,
    required this.idDueno,
    required this.tipo,
    required this.titulo,
  });

  final String id;
  final String descripcion;
  final String estadoActual;
  final DateTime fechaReporte;
  final String idDueno;
  final String tipo;
  final String titulo;

  Map<String, dynamic> toMap() {
    return {
      'descripcion': descripcion,
      'estadoActual': estadoActual,
      'fechaReporte': Timestamp.fromDate(fechaReporte),
      'idDueno': FirebaseFirestore.instance.collection('usuarios').doc(idDueno),
      'tipo': tipo,
      'titulo': titulo,
    };
  }

  factory ObjetoModel.fromMap(Map<String, dynamic> map, String id) {
    final rawDueno = map['idDueno'];
    final rawFecha = map['fechaReporte'];

    return ObjetoModel(
      id: id,
      descripcion: map['descripcion'] as String? ?? '',
      estadoActual: map['estadoActual'] as String? ?? 'Publicado',
      fechaReporte: rawFecha is Timestamp
          ? rawFecha.toDate()
          : rawFecha is DateTime
          ? rawFecha
          : DateTime.now(),
      idDueno: rawDueno is DocumentReference
          ? rawDueno.id
          : rawDueno is String
          ? rawDueno.split('/').last
          : '',
      tipo: map['tipo'] as String? ?? '',
      titulo: map['titulo'] as String? ?? '',
    );
  }
}
