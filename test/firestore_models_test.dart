import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:favores_usc/models/chat_model.dart';
import 'package:favores_usc/models/favor_model.dart';
import 'package:favores_usc/models/objeto_model.dart';

void main() {
  test('reads a favor using the existing favores fields', () {
    final fecha = DateTime(2026, 10, 5);
    final favor = FavorModel.fromMap({
      'descripcion': 'Llevar copias al 2do piso de Biblioteca',
      'estado': 'Publicado',
      'fechaCreacion': Timestamp.fromDate(fecha),
      'idAutor': '/users/wQgbmKWCLRCk2mTXljqO',
      'nombreAutor': 'Valeria',
      'pago': 2000,
      'soloLectura': false,
      'tipoServicio': 'Apuntes',
      'titulo': 'Copias Taller Calculo',
      'ubicacion': 'Biblioteca',
      'urlFotos': <String>[],
      'yaAvisado24h': false,
    }, 'fav_test_1');

    expect(favor.id, 'fav_test_1');
    expect(favor.idAutor, 'wQgbmKWCLRCk2mTXljqO');
    expect(favor.nombreAutor, 'Valeria');
    expect(favor.tipoServicio, 'Apuntes');
    expect(favor.titulo, 'Copias Taller Calculo');
    expect(favor.fechaCreacion, fecha);
    expect(favor.soloLectura, isFalse);
    expect(favor.yaAvisado24h, isFalse);
  });

  test('reads an object using the existing objetos fields', () {
    final fecha = DateTime(2026, 10, 5);
    final objeto = ObjetoModel.fromMap({
      'descripcion': 'Negra, olvidada en Bloque 2',
      'estadoActual': 'Publicado',
      'fechaReporte': Timestamp.fromDate(fecha),
      'idDueno': '/users/wQgbmKWCLRCk2mTXljqO',
      'tipo': 'perdido',
      'titulo': 'Calculadora Casio',
    }, 'obj_test_1');

    expect(objeto.id, 'obj_test_1');
    expect(objeto.idDueno, 'wQgbmKWCLRCk2mTXljqO');
    expect(objeto.tipo, 'perdido');
    expect(objeto.titulo, 'Calculadora Casio');
    expect(objeto.fechaReporte, fecha);
  });

  test('reads a chat using the existing chats fields', () {
    final chat = ChatModel.fromMap({
      'idReferencia': 'fav_test_1',
      'participantes': ['/users/wQgbmKWCLRCk2mTXljqO', '/users/user-2'],
      'soloLectura': false,
      'tipoReferencia': 'FAVOR',
      'ultimoMensaje': 'Hola, ya voy en camino',
    }, 'chat_test_1');

    expect(chat.id, 'chat_test_1');
    expect(chat.idReferencia, 'fav_test_1');
    expect(chat.participantes, ['wQgbmKWCLRCk2mTXljqO', 'user-2']);
    expect(chat.soloLectura, isFalse);
    expect(chat.tipoReferencia, 'FAVOR');
    expect(chat.ultimoMensaje, 'Hola, ya voy en camino');
  });
}
