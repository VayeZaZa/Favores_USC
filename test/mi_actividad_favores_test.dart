import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:favores_usc/providers/favor_provider.dart';
import 'package:favores_usc/screens/favores/mi_actividad_favores_screen.dart';
import 'package:favores_usc/services/favor_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late FakeFirebaseFirestore db;
  late FavorService servicio;
  setUp(() {
    db = FakeFirebaseFirestore();
    servicio = FavorService(firestore: db, usuarioActualId: () => 'autor');
  });

  Future<void> mostrar(WidgetTester tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [favorServiceProvider.overrideWithValue(servicio)],
        child: MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: ThemeData(
            colorScheme: ColorScheme.fromSeed(
              seedColor: const Color(0xFF1265D8),
            ),
          ),
          home: const MiActividadFavoresScreen(usuarioId: 'autor'),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  Future<void> documento(
    String id, {
    String autor = 'autor',
    String? ayudante,
    String estado = 'Publicado',
  }) => db.doc('favores/$id').set({
    'titulo': id,
    'idAutor': autor,
    'idAyudante': ayudante,
    'estado': estado,
    'pago': 2000,
    'fechaCreacion': Timestamp.fromDate(
      DateTime.now().subtract(const Duration(hours: 25)),
    ),
  });

  testWidgets('la actividad se adapta a una pantalla móvil de 320 px', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 740);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await documento('Apuntes de Cálculo II para estudiar el parcial');
    await mostrar(tester);
    expect(tester.takeException(), isNull);
    expect(find.text('Republicar'), findsOneWidget);
  });

  testWidgets('muestra una actividad vacía sin error', (tester) async {
    await mostrar(tester);
    expect(
      find.text('Todavía no hay favores en esta sección.'),
      findsOneWidget,
    );
    expect(find.text('Crear favor'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('retirar conserva el favor como cancelado', (tester) async {
    await documento('Favor de prueba');
    await mostrar(tester);
    expect(find.text('Republicar'), findsOneWidget);
    await tester.tap(find.text('Retirar'));
    await tester.pumpAndSettle();
    expect(find.text('¿Retirar este favor?'), findsOneWidget);
    await tester.tap(find.text('Retirar').last);
    await tester.pumpAndSettle();
    expect((await db.doc('favores/Favor de prueba').get()).exists, true);
    expect(
      (await db.doc('favores/Favor de prueba').get()).get('estado'),
      'Cancelado',
    );
    expect(find.text('Cancelado'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('cada pestaña muestra los favores correspondientes al usuario', (
    tester,
  ) async {
    await documento('Pedido propio');
    await documento(
      'Ayuda asignada',
      autor: 'otra-persona',
      ayudante: 'autor',
      estado: 'Aceptado',
    );
    await documento('Ajeno', autor: 'otra-persona', ayudante: 'otra');
    await documento(
      'Entrega propia',
      ayudante: 'ayudante',
      estado: 'Entregado',
    );
    await mostrar(tester);
    expect(find.text('Pedido propio'), findsOneWidget);
    expect(find.text('Ayuda asignada'), findsNothing);
    await tester.tap(find.text('Ayudando'));
    await tester.pumpAndSettle();
    expect(find.text('Ayuda asignada'), findsOneWidget);
    expect(find.text('Pedido propio'), findsNothing);
    await tester.tap(find.text('Historial'));
    await tester.pumpAndSettle();
    expect(find.text('Entrega propia'), findsOneWidget);
    expect(find.text('Ajeno'), findsNothing);
    expect(tester.takeException(), isNull);
  });
}
