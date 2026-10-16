import 'package:firebase_core/firebase_core.dart';
import 'package:favores_usc/utils/favor_load_failure.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  FirebaseException fallo(String code, [String? message]) => FirebaseException(
    plugin: 'cloud_firestore',
    code: code,
    message: message,
  );

  test('un índice pendiente no se presenta como falta de conexión', () {
    final error = FavorLoadFailure.from(
      fallo('failed-precondition', 'The query requires an index.'),
    );
    expect(error.kind, FavorLoadFailureKind.indice);
    expect(error.code, 'failed-precondition');
    expect(error.message, isNot(contains('conexión')));
  });

  test('distingue permisos y sesión expirada de problemas de red', () {
    expect(
      FavorLoadFailure.from(fallo('permission-denied')).kind,
      FavorLoadFailureKind.permisos,
    );
    expect(
      FavorLoadFailure.from(fallo('unauthenticated')).kind,
      FavorLoadFailureKind.sesion,
    );
    for (final code in [
      'unavailable',
      'deadline-exceeded',
      'network-request-failed',
    ]) {
      expect(
        FavorLoadFailure.from(fallo(code)).kind,
        FavorLoadFailureKind.conexion,
      );
    }
  });

  test('una precondición distinta de índice conserva un mensaje genérico', () {
    final error = FavorLoadFailure.from(
      fallo('failed-precondition', 'Other precondition'),
    );
    expect(error.kind, FavorLoadFailureKind.desconocido);
  });

  test('los detalles técnicos no se muestran en el mensaje del usuario', () {
    final error = FavorLoadFailure.from(
      fallo('permission-denied', 'internal detail /usuarios/privado'),
    );
    expect(error.message, isNot(contains('internal detail')));
    expect(error.message, isNot(contains('/usuarios/')));
    expect(
      FavorLoadFailure.from(const FormatException('dato interno')).kind,
      FavorLoadFailureKind.datos,
    );
  });
}
