import 'dart:async';
import 'dart:ui' show PointerDeviceKind;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:favores_usc/providers/favor_provider.dart';
import 'package:favores_usc/screens/favores/favores_feed_screen.dart';
import 'package:favores_usc/services/favor_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

class _ServicioConFallos implements FavorService {
  final solicitudes = <Completer<QuerySnapshot>>[];
  @override
  Future<QuerySnapshot> obtenerFavoresPaginados({
    DocumentSnapshot? lastDocument,
    int limit = 10,
    String? filtroTipo,
  }) {
    final solicitud = Completer<QuerySnapshot>();
    solicitudes.add(solicitud);
    return solicitud.future;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  testWidgets(
    'el feed permite reintentar bajo el cursor sin confundir errores con falta de red',
    (tester) async {
      final servicio = _ServicioConFallos();
      final mensajes = <String>[];
      final imprimirAnterior = debugPrint;
      debugPrint = (String? mensaje, {int? wrapWidth}) {
        if (mensaje != null) mensajes.add(mensaje);
      };
      addTearDown(() => debugPrint = imprimirAnterior);
      tester.view.physicalSize = const Size(360, 800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            favorSesionUsuarioProvider.overrideWith(
              (ref) => Stream.value(null),
            ),
            favorServiceProvider.overrideWithValue(servicio),
          ],
          child: MaterialApp(
            theme: ThemeData(
              elevatedButtonTheme: ElevatedButtonThemeData(
                style: ElevatedButton.styleFrom(
                  minimumSize: const Size.fromHeight(50),
                ),
              ),
            ),
            home: const FavoresFeedScreen(),
          ),
        ),
      );
      servicio.solicitudes.last.completeError(
        FirebaseException(
          plugin: 'cloud_firestore',
          code: 'failed-precondition',
          message: 'The query requires an index.',
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byIcon(Icons.settings_outlined), findsOneWidget);
      expect(find.byIcon(Icons.wifi_off_rounded), findsNothing);
      expect(tester.takeException(), isNull);
      final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
      await mouse.addPointer(location: Offset.zero);
      addTearDown(mouse.removePointer);
      for (var i = 0; i < 4; i++) {
        await mouse.moveTo(tester.getCenter(find.text('Reintentar')));
        await tester.pump();
        await tester.tap(find.text('Reintentar'));
        await tester.pump();
        servicio.solicitudes.last.completeError(
          FirebaseException(
            plugin: 'cloud_firestore',
            code: 'permission-denied',
          ),
        );
        await tester.pumpAndSettle();
        expect(find.byIcon(Icons.lock_outline_rounded), findsOneWidget);
        expect(tester.takeException(), isNull);
      }
      expect(
        mensajes.any(
          (m) => m.contains('[Favores/feed.inicial] failed-precondition'),
        ),
        true,
      );
      debugPrint = imprimirAnterior;
      expect(
        mensajes.any(
          (m) => m.contains('[Favores/feed.inicial] permission-denied'),
        ),
        true,
      );
    },
  );
}
