import 'package:cloud_firestore/cloud_firestore.dart';

/// Máquina de Estados estricta para Objetos (RF13)
/// Secuencia estricta: Publicado -> Pendiente -> Confirmado -> Entregado.
/// Retroceso permitido únicamente a Publicado por rechazo o no entrega.
enum EstadoObjeto {
  publicado('Publicado'),
  pendiente('Pendiente'),
  confirmado('Confirmado'),
  entregado('Entregado');

  final String valor;
  const EstadoObjeto(this.valor);

  static EstadoObjeto fromString(String? estado) {
    switch (estado?.toLowerCase().trim()) {
      case 'pendiente':
        return EstadoObjeto.pendiente;
      case 'confirmado':
        return EstadoObjeto.confirmado;
      case 'entregado':
        return EstadoObjeto.entregado;
      case 'publicado':
      default:
        return EstadoObjeto.publicado;
    }
  }

  /// Validador estricto de transiciones (RF13)
  bool puedeTransicionarA(EstadoObjeto nuevoEstado, {bool esRechazo = false}) {
    // Si ya está entregado, el caso está cerrado de forma terminal
    if (this == EstadoObjeto.entregado) return false;

    // Transiciones hacia adelante estrictas
    if (this == EstadoObjeto.publicado && nuevoEstado == EstadoObjeto.pendiente) {
      return true;
    }
    if (this == EstadoObjeto.pendiente && nuevoEstado == EstadoObjeto.confirmado) {
      return true;
    }
    if (this == EstadoObjeto.confirmado && nuevoEstado == EstadoObjeto.entregado) {
      return true;
    }

    // Retroceso legal: solo hacia 'Publicado' por rechazo o cancelación de entrega
    if ((this == EstadoObjeto.pendiente || this == EstadoObjeto.confirmado) &&
        nuevoEstado == EstadoObjeto.publicado &&
        esRechazo) {
      return true;
    }

    // Cualquier otro salto no está permitido
    return false;
  }
}

/// Modelo de Objeto Perdido o Encontrado (RF10, RF11, RF12, RF13)
class ObjetoModel {
  const ObjetoModel({
    required this.id,
    required this.idDueno,
    this.nombreDueno = '',
    required this.titulo,
    required this.descripcion,
    required this.tipo, // 'perdido' o 'encontrado'
    required this.etiquetaColor, // 'rojo', 'verde', 'azul', etc.
    required this.lugarCampus,
    this.urlFoto = '', // Cloudinary (obligatorio si tipo == 'encontrado')
    this.estadoActual = 'Publicado',
    this.idReclamante,
    this.nombreReclamante,
    this.fotoPruebaUrl,
    required this.fechaReporte,
    this.fechaActualizacion,
    this.soloLectura = false,
  });

  final String id;
  final String idDueno;
  final String nombreDueno;
  final String titulo;
  final String descripcion;
  final String tipo; // 'perdido' | 'encontrado'
  final String etiquetaColor; // Color distintivo para la tarjeta
  final String lugarCampus;
  final String urlFoto;
  final String estadoActual;
  final String? idReclamante;
  final String? nombreReclamante;
  final String? fotoPruebaUrl;
  final DateTime fechaReporte;
  final DateTime? fechaActualizacion;
  final bool soloLectura;

  // Getters de conveniencia
  bool get esPerdido => tipo.toLowerCase() == 'perdido';
  bool get esEncontrado => tipo.toLowerCase() == 'encontrado';
  bool get esPublicado => estadoActual == 'Publicado';
  bool get esPendiente => estadoActual == 'Pendiente';
  bool get esConfirmado => estadoActual == 'Confirmado';
  bool get esEntregado => estadoActual == 'Entregado';
  bool get casoCerrado => esEntregado || soloLectura;

  EstadoObjeto get estadoEnum => EstadoObjeto.fromString(estadoActual);

  /// Valida si se puede cambiar a un nuevo estado según RF13
  bool validarCambioEstado(String nuevoEstadoStr, {bool esRechazo = false}) {
    final nuevo = EstadoObjeto.fromString(nuevoEstadoStr);
    return estadoEnum.puedeTransicionarA(nuevo, esRechazo: esRechazo);
  }

