# FAVORES USC

Aplicacion movil Flutter para conectar estudiantes de la Universidad Santiago de
Cali que necesitan u ofrecen favores dentro de la comunidad universitaria.

## Pantallas disponibles

- Bienvenida: presenta brevemente la aplicacion y permite continuar.
- Inicio de sesion: valida correo institucional `@usc.edu.co`.
- Registro: solicita datos personales y academicos, con validaciones y envio de
  verificacion de correo mediante Firebase Authentication.

Las pantallas iniciales usan una identidad visual azul. La carpeta
`assets/images/` esta preparada para el logo de la Universidad y otras imagenes.

## Tecnologias

- Flutter y Dart
- Firebase Core, Authentication, Firestore, Messaging y Storage
- Riverpod para gestion de estado
- Google Fonts y componentes Material
- GoRouter como dependencia para navegacion

## Requisitos

- Flutter SDK instalado y agregado al `PATH`
- Android Studio con Android SDK y un emulador configurado, o un dispositivo
  Android conectado con depuracion USB activada
- Un proyecto Firebase configurado para habilitar autenticacion y persistencia

## Ejecutar en Android

Desde la raiz del proyecto:

```bash
flutter pub get
flutter emulators
flutter emulators --launch <id-del-emulador>
flutter devices
flutter run -d <id-del-dispositivo-android>
```

La primera compilacion de Android puede tardar porque Gradle descarga sus
herramientas. No se deben subir archivos locales como `android/local.properties`.

## Configurar Firebase

La autenticacion y Firestore necesitan un proyecto Firebase propio. Configura
las plataformas con FlutterFire CLI (`flutterfire configure`) antes de probar
registro o inicio de sesion. Sin esa configuracion se pueden revisar las
pantallas, pero las operaciones de cuenta no funcionaran.

## Analisis y pruebas

```bash
flutter analyze
flutter test
```
