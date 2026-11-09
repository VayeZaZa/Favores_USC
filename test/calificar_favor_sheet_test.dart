import 'package:favores_usc/screens/favores/widgets/calificar_favor_sheet.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('pide elegir estrellas y conserva el comentario al reintentar', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(360, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final intentos = <(int, String)>[];
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => TextButton(
              onPressed: () => showModalBottomSheet<bool>(
                context: context,
                isScrollControlled: true,
                builder: (_) => CalificarFavorSheet(
                  tituloFavor: 'Entrega de apuntes',
                  nombre: 'David San',
                  foto: '',
                  enviar: (estrellas, comentario) async {
                    intentos.add((estrellas, comentario));
                    if (intentos.length == 1) {
                      throw Exception('No se pudo guardar');
                    }
                  },
                ),
              ),
              child: const Text('Abrir'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Abrir'));
    await tester.pumpAndSettle();

    final boton = find.widgetWithText(FilledButton, 'Enviar calificación');
    expect(find.text('David San'), findsOneWidget);
    expect(tester.widget<FilledButton>(boton).onPressed, isNull);
    await tester.tap(find.byIcon(Icons.star_rounded).at(3));
    await tester.enterText(find.byType(TextField), 'Llegó a tiempo');
    await tester.ensureVisible(boton);
    await tester.tap(boton);
    await tester.pumpAndSettle();

    expect(find.text('No se pudo guardar'), findsOneWidget);
    expect(find.text('Llegó a tiempo'), findsOneWidget);
    await tester.ensureVisible(boton);
    await tester.tap(boton);
    await tester.pumpAndSettle();

    expect(intentos, [(4, 'Llegó a tiempo'), (4, 'Llegó a tiempo')]);
    expect(find.byType(CalificarFavorSheet), findsNothing);
    expect(tester.takeException(), isNull);
  });
}
