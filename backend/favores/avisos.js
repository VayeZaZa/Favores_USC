"use strict";

const { randomUUID } = require("node:crypto");
const { DIA, usuarioId, requiereAviso, eventoId, avisoVigente } = require("./policy");
const HORA = DIA / 24;

async function encolarAvisos(db, Timestamp, ahora) {
  const progresoRef = db.doc("estadoTareasFavores/avisos24h");
  const progreso = (await progresoRef.get()).data();
  const base = db.collection("favores").where("estado", "==", "Publicado")
    .where("fechaCreacion", "<=", Timestamp.fromMillis(ahora - DIA))
    .orderBy("fechaCreacion").orderBy("__name__");
  let query = progreso?.fecha && progreso?.id
    ? base.startAfter(progreso.fecha, progreso.id) : base;
  // Cursor persistente: una base grande continúa en la siguiente ejecución.
  for (let pagina = 0; pagina < 20; pagina++) {
    const lote = await query.limit(100).get();
    for (const doc of lote.docs) {
      await db.runTransaction(async (tx) => {
        const vigente = await tx.get(doc.ref);
        if (!vigente.exists || !requiereAviso(vigente.data(), ahora)) return;
        const favor = vigente.data();
        const id = eventoId(doc.id, favor.fechaCreacion);
        const avisoRef = db.doc(`alertasFavores/${id}`);
        const anterior = await tx.get(avisoRef);
        if (!anterior.exists) {
          tx.create(avisoRef, {
            id, idFavor: doc.id, idAutor: usuarioId(favor.idAutor),
            estado: "Pendiente", intentos: 0,
            fechaCreacion: Timestamp.fromMillis(ahora),
            proximoIntento: Timestamp.fromMillis(ahora),
          });
        }
        tx.update(doc.ref, { yaAvisado: true, yaAvisado24h: true });
      });
    }
    if (lote.size < 100) {
      await progresoRef.set({ fecha: null, id: null }, { merge: true });
      return;
    }
    const ultimo = lote.docs.at(-1);
    await progresoRef.set({ fecha: ultimo.get("fechaCreacion"), id: ultimo.id }, { merge: true });
    query = base.startAfter(ultimo);
  }
}

async function finalizar(db, ref, lease, datos) {
  await db.runTransaction(async (tx) => {
    const actual = await tx.get(ref);
    if (actual.data()?.lease === lease) tx.update(ref, datos);
  });
}

async function enviarAvisos(db, messaging, Timestamp, ahora, logger) {
  const pendientes = await db.collection("alertasFavores")
    .where("estado", "in", ["Pendiente", "Procesando"])
    .where("proximoIntento", "<=", Timestamp.fromMillis(ahora))
    .orderBy("proximoIntento").limit(100).get();
  for (const doc of pendientes.docs) {
    const lease = randomUUID();
    const envio = await db.runTransaction(async (tx) => {
      const snapshot = await tx.get(doc.ref);
      const aviso = snapshot.data();
      if (!aviso || !["Pendiente", "Procesando"].includes(aviso.estado) ||
          aviso.proximoIntento.toMillis() > ahora) return null;
      const favorSnap = await tx.get(db.doc(`favores/${aviso.idFavor}`));
      const autorSnap = await tx.get(db.doc(`usuarios/${aviso.idAutor}`));
      if (!favorSnap.exists || !avisoVigente(aviso, favorSnap.data(), ahora)) {
        tx.update(doc.ref, { estado: "Obsoleto" });
        return null;
      }
      const token = autorSnap.data()?.tokenFCM;
      if (typeof token !== "string" || !token.trim()) {
        tx.update(doc.ref, { estado: "Pendiente", proximoIntento: Timestamp.fromMillis(ahora + HORA) });
        return null;
      }
      tx.update(doc.ref, {
        estado: "Procesando", lease, intentos: (aviso.intentos || 0) + 1,
        proximoIntento: Timestamp.fromMillis(ahora + 10 * 60 * 1000),
      });
      return { aviso, token };
    });
    if (!envio) continue;
    try {
      const idMensaje = await messaging.send({
        token: envio.token,
        notification: {
          title: "Tu favor sigue disponible",
          body: "Han pasado 24 horas sin ser aceptado. Puedes republicarlo o retirarlo desde Mi actividad.",
        },
        data: { tipo: "favor_sin_aceptar_24h", idFavor: envio.aviso.idFavor, eventoId: doc.id },
        android: { notification: { tag: doc.id } },
        apns: { headers: { "apns-collapse-id": doc.id } },
      });
      await finalizar(db, doc.ref, lease, {
        estado: "Enviado", fechaEnvio: Timestamp.fromMillis(ahora), idMensaje,
      });
    } catch (error) {
      const tokenInvalido = ["messaging/registration-token-not-registered", "messaging/invalid-registration-token"].includes(error.code);
      await finalizar(db, doc.ref, lease, {
        estado: tokenInvalido ? "TokenInvalido" : "Pendiente",
        proximoIntento: Timestamp.fromMillis(ahora + HORA),
        ultimoError: error.code || "envio-fallido",
      });
      logger.warn("No se pudo entregar una alerta de favor", { eventoId: doc.id, codigo: error.code });
    }
  }
}

module.exports = { encolarAvisos, enviarAvisos };
