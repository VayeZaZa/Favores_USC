import 'dart:async';
import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/favor_model.dart';
import 'cloudinary_service.dart';

/// Lectura del perfil y persistencia de la foto de usuario.
class PerfilService {
  PerfilService({
    FirebaseFirestore? firestore,
    CloudinaryService? cloudinaryService,
  }) : _firestore = firestore ?? FirebaseFirestore.instance,
       _cloudinaryService = cloudinaryService ?? CloudinaryService();

  final FirebaseFirestore _firestore;
  final CloudinaryService _cloudinaryService;

  DocumentReference<Map<String, dynamic>> _perfilRef(String uid) =>
      _firestore.collection('usuarios').doc(uid);

  Stream<Map<String, dynamic>?> observarPerfil(String uid) {
    // El promedio se calcula sin permitir que otra persona edite este perfil.
    return Stream.multi((eventos) {
      Map<String, dynamic>? perfil;
      double? promedio;
      void publicar() {
        final datos = perfil;
        eventos.add(
          datos == null ? null : {...datos, 'promedioCalificacion': ?promedio},
        );
      }

      final perfilSub = _perfilRef(uid).snapshots().listen((snapshot) {
        perfil = snapshot.data();
        publicar();
      }, onError: eventos.addError);
      final notasSub = _firestore
          .collection('calificaciones')
          .where('idDestinatario', isEqualTo: uid)
          .snapshots()
          .listen((snapshot) {
            final total = snapshot.docs.fold<double>(
              0,
              (suma, doc) =>
                  suma + ((doc.data()['estrellas'] as num?)?.toDouble() ?? 0),
            );
            promedio = snapshot.docs.isEmpty
                ? null
                : total / snapshot.docs.length;
            publicar();
          }, onError: eventos.addError);
      eventos.onCancel = () {
        unawaited(perfilSub.cancel());
        unawaited(notasSub.cancel());
      };
    });
  }

  Future<String> guardarFotoPerfil({
    required String uid,
    required File archivo,
  }) async {
    final url = await _cloudinaryService.subirImagenObjeto(
      archivo,
      folder: 'usuarios_fotos',
    );

    if (url == null || url.isEmpty) {
      throw Exception('No se pudo subir la foto. Intenta de nuevo.');
    }

    await _perfilRef(uid).update({'fotoPerfil': url});
    return url;
  }

  Future<List<FavorModel>> cargarFavores(String uid) async {
    final resultados = await Future.wait([
      _firestore.collection('favores').where('idAutor', isEqualTo: uid).get(),
      _firestore
          .collection('favores')
          .where('idAyudante', isEqualTo: uid)
          .get(),
    ]);

    final documentos = <String, QueryDocumentSnapshot<Map<String, dynamic>>>{};
    for (final resultado in resultados) {
      for (final documento in resultado.docs) {
        documentos[documento.id] = documento;
      }
    }

    final favores =
        documentos.values
            .map(
              (documento) => FavorModel.fromMap(documento.data(), documento.id),
            )
            .toList()
          ..sort((a, b) => b.fechaCreacion.compareTo(a.fechaCreacion));

    return favores;
  }
}
