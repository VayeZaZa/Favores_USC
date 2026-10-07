import 'package:cloud_firestore/cloud_firestore.dart';

/// Modelo de Usuario en Firestore para FAVORES USC (RF01, RF02, RF09, RF14, RF15)
class UsuarioModel {
  final String uid;
  final String nombre;
  final String correo;
  final String programa;
  final int semestre;
  final String telefono;
  final bool verificado; // RF01: cuenta activa solo si verificado == true
  final int intentosFallidos; // RF02: suma 1 si falla contraseña
  final DateTime? bloqueadoHasta; // RF02: 15 min de bloqueo si llega a 5
  final String? tokenFCM; // RF06: notificaciones push
  final int favoresCompletados; // RF14, RF15
  final int favoresDevueltos;
  final int favoresPedidos;
  final int objetosDevueltos; // RF14, RF15
  final double promedio; // RF09, RF15: calificación promedio (1.0 a 5.0)
  final List<String> insignias; // RF14: lista de insignias obtenidas

  UsuarioModel({
    required this.uid,
    required this.nombre,
    required this.correo,
    required this.programa,
    required this.semestre,
    required this.telefono,
    this.verificado = false,
    this.intentosFallidos = 0,
    this.bloqueadoHasta,
    this.tokenFCM,
    this.favoresCompletados = 0,
    this.favoresDevueltos = 0,
    this.favoresPedidos = 0,
    this.objetosDevueltos = 0,
    this.promedio = 5.0,
    this.insignias = const ['novato_solidario'],
  });

  /// Verifica si el usuario está actualmente bloqueado por intentos fallidos (RF02)
  bool get estaBloqueado {
    if (bloqueadoHasta == null) return false;
    return DateTime.now().isBefore(bloqueadoHasta!);
  }

  /// Minutos restantes de bloqueo
  int get minutosRestantesBloqueo {
    if (!estaBloqueado) return 0;
    return bloqueadoHasta!.difference(DateTime.now()).inMinutes + 1;
  }

  Map<String, dynamic> toMap() {
    return {
      'uid': uid,
      'nombre': nombre,
      'display_name': nombre,
      'correo': correo,
      'email': correo,
      'telefono': telefono,
      'phone_number': telefono,
      'programa': programa,
      'semestre': semestre,
      'verificado': verificado,
      'intentosFallidos': intentosFallidos,
      'bloqueadoHasta': bloqueadoHasta != null
          ? Timestamp.fromDate(bloqueadoHasta!)
          : null,
      'tokenFCM': tokenFCM,
      'favoresCompletados': favoresCompletados,
      'favoresDevueltos': favoresDevueltos,
      'favoresPedidos': favoresPedidos,
      'objetosDevueltos': objetosDevueltos,
      'promedio': promedio,
      'promedioCalificacion': promedio,
      'insignias': insignias.isEmpty ? const ['novato_solidario'] : insignias,
    };
  }

  factory UsuarioModel.fromMap(Map<String, dynamic> map, String id) {
    final rawInsignias = map['insignias'];
    var insignias = rawInsignias is List
        ? List<String>.from(rawInsignias)
        : rawInsignias is String
        ? [rawInsignias]
        : <String>[];
    if (insignias.isEmpty) {
      insignias = const ['novato_solidario'];
    }
    final rawBloqueadoHasta = map['bloqueadoHasta'];

    return UsuarioModel(
      uid: id,
      nombre: map['display_name'] ?? map['nombre'] ?? '',
      correo: map['email'] ?? map['correo'] ?? '',
      programa: map['programa'] ?? '',
      semestre: (map['semestre'] as num?)?.toInt() ?? 1,
      telefono: map['phone_number'] ?? map['telefono'] ?? '',
      verificado: map['verificado'] ?? false,
      intentosFallidos: (map['intentosFallidos'] as num?)?.toInt() ?? 0,
      bloqueadoHasta: rawBloqueadoHasta is Timestamp
          ? rawBloqueadoHasta.toDate()
          : rawBloqueadoHasta is DateTime
          ? rawBloqueadoHasta
          : null,
      tokenFCM: map['tokenFCM'],
      favoresCompletados: (map['favoresCompletados'] as num?)?.toInt() ?? 0,
      favoresDevueltos: (map['favoresDevueltos'] as num?)?.toInt() ?? 0,
      favoresPedidos: (map['favoresPedidos'] as num?)?.toInt() ?? 0,
      objetosDevueltos: (map['objetosDevueltos'] as num?)?.toInt() ?? 0,
      promedio: (map['promedioCalificacion'] as num?)?.toDouble()
          ?? (map['promedio'] as num?)?.toDouble()
          ?? 5.0,
      insignias: insignias,
    );
  }

  UsuarioModel copyWith({
    String? nombre,
    String? correo,
    String? programa,
    int? semestre,
    String? telefono,
    bool? verificado,
    int? intentosFallidos,
    DateTime? bloqueadoHasta,
    String? tokenFCM,
    int? favoresCompletados,
    int? favoresDevueltos,
    int? favoresPedidos,
    int? objetosDevueltos,
    double? promedio,
    List<String>? insignias,
  }) {
    return UsuarioModel(
      uid: uid,
      nombre: nombre ?? this.nombre,
      correo: correo ?? this.correo,
      programa: programa ?? this.programa,
      semestre: semestre ?? this.semestre,
      telefono: telefono ?? this.telefono,
      verificado: verificado ?? this.verificado,
      intentosFallidos: intentosFallidos ?? this.intentosFallidos,
      bloqueadoHasta: bloqueadoHasta ?? this.bloqueadoHasta,
      tokenFCM: tokenFCM ?? this.tokenFCM,
      favoresCompletados: favoresCompletados ?? this.favoresCompletados,
      favoresDevueltos: favoresDevueltos ?? this.favoresDevueltos,
      favoresPedidos: favoresPedidos ?? this.favoresPedidos,
      objetosDevueltos: objetosDevueltos ?? this.objetosDevueltos,
      promedio: promedio ?? this.promedio,
      insignias: insignias ?? this.insignias,
    );
  }
}
