import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:favores_usc/widgets/chat_status_view.dart';

void main() {
  testWidgets('el estado de carga no ofrece reintentos simultáneos', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ChatStatusView(
            titulo: 'Abriendo',
            cargando: true,
            reintentar: () {},
          ),
        ),
      ),
    );
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    expect(find.text('Reintentar'), findsNothing);
  });
  testWidgets('un error ofrece reintento explícito', (tester) async {
    var intentos = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ChatStatusView(
            titulo: 'No se pudo cargar',
            reintentar: () => intentos++,
          ),
        ),
      ),
    );
    await tester.tap(find.text('Reintentar'));
    expect(intentos, 1);
  });
}
