import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:favores_usc/providers/favor_provider.dart';
import 'package:favores_usc/services/favor_service.dart';
import 'package:flutter_test/flutter_test.dart';

class _ServicioControlado implements FavorService {
  final solicitudes = <Completer<QuerySnapshot>>[];

  @override
  Future<QuerySnapshot> obtenerFavoresPaginados({
    DocumentSnapshot? lastDocument,
    int limit = 10,
    String? filtroTipo,
  }) {
    final solicitud = Completer<QuerySnapshot>();
    solicitudes.add(solicitud);
    return solicitud.future;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _Pagina implements QuerySnapshot<Map<String, dynamic>> {
  _Pagina(this.docs);

  @override
  final List<QueryDocumentSnapshot<Map<String, dynamic>>> docs;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

// Doble de prueba: permite simular respuestas fuera de orden sin Firebase nativo.
// ignore: subtype_of_sealed_class
class _Documento implements QueryDocumentSnapshot<Map<String, dynamic>> {
  _Documento(this.id);

  @override
  final String id;

  @override
  Map<String, dynamic> data() => {'titulo': id};

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  test('un filtro nuevo descarta respuestas antiguas', () async {
    final servicio = _ServicioControlado();
    final feed = FavoresFeedNotifier(servicio);
    addTearDown(feed.dispose);

    final cambio = feed.cambiarFiltro('Apuntes');
    servicio.solicitudes[1].complete(_Pagina([_Documento('nuevo')]));
    await cambio;
    servicio.solicitudes[0].complete(_Pagina([_Documento('antiguo')]));
    await Future<void>.delayed(Duration.zero);

    expect(feed.state.filtroTipo, 'Apuntes');
    expect(feed.state.favores.single.id, 'nuevo');
  });

  test('una recarga vacía elimina el cursor anterior', () async {
    final servicio = _ServicioControlado();
    final feed = FavoresFeedNotifier(servicio);
    addTearDown(feed.dispose);
    servicio.solicitudes[0].complete(_Pagina([_Documento('favor')]));
    await Future<void>.delayed(Duration.zero);
    expect(feed.state.lastDocument, isNotNull);

    final recarga = feed.cargarInicial();
    servicio.solicitudes[1].complete(_Pagina([]));
    await recarga;

    expect(feed.state.lastDocument, isNull);
    expect(feed.state.favores, isEmpty);
    expect(feed.state.hasMore, isFalse);
  });

  test('una respuesta posterior a dispose no modifica el estado', () async {
    final servicio = _ServicioControlado();
    final feed = FavoresFeedNotifier(servicio);
    feed.dispose();
    servicio.solicitudes.single.complete(_Pagina([]));
    await Future<void>.delayed(Duration.zero);
  });
}
