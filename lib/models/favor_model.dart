import 'package:cloud_firestore/cloud_firestore.dart';

/// Modelo de Favor para FAVORES USC (RF03, RF04, RF05, RF08, RF16)
class FavorModel {
  final String id;
  final String idAutor; // Referencia al usuario creador
  final String? idAyudante; // Referencia al usuario que acepta el favor
  final String tipo; // Lista de tipos predefinidos
  final String descripcion;
  final String ubicacion; // Puntos fijos del campus (sin GPS)
  final int pago; // Monto en COP >= 1000
  final String estado; // "Publicado", "Aceptado", "Entregado", "Cancelado"
  final List<String> urlFotos; // Hasta 3 fotos en Cloudinary (RF04)
  final DateTime fechaCreacion;
  final bool yaAvisado; // RF16: notificación tras 24h sin aceptar
  final bool calificacionHabilitada; // RF08, RF09: true cuando pasa a "Entregado"

  FavorModel({
    required this.id,
    required this.idAutor,
    this.idAyudante,
    required this.tipo,
    required this.descripcion,
    required this.ubicacion,
    required this.pago,
    this.estado = 'Publicado',
    this.urlFotos = const [],
    required this.fechaCreacion,
    this.yaAvisado = false,
    this.calificacionHabilitada = false,
  });

  bool get esPublicado => estado == 'Publicado';
  bool get esAceptado => estado == 'Aceptado';
  bool get esEntregado => estado == 'Entregado';
  bool get esCancelado => estado == 'Cancelado';

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'idAutor': idAutor,
      'idAyudante': idAyudante,
      'tipo': tipo,
      'descripcion': descripcion,
      'ubicacion': ubicacion,
      'pago': pago,
      'estado': estado,
      'urlFotos': urlFotos,
      'fechaCreacion': Timestamp.fromDate(fechaCreacion),
      'yaAvisado': yaAvisado,
      'calificacionHabilitada': calificacionHabilitada,
    };
  }

  factory FavorModel.fromMap(Map<String, dynamic> map, String id) {
    return FavorModel(
      id: id,
      idAutor: map['idAutor'] ?? '',
      idAyudante: map['idAyudante'],
      tipo: map['tipo'] ?? '',
      descripcion: map['descripcion'] ?? '',
      ubicacion: map['ubicacion'] ?? '',
      pago: (map['pago'] as num?)?.toInt() ?? 0,
      estado: map['estado'] ?? 'Publicado',
      urlFotos: List<String>.from(map['urlFotos'] ?? []),
      fechaCreacion: map['fechaCreacion'] != null
          ? (map['fechaCreacion'] as Timestamp).toDate()
          : DateTime.now(),
      yaAvisado: map['yaAvisado'] ?? false,
      calificacionHabilitada: map['calificacionHabilitada'] ?? false,
    );
  }
}
