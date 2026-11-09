'use strict';

const { initializeApp } = require('firebase-admin/app');
const { getFirestore } = require('firebase-admin/firestore');
const { getMessaging } = require('firebase-admin/messaging');
const { onDocumentCreated } = require('firebase-functions/v2/firestore');
const { procesarPrueba } = require('./reclamo');

initializeApp();

exports.notificarReclamoObjeto = onDocumentCreated({
  document: 'chats/{idChat}/mensajes/{idMensaje}',
  retry: true,
}, async (evento) => {
  if (evento.params.idMensaje !== 'prueba' || !evento.data) return;
  // El emulador no sustituye FCM; nunca envía a dispositivos reales.
  if (process.env.FUNCTIONS_EMULATOR === 'true') return;
  await procesarPrueba({
    db: getFirestore(),
    enviar: (mensaje) => getMessaging().send(mensaje),
    idChat: evento.params.idChat,
    mensaje: evento.data.data(),
  });
});
