import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:favores_usc/widgets/confirmar_objeto_dialog.dart';

void main() {
  for (final estado in ['Confirmado', 'Publicado', 'Entregado']) {
    for (final aceptar in [false, true]) {
      testWidgets('$estado requiere decisión explícita: $aceptar', (
        tester,
      ) async {
        bool? resultado;
        await tester.pumpWidget(
          MaterialApp(
            home: Builder(
              builder: (context) => Scaffold(
                body: TextButton(
                  onPressed: () async {
                    resultado = await showDialog<bool>(
                      context: context,
                      builder: (_) => ConfirmarObjetoDialog(
                        nuevoEstado: estado,
                        esRechazo: estado == 'Publicado',
                      ),
                    );
                  },
                  child: const Text('Abrir'),
                ),
              ),
            ),
          ),
        );
        await tester.tap(find.text('Abrir'));
        await tester.pumpAndSettle();
        expect(resultado, isNull);
        if (estado == 'Entregado') {
          expect(find.textContaining('no se puede deshacer'), findsOneWidget);
        }
        await tester.tap(
          aceptar ? find.byType(FilledButton) : find.text('Volver'),
        );
        await tester.pumpAndSettle();
        expect(resultado, aceptar);
        expect(find.byType(ConfirmarObjetoDialog), findsNothing);
      });
    }
  }
}
