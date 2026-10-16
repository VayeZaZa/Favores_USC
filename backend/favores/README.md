# Alertas de favores sin aceptar

Implementación local de RF16. No está desplegada ni conectada a la ejecución de la app. No tiene operaciones de borrado. El `firebase.json` del equipo no se modificó para activar estas funciones.

## Comportamiento

La función `avisarFavoresSinAceptar24h` revisa cada hora los favores publicados desde hace al menos 24 horas. Una transacción vuelve a validar el estado y el autor, crea un aviso en `alertasFavores` y sincroniza `yaAvisado` y `yaAvisado24h`. Su clave representa el favor y la fecha exacta de ese ciclo de publicación, de modo que una republicación permite una nueva alerta.

La cola se procesa con una reserva temporal para evitar envíos simultáneos. Antes de enviar, comprueba que el favor siga publicado y que no haya sido republicado. Si falta `usuarios/{idAutor}.tokenFCM`, conserva el aviso pendiente. Si FCM rechaza un token definitivamente, marca el aviso TokenInvalido sin modificar el perfil de usuario. Los errores transitorios se reintentan en la siguiente ejecución.

La búsqueda usa páginas de 100 y un cursor persistente en `estadoTareasFavores/avisos24h`. Procesa hasta 20 páginas y 100 avisos por ejecución; una base grande continúa en ejecuciones posteriores. El aviso puede llegar después de las 24 horas, según el intervalo y la cola.

Los envíos externos de FCM no participan en la transacción Firestore. Si el proceso falla después de enviar y antes de registrar Enviado, un reintento puede repetir el push. Se proporciona un eventoId estable y un tag de notificación para facilitar la deduplicación. No se promete entrega exactamente una vez.

## Integración con notificaciones

La app recibe `tipo=favor_sin_aceptar_24h`, `idFavor` y `eventoId`. El manejo de tokens, permisos push y navegación al tocar la notificación corresponde al módulo de notificaciones de Valeria y no se modificó. La pantalla propia Mi actividad de favores ya permite republicar o retirar.

## Validación local

```powershell
npm ci --ignore-scripts
npm test
npm run check
```

Las once pruebas cubren el umbral de 24 horas, ambos alias, estados excluidos, ciclos distintos, avisos obsoletos, encolado, falta de token, envío y reintentos mediante un adaptador en memoria. Ese adaptador no reproduce consultas reales ni aislamiento transaccional. También se verificó la carga del módulo con sus dependencias. Falta la prueba integral de la cola, los reintentos y la concurrencia con Firestore Emulator, y posteriormente la entrega FCM en un dispositivo. Las pruebas actuales no demuestran esas garantías en producción.

El despliegue previsto usa Node.js 22; las comprobaciones locales disponibles se ejecutaron con Node.js 24. Antes de desplegar se debe repetir la validación con la versión objetivo.

## Revisión antes de activar

El archivo `firestore.indexes.proposed.json` contiene únicamente los índices necesarios para Favores y esta cola. Hay que combinarlos con los índices actuales del equipo, sin reemplazar el inventario completo. Revisar también las reglas: solo el servidor debe escribir `alertasFavores` y `estadoTareasFavores`; el cliente no debe poder desactivar arbitrariamente los avisos.

La activación requiere revisar el proyecto, facturación de Functions/Scheduler, permisos de la cuenta de servicio y reglas junto al equipo. No se ejecutaron despliegues, habilitación de APIs, migraciones ni cambios de facturación.

Referencias: [funciones programadas](https://firebase.google.com/docs/functions/schedule-functions), [envío con Admin SDK](https://firebase.google.com/docs/cloud-messaging/send/admin-sdk).
