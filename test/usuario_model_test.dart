import 'package:flutter_test/flutter_test.dart';
import 'package:favores_usc/models/usuario_model.dart';

void main() {
  test('serializes user data with the existing Firestore schema', () {
    final usuario = UsuarioModel(
      uid: 'user-123',
      nombre: 'David Lopez',
      correo: 'david.lopez05@usc.edu.co',
      programa: 'Ingenieria de Sistemas',
      semestre: 6,
      telefono: '3101234567',
      verificado: false,
      favoresCompletados: 0,
      favoresDevueltos: 0,
      favoresPedidos: 0,
      objetosDevueltos: 0,
      promedio: 5.0,
      insignias: const ['novato_solidario'],
    );

    final map = usuario.toMap();

    expect(map['display_name'], 'David Lopez');
    expect(map['email'], 'david.lopez05@usc.edu.co');
    expect(map['phone_number'], '3101234567');
    expect(map['favoresCompletados'], 0);
    expect(map['favoresDevueltos'], 0);
    expect(map['favoresPedidos'], 0);
    expect(map['objetosDevueltos'], 0);
    expect(map['promedioCalificacion'], 5.0);
    expect(map['insignias'], ['novato_solidario']);
    expect(map.containsKey('nombre'), isFalse);
    expect(map.containsKey('correo'), isFalse);
    expect(map.containsKey('telefono'), isFalse);
    expect(map.containsKey('promedio'), isFalse);
  });

  test('reads the existing Firestore field names', () {
    final usuario = UsuarioModel.fromMap({
      'display_name': 'David Lopez',
      'email': 'david.lopez05@usc.edu.co',
      'phone_number': '3101234567',
      'programa': 'Ingenieria de Sistemas',
      'semestre': 6,
      'verificado': true,
      'favoresCompletados': 2,
      'favoresDevueltos': 1,
      'favoresPedidos': 3,
      'objetosDevueltos': 4,
      'promedioCalificacion': 4.8,
      'insignias': ['novato_solidario'],
    }, 'user-123');

    expect(usuario.uid, 'user-123');
    expect(usuario.nombre, 'David Lopez');
    expect(usuario.correo, 'david.lopez05@usc.edu.co');
    expect(usuario.telefono, '3101234567');
    expect(usuario.favoresDevueltos, 1);
    expect(usuario.favoresPedidos, 3);
    expect(usuario.promedio, 4.8);
    expect(usuario.insignias, ['novato_solidario']);
  });
}
