"use strict";

const { initializeApp } = require("firebase-admin/app");
const { getFirestore, Timestamp } = require("firebase-admin/firestore");
const { getMessaging } = require("firebase-admin/messaging");
const { onSchedule } = require("firebase-functions/v2/scheduler");
const logger = require("firebase-functions/logger");
const { ejecutarCiclo } = require("./ciclo");

initializeApp();

exports.avisarFavoresSinAceptar24h = onSchedule({
  schedule: "every 60 minutes", timeZone: "America/Bogota", region: "us-west1",
  timeoutSeconds: 540, maxInstances: 1, concurrency: 1, retryCount: 3,
}, async () => {
  await ejecutarCiclo({
    db: getFirestore(), messaging: getMessaging(), Timestamp,
    ahora: Date.now(), logger,
  });
});
