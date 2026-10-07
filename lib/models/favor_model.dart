import 'package:cloud_firestore/cloud_firestore.dart';

/// Modelo de Favor para FAVORES USC (RF03, RF04, RF05, RF08, RF16)
class FavorModel {
  final String id;
  final String idAutor; // Referencia al usuario creador
  final String nombreAutor;
  final String? idAyudante; // Referencia al usuario que acepta el favor
  final String tipoServicio;
  final String titulo;
  final String descripcion;
  final String ubicacion; // Puntos fijos del campus (sin GPS)
  final int pago; // Monto en COP >= 1000
  final String estado; // "Publicado", "Aceptado", "Entregado", "Cancelado"
  final List<String> urlFotos; // Hasta 3 fotos en Cloudinary (RF04)
  final DateTime fechaCreacion;
  final bool soloLectura;
  final bool yaAvisado24h; // RF16: notificación tras 24h sin aceptar
  final bool calificacionHabilitada; // RF08, RF09: true cuando pasa a "Entregado"

  FavorModel({
    required this.id,
    required this.idAutor,
    this.nombreAutor = '',
    this.idAyudante,
    required this.tipoServicio,
    required this.titulo,
    required this.descripcion,
    required this.ubicacion,
    required this.pago,
    this.estado = 'Publicado',
    this.urlFotos = const [],
    required this.fechaCreacion,
    this.soloLectura = false,
    this.yaAvisado24h = false,
    this.calificacionHabilitada = false,
  });

  String get tipo => tipoServicio;
  bool get yaAvisado => yaAvisado24h;
  bool get esPublicado => estado == 'Publicado';
  bool get esAceptado => estado == 'Aceptado';
  bool get esEntregado => estado == 'Entregado';
  bool get esCancelado => estado == 'Cancelado';

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'idAutor': idAutor,
      'idAyudante': idAyudante,
      'nombreAutor': nombreAutor,
      'tipo': tipoServicio,
      'tipoServicio': tipoServicio,
      'titulo': titulo,
      'descripcion': descripcion,
      'ubicacion': ubicacion,
      'pago': pago,
      'estado': estado,
      'urlFotos': urlFotos,
      'fechaCreacion': Timestamp.fromDate(fechaCreacion),
      'soloLectura': soloLectura,
      'yaAvisado': yaAvisado24h,
      'yaAvisado24h': yaAvisado24h,
      'calificacionHabilitada': calificacionHabilitada,
    };
  }

  factory FavorModel.fromMap(Map<String, dynamic> map, String id) {
    final rawAutor = map['idAutor'];
    final idAutor = rawAutor is DocumentReference
        ? rawAutor.id
        : rawAutor is String
        ? rawAutor.split('/').last
        : '';
    final rawFecha = map['fechaCreacion'];
    final rawFotos = map['urlFotos'];

    return FavorModel(
      id: id,
      idAutor: idAutor,
      nombreAutor: map['nombreAutor'] as String? ?? '',
      idAyudante: map['idAyudante'] is DocumentReference
          ? (map['idAyudante'] as DocumentReference).id
          : map['idAyudante'] as String?,
      tipoServicio: map['tipoServicio'] as String? ?? map['tipo'] as String? ?? '',
      titulo: map['titulo'] as String? ?? '',
      descripcion: map['descripcion'] ?? '',
      ubicacion: map['ubicacion'] ?? '',
      pago: (map['pago'] as num?)?.toInt() ?? 0,
      estado: map['estado'] ?? 'Publicado',
      urlFotos: rawFotos is List ? List<String>.from(rawFotos) : const [],
      fechaCreacion: rawFecha is Timestamp
          ? rawFecha.toDate()
          : rawFecha is DateTime
          ? rawFecha
          : DateTime.now(),
      soloLectura: map['soloLectura'] as bool? ?? false,
      yaAvisado24h:
          map['yaAvisado24h'] as bool? ?? map['yaAvisado'] as bool? ?? false,
      calificacionHabilitada: map['calificacionHabilitada'] ?? false,
    );
  }
}
