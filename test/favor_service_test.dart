import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:favores_usc/config/app_constants.dart';
import 'package:favores_usc/services/favor_service.dart';
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
    expect((await db.doc('chats/favor_f1').get()).get('participantes'), [
      'autor',
      'ayudante',
    ]);
  });

  test('no modifica agregados incompletos o fraccionarios', () async {
    await db.doc('usuarios/ayudante').update({'cantidadCalificaciones': 1});
    await expectLater(calificar(), throwsException);
    await db.doc('usuarios/ayudante').update({
      'cantidadCalificaciones': 1.5,
      'sumaEstrellas': 5,
    });
    await expectLater(calificar(), throwsException);
    expect((await db.collection('calificaciones').get()).docs, isEmpty);
  });

  test(
    'guarda una calificación, ambos promedios y contadores exactos',
    () async {
      await calificar();
      final usuario = (await db.doc('usuarios/ayudante').get()).data()!;
      expect(usuario['sumaEstrellas'], 4);
      expect(usuario['cantidadCalificaciones'], 1);
      expect(usuario['promedio'], 4.0);
      expect(usuario['promedioCalificacion'], 4.0);
      expect((await db.doc('favores/f1').get()).data()!['calificadoPor'], [
        'autor',
      ]);
    },
  );

  test('bloquea una segunda calificación sin alterar el promedio', () async {
    await calificar();
    await expectLater(calificar(estrellas: 1), throwsException);
    expect((await db.collection('calificaciones').get()).docs, hasLength(1));
    expect((await db.doc('usuarios/ayudante').get()).get('promedio'), 4.0);
  });

  test(
    'promedia calificaciones de distintos favores sin redondeo acumulado',
    () async {
      await calificar(estrellas: 5);
      await prepararFavor(id: 'f2');
      await calificar(favor: 'f2', estrellas: 2);
      await prepararFavor(id: 'f3');
      await calificar(favor: 'f3', estrellas: 3);
      final usuario = (await db.doc('usuarios/ayudante').get()).data()!;
      expect(usuario['sumaEstrellas'], 10);
      expect(usuario['cantidadCalificaciones'], 3);
      expect(usuario['promedio'], closeTo(10 / 3, 0.000001));
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
      (await db.doc('usuarios/autor').get()).get('cantidadCalificaciones'),
      1,
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
    'no reinicia el promedio antiguo cuando faltan sus contadores',
    () async {
      await db.doc('calificaciones/antigua').set({
        'idFavor': 'otro',
        'idAutor': 'otra-persona',
        'idDestinatario': 'ayudante',
        'estrellas': 2,
      });
      await db.doc('usuarios/ayudante').update({'promedio': 2.0});
      await expectLater(calificar(), throwsException);
      expect((await db.doc('usuarios/ayudante').get()).get('promedio'), 2.0);
      expect((await db.collection('calificaciones').get()).docs, hasLength(1));
    },
  );

  test('las claves de calificación no colisionan con guiones bajos', () {
    expect(
      FavorService.calificacionId('a_b', 'c'),
      isNot(FavorService.calificacionId('a', 'b_c')),
    );
  });

  test('aceptar crea una sala privada junto con la asignación', () async {
    await prepararFavor(estado: 'Publicado');
    sesion = 'ayudante';
    await servicio.aceptarFavor(favorId: 'f1', idAyudante: sesion);
    expect((await db.doc('favores/f1').get()).get('estado'), 'Aceptado');
    final chat = (await db.doc('chats/favor_f1').get()).data()!;
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

  test(
    'solo el ayudante confirma pago, cierra chat e incrementa una vez',
    () async {
      await prepararFavor(estado: 'Publicado');
      sesion = 'ayudante';
      await servicio.aceptarFavor(favorId: 'f1', idAyudante: sesion);
      sesion = 'autor';
      await expectLater(
        servicio.confirmarPagoYEntregar(favorId: 'f1', idAyudante: sesion),
        throwsException,
      );
      sesion = 'ayudante';
      await servicio.confirmarPagoYEntregar(favorId: 'f1', idAyudante: sesion);
      expect((await db.doc('chats/favor_f1').get()).get('soloLectura'), true);
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
