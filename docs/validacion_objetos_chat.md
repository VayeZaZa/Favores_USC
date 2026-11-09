# Validación de objetos, chat y avisos

| Requisito | Verificado localmente | Validación pendiente en dispositivo |
| --- | --- | --- |
| RF07 | Firestore Emulator permite el chat del favor aceptado, bloquea a terceros y deja el historial disponible al entregar. Flutter cubre permisos y reintentos. | Intercambiar texto y fotos entre dos cuentas reales y verificar el cierre de ambos tipos de sala. |
| RF10 | Flutter y Firestore Emulator cubren foto opcional en Perdido, obligatoria en Encontrado, colores y persistencia de URL. | Tomar o seleccionar una foto real y confirmar que Cloudinary la recibe y se puede abrir en otro teléfono. |
| RF11 | Reclamo, sala y mensaje de prueba se guardan juntos. El mensaje con evidencia solo se lee desde la sala. La lógica del aviso se probó con FCM simulado. | Activar notificaciones y verificar el aviso en un teléfono, con app en primer plano y en segundo plano. |
| RF12 | Firestore Emulator cubre confirmación, reapertura, entrega y bloqueo de la sala anterior; Flutter cubre diálogos y ampliación de foto. | Recorrer el flujo completo desde las pantallas móviles con dos cuentas. |
| RF13 | Dos decisiones simultáneas sobre el mismo reporte en el emulador dejan un solo ganador. Las reglas rechazan saltos, terceros y escritura desde una sala anterior. | Repetir el escenario desde dos sesiones de la app si se requiere evidencia del cliente móvil. |
| RN03 | Listas con construcción bajo demanda y miniaturas de tamaño acotado en memoria. | Medir fluidez, memoria y tiempo de carga en un Android y un iPhone de gama media. |
| RN06 | Barra compartida con Inicio, Favores, Objetos y Perfil; prueba de navegación en ancho de 360 px. | Comprobar con texto grande, teclado abierto y navegación en teléfonos reales. |

## Reproducir las pruebas

Desde el repositorio, con Flutter, Java 21, Node 22 y Firebase CLI:

```sh
flutter pub get
flutter test
npm --prefix functions ci
npm --prefix functions test
firebase emulators:exec --only firestore --project demo-favores-tests "npm --prefix functions run test:rules"
```

Las pruebas de reglas usan exclusivamente el proyecto ficticio demo-favores-tests
y un servidor local. La prueba Flutter de integración con dispositivo que ya
existía se explica en [RF13_pruebas.md](RF13_pruebas.md). La suite general tiene
dos pruebas previas ajenas a esta entrega: serialización de perfil y navegación
de bienvenida. Las pruebas de RF11 no envían notificaciones reales.

## Activar el aviso en un entorno Firebase de prueba

1. Usar un proyecto de prueba autorizado con Authentication, Firestore,
   Cloud Functions y FCM. Configurar la app para ese proyecto y usar cuentas de
   prueba. El envío ocurre en la función notificarReclamoObjeto después de la
   creación del mensaje privado de evidencia.
2. Revisar diferencias con las reglas e índices desplegados antes de publicar.
   Las reglas parten de la versión de desarrollo y requieren casos con chatId
   vinculado para escribir en el chat. Las conversaciones antiguas se pueden
   leer si son de los participantes. Revisar cómo migrar casos antiguos activos
   sin chatId y retirar las URL de evidencia antiguas que quedaron en reportes.
3. Confirmar que la región de la función corresponde a la ubicación de Firestore.
   Publicar en el proyecto de prueba las reglas, índices y la función; esperar
   a que el índice de Objetos esté listo. Para iOS, habilitar Push Notifications
   en el equipo de firma y configurar APNs en Firebase. No incluir claves en Git.
4. Iniciar sesión como dueño en un dispositivo y activar avisos desde Perfil.
   El perfil conserva un token de dispositivo activo. Con otra cuenta, reportar
   la coincidencia y adjuntar una foto; el dueño recibe un aviso genérico.
   Abrir Objetos y comprobar que solo los dos participantes pueden ver la prueba.
5. Concluir con la matriz de la tabla. Para RN03, usar una compilación de perfil,
   registrar dispositivo/OS y medir el desplazamiento por listados, apertura de
   fotos y zoom con Flutter DevTools. Para RN06, repetir en las cuatro pestañas.

No se han publicado reglas, índices ni funciones en Firebase de producción.
