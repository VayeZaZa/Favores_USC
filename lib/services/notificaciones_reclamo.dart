import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';

/// RF11: registra el dispositivo después del inicio de sesión.
class NotificacionesReclamo {
  NotificacionesReclamo(this.uid);

  final String uid;
  StreamSubscription<String>? _renovacion;
  String? _token;
  bool _detenido = false;
  bool _activando = false;

  static bool get compatible =>
      !kIsWeb &&
      [
        TargetPlatform.android,
        TargetPlatform.iOS,
      ].contains(defaultTargetPlatform);

  bool get _sesionVigente =>
      !_detenido && FirebaseAuth.instance.currentUser?.uid == uid;

  bool corresponde(RemoteMessage mensaje) =>
      _sesionVigente &&
      mensaje.data['tipo'] == 'reclamo_objeto' &&
      mensaje.data['destinatario'] == uid;

  DocumentReference<Map<String, dynamic>> get _perfil =>
      FirebaseFirestore.instance.collection('usuarios').doc(uid);

  Future<bool> activar() async {
    if (!compatible || !_sesionVigente || _activando) return false;
    _activando = true;
    try {
      final fcm = FirebaseMessaging.instance;
      final permiso = await fcm.requestPermission();
      if (!_sesionVigente ||
          ![
            AuthorizationStatus.authorized,
            AuthorizationStatus.provisional,
          ].contains(permiso.authorizationStatus)) {
        return false;
      }
      _renovacion ??= fcm.onTokenRefresh.listen((token) {
        unawaited(_guardar(token).catchError((Object _) => false));
      });
      final token = await fcm.getToken();
      return token != null && await _guardar(token);
    } on Exception {
      return false;
    } finally {
      _activando = false;
    }
  }

  Future<bool> _guardar(String token) async {
    if (!_sesionVigente || token.isEmpty) return false;
    _token = token;
    await _perfil.update({'tokenFCM': token});
    return true;
  }

  Future<void> detener({bool cerrarSesion = false}) async {
    _detenido = true;
    await _renovacion?.cancel();
    if (!cerrarSesion ||
        !compatible ||
        FirebaseAuth.instance.currentUser?.uid != uid) {
      return;
    }
    // No quitar el token de otro dispositivo que inició sesión después.
    final token = _token;
    if (token == null) return;
    try {
      await FirebaseFirestore.instance
          .runTransaction((tx) async {
            if ((await tx.get(_perfil)).data()?['tokenFCM'] == token) {
              tx.update(_perfil, {'tokenFCM': null});
            }
          })
          .timeout(const Duration(seconds: 4));
    } on Exception {
      // La revocación del token se intenta aun si Firestore no responde.
    }
    try {
      await FirebaseMessaging.instance.deleteToken().timeout(
        const Duration(seconds: 4),
      );
    } on Exception {
      // El cierre de sesión no depende de la conexión con FCM.
    }
  }
}
