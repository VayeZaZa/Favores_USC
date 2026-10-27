"use strict";

const { encolarAvisos, enviarAvisos } = require("./avisos");

// La creación de alertas y su entrega tienen progreso independiente. Un fallo
// al consultar/encolar no debe impedir atender la cola de ejecuciones previas.
async function ejecutarCiclo({ db, messaging, Timestamp, ahora, logger }, fases = {}) {
  const encolar = fases.encolar || encolarAvisos;
  const enviar = fases.enviar || enviarAvisos;
  const resultado = { encolado: "Pendiente", envio: "Pendiente" };
  const errores = [];

  async function ejecutar(nombre, accion) {
    try {
      await accion();
      resultado[nombre] = "Completado";
    } catch {
      resultado[nombre] = "Fallido";
      // No registrar mensajes del proveedor, documentos ni tokens FCM.
      // El resumen conserva solo la fase; la excepción final solicita retry.
      logger.error("Falló una fase de alertas RF16", { fase: nombre });
      errores.push(new Error(`RF16: fase ${nombre} fallida`));
    }
  }

  await ejecutar("encolado", () => encolar(db, Timestamp, ahora));
  await ejecutar("envio", () => enviar(db, messaging, Timestamp, ahora, logger));
  logger.info("Ciclo de alertas RF16 finalizado", { ...resultado });

  if (errores.length) {
    // Propagar el fallo después de intentar ambas fases, no devolver éxito
    // parcial al Scheduler. Las reservas y los eventos existentes se conservan.
    throw new AggregateError(errores, "RF16: ciclo incompleto; requiere reintento");
  }
  return resultado;
}

module.exports = { ejecutarCiclo };
