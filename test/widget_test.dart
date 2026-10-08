// This is a basic Flutter widget test.
//
// To perform an interaction with a widget in your test, use the WidgetTester
// utility in the flutter_test package. For example, you can send tap and scroll
// gestures. You can also use WidgetTester to find child widgets in the widget
// tree, read text, and verify that the values of widget properties are correct.

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:favores_usc/main.dart';

void main() {
  testWidgets('welcome slides navigate to login and registration', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const ProviderScope(child: FavoresUscApp()));
    await tester.pumpAndSettle();

    expect(find.text('Tu universidad,\nmás cerca'), findsOneWidget);

    await tester.tap(find.text('Siguiente'));
    await tester.pumpAndSettle();
    expect(find.text('La vida en la USC,\nse hace en equipo'), findsOneWidget);

    await tester.tap(find.text('Siguiente'));
    await tester.pumpAndSettle();
    expect(find.text('Lo que se pierde,\npuede volver'), findsOneWidget);

    await tester.tap(find.text('Comenzar'));
    await tester.pumpAndSettle();
    expect(find.text('Correo institucional'), findsOneWidget);

    await tester.ensureVisible(find.text('Regístrate'));
    await tester.tap(find.text('Regístrate'));
    await tester.pumpAndSettle();
    expect(find.text('Datos personales'), findsOneWidget);
  });
}
