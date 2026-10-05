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

  // Puntos fijos del campus USC Pampalinda (RF03, RN04: sin GPS)
  static const List<String> puntosCampus = [
    'Bloque 1 - Administración Central',
    'Bloque 2 - Biblioteca y Aulas Generales',
    'Bloque 3 - Facultad de Ingeniería',
    'Bloque 4 - Facultad de Salud y Laboratorios',
    'Bloque 5 - Auditorio Aula Máxima',
    'Bloque 6 - Cafetería Central / Plazoleta',
    'Bloque 7 - Ciencias Básicas',
    'Polideportivo / Canchas Sintéticas',
    'Edificio Nuevo - Posgrados',
    'Entrada Peatonal Principal (Calle 5)',
    'Entrada Vehicular (Carrera 62)',
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
    'Fotocopias / Impresiones',
    'Comida / Cafetería',
    'Cuidar puesto / fila',
    'Préstamo de materiales',
    'Explicación / Tutoría rápida',
    'Transporte / Acompañamiento',
    'Otro favor académico',
  ];
}
