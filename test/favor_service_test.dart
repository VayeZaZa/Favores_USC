import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:favores_usc/config/app_constants.dart';
import 'package:favores_usc/services/favor_service.dart';
import 'package:favores_usc/services/perfil_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late FakeFirebaseFirestore db;
  late FavorService servicio;
  late String sesion;

  Future<void> prepararFavor({
    String estado = 'Entregado',
    String id = 'f1',
  }) async {
    await db.collection('favores').doc(id).set({
      'idAutor': 'autor',
      'idAyudante': estado == 'Publicado' ? null : 'ayudante',
      'titulo': 'Apuntes',
      'descripcion': 'Apuntes de cálculo',
      'estado': estado,
      'calificacionHabilitada': estado == 'Entregado',
      'fechaCreacion': Timestamp.fromDate(
        DateTime.now().subtract(const Duration(hours: 25)),
      ),
    });
  }

  Future<void> calificar({
    String favor = 'f1',
    String destinatario = 'ayudante',
    int estrellas = 4,
    String comentario = '',
  }) => servicio.calificarUsuario(
    favorId: favor,
    idAutorCalificador: sesion,
    idDestinatario: destinatario,
    estrellas: estrellas,
    comentario: comentario,
  );

  setUp(() async {
    db = FakeFirebaseFirestore();
    sesion = 'autor';
    servicio = FavorService(firestore: db, usuarioActualId: () => sesion);
    await db.doc('usuarios/autor').set({
      'nombre': 'Autor',
      'favoresCompletados': 0,
    });
    await db.doc('usuarios/ayudante').set({
      'nombre': 'Ayudante',
      'favoresCompletados': 0,
    });
    await prepararFavor();
  });

  test('la actividad pagina sin incluir favores ajenos', () async {
    sesion = 'usuario-paginacion';
    final fecha = DateTime.now();
    for (var i = 0; i < 11; i++) {
      await db.doc('favores/pagina$i').set({
        'idAutor': sesion,
        'estado': 'Publicado',
        'fechaCreacion': Timestamp.fromDate(
          fecha.subtract(Duration(minutes: i)),
        ),
      });
    }
    final primera = await servicio.obtenerActividadPaginada(
      idUsuario: sesion,
      filtro: 'Mis favores',
    );
    final segunda = await servicio.obtenerActividadPaginada(
      idUsuario: sesion,
      filtro: 'Mis favores',
      lastDocument: primera.docs.last,
    );
    expect(primera.docs, hasLength(10));
    expect(segunda.docs, hasLength(1));
    expect({
      ...primera.docs.map((doc) => doc.id),
      ...segunda.docs.map((doc) => doc.id),
    }, hasLength(11));
    expect(primera.docs.map((doc) => doc.id), isNot(contains('f1')));
  });

  test('aceptar normaliza referencias de autor existentes', () async {
    await prepararFavor(estado: 'Publicado');
    await db.doc('favores/f1').update({'idAutor': db.doc('usuarios/autor')});
    await expectLater(
      servicio.aceptarFavor(favorId: 'f1', idAyudante: sesion),
      throwsException,
    );
    sesion = 'ayudante';
    await servicio.aceptarFavor(favorId: 'f1', idAyudante: sesion);
    final salaId = (await db.doc('favores/f1').get()).get('idChat') as String;
    expect((await db.doc('chats/$salaId').get()).get('participantes'), [
      'autor',
      'ayudante',
    ]);
  });

  test('guarda la calificación sin modificar el perfil ni el favor', () async {
    final perfil = db.doc('usuarios/ayudante');
    final favor = db.doc('favores/f1');
    final perfilAntes = (await perfil.get()).data();
    final favorAntes = (await favor.get()).data();
    await calificar();
    final nota = (await db.doc('calificaciones/f1_autor').get()).data()!;
    expect(nota['estrellas'], 4);
    expect(nota['idDestinatario'], 'ayudante');
    expect((await perfil.get()).data(), perfilAntes);
    expect((await favor.get()).data(), favorAntes);
  });

  test('bloquea una segunda calificación sin alterar el promedio', () async {
    await calificar();
    await expectLater(calificar(estrellas: 1), throwsException);
    expect((await db.collection('calificaciones').get()).docs, hasLength(1));
    expect((await db.doc('calificaciones/f1_autor').get()).get('estrellas'), 4);
  });

  test(
    'promedia calificaciones de distintos favores sin redondeo acumulado',
    () async {
      await calificar(estrellas: 5);
      await prepararFavor(id: 'f2');
      await calificar(favor: 'f2', estrellas: 2);
      await prepararFavor(id: 'f3');
      await calificar(favor: 'f3', estrellas: 3);
      final perfil = await PerfilService(firestore: db)
          .observarPerfil('ayudante')
          .firstWhere(
            (datos) => datos?['promedioCalificacion'] != 0.0 && datos != null,
          );
      expect(perfil?['promedioCalificacion'], closeTo(10 / 3, 0.000001));
    },
  );

  test('rechaza extraños, autocalificación y destinatarios ajenos', () async {
    sesion = 'extraño';
    await expectLater(calificar(), throwsException);
    sesion = 'autor';
    await expectLater(calificar(destinatario: 'autor'), throwsException);
    await expectLater(calificar(destinatario: 'extraño'), throwsException);
    expect((await db.collection('calificaciones').get()).docs, isEmpty);
  });

  test(
    'rechaza calificación antes de la entrega y entradas inválidas',
    () async {
      await prepararFavor(estado: 'Aceptado');
      await expectLater(calificar(), throwsException);
      await prepararFavor();
      await expectLater(calificar(estrellas: 0), throwsException);
      await expectLater(calificar(estrellas: 6), throwsException);
      await expectLater(calificar(comentario: 'a' * 301), throwsException);
      expect((await db.collection('calificaciones').get()).docs, isEmpty);
    },
  );

  test('el ayudante también puede calificar al autor una sola vez', () async {
    sesion = 'ayudante';
    await calificar(destinatario: 'autor');
    await expectLater(calificar(destinatario: 'autor'), throwsException);
    expect(
      (await db.doc('calificaciones/f1_ayudante').get()).get('idDestinatario'),
      'autor',
    );
  });

  test(
    'conserva calificaciones antiguas y bloquea duplicados de ID aleatorio',
    () async {
      await db.doc('calificaciones/antigua').set({
        'idFavor': 'f1',
        'idAutor': 'autor',
        'idDestinatario': 'ayudante',
        'estrellas': 5,
      });
      await expectLater(calificar(), throwsException);
      expect(
        (await db.doc('calificaciones/antigua').get()).get('estrellas'),
        5,
      );
    },
  );

  test(
    'las calificaciones previas cuentan aunque el perfil no tenga contadores',
    () async {
      await db.doc('calificaciones/antigua').set({
        'idFavor': 'otro',
        'idAutor': 'otra-persona',
        'idDestinatario': 'ayudante',
        'estrellas': 2,
      });
      await db.doc('usuarios/ayudante').update({'promedio': 2.0});
      await calificar();
      expect((await db.doc('usuarios/ayudante').get()).get('promedio'), 2.0);
      expect((await db.collection('calificaciones').get()).docs, hasLength(2));
    },
  );

  test('la clave de la calificación coincide con las reglas publicadas', () {
    expect(
      FavorService.calificacionId('ejemplo_favor', 'abc'),
      'ejemplo_favor_abc',
    );
  });

  test('aceptar crea una sala privada junto con la asignación', () async {
    await prepararFavor(estado: 'Publicado');
    sesion = 'ayudante';
    await servicio.aceptarFavor(favorId: 'f1', idAyudante: sesion);
    expect((await db.doc('favores/f1').get()).get('estado'), 'Aceptado');
    final salaId = (await db.doc('favores/f1').get()).get('idChat') as String;
    final chat = (await db.doc('chats/$salaId').get()).data()!;
    expect(chat['participantes'], ['autor', 'ayudante']);
    expect(chat['soloLectura'], false);
    await expectLater(
      servicio.aceptarFavor(favorId: 'f1', idAyudante: sesion),
      throwsException,
    );
  });

  test('rechaza aceptar el propio favor y suplantar al ayudante', () async {
    await prepararFavor(estado: 'Publicado');
    await expectLater(
      servicio.aceptarFavor(favorId: 'f1', idAyudante: 'autor'),
      throwsException,
    );
    await expectLater(
      servicio.aceptarFavor(favorId: 'f1', idAyudante: 'ayudante'),
      throwsException,
    );
    expect((await db.doc('favores/f1').get()).get('estado'), 'Publicado');
    expect((await db.collection('chats').get()).docs, isEmpty);
  });

  test('solo el ayudante cancela y el favor admite otra aceptación', () async {
    await prepararFavor(estado: 'Publicado');
    sesion = 'ayudante';
    await servicio.aceptarFavor(favorId: 'f1', idAyudante: sesion);
    final favor = db.doc('favores/f1');
    final salaId = (await favor.get()).get('idChat') as String;
    await db.doc('chats/$salaId/mensajes/m1').set({'texto': 'Hola'});

    sesion = 'autor';
    await expectLater(
      servicio.cancelarAceptacion(favorId: 'f1', idAyudante: sesion),
      throwsException,
    );
    sesion = 'ayudante';
    await servicio.cancelarAceptacion(favorId: 'f1', idAyudante: sesion);
    final publicado = (await favor.get()).data()!;
    expect(publicado['estado'], 'Publicado');
    expect(publicado['idAyudante'], isNull);
    expect(publicado, isNot(contains('idChat')));
    expect((await db.doc('chats/$salaId').get()).get('soloLectura'), true);
    expect((await db.doc('chats/$salaId/mensajes/m1').get()).exists, true);

    await servicio.aceptarFavor(favorId: 'f1', idAyudante: sesion);
    final salaNueva = (await favor.get()).get('idChat') as String;
    expect(salaNueva, isNot(salaId));
    expect((await db.doc('chats/$salaNueva').get()).get('soloLectura'), false);
  });

  test('borrar elimina el favor publicado solo para su autor', () async {
    await expectLater(
      servicio.eliminarFavor('f1', idAutor: sesion),
      throwsException,
    );
    await prepararFavor(estado: 'Publicado');
    sesion = 'ayudante';
    await expectLater(
      servicio.eliminarFavor('f1', idAutor: sesion),
      throwsException,
    );
    sesion = 'autor';
    await servicio.eliminarFavor('f1', idAutor: sesion);
    expect((await db.doc('favores/f1').get()).exists, false);
  });

  test(
    'solo el ayudante confirma pago, cierra chat e incrementa una vez',
    () async {
      await prepararFavor(estado: 'Publicado');
      sesion = 'ayudante';
      await servicio.aceptarFavor(favorId: 'f1', idAyudante: sesion);
      final salaId = (await db.doc('favores/f1').get()).get('idChat') as String;
      sesion = 'autor';
      await expectLater(
        servicio.confirmarPagoYEntregar(favorId: 'f1', idAyudante: sesion),
        throwsException,
      );
      sesion = 'ayudante';
      await servicio.confirmarPagoYEntregar(favorId: 'f1', idAyudante: sesion);
      expect((await db.doc('chats/$salaId').get()).get('soloLectura'), true);
      expect(
        (await db.doc('favores/f1').get()).get('calificacionHabilitada'),
        true,
      );
      expect(
        (await db.doc('usuarios/ayudante').get()).get('favoresCompletados'),
        1,
      );
      await expectLater(
        servicio.confirmarPagoYEntregar(favorId: 'f1', idAyudante: sesion),
        throwsException,
      );
      expect(
        (await db.doc('usuarios/ayudante').get()).get('favoresCompletados'),
        1,
      );
    },
  );

  test(
    'abrir un chat histórico entregado conserva los mensajes y lo cierra',
    () async {
      await db.doc('chats/historico').set({
        'idReferencia': 'f1',
        'tipoReferencia': 'FAVOR',
        'participantes': ['autor', 'ayudante'],
        'soloLectura': false,
      });
      await db.doc('chats/historico/mensajes/m1').set({
        'texto': 'Mensaje antiguo',
      });
      await servicio.prepararChatFavor('f1', idUsuario: sesion);
      expect((await db.doc('chats/historico').get()).get('soloLectura'), true);
      expect(
        (await db.doc('chats/historico/mensajes/m1').get()).get('texto'),
        'Mensaje antiguo',
      );
      sesion = 'extraño';
      await expectLater(
        servicio.prepararChatFavor('f1', idUsuario: sesion),
        throwsException,
      );
    },
  );

  test('un favor entregado sin chat lo obtiene en modo lectura', () async {
    await servicio.prepararChatFavor('f1', idUsuario: sesion);
    expect((await db.doc('chats/favor_f1').get()).get('soloLectura'), true);
  });

  test('el reporte requiere entrega y destinatario participante', () async {
    Future<void> reportar(String destino) => servicio.crearReporte(
      favorId: 'f1',
      idReportante: sesion,
      idReportado: destino,
      motivo: 'Incumplimiento',
      descripcion: 'Detalles',
    );
    await expectLater(reportar('autor'), throwsException);
    await expectLater(reportar('extraño'), throwsException);
    await prepararFavor(estado: 'Aceptado');
    await expectLater(reportar('ayudante'), throwsException);
    await prepararFavor();
    await reportar('ayudante');
    expect((await db.collection('reportes').get()).docs, hasLength(1));
  });

  test('retirar conserva el documento y solo permite al autor', () async {
    await prepararFavor(estado: 'Publicado');
    sesion = 'ayudante';
    await expectLater(
      servicio.retirarFavor('f1', idAutor: sesion),
      throwsException,
    );
    sesion = 'autor';
    await servicio.retirarFavor('f1', idAutor: sesion);
    final favor = await db.doc('favores/f1').get();
    expect(favor.exists, true);
    expect(favor.get('estado'), 'Cancelado');
  });

  test(
    'republicar reinicia ambos alias sin permitir favores aceptados',
    () async {
      await prepararFavor(estado: 'Publicado');
      await db.doc('favores/f1').update({
        'yaAvisado': true,
        'yaAvisado24h': true,
      });
      await servicio.republicarFavor('f1', idAutor: sesion);
      final favor = (await db.doc('favores/f1').get()).data()!;
      expect(favor['yaAvisado'], false);
      expect(favor['yaAvisado24h'], false);
      await expectLater(
        servicio.republicarFavor('f1', idAutor: sesion),
        throwsException,
      );
      await prepararFavor(estado: 'Aceptado');
      await expectLater(
        servicio.republicarFavor('f1', idAutor: sesion),
        throwsException,
      );
      await expectLater(
        servicio.retirarFavor('f1', idAutor: sesion),
        throwsException,
      );
    },
  );

  test('las categorías nuevas publican con el autor autenticado', () async {
    for (final tipo in ['Objeto', 'Apuntes', 'Domicilio']) {
      final id = await servicio.crearFavor(
        idAutor: sesion,
        titulo: 'Título',
        tipo: tipo,
        descripcion: 'Descripción del favor',
        ubicacion: AppConstants.puntosCampus.first,
        pago: 1000,
      );
      expect(
        (await db.collection('favores').doc(id).get()).get('tipoServicio'),
        tipo,
      );
    }
  });
}
