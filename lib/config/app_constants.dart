/// Constantes del sistema FAVORES USC
class AppConstants {
  // Dominio institucional obligatorio (RF01, RN01)
  static const String emailDomain = '@usc.edu.co';

  // Monto mínimo para publicar un favor en COP (RF03)
  static const int minPagoFavor = 1000;

  // Límite de intentos fallidos antes de bloquear (RF02)
  static const int maxIntentosFallidos = 5;

  // Tiempo de bloqueo en minutos (RF02)
  static const int minutosBloqueo = 15;

  // Máximo de fotos permitidas por publicación (RF04)
  static const int maxFotosFavor = 3;
  static const int maxFotoSizeMB = 5;

  static const bloquesCampus = [
    'Bloque 1',
    'Bloque 2',
    'Bloque 3',
    'Bloque 4',
    'Bloque 5',
    'Bloque 6',
    'Bloque 7',
    'Bloque 8',
  ];

  static const zonasComidaDescanso = [
    'Plazoleta de comidas',
    'Plazoleta de los Sabios',
    'El Bosque USC',
    'El Lago',
    'La Fuente',
  ];

  static const zonasDeporteJuegos = [
    'Canchas',
    'Sala de juegos (Bloque 5)',
    'Sala de juegos (Bloque 8)',
    'Plazoleta de la Arena USC',
  ];

  static const laboratorioMatematicas = 'Bloque 6 - Laboratorio de Matemáticas';

  static const accesosCampus = [
    'Entrada del Bloque 1',
    'Medialuna del Bloque 2',
    'Entrada Peatonal Principal (Calle 5)',
    'Entrada Vehicular (Carrera 62)',
    'Parqueadero de estudiantes',
    'Edificio Nuevo - Posgrados',
    laboratorioMatematicas,
  ];

  // Puntos fijos del campus y nombres usados en publicaciones anteriores.
  static const List<String> puntosCampus = [
    ...bloquesCampus,
    ...zonasComidaDescanso,
    ...zonasDeporteJuegos,
    ...accesosCampus,
    'Bloque 1 - Administración Central',
    'Bloque 2 - Biblioteca y Aulas Generales',
    'Bloque 3 - Facultad de Ingeniería',
    'Bloque 4 - Facultad de Salud y Laboratorios',
    'Bloque 5 - Auditorio Aula Máxima',
    'Bloque 7 - Ciencias Básicas',
    'Polideportivo / Canchas Sintéticas',
    'Bulevar USC (restaurantes)',
  ];

  // Programas académicos USC (RF01)
  static const List<String> programasAcademicos = [
    'Ingeniería de Sistemas',
    'Ingeniería Industrial',
    'Ingeniería Electrónica',
    'Medicina',
    'Enfermería',
    'Odontología',
    'Fisioterapia',
    'Derecho',
    'Administración de Empresas',
    'Contaduría Pública',
    'Mercadeo',
    'Comunicación Social',
    'Publicidad',
    'Psicología',
    'Licenciatura en Educación',
  ];

  // Tipos de favores (RF03)
  static const List<String> tiposFavores = [
    'Objeto',
    'Apuntes',
    'Domicilio',
    'Fotocopias / Impresiones',
    'Comida / Cafetería',
    'Cuidar puesto / fila',
    'Préstamo de materiales',
    'Explicación / Tutoría rápida',
    'Transporte / Acompañamiento',
    'Otro favor académico',
  ];
}
