import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../config/app_constants.dart';
import '../../config/app_theme.dart';
import '../../utils/favor_validators.dart';

class CampusPicker extends StatelessWidget {
  const CampusPicker({super.key, required this.punto, required this.onChanged});

  final String? punto;
  final ValueChanged<String> onChanged;

  Future<void> _abrir(BuildContext context) async {
    final elegido = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (context) => Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.viewInsetsOf(context).bottom,
        ),
        child: FractionallySizedBox(
          heightFactor: 0.94,
          child: _SelectorCampus(puntoInicial: punto),
        ),
      ),
    );
    if (context.mounted && elegido != null) onChanged(elegido);
  }

  @override
  Widget build(BuildContext context) {
    final lugar = punto?.split(' · ').first;
    return OutlinedButton.icon(
      onPressed: () => _abrir(context),
      icon: const Icon(Icons.map_outlined),
      label: Text(
        lugar == null
            ? 'Elegir punto de encuentro'
            : 'Punto de encuentro: $lugar',
      ),
    );
  }
}

class _SelectorCampus extends StatefulWidget {
  const _SelectorCampus({required this.puntoInicial});

  final String? puntoInicial;

  @override
  State<_SelectorCampus> createState() => _SelectorCampusState();
}

class _SelectorCampusState extends State<_SelectorCampus> {
  static const _marcadores = <String, Alignment>{
    'Canchas': Alignment(0.42, -0.55),
    'Parqueadero de estudiantes': Alignment(-0.39, -0.20),
    'Plazoleta de los Sabios': Alignment(0.05, 0.29),
    'Plazoleta de la Arena USC': Alignment(-0.55, 0.46),
    'Medialuna del Bloque 2': Alignment(0.39, 0.59),
    'Entrada del Bloque 1': Alignment(0.65, 0.69),
    'El Lago': Alignment(0.16, 0.78),
  };

  static const _grupos = {
    'Bloques del campus': AppConstants.bloquesCampus,
    'Comida y descanso': AppConstants.zonasComidaDescanso,
    'Deporte y juegos': AppConstants.zonasDeporteJuegos,
    'Entradas y otros lugares': AppConstants.accesosCampus,
  };

  String? _punto;
  String _piso = '';
  String _salon = '';
  String _detalles = '';
  final _detallesKey = GlobalKey();

  bool get _esBloque => AppConstants.bloquesCampus.contains(_punto);

  String? get _resumen {
    final punto = _punto;
    if (punto == null) return null;
    return [
      punto,
      if (_esBloque && _piso.trim().isNotEmpty) 'Piso ${_piso.trim()}',
      if (_esBloque && _salon.trim().isNotEmpty) 'Salón ${_salon.trim()}',
      if (_detalles.trim().isNotEmpty) 'Detalles: ${_detalles.trim()}',
    ].join(' · ');
  }

  @override
  void initState() {
    super.initState();
    final partes = widget.puntoInicial?.split(' · ');
    if (partes == null) return;
    _punto = partes.first == 'Bulevar USC (restaurantes)'
        ? 'Plazoleta de comidas'
        : partes.first;
    for (final parte in partes.skip(1)) {
      if (parte.startsWith('Piso ')) _piso = parte.substring('Piso '.length);
      if (parte.startsWith('Salón ')) _salon = parte.substring('Salón '.length);
      if (parte.startsWith('Detalles: ')) {
        _detalles = parte.substring('Detalles: '.length);
      }
    }
  }

