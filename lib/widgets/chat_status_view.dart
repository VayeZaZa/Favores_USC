import 'package:flutter/material.dart';

class ChatStatusView extends StatelessWidget {
  final String titulo;
  final String detalle;
  final VoidCallback? reintentar;
  final bool cargando;
  const ChatStatusView({
    super.key,
    required this.titulo,
    this.detalle = '',
    this.reintentar,
    this.cargando = false,
  });

  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (cargando)
            const CircularProgressIndicator()
          else
            const Icon(Icons.chat_bubble_outline, size: 40),
          const SizedBox(height: 16),
          Text(
            titulo,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.titleMedium,
          ),
          if (detalle.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(detalle, textAlign: TextAlign.center),
          ],
          if (reintentar != null && !cargando) ...[
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: reintentar,
              icon: const Icon(Icons.refresh),
              label: const Text('Reintentar'),
            ),
          ],
        ],
      ),
    ),
  );
}
