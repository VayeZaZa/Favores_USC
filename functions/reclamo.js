'use strict';

const invalido = new Set([
  'messaging/registration-token-not-registered',
  'messaging/invalid-registration-token',
]);

function uid(valor) {
  return typeof valor === 'string' ? valor : valor?.id;
}

async function procesarPrueba({db, enviar, idChat, mensaje}) {
  if (mensaje?.esSistema !== true || mensaje.chatId !== idChat ||
      typeof mensaje.urlFoto !== 'string' || !mensaje.urlFoto.startsWith('https://')) {
    return 'omitido';
  }
  const recibo = db.doc(`entregasReclamo/${idChat}`);
  const [chatSnapshot, reciboSnapshot] = await Promise.all([
    db.doc(`chats/${idChat}`).get(), recibo.get(),
  ]);
  if (reciboSnapshot.exists) return 'ya-enviado';
  const chat = chatSnapshot.data();
  if (chat?.tipoReferencia !== 'objeto' || chat.soloLectura !== false ||
      typeof chat.idReferencia !== 'string' || chat.idReferencia.includes('/') ||
      !Array.isArray(chat.participantes) || chat.participantes.length !== 2) return 'omitido';
  const objeto = (await db.doc(`objetos/${chat.idReferencia}`).get()).data();
  const dueno = uid(objeto?.idDueno);
  if (!dueno || dueno.includes('/') || objeto.chatId !== idChat ||
      objeto.estadoActual !== 'Pendiente' || objeto.idReclamante !== mensaje.idEmisor ||
      dueno === mensaje.idEmisor || !chat.participantes.includes(dueno) ||
      !chat.participantes.includes(mensaje.idEmisor)) return 'omitido';

  const perfil = db.doc(`usuarios/${dueno}`);
  const token = (await perfil.get()).data()?.tokenFCM;
  if (typeof token !== 'string' || !token) return 'sin-token';

  try {
    await enviar({
      token,
      notification: {
        title: 'Tienes un reclamo por revisar',
        body: 'Abre Objetos en Favores USC para revisar la evidencia.',
      },
      data: { tipo: 'reclamo_objeto', destinatario: dueno },
      android: { notification: { tag: idChat } },
      apns: { headers: { 'apns-collapse-id': idChat } },
    });
  } catch (error) {
    if (!invalido.has(error.code)) throw error;
    await db.runTransaction(async (tx) => {
      if ((await tx.get(perfil)).data()?.tokenFCM === token) {
        tx.update(perfil, { tokenFCM: null });
      }
    });
    return 'token-invalido';
  }
  await recibo.set({ enviadoEn: new Date() });
  return 'enviado';
}

module.exports = { procesarPrueba };