  Map<String, dynamic> toMap() {
    return {
      'idDueno': idDueno,
      'nombreDueno': nombreDueno,
      'titulo': titulo,
      'descripcion': descripcion,
      'tipo': tipo,
      'etiquetaColor': etiquetaColor,
      'lugarCampus': lugarCampus,
      'urlFoto': urlFoto,
      'estadoActual': estadoActual,
      'idReclamante': idReclamante,
      'nombreReclamante': nombreReclamante,
      'fotoPruebaUrl': fotoPruebaUrl,
      'fechaReporte': Timestamp.fromDate(fechaReporte),
      'fechaActualizacion': fechaActualizacion != null
          ? Timestamp.fromDate(fechaActualizacion!)
          : FieldValue.serverTimestamp(),
      'soloLectura': casoCerrado,
    };
  }

  factory ObjetoModel.fromMap(Map<String, dynamic> map, String id) {
    final rawDueno = map['idDueno'];
    final rawFechaReporte = map['fechaReporte'];
    final rawFechaAct = map['fechaActualizacion'];

    DateTime parseFecha(dynamic raw) {
      if (raw is Timestamp) return raw.toDate();
      if (raw is DateTime) return raw;
      return DateTime.now();
    }

    final estado = map['estadoActual'] as String? ?? 'Publicado';
    final soloLect = (map['soloLectura'] as bool? ?? false) || estado == 'Entregado';

    return ObjetoModel(
      id: id,
      idDueno: rawDueno is DocumentReference
          ? rawDueno.id
          : rawDueno is String
              ? rawDueno.split('/').last
              : '',
      nombreDueno: map['nombreDueno'] as String? ?? '',
      titulo: map['titulo'] as String? ?? '',
      descripcion: map['descripcion'] as String? ?? '',
      tipo: map['tipo'] as String? ?? 'perdido',
      etiquetaColor: map['etiquetaColor'] as String? ?? 'rojo',
      lugarCampus: map['lugarCampus'] as String? ?? '',
      urlFoto: map['urlFoto'] as String? ?? '',
      estadoActual: estado,
      idReclamante: map['idReclamante'] as String?,
      nombreReclamante: map['nombreReclamante'] as String?,
      fotoPruebaUrl: map['fotoPruebaUrl'] as String?,
      fechaReporte: parseFecha(rawFechaReporte),
      fechaActualizacion: rawFechaAct != null ? parseFecha(rawFechaAct) : null,
      soloLectura: soloLect,
    );
  }

  ObjetoModel copyWith({
    String? id,
    String? idDueno,
    String? nombreDueno,
    String? titulo,
    String? descripcion,
    String? tipo,
    String? etiquetaColor,
    String? lugarCampus,
    String? urlFoto,
    String? estadoActual,
    String? idReclamante,
    String? nombreReclamante,
    String? fotoPruebaUrl,
    DateTime? fechaReporte,
    DateTime? fechaActualizacion,
    bool? soloLectura,
  }) {
    return ObjetoModel(
      id: id ?? this.id,
      idDueno: idDueno ?? this.idDueno,
      nombreDueno: nombreDueno ?? this.nombreDueno,
      titulo: titulo ?? this.titulo,
      descripcion: descripcion ?? this.descripcion,
      tipo: tipo ?? this.tipo,
      etiquetaColor: etiquetaColor ?? this.etiquetaColor,
      lugarCampus: lugarCampus ?? this.lugarCampus,
      urlFoto: urlFoto ?? this.urlFoto,
      estadoActual: estadoActual ?? this.estadoActual,
      idReclamante: idReclamante ?? this.idReclamante,
      nombreReclamante: nombreReclamante ?? this.nombreReclamante,
      fotoPruebaUrl: fotoPruebaUrl ?? this.fotoPruebaUrl,
      fechaReporte: fechaReporte ?? this.fechaReporte,
      fechaActualizacion: fechaActualizacion ?? this.fechaActualizacion,
      soloLectura: soloLectura ?? this.soloLectura,
    );
  }
}
