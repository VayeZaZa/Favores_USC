import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../config/app_constants.dart';
import '../models/usuario_model.dart';
import '../utils/validators.dart';

/// Servicio de Autenticación de FAVORES USC (RF01, RF02, RN01, RN07)
class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  User? get currentUser => _auth.currentUser;
  Stream<User?> get authStateChanges => _auth.authStateChanges();

  /// RF01: Registro de usuario institucional
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
    await user.sendEmailVerification();

    // 4. Guardar datos de perfil en Firestore (verificado = false inicialmente)
    final nuevoUsuario = UsuarioModel(
      uid: user.uid,
      nombre: nombre.trim(),
      correo: correo.trim().toLowerCase(),
      programa: programa,
      semestre: semestre,
      telefono: telefono.trim(),
      verificado: false,
      intentosFallidos: 0,
      promedio: 5.0,
      favoresCompletados: 0,
      objetosDevueltos: 0,
      insignias: [],
    );

    await _firestore
        .collection('usuarios')
        .doc(user.uid)
        .set(nuevoUsuario.toMap());
  }

  /// RF02: Inicio de sesión con correo y contraseña, control de intentos y bloqueo
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

    // 2. Buscar si el usuario ya existe en Firestore para chequear bloqueo previo
    final userQuery = await _firestore
        .collection('usuarios')
        .where('correo', isEqualTo: emailClean)
        .limit(1)
        .get();

    DocumentSnapshot<Map<String, dynamic>>? userDoc;
    if (userQuery.docs.isNotEmpty) {
      userDoc = userQuery.docs.first;
      final data = userDoc.data()!;
      final usuario = UsuarioModel.fromMap(data, userDoc.id);

      // Si está bloqueado, rechazar de inmediato con el tiempo restante
      if (usuario.estaBloqueado) {
        throw Exception(
          'Cuenta bloqueada por múltiples intentos fallidos. '
          'Intenta nuevamente en ${usuario.minutosRestantesBloqueo} minuto(s).',
        );
      }
    }

    try {
      // 3. Autenticar con Firebase Authentication (RN07: contraseñas con hash)
      final userCredential = await _auth.signInWithEmailAndPassword(
        email: emailClean,
        password: password,
      );

      final user = userCredential.user!;

      // 4. Forzar recarga del estado del usuario para comprobar si ya abrió el enlace
      await user.reload();
      final esVerificado = _auth.currentUser?.emailVerified ?? false;

      // Obtener o refrescar el documento de perfil
      final profileSnapshot = await _firestore.collection('usuarios').doc(user.uid).get();
      if (!profileSnapshot.exists) {
        throw Exception('Perfil no encontrado en Firestore');
      }

      var usuarioActual = UsuarioModel.fromMap(profileSnapshot.data()!, user.uid);

      // Si el email fue verificado pero en Firestore sigue false, actualizarlo a true (RF01)
      if (esVerificado && !usuarioActual.verificado) {
        await _firestore.collection('usuarios').doc(user.uid).update({
          'verificado': true,
        });
        usuarioActual = usuarioActual.copyWith(verificado: true);
      }

      // RF02: Si verificado es falso, negar acceso
      if (!esVerificado) {
        await _auth.signOut();
        throw Exception(
          'EMAIL_NOT_VERIFIED: Tu cuenta aún no ha sido verificada. '
          'Por favor abre el enlace que enviamos a tu correo institucional.',
        );
      }

      // 5. Inicio exitoso: reiniciar intentosFallidos a 0 y limpiar bloqueo (RF02)
      await _firestore.collection('usuarios').doc(user.uid).update({
        'intentosFallidos': 0,
        'bloqueadoHasta': null,
      });

      return usuarioActual.copyWith(intentosFallidos: 0, bloqueadoHasta: null);
    } on FirebaseAuthException catch (e) {
      // 6. Si la contraseña o credencial es incorrecta, registrar intento fallido (RF02)
      if (userDoc != null &&
          (e.code == 'wrong-password' || e.code == 'invalid-credential')) {
        final currentAttempts = (userDoc.data()?['intentosFallidos'] as num?)?.toInt() ?? 0;
        final nuevosIntentos = currentAttempts + 1;

        if (nuevosIntentos >= AppConstants.maxIntentosFallidos) {
          final bloqueo = DateTime.now().add(
            const Duration(minutes: AppConstants.minutosBloqueo),
          );
          await userDoc.reference.update({
            'intentosFallidos': nuevosIntentos,
            'bloqueadoHasta': Timestamp.fromDate(bloqueo),
          });
          throw Exception(
            'Has superado el límite de 5 intentos fallidos. '
            'Tu cuenta ha sido bloqueada por 15 minutos.',
          );
        } else {
          await userDoc.reference.update({
            'intentosFallidos': nuevosIntentos,
          });
          final restantes = AppConstants.maxIntentosFallidos - nuevosIntentos;
          throw Exception(
            'Contraseña incorrecta. Te quedan $restantes intento(s) antes del bloqueo.',
          );
        }
      }

      if (e.code == 'user-not-found') {
        throw Exception('No existe una cuenta registrada con este correo institucional.');
      }

      throw Exception(e.message ?? 'Error al iniciar sesión');
    }
  }

  /// Reenviar enlace de verificación de correo (RF02)
  Future<void> reenviarEnlaceVerificacion() async {
    final user = _auth.currentUser;
    if (user != null && !user.emailVerified) {
      await user.sendEmailVerification();
    }
  }

  /// Cerrar sesión
  Future<void> cerrarSesion() async {
    await _auth.signOut();
  }
}
