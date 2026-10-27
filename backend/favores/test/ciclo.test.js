"use strict";

const test = require("node:test");
const assert = require("node:assert/strict");
const { ejecutarCiclo } = require("../ciclo");

function escenario({ fallaEncolado = false, fallaEnvio = false } = {}) {
  const llamadas = [];
  const logs = [];
  const contexto = {
    db: {}, messaging: {}, Timestamp: {}, ahora: 1800000000000,
    logger: {
      error: (...args) => logs.push(args),
      info: (...args) => logs.push(args),
    },
  };
  const fases = {
    encolar: async (...args) => {
      assert.deepEqual(args, [contexto.db, contexto.Timestamp, contexto.ahora]);
      llamadas.push("encolar");
      if (fallaEncolado) throw new Error("detalle privado de la base");
    },
    enviar: async (...args) => {
      assert.deepEqual(args, [contexto.db, contexto.messaging, contexto.Timestamp,
        contexto.ahora, contexto.logger]);
      llamadas.push("enviar");
      if (fallaEnvio) throw new Error("token-privado-de-prueba");
    },
  };
  return { contexto, fases, llamadas, logs };
}

test("ejecuta las fases en orden y devuelve un resumen cuando ambas completan", async () => {
  const s = escenario();
  const resultado = await ejecutarCiclo(s.contexto, s.fases);
  assert.deepEqual(s.llamadas, ["encolar", "enviar"]);
  assert.deepEqual(resultado, { encolado: "Completado", envio: "Completado" });
  assert.deepEqual(s.logs.at(-1)[1], resultado);
});

test("si falla el encolado, atiende la cola pendiente y solicita reintento", async () => {
  const s = escenario({ fallaEncolado: true });
  await assert.rejects(ejecutarCiclo(s.contexto, s.fases), (error) => {
    assert.ok(error instanceof AggregateError);
    assert.equal(error.errors.length, 1);
    assert.match(error.errors[0].message, /encolado/);
    return true;
  });
  assert.deepEqual(s.llamadas, ["encolar", "enviar"]);
  assert.deepEqual(s.logs.at(-1)[1], { encolado: "Fallido", envio: "Completado" });
});

test("si falla el envío, no presenta éxito parcial como ciclo completo", async () => {
  const s = escenario({ fallaEnvio: true });
  await assert.rejects(ejecutarCiclo(s.contexto, s.fases), AggregateError);
  assert.deepEqual(s.llamadas, ["encolar", "enviar"]);
  assert.deepEqual(s.logs.at(-1)[1], { encolado: "Completado", envio: "Fallido" });
});

test("conserva ambos fallos sin exponer mensajes privados en logs ni excepción", async () => {
  const s = escenario({ fallaEncolado: true, fallaEnvio: true });
  await assert.rejects(ejecutarCiclo(s.contexto, s.fases), (error) => {
    assert.equal(error.errors.length, 2);
    assert.doesNotMatch(error.errors.map((e) => e.message).join(" "), /privado/);
    return true;
  });
  assert.deepEqual(s.llamadas, ["encolar", "enviar"]);
  assert.equal(s.logs.length, 3);
  assert.doesNotMatch(JSON.stringify(s.logs), /privado/);
});

test("una nueva ejecución puede completar después de un fallo previo", async () => {
  const s = escenario({ fallaEncolado: true });
  await assert.rejects(ejecutarCiclo(s.contexto, s.fases), AggregateError);
  s.fases.encolar = async () => s.llamadas.push("encolar-recuperado");
  const resultado = await ejecutarCiclo(s.contexto, s.fases);
  assert.deepEqual(resultado, { encolado: "Completado", envio: "Completado" });
  assert.deepEqual(s.llamadas, ["encolar", "enviar", "encolar-recuperado", "enviar"]);
});
