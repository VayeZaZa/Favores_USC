import 'dart:async';

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';

import '../../models/usuario_model.dart';
import '../../services/auth_service.dart';
import '../../services/notificaciones_reclamo.dart';
import '../auth/welcome_screen.dart';
import '../favores/favores_feed_screen.dart';
import '../objetos/articulos_screen.dart';

class PrincipalScreen extends StatefulWidget {
  const PrincipalScreen({super.key, required this.usuario});

  final UsuarioModel usuario;

  @override
  State<PrincipalScreen> createState() => _PrincipalScreenState();
}

class _PrincipalScreenState extends State<PrincipalScreen> {
  int _indice = 0;
  bool _saliendo = false;
  late final _avisos = NotificacionesReclamo(widget.usuario.uid);
  StreamSubscription<RemoteMessage>? _primerPlano;
  StreamSubscription<RemoteMessage>? _apertura;

  void _seleccionar(int indice) {
    if (mounted) setState(() => _indice = indice);
  }

  @override
  void initState() {
    super.initState();
    if (!NotificacionesReclamo.compatible) return;
    _primerPlano = FirebaseMessaging.onMessage.listen((mensaje) {
      if (!mounted || !_avisos.corresponde(mensaje)) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Tienes un reclamo por revisar.'),
          action: SnackBarAction(
            label: 'Ver objetos',
            onPressed: () => _seleccionar(2),
          ),
        ),
      );
    });
    _apertura = FirebaseMessaging.onMessageOpenedApp.listen((mensaje) {
      if (_avisos.corresponde(mensaje)) _seleccionar(2);
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) unawaited(_avisos.activar());
    });
  }

  @override
  void dispose() {
    unawaited(_primerPlano?.cancel());
    unawaited(_apertura?.cancel());
    unawaited(_avisos.detener());
    super.dispose();
  }

  Future<void> _cerrarSesion() async {
    if (_saliendo) return;
    setState(() => _saliendo = true);
    await _avisos.detener(cerrarSesion: true);
    await AuthService().cerrarSesion();
    if (!mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute<void>(builder: (_) => const WelcomeScreen()),
      (_) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    final usuario = widget.usuario;
    return NavegacionPrincipal(
      indice: _indice,
      alSeleccionar: _seleccionar,
      paginas: [
        Scaffold(
          appBar: AppBar(title: const Text('Inicio')),
          body: ListView(
            padding: const EdgeInsets.all(20),
            children: [
              Text(
                'Hola, ${usuario.nombre}',
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              const SizedBox(height: 12),
              const Text(
                'Ayuda a tu comunidad o revisa los reportes del campus.',
              ),
              const SizedBox(height: 24),
              FilledButton.icon(
                onPressed: () => _seleccionar(1),
                icon: const Icon(Icons.volunteer_activism_outlined),
                label: const Text('Ver favores'),
              ),
              const SizedBox(height: 12),
              OutlinedButton.icon(
                onPressed: () => _seleccionar(2),
                icon: const Icon(Icons.inventory_2_outlined),
                label: const Text('Ver objetos'),
              ),
            ],
          ),
        ),
        FavoresFeedScreen(alAbrirObjetos: () => _seleccionar(2)),
        const ArticulosScreen(),
        Scaffold(
          appBar: AppBar(title: const Text('Perfil')),
          body: ListView(
            padding: const EdgeInsets.all(20),
            children: [
              Text(
                usuario.nombre,
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              Text(usuario.correo),
              Text(usuario.programa),
              const SizedBox(height: 24),
              if (NotificacionesReclamo.compatible)
                OutlinedButton.icon(
                  icon: const Icon(Icons.notifications_outlined),
                  label: const Text('Activar avisos de reclamos'),
                  onPressed: () async {
                    final activo = await _avisos.activar();
                    if (!context.mounted) return;
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                          activo ? 'Avisos activados.' : 'No se pudieron activar. Revisa los permisos del teléfono.',
                        ),
                      ),
                    );
                  },
                ),
              TextButton(
                onPressed: _saliendo ? null : _cerrarSesion,
                child: const Text('Cerrar sesión'),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// RN06: la misma barra y destinos para toda la sesión.
class NavegacionPrincipal extends StatelessWidget {
  const NavegacionPrincipal({
    super.key,
    required this.indice,
    required this.alSeleccionar,
    required this.paginas,
  });

  final int indice;
  final ValueChanged<int> alSeleccionar;
  final List<Widget> paginas;

  @override
  Widget build(BuildContext context) => Scaffold(
    body: KeyedSubtree(key: ValueKey(indice), child: paginas[indice]),
    bottomNavigationBar: NavigationBar(
      selectedIndex: indice,
      onDestinationSelected: alSeleccionar,
      destinations: const [
        NavigationDestination(icon: Icon(Icons.home_outlined), label: 'Inicio'),
        NavigationDestination(
          icon: Icon(Icons.volunteer_activism_outlined),
          label: 'Favores',
        ),
        NavigationDestination(
          icon: Icon(Icons.inventory_2_outlined),
          label: 'Objetos',
        ),
        NavigationDestination(
          icon: Icon(Icons.person_outline),
          label: 'Perfil',
        ),
      ],
    ),
  );
}
