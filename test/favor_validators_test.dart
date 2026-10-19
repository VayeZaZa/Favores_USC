import 'package:favores_usc/config/app_constants.dart';
import 'package:favores_usc/utils/favor_validators.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  void validar({
    String autor = 'estudiante',
    String titulo = 'Copias de cálculo',
    String descripcion = 'Llevar copias a la biblioteca',
    String tipo = 'Apuntes',
    String? ubicacion,
    int pago = 1000,
    int fotos = 0,
  }) => FavorValidators.validarPublicacion(
    idAutor: autor,
    tituloFavor: titulo,
    descripcionFavor: descripcion,
    tipoFavor: tipo,
    ubicacionFavor: ubicacion ?? AppConstants.puntosCampus.first,
    pagoFavor: pago,
    cantidadFotos: fotos,
  );

  test('las tres categorías del formulario permiten publicar', () {
    for (final tipo in ['Objeto', 'Apuntes', 'Domicilio']) {
      expect(() => validar(tipo: tipo), returnsNormally);
    }
  });

  test('rechaza campos vacíos y ubicaciones fuera del campus', () {
    expect(() => validar(autor: ''), throwsException);
    expect(() => validar(titulo: '  '), throwsException);
    expect(() => validar(descripcion: '  '), throwsException);
    expect(() => validar(tipo: 'Desconocido'), throwsException);
    expect(() => validar(ubicacion: 'Mi casa'), throwsException);
  });

  test('acepta el pago mínimo y no impone un máximo', () {
    expect(() => validar(pago: 999), throwsException);
    expect(() => validar(pago: 1000), returnsNormally);
    expect(() => validar(pago: 999999999), returnsNormally);
    expect(FavorValidators.pago('1.5'), isNotNull);
    expect(FavorValidators.pago('abc'), isNotNull);
  });

  test('acepta fotos opcionales y rechaza más de tres', () {
    expect(() => validar(fotos: 0), returnsNormally);
    expect(() => validar(fotos: 3), returnsNormally);
    expect(() => validar(fotos: 4), throwsException);
  });

  test('valida formato y límite de 5 MB antes de comprimir', () {
    const limite = 5 * 1024 * 1024;
    for (final ruta in ['foto.JPG', 'foto.jpeg', 'foto.png']) {
      expect(FavorValidators.imagen(ruta: ruta, bytes: limite), isNull);
    }
    expect(FavorValidators.imagen(ruta: 'foto.gif', bytes: 10), isNotNull);
    expect(FavorValidators.imagen(ruta: 'foto.jpg', bytes: 0), isNotNull);
    expect(
      FavorValidators.imagen(ruta: 'foto.jpg', bytes: limite + 1),
      isNotNull,
    );
  });
}
