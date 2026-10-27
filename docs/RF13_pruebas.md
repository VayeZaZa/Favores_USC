# RF13 Permisos y concurrencia de objetos

El cambio de estado verifica la sesión, la autoría del reporte, el chat del
reclamo y el estado que el dueño vio al iniciar la acción. Firestore lee y
actualiza el caso y su sala dentro de una transacción. Si otra operación gana,
se rechaza la intención antigua en lugar de actuar sobre un estado nuevo.

El detalle del objeto ahora usa snapshots para reflejar confirmaciones,
rechazos y entregas en ambos dispositivos sin reabrir la pantalla.

## Pruebas locales

```sh
flutter test test/objeto_service_test.dart test/chat_access_test.dart
```

Cubren suplantación, ayudantes y terceros sin permiso, intenciones antiguas,
reclamos anteriores, reapertura, cierre y actualización en tiempo real.
Estas pruebas usan Firestore simulado y no demuestran contención real.

## Prueba de concurrencia con Firestore Emulator

Iniciar desde la raíz del repositorio, con Firebase CLI y Java instalados:

```sh
firebase emulators:start --only firestore --project demo-favores-tests --config test_support/firebase.json
```

En otra terminal, con un emulador Android activo:

```sh
flutter test integration_test/objeto_concurrencia_test.dart -d EMULADOR --dart-define=FIRESTORE_EMULATOR_HOST=10.0.2.2
```

Reemplazar EMULADOR por el identificador de flutter devices. En un dispositivo
físico, usar la dirección de la máquina accesible desde el teléfono.
La prueba confirma y rechaza simultáneamente el mismo caso y exige exactamente
un ganador, con cinco casos aislados. Sin FIRESTORE_EMULATOR_HOST se omite.
Solo usa el proyecto demo-favores-tests; no usa datos de producción.

Las reglas abiertas de test_support son una fixture exclusiva del emulador.
No desplegarlas. Los permisos probados son los del servicio de la aplicación;
las reglas de seguridad reales de Firebase requieren una validación aparte.

Esta prueba de integración todavía no se ha ejecutado en este equipo.
