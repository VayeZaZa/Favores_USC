import 'package:flutter/material.dart';

Future<bool> confirmarBorradoPublicacion(
  BuildContext context, {
  required String tipo,
  required String titulo,
}) async {
  final confirmado = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text('¿Borrar el $tipo?'),
      content: Text('«$titulo» se borrará de forma permanente.'),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: const Text('Cancelar'),
        ),
        FilledButton(
          style: FilledButton.styleFrom(
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
          onPressed: () => Navigator.pop(context, true),
          child: const Text('Borrar'),
        ),
      ],
    ),
  );
  return confirmado == true;
}
