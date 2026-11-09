import 'package:flutter/material.dart';
import 'package:flutter_rating_bar/flutter_rating_bar.dart';

import '../../../config/app_theme.dart';
import 'favor_presentacion.dart';

class CalificarFavorSheet extends StatefulWidget {
  const CalificarFavorSheet({
    super.key,
    required this.tituloFavor,
    required this.nombre,
    required this.foto,
    required this.enviar,
  });

  final String tituloFavor;
  final String nombre;
  final String foto;
  final Future<void> Function(int estrellas, String comentario) enviar;

  @override
  State<CalificarFavorSheet> createState() => _CalificarFavorSheetState();
}

class _CalificarFavorSheetState extends State<CalificarFavorSheet> {
  final _comentario = TextEditingController();
  int _estrellas = 0;
  bool _enviando = false;
  String? _error;

  @override
  void dispose() {
    _comentario.dispose();
    super.dispose();
  }

  Future<void> _enviar() async {
    if (_enviando || _estrellas == 0) return;
    FocusScope.of(context).unfocus();
    setState(() {
      _enviando = true;
      _error = null;
    });
    try {
      await widget.enviar(_estrellas, _comentario.text.trim());
      if (mounted) Navigator.pop(context, true);
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _enviando = false;
        _error = error.toString().replaceFirst('Exception: ', '');
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    const etiquetas = [
      'Selecciona una calificación',
      'Muy mala',
      'Mala',
      'Regular',
      'Buena',
      'Excelente',
    ];

    return PopScope(
      canPop: !_enviando,
      child: Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.viewInsetsOf(context).bottom,
        ),
        child: SafeArea(
          top: false,
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Calificar el favor',
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          color: AppTheme.primaryColor,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                    IconButton(
                      tooltip: 'Cerrar',
                      onPressed: _enviando
                          ? null
                          : () => Navigator.pop(context),
                      icon: const Icon(Icons.close),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [AppTheme.primaryLight, AppTheme.primaryColor],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(24),
                  ),
                  child: Column(
                    children: [
                      CircleAvatar(
                        radius: 35,
                        backgroundColor: AppTheme.accentColor,
                        child: FavorAvatar(foto: widget.foto, radius: 31),
                      ),
                      const SizedBox(height: 10),
                      Text(
                        widget.nombre,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 20,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        widget.tituloFavor,
                        textAlign: TextAlign.center,
                        style: const TextStyle(color: AppTheme.doradoClaro),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppTheme.doradoClaro,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Column(
                    children: [
                      const Text(
                        '¿Cómo fue tu experiencia?',
                        style: TextStyle(
                          color: AppTheme.primaryColor,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 8),
                      FittedBox(
                        fit: BoxFit.scaleDown,
                        child: RatingBar.builder(
                          initialRating: _estrellas.toDouble(),
                          minRating: 1,
                          itemCount: 5,
                          itemSize: 36,
                          itemPadding: const EdgeInsets.symmetric(
                            horizontal: 3,
                          ),
                          unratedColor: const Color(0xFFB49B70),
                          ignoreGestures: _enviando,
                          itemBuilder: (_, _) => const Icon(
                            Icons.star_rounded,
                            color: Color(0xFF8A550D),
                          ),
                          onRatingUpdate: (valor) =>
                              setState(() => _estrellas = valor.toInt()),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        etiquetas[_estrellas],
                        style: const TextStyle(color: AppTheme.primaryColor),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),
                TextField(
                  controller: _comentario,
                  enabled: !_enviando,
                  maxLength: 300,
                  minLines: 2,
                  maxLines: 3,
                  textCapitalization: TextCapitalization.sentences,
                  decoration: const InputDecoration(
                    labelText: 'Comentario opcional',
                    hintText: 'Cuéntanos qué salió bien o qué podría mejorar',
                    alignLabelWithHint: true,
                  ),
                ),
                if (_error != null) ...[
                  Text(
                    _error!,
                    style: const TextStyle(color: AppTheme.errorColor),
                  ),
                  const SizedBox(height: 8),
                ],
                FilledButton.icon(
                  onPressed: _enviando || _estrellas == 0 ? null : _enviar,
                  icon: _enviando
                      ? const SizedBox.square(
                          dimension: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.check_rounded),
                  label: Text(_enviando ? 'Guardando…' : 'Enviar calificación'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
