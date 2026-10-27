import 'package:flutter/material.dart';

/// Confirma la intención antes de cambiar el estado persistido del objeto.
class ConfirmarObjetoDialog extends StatelessWidget {
  final String nuevoEstado;
  final bool esRechazo;
  const ConfirmarObjetoDialog({
    super.key,
    required this.nuevoEstado,
    this.esRechazo = false,
  });

  @override
  Widget build(BuildContext context) {
    final cerrar = nuevoEstado == 'Entregado';
    return AlertDialog(
      title: Text(
        esRechazo
            ? '¿Reabrir el reporte?'
            : cerrar
            ? '¿Recibiste el objeto?'
            : '¿La prueba corresponde al objeto?',
      ),
      content: Text(
        esRechazo
            ? 'Se liberará el reclamo y se cerrará esta conversación. El reporte volverá a estar disponible.'
            : cerrar
            ? 'Confirma solo si ya recibiste el objeto. El caso se cerrará y el chat quedará en solo lectura. Esta acción no se puede deshacer.'
            : 'Al confirmar la foto de prueba, ambos podrán conversar para coordinar la entrega.',
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: const Text('Volver'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(context, true),
          child: Text(
            esRechazo
                ? 'Reabrir reporte'
                : cerrar
                ? 'Sí, lo recibí'
                : 'Confirmar coincidencia',
          ),
        ),
      ],
    );
  }
}
