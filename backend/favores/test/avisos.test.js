"use strict";
const test = require("node:test");
const assert = require("node:assert/strict");
const { encolarAvisos, enviarAvisos } = require("../avisos");
const { eventoId, DIA } = require("../policy");
const ahora = 1800000000000;
const Timestamp = { fromMillis: (ms) => ({ seconds: Math.floor(ms / 1000), nanoseconds: 0, toMillis: () => ms }) };

// Adaptador mínimo para probar decisiones y llamadas. No simula concurrencia,
// índices, reglas ni el aislamiento de las transacciones de Firestore.
function escenario({ token = "token-prueba", estadoFavor = "Publicado", fallaEnvio } = {}) {
  const registros = new Map();
  const fecha = Timestamp.fromMillis(ahora - DIA);
  const id = eventoId("f1", fecha);
  registros.set("favores/f1", { idAutor: "autor", estado: estadoFavor, fechaCreacion: fecha });
  registros.set("usuarios/autor", { tokenFCM: token });
  const ref = (path) => ({ path, id: path.split("/").at(-1),
    get: async () => snapshot(path),
    set: async (data) => registros.set(path, { ...(registros.get(path) || {}), ...data }),
  });
  const snapshot = (path) => ({ ref: ref(path), id: ref(path).id, exists: registros.has(path),
    data: () => registros.has(path) ? { ...registros.get(path) } : undefined,
    get: (campo) => registros.get(path)?.[campo],
  });
  const db = {
    doc: ref,
    runTransaction: async (handler) => handler({
      get: async (doc) => snapshot(doc.path),
      update: (doc, data) => registros.set(doc.path, { ...registros.get(doc.path), ...data }),
      create: (doc, data) => { assert.equal(registros.has(doc.path), false); registros.set(doc.path, data); },
    }),
    collection: (nombre) => {
      const query = {
        where: () => query, orderBy: () => query, startAfter: () => query, limit: () => query,
        get: async () => {
          const docs = [...registros.keys()].filter((p) => p.startsWith(`${nombre}/`) && p.split("/").length === 2).map(snapshot);
          return { docs, size: docs.length };
        },
      };
      return query;
    },
  };
  const enviados = [];
  const messaging = { send: async (payload) => {
    if (fallaEnvio) throw Object.assign(new Error("fallo simulado"), { code: fallaEnvio });
    enviados.push(payload);
    return "mensaje-prueba";
  } };
  return { db, registros, id, enviados, messaging };
}
const logger = { warn() {} };

test("encola una sola alerta y alinea ambos indicadores sin borrar el favor", async () => {
  const s = escenario();
  await encolarAvisos(s.db, Timestamp, ahora);
  await encolarAvisos(s.db, Timestamp, ahora);
  assert.equal([...s.registros.keys()].filter((p) => p.startsWith("alertasFavores/")).length, 1);
  assert.equal(s.registros.get("favores/f1").yaAvisado, true);
  assert.equal(s.registros.get("favores/f1").yaAvisado24h, true);
});

test("registra el envío y no repite un evento Enviado", async () => {
  const s = escenario();
  await encolarAvisos(s.db, Timestamp, ahora);
  await enviarAvisos(s.db, s.messaging, Timestamp, ahora, logger);
  await enviarAvisos(s.db, s.messaging, Timestamp, ahora, logger);
  assert.equal(s.enviados.length, 1);
  assert.equal(s.enviados[0].data.idFavor, "f1");
  assert.equal(s.registros.get(`alertasFavores/${s.id}`).estado, "Enviado");
});

test("conserva pendiente un aviso si el usuario no tiene token", async () => {
  const s = escenario({ token: "" });
  await encolarAvisos(s.db, Timestamp, ahora);
  await enviarAvisos(s.db, s.messaging, Timestamp, ahora, logger);
  assert.equal(s.enviados.length, 0);
  assert.equal(s.registros.get(`alertasFavores/${s.id}`).estado, "Pendiente");
  assert.ok(s.registros.get(`alertasFavores/${s.id}`).proximoIntento.toMillis() > ahora);
});

test("un favor aceptado después de encolarse no genera push", async () => {
  const s = escenario();
  await encolarAvisos(s.db, Timestamp, ahora);
  s.registros.get("favores/f1").estado = "Aceptado";
  await enviarAvisos(s.db, s.messaging, Timestamp, ahora, logger);
  assert.equal(s.enviados.length, 0);
  assert.equal(s.registros.get(`alertasFavores/${s.id}`).estado, "Obsoleto");
});

test("un fallo transitorio conserva el aviso para un reintento", async () => {
  const s = escenario({ fallaEnvio: "messaging/server-unavailable" });
  await encolarAvisos(s.db, Timestamp, ahora);
  await enviarAvisos(s.db, s.messaging, Timestamp, ahora, logger);
  const aviso = s.registros.get(`alertasFavores/${s.id}`);
  assert.equal(aviso.estado, "Pendiente");
  assert.equal(aviso.intentos, 1);
  assert.ok(aviso.proximoIntento.toMillis() > ahora);
});

test("marca un token inválido sin eliminarlo del perfil del compañero", async () => {
  const s = escenario({ fallaEnvio: "messaging/registration-token-not-registered" });
  await encolarAvisos(s.db, Timestamp, ahora);
  await enviarAvisos(s.db, s.messaging, Timestamp, ahora, logger);
  assert.equal(s.registros.get(`alertasFavores/${s.id}`).estado, "TokenInvalido");
  assert.equal(s.registros.get("usuarios/autor").tokenFCM, "token-prueba");
});

