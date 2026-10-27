import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:favores_usc/services/objeto_service.dart';

void main() {
  late FakeFirebaseFirestore db;
  late ObjetoService service;
  String? uid;

  setUp(() async {
    db = FakeFirebaseFirestore();
    uid = 'dueno';
    service = ObjetoService(firestore: db, usuarioActual: () => uid);
    await db.collection('objetos').doc('objeto').set({
      'idDueno': 'dueno',
      'idReclamante': 'ayudante',
      'estadoActual': 'Pendiente',
      'chatId': 'chat',
      'fotoPruebaUrl': 'https://example.test/prueba.jpg',
    });
    await db.collection('chats').doc('chat').set({'soloLectura': false});
  });

  Future<void> cambiar(
    String estado, {
    String actor = 'dueno',
    String esperado = 'Pendiente',
    String chat = 'chat',
    bool rechazo = false,
  }) => service.cambiarEstadoObjeto(
    idObjeto: 'objeto',
    nuevoEstadoStr: estado,
    idUsuarioAccion: actor,
    chatIdEsperado: chat,
    estadoEsperado: esperado,
    esRechazo: rechazo,
  );

  for (final actor in ['ayudante', 'externo']) {
    test('$actor no puede confirmar, rechazar ni cerrar', () async {
      uid = actor;
      for (final estado in ['Confirmado', 'Publicado', 'Entregado']) {
        await expectLater(
          cambiar(estado, actor: actor, rechazo: true),
          throwsStateError,
        );
        expect(
          (await db.collection('objetos').doc('objeto').get())
              .data()!['estadoActual'],
          'Pendiente',
        );
      }
    });
  }
  test('una sesión externa no puede suplantar al dueño', () async {
    uid = 'externo';
    await expectLater(cambiar('Confirmado'), throwsStateError);
    uid = null;
    await expectLater(cambiar('Confirmado'), throwsStateError);
  });
  test('la segunda intención sobre el estado anterior se rechaza', () async {
    await cambiar('Confirmado');
    await expectLater(cambiar('Publicado', rechazo: true), throwsStateError);
    expect(
      (await db.collection('objetos').doc('objeto').get())
          .data()!['estadoActual'],
      'Confirmado',
    );
  });
  test('no se puede gestionar un reclamo desde un chat anterior', () async {
    await expectLater(
      cambiar('Confirmado', chat: 'anterior'),
      throwsStateError,
    );
  });
  test('rechazar libera el reclamo y bloquea la conversación', () async {
    await cambiar('Publicado', rechazo: true);
    final objeto = (await db.collection('objetos').doc('objeto').get()).data()!;
    expect(objeto['estadoActual'], 'Publicado');
    expect(objeto['idReclamante'], isNull);
    expect(objeto['fotoPruebaUrl'], isNull);
    expect(objeto['chatId'], isNull);
    expect(
      (await db.collection('chats').doc('chat').get()).data()!['soloLectura'],
      isTrue,
    );
  });
  test('entregar cierra objeto y chat y bloquea retrocesos', () async {
    await cambiar('Confirmado');
    await cambiar('Entregado', esperado: 'Confirmado');
    final objeto = (await db.collection('objetos').doc('objeto').get()).data()!;
    expect(objeto['soloLectura'], isTrue);
    expect(
      (await db.collection('chats').doc('chat').get()).data()!['soloLectura'],
      isTrue,
    );
    await expectLater(
      cambiar('Publicado', esperado: 'Entregado', rechazo: true),
      throwsStateError,
    );
  });
  test('el detalle observa cambios remotos sin reabrir la pantalla', () async {
    final estados = service
        .observarObjeto('objeto')
        .map((o) => o?.estadoActual);
    final verificacion = expectLater(
      estados,
      emitsInOrder(['Pendiente', 'Confirmado']),
    );
    await cambiar('Confirmado');
    await verificacion;
  });
}
