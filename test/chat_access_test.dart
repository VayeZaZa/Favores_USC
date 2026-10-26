import 'package:flutter_test/flutter_test.dart';
import 'package:favores_usc/models/chat_access.dart';
import 'package:favores_usc/models/chat_model.dart';
import 'package:favores_usc/models/favor_model.dart';
import 'package:favores_usc/models/objeto_model.dart';

ChatModel chat(String tipo, {bool cerrado = false, List<String>? usuarios}) =>
    ChatModel(id: 'chat', idReferencia: 'caso', tipoReferencia: tipo,
      participantes: usuarios ?? ['dueno', 'ayudante'], soloLectura: cerrado);

FavorModel favor(String estado) => FavorModel(
    id: 'caso', idAutor: 'dueno', idAyudante: 'ayudante',
    titulo: 'Copias', tipoServicio: 'Copias', descripcion: 'Entrega',
    ubicacion: 'Biblioteca', pago: 1000, fechaCreacion: DateTime(2026),
    estado: estado);

ObjetoModel objeto(String estado, {String reclamante = 'ayudante'}) => ObjetoModel(
    id: 'caso', idDueno: 'dueno', idReclamante: reclamante,
    titulo: 'Llaves', descripcion: 'Llaves USC', tipo: 'perdido',
    etiquetaColor: 'rojo', lugarCampus: 'Biblioteca',
    fechaReporte: DateTime(2026), estadoActual: estado);

void main() {
  for (final estado in ['Publicado', 'Aceptado', 'Entregado', 'Cancelado']) {
    test('favor $estado permite conversar únicamente si está aceptado', () {
      for (final uid in ['dueno', 'ayudante', 'externo', '']) {
        expect(ChatAccess.puedeEscribir(chat: chat('favor'), usuarioId: uid,
          favor: favor(estado)),
          estado == 'Aceptado' && ['dueno', 'ayudante'].contains(uid));
      }
    });
  }
  for (final estado in ['Publicado', 'Pendiente', 'Confirmado', 'Entregado']) {
    test('objeto $estado exige confirmación antes de conversar', () {
      expect(ChatAccess.puedeEscribir(chat: chat('objeto'),
        usuarioId: 'ayudante', objeto: objeto(estado)), estado == 'Confirmado');
    });
  }
  test('el cierre, la ausencia de datos y los participantes inválidos bloquean', () {
    expect(ChatAccess.puedeEscribir(chat: chat('favor', cerrado: true),
      usuarioId: 'dueno', favor: favor('Aceptado')), isFalse);
    expect(ChatAccess.puedeEscribir(chat: chat('favor'), usuarioId: 'dueno'), isFalse);
    expect(ChatAccess.puedeEscribir(chat: chat('favor', usuarios: ['dueno', 'dueno']),
      usuarioId: 'dueno', favor: favor('Aceptado')), isFalse);
  });
  test('un chat de un reclamo anterior no autoriza nuevos mensajes', () {
    expect(ChatAccess.puedeEscribir(chat: chat('objeto'), usuarioId: 'dueno',
      objeto: objeto('Confirmado', reclamante: 'otra-persona')), isFalse);
    expect(ChatAccess.puedeEscribir(chat: chat('objeto'), usuarioId: 'dueno',
      objeto: objeto('Confirmado'), chatActualId: 'nuevo-chat'), isFalse);
  });
  test('solo el dueño puede confirmar o cerrar y nunca saltarse estados', () {
    expect(objeto('Pendiente').permiteAccion('dueno', 'Confirmado'), isTrue);
    expect(objeto('Pendiente').permiteAccion('ayudante', 'Confirmado'), isFalse);
    expect(objeto('Pendiente').permiteAccion('externo', 'Confirmado'), isFalse);
    expect(objeto('Publicado').permiteAccion('dueno', 'Entregado'), isFalse);
    expect(objeto('Confirmado').permiteAccion('dueno', 'Entregado'), isTrue);
    expect(objeto('Entregado').permiteAccion('dueno', 'Publicado', esRechazo: true), isFalse);
  });
  test('solo un rechazo explícito reabre y los estados desconocidos se rechazan', () {
    for (final estado in ['Pendiente', 'Confirmado']) {
      expect(objeto(estado).permiteAccion('dueno', 'Publicado'), isFalse);
      expect(objeto(estado).permiteAccion('dueno', 'Publicado', esRechazo: true), isTrue);
      expect(objeto(estado).permiteAccion('dueno', 'inexistente', esRechazo: true), isFalse);
    }
  });
}
