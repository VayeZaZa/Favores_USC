import 'package:cloud_firestore/cloud_firestore.dart';

/// Modelo de Reporte para FAVORES USC (RF09)
class ReporteModel {
  final String id;
  final String idFavor;
  final String idReportante; // Usuario que envía el reporte
  final String idReportado; // Usuario reportado
  final String motivo; // Ej. 'Incumplimiento', 'Conducta inadecuada', 'Fraude'
  final String descripcion; // Detalle adicional del reporte
  final String estado; // 'Pendiente', 'En Revisión', 'Resuelto'
  final DateTime fechaCreacion;

  ReporteModel({
    required this.id,
    required this.idFavor,
    required this.idReportante,
    required this.idReportado,
    required this.motivo,
    required this.descripcion,
    this.estado = 'Pendiente',
    required this.fechaCreacion,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'idFavor': idFavor,
      'idReportante': idReportante,
      'idReportado': idReportado,
      'motivo': motivo,
      'descripcion': descripcion,
      'estado': estado,
      'fechaCreacion': Timestamp.fromDate(fechaCreacion),
    };
  }

  factory ReporteModel.fromMap(Map<String, dynamic> map, String id) {
    return ReporteModel(
      id: id,
      idFavor: map['idFavor'] ?? '',
      idReportante: map['idReportante'] ?? '',
      idReportado: map['idReportado'] ?? '',
      motivo: map['motivo'] ?? '',
      descripcion: map['descripcion'] ?? '',
      estado: map['estado'] ?? 'Pendiente',
      fechaCreacion: map['fechaCreacion'] != null
          ? (map['fechaCreacion'] as Timestamp).toDate()
          : DateTime.now(),
    );
  }
}