  void _seleccionar(String punto) {
    if (_punto == punto) return;
    setState(() {
      _punto = punto;
      _piso = '';
      _salon = '';
      _detalles = '';
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final detallesContext = _detallesKey.currentContext;
      if (!mounted || detallesContext == null) return;
      Scrollable.ensureVisible(
        detallesContext,
        duration: const Duration(milliseconds: 230),
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    final resumen = _resumen;
    final salon = _salon.trim();
    final error =
        _esBloque && salon.isNotEmpty && !RegExp(r'^\d{4}$').hasMatch(salon)
        ? 'Escribe el código de 4 dígitos del salón.'
        : resumen == null
        ? null
        : FavorValidators.ubicacion(resumen);
    return SafeArea(
      top: false,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 8, 8, 4),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    'Campus USC · Pampalinda',
                    style: tema.textTheme.titleLarge,
                  ),
                ),
                IconButton(
                  tooltip: 'Cerrar selector',
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close),
                ),
              ],
            ),
          ),
          Expanded(
            child: SingleChildScrollView(
              keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
              padding: const EdgeInsets.fromLTRB(20, 4, 20, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Toca un marcador o elige un lugar de la lista.'),
                  const SizedBox(height: 12),
                  _mapa(),
                  for (final grupo in _grupos.entries) ...[
                    const SizedBox(height: 16),
                    Text(grupo.key, style: tema.textTheme.titleSmall),
                    const SizedBox(height: 6),
                    Wrap(
                      spacing: 8,
                      runSpacing: 4,
                      children: [
                        for (final lugar in grupo.value)
                          ChoiceChip(
                            label: Text(lugar),
                            selected: lugar == _punto,
                            onSelected: (_) => _seleccionar(lugar),
                          ),
                      ],
                    ),
                  ],
                  if (_punto != null) ...[
                    const SizedBox(height: 20),
                    Text(
                      'Detalles del punto de encuentro',
                      key: _detallesKey,
                      style: tema.textTheme.titleMedium,
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      'Agrega una referencia para que sea más fácil encontrarte.',
                    ),
                    const SizedBox(height: 12),
                    if (_esBloque) ...[
                      _campo(
                        'Piso (opcional)',
                        'Ej. 2',
                        _piso,
                        12,
                        (valor) => setState(() => _piso = valor),
                      ),
                      const SizedBox(height: 8),
                      _campo(
                        'Salón de 4 dígitos (opcional)',
                        'Ej. ${_punto!.split(' ').last}405',
                        _salon,
                        4,
                        (valor) => setState(() => _salon = valor),
                        soloDigitos: true,
                      ),
                      const SizedBox(height: 8),
                    ],
                    _campo(
                      'Referencia (opcional)',
                      'Ej. Junto a la entrada',
                      _detalles,
                      100,
                      (valor) => setState(() => _detalles = valor),
                    ),
                  ],
                ],
              ),
            ),
          ),
          const Divider(height: 1),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 10, 20, 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text('Punto de encuentro', style: tema.textTheme.titleSmall),
                Text(
                  error ?? resumen ?? 'Elige un bloque o una zona.',
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                  style: error == null
                      ? null
                      : TextStyle(color: tema.colorScheme.error),
                ),
                const SizedBox(height: 8),
                FilledButton(
                  onPressed: resumen == null || error != null
                      ? null
                      : () => Navigator.pop(context, resumen),
                  child: const Text('Confirmar punto'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _mapa() => ClipRRect(
    borderRadius: BorderRadius.circular(16),
    child: AspectRatio(
      aspectRatio: 598 / 505,
      child: Stack(
        fit: StackFit.expand,
        children: [
          Image.asset(
            'assets/images/mapa_usc_pampalinda.png',
            fit: BoxFit.fill,
            excludeFromSemantics: true,
          ),
          for (final marcador in _marcadores.entries)
            Align(
              alignment: marcador.value,
              child: IconButton(
                tooltip: marcador.key,
                onPressed: () => _seleccionar(marcador.key),
                style: IconButton.styleFrom(
                  backgroundColor: AppTheme.primaryColor,
                  foregroundColor: AppTheme.accentColor,
                ),
                icon: Icon(
                  marcador.key == _punto ? Icons.check_circle : Icons.place,
                  size: 19,
                ),
              ),
            ),
        ],
      ),
    ),
  );

  Widget _campo(
    String etiqueta,
    String ejemplo,
    String valorInicial,
    int maximo,
    ValueChanged<String> onChanged, {
    bool soloDigitos = false,
  }) => TextFormField(
    key: ValueKey('$_punto/$etiqueta'),
    initialValue: valorInicial,
    maxLength: maximo,
    keyboardType: soloDigitos ? TextInputType.number : TextInputType.text,
    inputFormatters: [
      if (soloDigitos)
        FilteringTextInputFormatter.digitsOnly
      else
        FilteringTextInputFormatter.deny(RegExp(r'[·\r\n]')),
    ],
    decoration: InputDecoration(
      labelText: etiqueta,
      hintText: ejemplo,
      counterText: '',
    ),
    onChanged: onChanged,
  );
}
