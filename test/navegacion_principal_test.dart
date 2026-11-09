import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:favores_usc/screens/principal/principal_screen.dart';

void main() {
  testWidgets('RN06: cuatro pestañas en un ancho móvil', (tester) async {
    await tester.binding.setSurfaceSize(const Size(360, 720));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    var actual = 0;
    const nombres = ['Inicio', 'Favores', 'Objetos', 'Perfil'];
    await tester.pumpWidget(
      MaterialApp(
        home: StatefulBuilder(
          builder: (context, setState) => NavegacionPrincipal(
            indice: actual,
            alSeleccionar: (indice) => setState(() => actual = indice),
            paginas: nombres
                .map((nombre) => Center(child: Text('Pantalla de $nombre')))
                .toList(),
          ),
        ),
      ),
    );
    for (final nombre in ['Favores', 'Objetos', 'Perfil', 'Inicio']) {
      await tester.tap(find.text(nombre));
      await tester.pumpAndSettle();
      expect(find.text('Pantalla de $nombre'), findsOneWidget);
      expect(find.byType(NavigationBar), findsOneWidget);
      expect(tester.takeException(), isNull);
    }
  });
}
