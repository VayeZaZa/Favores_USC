"use strict";

const { initializeApp } = require("firebase-admin/app");
const { getFirestore, Timestamp } = require("firebase-admin/firestore");
const { getMessaging } = require("firebase-admin/messaging");
const { onSchedule } = require("firebase-functions/v2/scheduler");
const logger = require("firebase-functions/logger");
const { encolarAvisos, enviarAvisos } = require("./avisos");

initializeApp();

exports.avisarFavoresSinAceptar24h = onSchedule({
  schedule: "every 60 minutes", timeZone: "America/Bogota", region: "us-west1",
  timeoutSeconds: 540, maxInstances: 1, concurrency: 1, retryCount: 3,
}, async () => {
  const db = getFirestore();
  const ahora = Date.now();
  await encolarAvisos(db, Timestamp, ahora);
  await enviarAvisos(db, getMessaging(), Timestamp, ahora, logger);
});
