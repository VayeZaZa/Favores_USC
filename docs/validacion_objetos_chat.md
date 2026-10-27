# Validación de objetos y chat

Cambios locales para RF07, RF12 y RF13. Sin despliegue de reglas ni cambios remotos.

## Comprobaciones automáticas

Con Flutter instalado, ejecutar desde la raíz del proyecto:

```sh
flutter pub get
flutter analyze
flutter test test/chat_access_test.dart
flutter test
```

Las pruebas de permisos cubren los estados de favores y objetos, participantes externos,
reclamos anteriores, cierre, autorización del dueño y retrocesos permitidos.
No sustituyen las pruebas de integración de las transacciones ni las reglas de Firestore.

## Validación con dos cuentas y una tercera cuenta externa

1. A publica un favor y B lo acepta. La aceptación y la creación de sala deben
   guardarse juntas. El chat se abre para B y el botón Chat funciona para A.
2. A y B intercambian texto y fotografías. C no puede acceder como participante.
3. B confirma el pago. Ambos conservan el historial sin poder escribir.
   Si el favor cambia a Cancelado por el flujo correspondiente, también se bloquea
   la escritura al consultar el estado de la publicación.
4. A publica un objeto perdido. B adjunta prueba. El objeto queda Pendiente y
   ambos pueden abrir la sala desde Objetos para ver la evidencia, sin escribir.
5. A confirma la prueba desde el menú del chat. La escritura se habilita en ambos.
   B y C no pueden confirmar, rechazar ni marcar la entrega.
6. A rechaza la prueba o cancela la entrega: el reporte vuelve a Publicado,
   se limpia el reclamante y la sala anterior queda bloqueada. Un nuevo reclamo
   debe crear otra sala y no habilitar la anterior.
7. A marca Entregado. Objeto y sala se cierran juntos. No se puede reabrir el caso.
8. Dos cuentas reclaman simultáneamente: una sola transacción debe ganar y
   guardar tanto el reclamo como la sala y el mensaje de prueba.

## Estado de la verificación

Se preparó Flutter 3.47.8 / Dart 3.13.7 dentro de work/ para esta revisión.
Las pruebas de permisos, estados, reintentos, diálogos y ampliación de la evidencia
se ejecutaron. El análisis estático de los archivos cambiados no tiene incidencias.

La suite general conserva dos fallos en archivos ajenos a estos cambios:
usuario_model_test.dart espera un campo ausente y widget_test.dart busca el botón
Siguiente que la bienvenida actual no presenta. No se modificaron esos módulos.

La contención real de Firestore todavía requiere ejecutar la prueba de integración
descrita en RF13_pruebas.md. No se ha probado la app completa en un dispositivo.

Los controles de sesión y estados incluidos se ejecutan en el cliente.
La autorización frente a clientes modificados requiere reglas de Firestore
compatibles y sus pruebas en emulador. Esta copia de main no contiene esas reglas;
no se modificó la configuración desplegada en Firebase.
