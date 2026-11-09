import 'dart:io';

import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:favores_usc/services/cloudinary_service.dart';
import 'package:favores_usc/services/objeto_service.dart';
import 'package:flutter_test/flutter_test.dart';

class _SubidaDePrueba extends CloudinaryService {
  String? respuesta;

  @override
  Future<String?> subirImagenObjeto(
    File imagen, {
    String folder = 'objetos_fotos',
  }) async => respuesta;
}

void main() {
  test(
    'publica perdidos sin foto y encontrados solo si se guardó la foto',
    () async {
      final db = FakeFirebaseFirestore();
      final subida = _SubidaDePrueba();
      final servicio = ObjetoService(
        firestore: db,
        cloudinaryService: subida,
        usuarioActualId: () => 'autor',
      );

      Future<void> publicar(String tipo, {File? foto}) =>
          servicio.publicarObjeto(
            idDueno: 'autor',
            nombreDueno: 'Estudiante',
            titulo: 'Calculadora',
            descripcion: 'Calculadora científica',
            tipo: tipo,
            etiquetaColor: 'sin_color',
            lugarCampus: 'Bloque 2',
            imagenArchivo: foto,
          );

      await publicar('perdido');
      final foto = File('calculadora.jpg');
      await expectLater(publicar('encontrado'), throwsArgumentError);
      await expectLater(publicar('encontrado', foto: foto), throwsException);
      await expectLater(publicar('perdido', foto: foto), throwsException);
      expect((await db.collection('objetos').get()).docs, hasLength(1));

      subida.respuesta = 'https://example.com/calculadora.jpg';
      await publicar('encontrado', foto: foto);
      final objetos = await servicio.obtenerObjetosStream().first;
      expect(objetos, hasLength(2));
      expect(
        objetos.singleWhere((objeto) => objeto.esEncontrado).urlFoto,
        subida.respuesta,
      );
    },
  );

  test('solo el dueño puede borrar un reporte publicado', () async {
    final db = FakeFirebaseFirestore();
    var uid = 'autor';
    final servicio = ObjetoService(firestore: db, usuarioActualId: () => uid);
    final doc = db.doc('objetos/reporte');
    await doc.set({'idDueno': 'autor', 'estadoActual': 'Publicado'});

    uid = 'otra-cuenta';
    await expectLater(servicio.eliminarObjeto(doc.id), throwsException);
    uid = 'autor';
    await doc.update({'estadoActual': 'Pendiente'});
    await expectLater(servicio.eliminarObjeto(doc.id), throwsException);
    await doc.update({'estadoActual': 'Publicado'});
    await servicio.eliminarObjeto(doc.id);
    expect((await doc.get()).exists, false);
  });
}
