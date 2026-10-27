import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:favores_usc/widgets/foto_prueba_view.dart';

void main() {
  testWidgets('la evidencia permite ampliar y volver sin cambiar el caso', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: FotoPruebaView(url: 'https://example.test/prueba.jpg'),
        ),
      ),
    );
    await tester.pump();
    await tester.tap(find.text('Ampliar foto de prueba'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.byType(InteractiveViewer), findsOneWidget);
    expect(find.text('Foto de prueba'), findsOneWidget);
    await tester.pageBack();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.byType(InteractiveViewer), findsNothing);
    expect(find.text('Ampliar foto de prueba'), findsOneWidget);
  });
}
