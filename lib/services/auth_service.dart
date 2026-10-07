import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import '../config/app_constants.dart';
import '../models/usuario_model.dart';
import '../utils/validators.dart';

/// Servicio de Autenticación de FAVORES USC (RF01, RF02, RN01, RN07)
class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> get _usuariosRef =>
      _firestore.collection('usuarios');

  /// Bandera de desarrollo: cambiar a false en producción para exigir correo verificado (RF01, RF02)
  static const bool bypassEmailVerificationDev = true;

  User? get currentUser => _auth.currentUser;
  Stream<User?> get authStateChanges => _auth.authStateChanges();

  /// RF01: Registro de usuario institucional (Guarda exclusivamente en 'usuarios')
  Future<void> registrarUsuario({
    required String nombre,
    required String correo,
    required String password,
    required String programa,
    required int semestre,
    required String telefono,
  }) async {
    // 1. Doble validación del dominio @usc.edu.co (RN01)
    final emailError = Validators.validateEmail(correo);
    if (emailError != null) {
      throw Exception(emailError);
    }

    // 2. Crear cuenta en Firebase Authentication
    final userCredential = await _auth.createUserWithEmailAndPassword(
      email: correo.trim().toLowerCase(),
      password: password,
    );

    final user = userCredential.user;
    if (user == null) {
      throw Exception('No se pudo crear la cuenta de usuario');
    }

    // 3. Enviar enlace de verificación al correo institucional (RF01)
    try {
      await user.sendEmailVerification();
    } catch (e) {
      // Ignorar error de envío en dev si no llega a tiempo
    }

    // 4. Guardar datos de perfil en Firestore en la colección 'usuarios' (igual que David)
    final nuevoUsuario = UsuarioModel(
      uid: user.uid,
      nombre: nombre.trim(),
      correo: correo.trim().toLowerCase(),
      programa: programa,
      semestre: semestre,
      telefono: telefono.trim(),
      verificado: bypassEmailVerificationDev,
      intentosFallidos: 0,
      promedio: 5.0,
      favoresCompletados: 0,
      favoresDevueltos: 0,
      favoresPedidos: 0,
      objetosDevueltos: 0,
      insignias: ['novato_solidario'],
    );

    await _usuariosRef.doc(user.uid).set(nuevoUsuario.toMap());
  }

  /// RF02: Inicio de sesión con correo y contraseña
  Future<UsuarioModel> iniciarSesion({
    required String correo,
    required String password,
  }) async {
    final emailClean = correo.trim().toLowerCase();

    // 1. Validar dominio institucional en login (RN01)
    final emailError = Validators.validateEmail(emailClean);
    if (emailError != null) {
      throw Exception(emailError);
    }

    try {
      // 2. AUTENTICAR PRIMERO en Firebase Auth para tener permisos de lectura en Firestore
      final userCredential = await _auth.signInWithEmailAndPassword(
        email: emailClean,
        password: password,
      );

      final user = userCredential.user!;

      // 3. Consultar perfil en Firestore (en 'usuarios', con fallback a 'users' si era una cuenta anterior)
      var profileSnapshot = await _usuariosRef.doc(user.uid).get();
      if (!profileSnapshot.exists) {
        profileSnapshot = await _firestore.collection('users').doc(user.uid).get();
        // Si estaba en 'users', migrarlo a 'usuarios' automáticamente
        if (profileSnapshot.exists && profileSnapshot.data() != null) {
          await _usuariosRef.doc(user.uid).set(profileSnapshot.data()!);
        }
      }

      if (!profileSnapshot.exists || profileSnapshot.data() == null) {
        throw Exception('Perfil no encontrado en la base de datos de Firestore.');
      }

      var usuarioActual = UsuarioModel.fromMap(profileSnapshot.data()!, user.uid);

      // 4. Validar si la cuenta está bloqueada temporalmente por intentos fallidos (RF02)
      if (usuarioActual.estaBloqueado) {
        await _auth.signOut();
        throw Exception(
          'Cuenta bloqueada por múltiples intentos fallidos. '
          'Intenta nuevamente en ${usuarioActual.minutosRestantesBloqueo} minuto(s).',
        );
      }

      // 5. Comprobar estado de verificación (o omitir si estamos en modo desarrollo)
      await user.reload();
      final esVerificado = bypassEmailVerificationDev
          ? true
          : (_auth.currentUser?.emailVerified ?? false);

      // Si es verificado (o modo dev), actualizar Firestore si estaba en false
      if (esVerificado && !usuarioActual.verificado) {
        await _usuariosRef.doc(user.uid).update({'verificado': true});
        usuarioActual = usuarioActual.copyWith(verificado: true);
      }

      // RF02: Si verificado es falso y no está en modo dev, negar acceso
      if (!esVerificado) {
        await _auth.signOut();
        throw Exception(
          'EMAIL_NOT_VERIFIED: Tu cuenta aún no ha sido verificada. '
          'Por favor abre el enlace que enviamos a tu correo institucional.',
        );
      }

      // 6. Inicio exitoso: reiniciar intentosFallidos a 0 y limpiar bloqueo (RF02)
      await _usuariosRef.doc(user.uid).update({
        'intentosFallidos': 0,
        'bloqueadoHasta': null,
      });

      return usuarioActual.copyWith(intentosFallidos: 0, bloqueadoHasta: null);
    } on FirebaseAuthException catch (e) {
      if (e.code == 'wrong-password' || e.code == 'invalid-credential') {
        throw Exception('Contraseña o correo institucional incorrectos.');
      }

      if (e.code == 'user-not-found') {
        throw Exception('No existe una cuenta registrada con este correo institucional.');
      }

      throw Exception(e.message ?? 'Error al iniciar sesión');
    }
  }

  /// Reenviar enlace de verificación de correo (RF02)
  Future<void> reenviarEnlaceVerificacion({
    required String correo,
    required String password,
  }) async {
    try {
      final userCredential = await _auth.signInWithEmailAndPassword(
        email: correo.trim().toLowerCase(),
        password: password,
      );
      final user = userCredential.user;
      if (user == null) {
        throw Exception('No se pudo recuperar la cuenta de usuario');
      }

      await user.reload();
      final refreshedUser = _auth.currentUser;
      if (refreshedUser == null) {
        throw Exception('No se pudo recuperar la cuenta de usuario');
      }
      if (refreshedUser.emailVerified) {
        throw Exception(
          'Este correo ya aparece verificado. Intenta iniciar sesión.',
        );
      }

      await refreshedUser.sendEmailVerification();
    } finally {
      if (_auth.currentUser != null) {
        await _auth.signOut();
      }
    }
  }

  /// Enviar enlace para restablecer la contraseña.
  Future<void> enviarEnlaceRecuperacion({required String correo}) async {
    await _auth.sendPasswordResetEmail(email: correo.trim().toLowerCase());
  }

  /// Cerrar sesión
  Future<void> cerrarSesion() async {
    await _auth.signOut();
  }
}
