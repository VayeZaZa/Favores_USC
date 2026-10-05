import '../config/app_constants.dart';

/// Validadores para formularios de FAVORES USC (RF01, RF03, RN01)
class Validators {
  /// Valida que el correo termine estrictamente en @usc.edu.co (RF01, RN01)
  static String? validateEmail(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'El correo institucional es obligatorio';
    }
    final trimmed = value.trim().toLowerCase();
    if (!trimmed.endsWith(AppConstants.emailDomain)) {
      return 'El correo debe ser institucional (${AppConstants.emailDomain})';
    }
    // Formato de email básico antes del dominio
    final parts = trimmed.split('@');
    if (parts[0].isEmpty || parts[0].contains(' ')) {
      return 'Ingresa un usuario de correo válido';
    }
    return null;
  }

  /// Valida contraseña mínima de 6 caracteres (Firebase Auth)
  static String? validatePassword(String? value) {
    if (value == null || value.isEmpty) {
      return 'La contraseña es obligatoria';
    }
    if (value.length < 6) {
      return 'La contraseña debe tener al menos 6 caracteres';
    }
    return null;
  }

  /// Valida campo requerido de texto genérico
  static String? validateRequired(String? value, String fieldName) {
    if (value == null || value.trim().isEmpty) {
      return '$fieldName no puede estar vacío';
    }
    return null;
  }

  /// Valida número de teléfono colombiano (10 dígitos)
  static String? validateTelefono(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'El teléfono es obligatorio';
    }
    final clean = value.replaceAll(RegExp(r'\D'), '');
    if (clean.length != 10) {
      return 'Ingresa un teléfono válido de 10 dígitos (ej. 3001234567)';
    }
    return null;
  }

  /// Valida semestre académico entre 1 y 12
  static String? validateSemestre(int? value) {
    if (value == null || value < 1 || value > 12) {
      return 'Selecciona un semestre válido (1 al 12)';
    }
    return null;
  }

  /// Valida monto de pago del favor (>= 1000 COP) (RF03)
  static String? validatePago(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Indica el valor del pago';
    }
    final number = int.tryParse(value.replaceAll(RegExp(r'\D'), ''));
    if (number == null || number < AppConstants.minPagoFavor) {
      return 'El pago mínimo es de \$${AppConstants.minPagoFavor} COP';
    }
    return null;
  }
}
