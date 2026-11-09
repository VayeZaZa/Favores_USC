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

  /// Cuentas del equipo que pueden entrar sin confirmar el correo.
  /// Las reglas de Firestore deben mantener la misma lista.
  static const Set<String> correosExentosVerificacion = {
    'alex@usc.edu.co',
    'valeria@usc.edu.co',
    'david@usc.edu.co',
  };

  static bool estaExentoDeVerificacion(String correo) =>
      correosExentosVerificacion.contains(correo.trim().toLowerCase());

  User? get currentUser => _auth.currentUser;
  Stream<User?> get authStateChanges => _auth.authStateChanges();

  /// RF01: Crea el perfil y envía el correo si la cuenta requiere verificación.
  /// Retorna true únicamente cuando Firebase acepta el envío del enlace.
  Future<bool> registrarUsuario({
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

    final estaExento = estaExentoDeVerificacion(correo);

    // 3. Guardar el perfil para que el usuario pueda solicitar otro enlace
    // desde el inicio de sesión si Firebase falla al enviar el primero.
    final nuevoUsuario = UsuarioModel(
      uid: user.uid,
      nombre: nombre.trim(),
      correo: correo.trim().toLowerCase(),
      programa: programa,
      semestre: semestre,
      telefono: telefono.trim(),
      verificado: estaExento,
      intentosFallidos: 0,
      promedio: 0.0,
      favoresCompletados: 0,
      favoresDevueltos: 0,
      favoresPedidos: 0,
      objetosDevueltos: 0,
      insignias: ['novato_solidario'],
    );

    await _usuariosRef.doc(user.uid).set(nuevoUsuario.toMap());

    // Las tres cuentas del equipo están exentas de verificación.
    if (estaExento) return false;

    // No informar éxito de envío si Firebase rechazó la solicitud.
    try {
      await user.sendEmailVerification();
      return true;
    } catch (_) {
      // El perfil ya existe; se puede reenviar desde la pantalla de acceso.
      return false;
    }
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

      // 3. Consultar perfil en Firestore únicamente en la colección 'usuarios'
      final profileSnapshot = await _usuariosRef.doc(user.uid).get();

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

      // 5. Comprobar el estado actualizado de verificación o la excepción del equipo.
      await user.reload();
      await user.getIdToken(true);
      final esVerificado = (_auth.currentUser?.emailVerified ?? false) ||
          estaExentoDeVerificacion(emailClean);

      // Si está verificado o exento, actualizar el perfil si estaba en false.
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
      final datosActualizar = <String, dynamic>{
        'intentosFallidos': 0,
        'bloqueadoHasta': null,
      };

      // Si no tiene la insignia 'novato_solidario', asignarla y actualizarla en Firestore
      if (usuarioActual.insignias.isEmpty ||
          !usuarioActual.insignias.contains('novato_solidario')) {
        final nuevasInsignias = List<String>.from(usuarioActual.insignias);
        if (!nuevasInsignias.contains('novato_solidario')) {
          nuevasInsignias.add('novato_solidario');
        }
        datosActualizar['insignias'] = nuevasInsignias;
        usuarioActual = usuarioActual.copyWith(insignias: nuevasInsignias);
      }

      await _usuariosRef.doc(user.uid).update(datosActualizar);

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
