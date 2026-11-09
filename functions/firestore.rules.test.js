'use strict';

const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const { test, before, after, beforeEach } = require('node:test');
const { initializeTestEnvironment, assertFails, assertSucceeds } = require('@firebase/rules-unit-testing');
const { collection, doc, getDoc, getDocs, query, where, runTransaction, serverTimestamp,
  setDoc, updateDoc, writeBatch } = require('firebase/firestore');

const projectId = 'demo-favores-tests';
const evidencia = 'https://example.test/evidencia.jpg';
let env;
before(async () => {
  const [host, port] = (process.env.FIRESTORE_EMULATOR_HOST || '127.0.0.1:8080').split(':');
  if (!['127.0.0.1', 'localhost'].includes(host)) throw new Error('Solo emulador local');
  env = await initializeTestEnvironment({
    projectId,
    firestore: { host, port: Number(port), rules: fs.readFileSync(path.join(__dirname, '../firestore.rules'), 'utf8') },
  });
});
beforeEach(async () => env.clearFirestore());
after(async () => { if (env) await env.cleanup(); });

const db = (uid) => env.authenticatedContext(uid, { email: `${uid}@usc.edu.co` }).firestore();
const objeto = (base, id = 'obj') => doc(base, 'objetos', id);
const chat = (base, id = 'chat') => doc(base, 'chats', id);
const msg = (base, id = 'chat', mid = 'prueba') => doc(base, 'chats', id, 'mensajes', mid);
const reporte = (tipo = 'perdido', cambios = {}) => ({
  idDueno: 'dueno', titulo: 'Llaves', descripcion: 'Cerca de la biblioteca',
  tipo, etiquetaColor: tipo === 'perdido' ? 'rojo' : 'verde',
  lugarCampus: 'Biblioteca', fechaReporte: serverTimestamp(), urlFoto: '',
  estadoActual: 'Publicado', soloLectura: false, ...cambios,
});
const sala = (otro = 'ayudante', tipo = 'objeto') => ({
  tipoReferencia: tipo, idReferencia: 'obj', tituloReferencia: 'Llaves',
  participantes: ['dueno', otro], nombresParticipantes: {}, soloLectura: false,
  ultimoMensaje: '', fechaUltimoMensaje: serverTimestamp(),
});
const mensaje = (idChat = 'chat', actor = 'ayudante', prueba = true) => ({
  chatId: idChat, idEmisor: actor, nombreEmisor: actor, texto: prueba ? 'Foto de prueba' : 'Hola',
  timestamp: serverTimestamp(), esSistema: prueba, urlFoto: prueba ? evidencia : null, leido: false,
});
const reclamo = (base, actor, idChat, incluirPrueba = true) => {
  const batch = writeBatch(base);
  batch.update(objeto(base), {
    estadoActual: 'Pendiente', idReclamante: actor, nombreReclamante: actor,
    fotoPruebaUrl: null, chatId: idChat, fechaActualizacion: serverTimestamp(),
  });
  batch.set(chat(base, idChat), sala(actor));
  if (incluirPrueba) batch.set(msg(base, idChat), mensaje(idChat, actor));
  return batch.commit();
};

test('RF10: solo el dueño publica; perdido sin foto, encontrado con foto y color correcto', async () => {
  const owner = db('dueno');
  await assertSucceeds(setDoc(objeto(owner), reporte()));
  await assertFails(setDoc(objeto(owner, 'falla1'), reporte('encontrado')));
  await assertFails(setDoc(objeto(owner, 'falla2'), reporte('perdido', { etiquetaColor: 'verde' })));
  await assertFails(setDoc(objeto(db('tercero'), 'falla3'), reporte()));
  await assertSucceeds(setDoc(objeto(owner, 'encontrado'), reporte('encontrado', { urlFoto: evidencia })));
  assert.equal((await getDoc(objeto(owner, 'encontrado'))).data().urlFoto, evidencia);
});

test('RF11: reclamo, sala y foto se guardan juntos; evidencia accesible solo a participantes', async () => {
  const owner = db('dueno'), helper = db('ayudante'), tercero = db('tercero');
  await setDoc(objeto(owner), reporte());
  await assertFails(reclamo(helper, 'ayudante', 'sin-foto', false));
  await assertFails(reclamo(owner, 'dueno', 'propio'));
  await assertSucceeds(reclamo(helper, 'ayudante', 'chat'));
  await assertFails(reclamo(tercero, 'tercero', 'segundo'));
  assert.equal((await getDoc(objeto(tercero))).data().fotoPruebaUrl, null);
  assert.equal((await getDoc(msg(owner))).data().urlFoto, evidencia);
  await assertFails(getDoc(msg(tercero)));
  await assertFails(getDoc(chat(tercero)));
  await assertSucceeds(getDocs(query(collection(owner, 'chats'), where('participantes', 'array-contains', 'dueno'))));
  await assertFails(setDoc(msg(helper, 'chat', 'normal'), mensaje('chat', 'ayudante', false)));
});

