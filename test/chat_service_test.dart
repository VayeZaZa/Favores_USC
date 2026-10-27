import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:favores_usc/services/chat_service.dart';

void main() {
  late FakeFirebaseFirestore db;
  late ChatService service;
  setUp(() async {
    db = FakeFirebaseFirestore();
    service = ChatService(firestore: db, usuarioActual: () => 'ayudante');
    await db.collection('favores').doc('favor').set({
      'estado': 'Aceptado',
      'idAutor': 'dueno',
      'idAyudante': 'ayudante',
      'chatId': 'chat',
    });
    await db.collection('chats').doc('chat').set({
      'idReferencia': 'favor',
      'tipoReferencia': 'favor',
      'participantes': ['dueno', 'ayudante'],
      'soloLectura': false,
    });
  });
  Future<void> enviar({String texto = 'Hola', String? foto}) =>
      service.enviarMensaje(
        chatId: 'chat',
        idEmisor: 'ayudante',
        nombreEmisor: 'Ayudante',
        texto: texto,
        urlFoto: foto,
        idMensaje: 'intento-estable',
      );

  test('reintentar el mismo envío no duplica texto ni fotografías', () async {
    await enviar(foto: 'https://example.test/foto.jpg');
    await enviar(foto: 'https://example.test/foto.jpg');
    final mensajes = await db
        .collection('chats')
        .doc('chat')
        .collection('mensajes')
        .get();
    expect(mensajes.docs, hasLength(1));
    expect(mensajes.docs.single.data()['texto'], 'Hola');
    expect(
      mensajes.docs.single.data()['urlFoto'],
      'https://example.test/foto.jpg',
    );
  });
  test(
    'el identificador de un mensaje no permite reemplazar su contenido',
    () async {
      await enviar();
      await expectLater(enviar(texto: 'Distinto'), throwsStateError);
      final msg = await db
          .collection('chats')
          .doc('chat')
          .collection('mensajes')
          .doc('intento-estable')
          .get();
      expect(msg.data()!['texto'], 'Hola');
    },
  );
  test('tras cerrar el favor no se guarda un nuevo mensaje', () async {
    await db.collection('favores').doc('favor').update({'estado': 'Cancelado'});
    await expectLater(enviar(), throwsStateError);
    expect(
      (await db.collection('chats').doc('chat').collection('mensajes').get())
          .docs,
      isEmpty,
    );
  });
  test(
    'reintentar un mensaje confirmado antes del cierre reconoce el envío',
    () async {
      await enviar();
      await db.collection('chats').doc('chat').update({'soloLectura': true});
      await db.collection('favores').doc('favor').update({
        'estado': 'Entregado',
      });
      await enviar();
      expect(
        (await db.collection('chats').doc('chat').collection('mensajes').get())
            .docs,
        hasLength(1),
      );
    },
  );
  test('un envío rechazado puede reintentarse sin duplicarlo', () async {
    await db.collection('chats').doc('chat').update({'soloLectura': true});
    await expectLater(enviar(), throwsStateError);
    await db.collection('chats').doc('chat').update({'soloLectura': false});
    await enviar();
    await enviar();
    expect(
      (await db.collection('chats').doc('chat').collection('mensajes').get())
          .docs,
      hasLength(1),
    );
  });
}
