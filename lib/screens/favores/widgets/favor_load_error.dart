import 'package:flutter/material.dart';

import '../../../utils/favor_load_failure.dart';

class FavorLoadError extends StatelessWidget {
  const FavorLoadError({
    super.key,
    required this.failure,
    required this.onRetry,
  });

  final FavorLoadFailure failure;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final icon = switch (failure.kind) {
      FavorLoadFailureKind.sesion => Icons.login_rounded,
      FavorLoadFailureKind.permisos => Icons.lock_outline_rounded,
      FavorLoadFailureKind.indice => Icons.settings_outlined,
      FavorLoadFailureKind.conexion => Icons.wifi_off_rounded,
      FavorLoadFailureKind.datos => Icons.description_outlined,
      FavorLoadFailureKind.desconocido => Icons.error_outline_rounded,
    };
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          icon,
          size: 48,
          color: Theme.of(context).colorScheme.onSurfaceVariant,
        ),
        const SizedBox(height: 12),
        Text(failure.message, textAlign: TextAlign.center),
        const SizedBox(height: 8),
        TextButton(onPressed: onRetry, child: const Text('Reintentar')),
      ],
    );
  }
}