test('RF12/RF13: dueño confirma, rechaza o entrega; sala anterior permanece cerrada', async () => {
  const owner = db('dueno'), helper = db('ayudante');
  await setDoc(objeto(owner), reporte());
  await reclamo(helper, 'ayudante', 'chat');
  await assertFails(updateDoc(objeto(helper), { estadoActual: 'Confirmado' }));
  await assertFails(updateDoc(objeto(owner), { estadoActual: 'Entregado', soloLectura: true }));
  await assertSucceeds(updateDoc(objeto(owner), { estadoActual: 'Confirmado' }));
  await assertSucceeds(setDoc(msg(helper, 'chat', 'normal'), mensaje('chat', 'ayudante', false)));
  await assertFails(setDoc(msg(db('tercero'), 'chat', 'externo'), mensaje('chat', 'tercero', false)));
  const reabrir = writeBatch(owner);
  reabrir.update(objeto(owner), { estadoActual: 'Publicado', idReclamante: null,
    nombreReclamante: null, fotoPruebaUrl: null, chatId: null, soloLectura: false });
  reabrir.update(chat(owner), { soloLectura: true });
  await assertSucceeds(reabrir.commit());
  await reclamo(helper, 'ayudante', 'nuevo');
  await updateDoc(objeto(owner), { estadoActual: 'Confirmado' });
  await assertFails(setDoc(msg(helper, 'chat', 'viejo'), mensaje('chat', 'ayudante', false)));
  await assertFails(updateDoc(objeto(owner), { estadoActual: 'Entregado', soloLectura: true }));
  const cierre = writeBatch(owner);
  cierre.update(objeto(owner), { estadoActual: 'Entregado', soloLectura: true });
  cierre.update(chat(owner, 'nuevo'), { soloLectura: true });
  await assertSucceeds(cierre.commit());
  await assertSucceeds(getDoc(msg(owner, 'nuevo')));
  await assertFails(setDoc(msg(helper, 'nuevo', 'tarde'), mensaje('nuevo', 'ayudante', false)));
});

test('RF13: dos decisiones simultáneas sobre el mismo Pendiente tienen un ganador', async () => {
  const owner = db('dueno'), otraSesion = db('dueno'), helper = db('ayudante');
  await setDoc(objeto(owner), reporte());
  await reclamo(helper, 'ayudante', 'chat');
  function decidir(base, confirmar) {
    return runTransaction(base, async (tx) => {
      const actual = (await tx.get(objeto(base))).data();
      if (actual.estadoActual !== 'Pendiente' || actual.chatId !== 'chat') throw new Error('Estado anterior');
      if (confirmar) tx.update(objeto(base), { estadoActual: 'Confirmado' });
      else {
        tx.update(objeto(base), { estadoActual: 'Publicado', chatId: null, idReclamante: null,
          nombreReclamante: null, fotoPruebaUrl: null });
        tx.update(chat(base), { soloLectura: true });
      }
    });
  }
  const resultados = await Promise.allSettled([decidir(owner, true), decidir(otraSesion, false)]);
  assert.equal(resultados.filter((r) => r.status === 'fulfilled').length, 1);
  const estado = (await getDoc(objeto(owner))).data().estadoActual;
  assert.ok(['Confirmado', 'Publicado'].includes(estado));
  assert.equal((await getDoc(chat(owner))).data().soloLectura, estado === 'Publicado');
});

test('RF07: aceptar crea chat de favor, permite intercambio y bloquea después de entregar', async () => {
  const owner = db('dueno'), helper = db('ayudante');
  const favor = (base) => doc(base, 'favores', 'obj');
  await setDoc(favor(owner), { idAutor: 'dueno', titulo: 'Copias', descripcion: 'Copias',
    ubicacion: 'Biblioteca', tipoServicio: 'Apuntes', pago: 1000,
    fechaCreacion: serverTimestamp(), estado: 'Publicado' });
  const aceptar = writeBatch(helper);
  aceptar.update(favor(helper), { estado: 'Aceptado', idAyudante: 'ayudante', chatId: 'chat' });
  aceptar.set(chat(helper), sala('ayudante', 'favor'));
  await assertSucceeds(aceptar.commit());
  await assertSucceeds(setDoc(msg(owner, 'chat', 'autor'), mensaje('chat', 'dueno', false)));
  await assertSucceeds(setDoc(msg(helper, 'chat', 'ayudante'), mensaje('chat', 'ayudante', false)));
  const cierre = writeBatch(helper);
  cierre.update(favor(helper), { estado: 'Entregado', calificacionHabilitada: true, soloLectura: true });
  cierre.update(chat(helper), { soloLectura: true });
  await assertSucceeds(cierre.commit());
  await assertSucceeds(getDoc(msg(owner, 'chat', 'ayudante')));
  await assertFails(setDoc(msg(owner, 'chat', 'tarde'), mensaje('chat', 'dueno', false)));
});
