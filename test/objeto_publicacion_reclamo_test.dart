import 'dart:io';

import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:favores_usc/services/cloudinary_service.dart';
import 'package:favores_usc/services/objeto_service.dart';

class _Fotos extends CloudinaryService {
  String? resultado = 'https://example.test/evidencia.jpg';

  @override
  Future<String?> subirImagenObjeto(
    File imagen, {
    String folder = 'objetos_fotos',
  }) async => resultado;
}

void main() {
  late FakeFirebaseFirestore db;
  late ObjetoService servicio;
  late _Fotos fotos;
  var uid = 'dueno';
  final imagen = File('evidencia.jpg');
  setUp(() {
    uid = 'dueno';
    db = FakeFirebaseFirestore();
    fotos = _Fotos();
    servicio = ObjetoService(
      firestore: db,
      cloudinaryService: fotos,
      usuarioActual: () => uid,
    );
  });

  Future<String> publicar(String tipo, [File? archivo]) async =>
      (await servicio.publicarObjeto(
        idDueno: 'dueno',
        nombreDueno: 'Dueño',
        titulo: 'Llaves',
        descripcion: 'Llaves de ejemplo',
        tipo: tipo,
        lugarCampus: 'Biblioteca',
        imagenArchivo: archivo,
      )).id;

  test('RF10: aplica etiqueta y foto según el tipo', () async {
    final perdido = await publicar('perdido');
    await expectLater(publicar('encontrado'), throwsArgumentError);
    final encontrado = await publicar('encontrado', imagen);
    final objetos = db.collection('objetos');
    expect(
      (await objetos.doc(perdido).get()).data(),
      containsPair('etiquetaColor', 'rojo'),
    );
    expect(
      (await objetos.doc(encontrado).get()).data(),
      allOf(
        containsPair('etiquetaColor', 'verde'),
        containsPair('estadoActual', 'Publicado'),
        containsPair('urlFoto', fotos.resultado),
      ),
    );
  });

  test(
    'RF10: no publica si falla la subida de una foto seleccionada',
    () async {
      fotos.resultado = null;
      await expectLater(publicar('perdido', imagen), throwsException);
      expect((await db.collection('objetos').get()).docs, isEmpty);
    },
  );

  test(
    'RF11: prueba válida en chat privado y fallo sin cambio de estado',
    () async {
      final id = await publicar('perdido');
      uid = 'ayudante';
      Future<void> reclamar() => servicio.reclamarObjeto(
        idObjeto: id,
        idReclamante: uid,
        nombreReclamante: 'Ayudante',
        fotoPrueba: imagen,
      );
      fotos.resultado = null;
      await expectLater(reclamar(), throwsException);
      expect(
        (await servicio.obtenerObjetoPorId(id))?.estadoActual,
        'Publicado',
      );
      expect((await db.collection('chats').get()).docs, isEmpty);
      fotos.resultado = 'https://example.test/prueba.jpg';
      await reclamar();
      final reporte = (await db.collection('objetos').doc(id).get()).data()!;
      expect(reporte['estadoActual'], 'Pendiente');
      expect(reporte['fotoPruebaUrl'], isNull);
      final prueba =
          (await db
                  .collection('chats')
                  .doc(reporte['chatId'] as String)
                  .collection('mensajes')
                  .doc('prueba')
                  .get())
              .data();
      expect(
        prueba,
        allOf(
          containsPair('urlFoto', fotos.resultado),
          containsPair('esSistema', true),
          containsPair('idEmisor', 'ayudante'),
        ),
      );
    },
  );
}
