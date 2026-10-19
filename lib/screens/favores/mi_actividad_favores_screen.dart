import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../models/favor_model.dart';
import '../../providers/favor_provider.dart';
import '../../utils/favor_load_failure.dart';
import 'widgets/favor_load_error.dart';
import 'crear_favor_screen.dart';
import 'favor_detail_screen.dart';

/// Actividad del módulo de Favores. No sustituye el perfil de usuario (RF15).
class MiActividadFavoresScreen extends ConsumerStatefulWidget {
  const MiActividadFavoresScreen({super.key, required this.usuarioId});

  final String usuarioId;

  @override
  ConsumerState<MiActividadFavoresScreen> createState() =>
      _MiActividadFavoresState();
}

class _MiActividadFavoresState extends ConsumerState<MiActividadFavoresScreen> {
  final _scroll = ScrollController();
  final _favores = <FavorModel>[];
  String _filtro = 'Mis favores';
  DocumentSnapshot? _cursor;
  bool _cargando = false;
  bool _hayMas = true;
  FavorLoadFailure? _error;
  String? _accionId;
  int _generacion = 0;

  @override
  void initState() {
    super.initState();
    _scroll.addListener(() {
      if (_scroll.position.extentAfter < 200 && _error == null) _cargar();
    });
    _cargar(reiniciar: true);
  }

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  Future<void> _cargar({bool reiniciar = false}) async {
    if (!reiniciar && (_cargando || !_hayMas)) return;
    if (reiniciar) {
      _generacion++;
      _cursor = null;
      _favores.clear();
      _hayMas = true;
    }
    final generacion = _generacion;
    setState(() {
      _cargando = true;
      _error = null;
    });
    try {
      final pagina = await ref
          .read(favorServiceProvider)
          .obtenerActividadPaginada(
            idUsuario: widget.usuarioId,
            filtro: _filtro,
            lastDocument: _cursor,
          );
      if (!mounted || generacion != _generacion) return;
      setState(() {
        _favores.addAll(
          pagina.docs.map(
            (doc) =>
                FavorModel.fromMap(doc.data() as Map<String, dynamic>, doc.id),
          ),
        );
        _cursor = pagina.docs.isEmpty ? _cursor : pagina.docs.last;
        _hayMas = pagina.docs.length == 10;
        _cargando = false;
      });
    } catch (e, stack) {
      if (!mounted || generacion != _generacion) return;
      registrarErrorCargaFavor('actividad', e, stack);
      setState(() {
        _cargando = false;
        _error = FavorLoadFailure.from(e);
      });
    }
  }

  Future<void> _gestionar(FavorModel favor, {required bool retirar}) async {
    if (_accionId != null) return;
    final confirmar = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(retirar ? '¿Retirar este favor?' : '¿Volver a publicar?'),
        content: Text(
          retirar
              ? 'Dejará de aparecer en el inicio. Lo conservarás en tu actividad como cancelado.'
              : 'Volverá al inicio y comenzará un nuevo plazo de 24 horas.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Volver'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: Text(retirar ? 'Retirar' : 'Republicar'),
          ),
        ],
      ),
    );
    if (confirmar != true || !mounted) return;
    setState(() => _accionId = favor.id);
    try {
      final servicio = ref.read(favorServiceProvider);
      if (retirar) {
        await servicio.retirarFavor(favor.id, idAutor: widget.usuarioId);
      } else {
        await servicio.republicarFavor(favor.id, idAutor: widget.usuarioId);
      }
      if (!mounted) return;
      ref.invalidate(favoresFeedProvider);
      await _cargar(reiniciar: true);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.toString().replaceFirst('Exception: ', ''))),
        );
      }
    } finally {
      if (mounted) setState(() => _accionId = null);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Mi actividad')),
    body: Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(12),
          child: Wrap(
            spacing: 8,
            children: [
              for (final filtro in ['Mis favores', 'Ayudando', 'Finalizados'])
                ChoiceChip(
                  label: Text(filtro == 'Finalizados' ? 'Historial' : filtro),
                  selected: filtro == _filtro,
                  onSelected: (_) {
                    if (_filtro == filtro) return;
                    _filtro = filtro;
                    _cargar(reiniciar: true);
                  },
                ),
            ],
          ),
        ),
        Expanded(
          child: RefreshIndicator(
            onRefresh: () => _cargar(reiniciar: true),
            child: ListView(
              controller: _scroll,
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 100),
              children: [
                if (_favores.isEmpty && !_cargando && _error == null)
                  const Padding(
                    padding: EdgeInsets.all(32),
                    child: Text(
                      'Todavía no hay favores en esta sección.',
                      textAlign: TextAlign.center,
                    ),
                  ),
                for (final favor in _favores) _tarjeta(favor),
                if (_cargando)
                  const Center(
                    child: Padding(
                      padding: EdgeInsets.all(16),
                      child: CircularProgressIndicator(),
                    ),
                  ),
                if (_error != null) ...[
                  FavorLoadError(
                    failure: _error!,
                    onRetry: () => _cargar(reiniciar: _favores.isEmpty),
                  ),
                ] else if (_hayMas && !_cargando && _favores.isNotEmpty)
                  TextButton(
                    onPressed: _cargar,
                    child: const Text('Cargar más'),
                  ),
              ],
            ),
          ),
        ),
      ],
    ),
    floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
    floatingActionButton: FloatingActionButton.extended(
      icon: const Icon(Icons.add),
      label: const Text('Crear favor'),
      onPressed: () async {
        await Navigator.push(
          context,
          MaterialPageRoute<void>(builder: (_) => const CrearFavorScreen()),
        );
        if (mounted) await _cargar(reiniciar: true);
      },
    ),
  );

  Widget _tarjeta(FavorModel favor) {
    final propioPublicado =
        favor.idAutor == widget.usuarioId && favor.esPublicado;
    final vencido =
        propioPublicado &&
        DateTime.now().difference(favor.fechaCreacion) >=
            const Duration(hours: 24);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    favor.titulo.isEmpty ? favor.descripcion : favor.titulo,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  favor.estado,
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.primary,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(favor.ubicacion),
            Text('\$${NumberFormat('#,##0', 'es_CO').format(favor.pago)} COP'),
            if (vencido)
              const Padding(
                padding: EdgeInsets.only(top: 8),
                child: Text(
                  'Han pasado 24 horas sin que alguien acepte. Puedes republicarlo o retirarlo.',
                ),
              ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              children: [
                OutlinedButton(
                  onPressed: () async {
                    await Navigator.push(
                      context,
                      MaterialPageRoute<void>(
                        builder: (_) => FavorDetailScreen(favorId: favor.id),
                      ),
                    );
                    if (mounted) await _cargar(reiniciar: true);
                  },
                  child: const Text('Ver favor'),
                ),
                if (vencido)
                  FilledButton(
                    onPressed: _accionId == null
                        ? () => _gestionar(favor, retirar: false)
                        : null,
                    child: const Text('Republicar'),
                  ),
                if (propioPublicado)
                  TextButton(
                    onPressed: _accionId == null
                        ? () => _gestionar(favor, retirar: true)
                        : null,
                    child: const Text('Retirar'),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
