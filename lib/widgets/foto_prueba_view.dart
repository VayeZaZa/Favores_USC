import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

/// Presenta la evidencia completa, con ampliación y recuperación ante errores.
class FotoPruebaView extends StatefulWidget {
  final String url;
  final bool ampliada;
  const FotoPruebaView({super.key, required this.url, this.ampliada = false});
  @override
  State<FotoPruebaView> createState() => _FotoPruebaViewState();
}

class _FotoPruebaViewState extends State<FotoPruebaView> {
  int _intento = 0;
  bool _reintentando = false;

  Future<void> _reintentar() async {
    if (_reintentando) return;
    setState(() => _reintentando = true);
    try {
      await CachedNetworkImage.evictFromCache(widget.url);
    } finally {
      if (mounted) {
        setState(() {
          _intento++;
          _reintentando = false;
        });
      }
    }
  }

  void _ampliar() {
    showDialog<void>(
      context: context,
      builder: (context) => Dialog.fullscreen(
        child: FotoPruebaView(url: widget.url, ampliada: true),
      ),
    );
  }

  Widget _imagen(BoxFit fit) => CachedNetworkImage(
    key: ValueKey('${widget.url}:$_intento'),
    imageUrl: widget.url,
    fit: fit,
    placeholder: (_, _) => const Center(child: CircularProgressIndicator()),
    errorWidget: (_, _, _) => Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text('No se pudo cargar la foto.'),
          TextButton.icon(
            onPressed: _reintentando ? null : _reintentar,
            icon: const Icon(Icons.refresh),
            label: const Text('Reintentar foto'),
          ),
        ],
      ),
    ),
  );

  @override
  Widget build(BuildContext context) {
    if (widget.ampliada) {
      return Scaffold(
        appBar: AppBar(title: const Text('Foto de prueba')),
        body: Center(
          child: InteractiveViewer(
            minScale: 1,
            maxScale: 5,
            child: _imagen(BoxFit.contain),
          ),
        ),
      );
    }
    return Column(
      children: [
        SizedBox(
          height: 190,
          width: double.infinity,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: _imagen(BoxFit.contain),
          ),
        ),
        TextButton.icon(
          onPressed: _ampliar,
          icon: const Icon(Icons.zoom_in),
          label: const Text('Ampliar foto de prueba'),
        ),
      ],
    );
  }
}