test("respeta la espera y recupera un fallo transitorio sin perder la alerta", async () => {
  const s = escenario({ fallaEnvio: "messaging/server-unavailable" });
  await encolarAvisos(s.db, Timestamp, ahora);
  let llamadas = 0;
  s.messaging.send = async (payload) => {
    llamadas++;
    if (llamadas < 3) throw Object.assign(new Error("temporal"), { code: "messaging/server-unavailable" });
    s.enviados.push(payload);
    return "recuperado";
  };
  const aviso = () => s.registros.get(`alertasFavores/${s.id}`);
  const hora = DIA / 24;
  await enviarAvisos(s.db, s.messaging, Timestamp, ahora, logger);
  await enviarAvisos(s.db, s.messaging, Timestamp, ahora + hora - 1, logger);
  assert.equal(llamadas, 1);
  await enviarAvisos(s.db, s.messaging, Timestamp, ahora + hora, logger);
  assert.equal(aviso().proximoIntento.toMillis(), ahora + 3 * hora);
  await enviarAvisos(s.db, s.messaging, Timestamp, ahora + 3 * hora, logger);
  assert.equal(llamadas, 3);
  assert.equal(s.enviados.length, 1);
  assert.equal(aviso().estado, "Enviado");
  assert.equal(aviso().ultimoError, null);
  assert.equal(aviso().intentos, 3);
});

test("una reserva activa impide enviar y una vencida permite recuperar", async () => {
  const s = escenario();
  await encolarAvisos(s.db, Timestamp, ahora);
  const path = `alertasFavores/${s.id}`;
  const vence = ahora + 10 * 60 * 1000;
  Object.assign(s.registros.get(path), {
    estado: "Procesando", lease: "trabajador-anterior", intentos: 1,
    proximoIntento: Timestamp.fromMillis(vence),
  });
  await enviarAvisos(s.db, s.messaging, Timestamp, vence - 1, logger);
  assert.equal(s.enviados.length, 0);
  await enviarAvisos(s.db, s.messaging, Timestamp, vence, logger);
  assert.equal(s.enviados.length, 1);
  assert.equal(s.registros.get(path).estado, "Enviado");
  assert.equal(s.registros.get(path).intentos, 2);
});

test("un trabajador anterior no sobrescribe una reserva nueva al finalizar", async () => {
  const s = escenario();
  await encolarAvisos(s.db, Timestamp, ahora);
  s.messaging.send = async () => {
    Object.assign(s.registros.get(`alertasFavores/${s.id}`), {
      lease: "otra-reserva", estado: "Procesando",
    });
    return "mensaje-anterior";
  };
  await enviarAvisos(s.db, s.messaging, Timestamp, ahora, logger);
  const aviso = s.registros.get(`alertasFavores/${s.id}`);
  assert.equal(aviso.lease, "otra-reserva");
  assert.equal(aviso.estado, "Procesando");
  assert.equal(aviso.idMensaje, undefined);
});

test("un fallo al confirmar el envío conserva la reserva y no se atribuye a FCM", async () => {
  const s = escenario();
  await encolarAvisos(s.db, Timestamp, ahora);
  const transaccion = s.db.runTransaction;
  s.db.runTransaction = (handler) => transaccion((tx) => handler({
    ...tx,
    update: (ref, datos) => {
      if (datos.estado === "Enviado") throw new Error("persistencia no disponible");
      return tx.update(ref, datos);
    },
  }));
  await assert.rejects(enviarAvisos(s.db, s.messaging, Timestamp, ahora, logger),
    /persistencia no disponible/);
  const aviso = s.registros.get(`alertasFavores/${s.id}`);
  assert.equal(s.enviados.length, 1);
  assert.equal(aviso.estado, "Procesando");
  assert.equal(aviso.ultimoError, undefined);
  s.db.runTransaction = transaccion;
  await enviarAvisos(s.db, s.messaging, Timestamp, ahora + 1, logger);
  assert.equal(s.enviados.length, 1);
});

test("una republicación descarta el aviso anterior y permite un nuevo ciclo", async () => {
  const s = escenario();
  await encolarAvisos(s.db, Timestamp, ahora);
  Object.assign(s.registros.get("favores/f1"), {
    fechaCreacion: Timestamp.fromMillis(ahora), yaAvisado: false, yaAvisado24h: false,
  });
  await enviarAvisos(s.db, s.messaging, Timestamp, ahora, logger);
  assert.equal(s.enviados.length, 0);
  assert.equal(s.registros.get(`alertasFavores/${s.id}`).estado, "Obsoleto");
  await encolarAvisos(s.db, Timestamp, ahora + DIA);
  await enviarAvisos(s.db, s.messaging, Timestamp, ahora + DIA, logger);
  assert.equal(s.enviados.length, 1);
  assert.notEqual(s.enviados[0].data.eventoId, s.id);
});

test("un token inválido no vuelve a intentarse ni altera el perfil", async () => {
  const s = escenario({ fallaEnvio: "messaging/invalid-registration-token" });
  await encolarAvisos(s.db, Timestamp, ahora);
  await enviarAvisos(s.db, s.messaging, Timestamp, ahora, logger);
  await enviarAvisos(s.db, s.messaging, Timestamp, ahora + DIA, logger);
  const aviso = s.registros.get(`alertasFavores/${s.id}`);
  assert.equal(aviso.estado, "TokenInvalido");
  assert.equal(aviso.intentos, 1);
  assert.equal(s.registros.get("usuarios/autor").tokenFCM, "token-prueba");
});
