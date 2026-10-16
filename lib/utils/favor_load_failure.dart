import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';

enum FavorLoadFailureKind {
  sesion,
  permisos,
  indice,
  conexion,
  datos,
  desconocido,
}

/// Mensajes de carga para el usuario; el error técnico se conserva en consola.
class FavorLoadFailure {
  const FavorLoadFailure(this.kind, this.message, {this.code});

  final FavorLoadFailureKind kind;
  final String message;
  final String? code;

  factory FavorLoadFailure.from(Object error) {
    if (error is FirebaseException) {
      final code = error.code;
      switch (code) {
        case 'unauthenticated':
          return FavorLoadFailure(
            FavorLoadFailureKind.sesion,
            'Tu sesión terminó. Inicia sesión de nuevo para consultar los favores.',
            code: code,
          );
        case 'permission-denied':
          return FavorLoadFailure(
            FavorLoadFailureKind.permisos,
            'Tu cuenta no tiene permiso para consultar estos favores. Solicita una revisión del acceso.',
            code: code,
          );
        case 'failed-precondition':
          final mensaje = (error.message ?? '').toLowerCase();
          if (mensaje.contains('index') || mensaje.contains('índice')) {
            return FavorLoadFailure(
              FavorLoadFailureKind.indice,
              'La consulta de favores necesita una configuración pendiente en la base de datos.',
              code: code,
            );
          }
        case 'unavailable':
        case 'deadline-exceeded':
        case 'network-request-failed':
          return FavorLoadFailure(
            FavorLoadFailureKind.conexion,
            'No pudimos conectar con el servicio. Revisa tu conexión e intenta de nuevo.',
            code: code,
          );
      }
      return FavorLoadFailure(
        FavorLoadFailureKind.desconocido,
        'No pudimos cargar los favores. Intenta de nuevo.',
        code: code,
      );
    }
    if (error is FormatException || error is TypeError) {
      return const FavorLoadFailure(
        FavorLoadFailureKind.datos,
        'Una publicación tiene datos que la app no puede leer. Solicita una revisión de esa publicación.',
      );
    }
    return const FavorLoadFailure(
      FavorLoadFailureKind.desconocido,
      'No pudimos cargar los favores. Intenta de nuevo.',
    );
  }
}

void registrarErrorCargaFavor(
  String operacion,
  Object error,
  StackTrace stack,
) {
  if (kDebugMode) {
    final fallo = FavorLoadFailure.from(error);
    // Incluye el mensaje original: Firestore puede proporcionar el enlace del índice.
    debugPrint('[Favores/$operacion] ${fallo.code ?? fallo.kind.name}: $error');
    debugPrintStack(
      label: '[Favores/$operacion] Origen del error',
      stackTrace: stack,
    );
  }
}
