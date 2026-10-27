"use strict";

const { createHash } = require("node:crypto");
const DIA = 24 * 60 * 60 * 1000;

// La tarea se ejecuta por horas. Los fallos consecutivos espacian los envíos
// hasta un día, sin descartar una alerta por una caída temporal de FCM.
function demoraReintento(intentos) {
  const intento = Number.isSafeInteger(intentos) && intentos > 0 ? intentos : 1;
  return Math.min(DIA, (DIA / 24) * 2 ** Math.min(intento - 1, 5));
}

function usuarioId(valor) {
  if (typeof valor === "string") return valor.split("/").at(-1);
  return valor?.id || "";
}

function fechaMillis(valor) {
  return typeof valor?.toMillis === "function" ? valor.toMillis() : NaN;
}

function publicadoVencido(favor, ahora) {
  const fecha = fechaMillis(favor?.fechaCreacion);
  return favor?.estado === "Publicado" && !usuarioId(favor.idAyudante) &&
    !!usuarioId(favor.idAutor) && Number.isFinite(fecha) && fecha <= ahora - DIA;
}

function requiereAviso(favor, ahora) {
  return publicadoVencido(favor, ahora) &&
    favor.yaAvisado !== true && favor.yaAvisado24h !== true;
}

function eventoId(idFavor, fecha) {
  // Incluye nanosegundos para distinguir cada republicación del mismo favor.
  return createHash("sha256")
    .update(JSON.stringify([idFavor, fecha.seconds, fecha.nanoseconds]))
    .digest("hex");
}

function avisoVigente(aviso, favor, ahora) {
  return publicadoVencido(favor, ahora) && usuarioId(favor.idAutor) === aviso.idAutor &&
    eventoId(aviso.idFavor, favor.fechaCreacion) === aviso.id;
}

module.exports = { DIA, usuarioId, requiereAviso, eventoId, avisoVigente, demoraReintento };
