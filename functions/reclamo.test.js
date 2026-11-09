'use strict';

const assert = require('node:assert/strict');
const { test } = require('node:test');
const { procesarPrueba } = require('./reclamo');

function caso({estado = 'Pendiente', token = 'token-del-dueno'} = {}) {
  const datos = new Map([
    ['chats/chat', { tipoReferencia: 'objeto', idReferencia: 'objeto',
      participantes: ['dueno', 'reclamante'], soloLectura: false }],
    ['objetos/objeto', { idDueno: 'dueno', idReclamante: 'reclamante',
      estadoActual: estado, chatId: 'chat' }],
    ['usuarios/dueno', { tokenFCM: token }],
    ['usuarios/reclamante', { tokenFCM: 'token-del-reclamante' }],
  ]);
  const peticiones = [];
  const db = {
    doc(path) {
      return {
        path, get: async () => ({ exists: datos.has(path), data: () => datos.get(path) }),
        set: async (valor) => datos.set(path, valor),
      };
    },
    runTransaction: async (f) => f({
      get: (doc) => doc.get(),
      update: (doc, cambios) => datos.set(doc.path, {...datos.get(doc.path), ...cambios}),
    }),
  };
  const argumentos = { db, idChat: 'chat',
    enviar: async (payload) => peticiones.push(payload),
    mensaje: { esSistema: true, chatId: 'chat', idEmisor: 'reclamante',
      urlFoto: 'https://example.test/prueba.jpg' } };
  return { argumentos, peticiones, datos };
}

test('envía únicamente al dueño; no incluye foto ni texto privado en el push', async () => {
  const { argumentos, peticiones } = caso();
  assert.equal(await procesarPrueba(argumentos), 'enviado');
  assert.equal(peticiones.length, 1);
  assert.equal(peticiones[0].token, 'token-del-dueno');
  assert.equal(peticiones[0].data.destinatario, 'dueno');
  assert.doesNotMatch(JSON.stringify(peticiones), /prueba\.jpg/);
  assert.equal(await procesarPrueba(argumentos), 'ya-enviado');
  assert.equal(peticiones.length, 1);
});

test('omite un reclamo resuelto, un mensaje forjado y un perfil sin token', async () => {
  const resuelto = caso({ estado: 'Publicado' });
  assert.equal(await procesarPrueba(resuelto.argumentos), 'omitido');
  const falso = caso();
  falso.argumentos.mensaje.idEmisor = 'tercero';
  assert.equal(await procesarPrueba(falso.argumentos), 'omitido');
  const sinToken = caso({ token: null });
  assert.equal(await procesarPrueba(sinToken.argumentos), 'sin-token');
  assert.deepEqual([...resuelto.peticiones, ...falso.peticiones, ...sinToken.peticiones], []);
});

test('descarta un token caducado sin borrar uno renovado durante el envío', async () => {
  for (const renovar of [false, true]) {
    const { argumentos, datos } = caso();
    argumentos.enviar = async () => {
      if (renovar) datos.set('usuarios/dueno', { tokenFCM: 'nuevo' });
      throw Object.assign(new Error('token inválido'), { code: 'messaging/registration-token-not-registered' });
    };
    assert.equal(await procesarPrueba(argumentos), 'token-invalido');
    assert.equal(datos.get('usuarios/dueno').tokenFCM, renovar ? 'nuevo' : null);
  }
});

test('un error transitorio deja el evento disponible para reintento', async () => {
  const { argumentos, datos } = caso();
  argumentos.enviar = async () => { throw new Error('red no disponible'); };
  await assert.rejects(procesarPrueba(argumentos), /red no disponible/);
  assert.equal(datos.has('entregasReclamo/chat'), false);
});
