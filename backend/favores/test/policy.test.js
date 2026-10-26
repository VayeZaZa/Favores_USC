"use strict";
const test = require("node:test");
const assert = require("node:assert/strict");
const { DIA, requiereAviso, eventoId, avisoVigente, demoraReintento } = require("../policy");
const ahora = 1800000000000;
const fecha = (ms, nanos = 0) => ({ seconds: Math.floor(ms / 1000), nanoseconds: nanos, toMillis: () => ms });
const favor = (cambios = {}) => ({ estado: "Publicado", idAutor: "autor", fechaCreacion: fecha(ahora - DIA), ...cambios });

test("los reintentos crecen por horas con límite de un día", () => {
  const hora = DIA / 24;
  assert.deepEqual([1, 2, 3, 4, 5, 6, 100].map(demoraReintento),
    [1, 2, 4, 8, 16, 24, 24].map((n) => n * hora));
  for (const valor of [undefined, null, NaN, Infinity, -1, 0, 1.5, "2"]) {
    assert.equal(demoraReintento(valor), hora);
  }
});

test("24 horas exactas son elegibles y un favor reciente no", () => {
  assert.equal(requiereAviso(favor(), ahora), true);
  assert.equal(requiereAviso(favor({ fechaCreacion: fecha(ahora - DIA + 1) }), ahora), false);
});
test("ambos alias de aviso previenen duplicados", () => {
  assert.equal(requiereAviso(favor({ yaAvisado: true }), ahora), false);
  assert.equal(requiereAviso(favor({ yaAvisado24h: true }), ahora), false);
});
test("ignora aceptados, cancelados, datos sin autor y asignaciones inconsistentes", () => {
  for (const cambios of [{ estado: "Aceptado" }, { estado: "Cancelado" }, { idAutor: "" }, { idAyudante: "ayudante" }, { fechaCreacion: null }]) {
    assert.equal(requiereAviso(favor(cambios), ahora), false);
  }
});
test("un ID de aviso representa un único ciclo de publicación", () => {
  assert.notEqual(eventoId("f1", fecha(1000, 1)), eventoId("f1", fecha(1000, 2)));
  assert.notEqual(eventoId("f1", fecha(1000)), eventoId("f2", fecha(1000)));
  assert.equal(eventoId("f1", fecha(1000)).length, 64);
});
test("descarta avisos de favores republicados, aceptados o con otro autor", () => {
  const anterior = favor();
  const aviso = { id: eventoId("f1", anterior.fechaCreacion), idFavor: "f1", idAutor: "autor" };
  assert.equal(avisoVigente(aviso, anterior, ahora), true);
  assert.equal(avisoVigente(aviso, favor({ fechaCreacion: fecha(ahora) }), ahora), false);
  assert.equal(avisoVigente(aviso, favor({ estado: "Aceptado" }), ahora), false);
  assert.equal(avisoVigente(aviso, favor({ idAutor: "otro" }), ahora), false);
});
