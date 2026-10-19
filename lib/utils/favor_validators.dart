import '../config/app_constants.dart';

/// Reglas compartidas por el formulario y el servicio de publicación.
class FavorValidators {
  static String? imagen({required String ruta, required int bytes}) {
    final nombre = ruta.toLowerCase();
    if (!['.jpg', '.jpeg', '.png'].any(nombre.endsWith)) {
      return 'Selecciona una imagen JPG o PNG.';
    }
    if (bytes <= 0 || bytes > AppConstants.maxFotoSizeMB * 1024 * 1024) {
      return 'Cada foto debe pesar como máximo ${AppConstants.maxFotoSizeMB} MB y no estar vacía.';
    }
    return null;
  }

  static String? titulo(String? valor) => valor == null || valor.trim().isEmpty
      ? 'Ingresa el título del favor.'
      : null;

  static String? descripcion(String? valor) =>
      valor == null || valor.trim().length < 5
      ? 'Describe lo que necesitas (mínimo 5 caracteres).'
      : null;

  static String? pago(String? valor) {
    final monto = int.tryParse(valor?.trim() ?? '');
    return monto == null || monto < AppConstants.minPagoFavor
        ? 'El pago mínimo es \$${AppConstants.minPagoFavor} COP.'
        : null;
  }

  static String? ubicacion(String? valor) =>
      AppConstants.puntosCampus.contains(valor)
      ? null
      : 'Selecciona un punto fijo válido dentro del campus USC.';

  static String? tipo(String? valor) =>
      AppConstants.tiposFavores.contains(valor)
      ? null
      : 'Selecciona un tipo de favor válido.';

  static void validarPublicacion({
    required String idAutor,
    required String tituloFavor,
    required String descripcionFavor,
    required String tipoFavor,
    required String ubicacionFavor,
    required int pagoFavor,
    required int cantidadFotos,
  }) {
    final errores = [
      if (idAutor.trim().isEmpty) 'Debes iniciar sesión para publicar.',
      titulo(tituloFavor),
      descripcion(descripcionFavor),
      tipo(tipoFavor),
      ubicacion(ubicacionFavor),
      pago(pagoFavor.toString()),
      if (cantidadFotos < 0 || cantidadFotos > AppConstants.maxFotosFavor)
        'Solo se permiten máximo ${AppConstants.maxFotosFavor} fotos por favor.',
    ];
    for (final error in errores) {
      if (error != null) throw Exception(error);
    }
  }
}
