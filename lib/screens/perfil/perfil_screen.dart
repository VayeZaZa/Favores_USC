import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';

import '../../config/app_theme.dart';
import '../../models/favor_model.dart';
import '../../services/auth_service.dart';
import '../../services/perfil_service.dart';
import '../auth/welcome_screen.dart';

/// Perfil personal con foto persistida en Cloudinary y datos de Firestore.
class PerfilScreen extends StatefulWidget {
  const PerfilScreen({super.key});

  @override
  State<PerfilScreen> createState() => _PerfilScreenState();
}

class _PerfilScreenState extends State<PerfilScreen> {
  static const _navy = Color(0xFF111B43);
  static const _panelBlue = Color(0xFF28365F);
  static const _softBlue = Color(0xFFA9BDE9);
  static const _gold = Color(0xFFFFD981);

  final _authService = AuthService();
  final _perfilService = PerfilService();
  final _imagePicker = ImagePicker();
  bool _subiendoFoto = false;
  bool _cerrandoSesion = false;
  Future<List<FavorModel>>? _favoresFuture;

  String? get _uid => _authService.currentUser?.uid;

  @override
  void initState() {
    super.initState();
    final uid = _uid;
    if (uid != null) _favoresFuture = _perfilService.cargarFavores(uid);
  }

  Future<void> _seleccionarFoto() async {
    final uid = _uid;
    if (uid == null || _subiendoFoto) return;

    try {
      final foto = await _imagePicker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 85,
      );
      if (foto == null || !mounted) return;

      setState(() => _subiendoFoto = true);
      await _perfilService.guardarFotoPerfil(
        uid: uid,
        archivo: File(foto.path),
      );

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Tu foto de perfil se guardó correctamente.'),
          backgroundColor: AppTheme.successColor,
        ),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('No se pudo guardar la foto: $error'),
          backgroundColor: AppTheme.errorColor,
        ),
      );
    } finally {
      if (mounted) setState(() => _subiendoFoto = false);
    }
  }

  Future<void> _editarDatosPersonales({
    required String programa,
    required int semestre,
    required String telefono,
  }) async {
    final uid = _uid;
    if (uid == null) return;

    final guardado = await showDialog<bool>(
      context: context,
      builder: (_) => _EditarPerfilDialog(
        programa: programa,
        semestre: semestre,
        telefono: telefono,
        onGuardar: (programa, semestre, telefono) =>
            _perfilService.actualizarDatosPersonales(
              uid: uid,
              programa: programa,
              semestre: semestre,
              telefono: telefono,
            ),
      ),
    );

    if (guardado != true || !mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Tu información se guardó correctamente.'),
        backgroundColor: AppTheme.successColor,
      ),
    );
  }

  Future<void> _cerrarSesion() async {
    if (_cerrandoSesion) return;
    setState(() => _cerrandoSesion = true);

    try {
      await _authService.cerrarSesion();
      if (!mounted) return;
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute<void>(builder: (_) => const WelcomeScreen()),
        (_) => false,
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No se pudo cerrar sesión. Intenta de nuevo.'),
          backgroundColor: AppTheme.errorColor,
        ),
      );
    } finally {
      if (mounted) setState(() => _cerrandoSesion = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final uid = _uid;
    if (uid == null) {
      return Scaffold(
        backgroundColor: _navy,
        appBar: AppBar(title: const Text('Mi perfil')),
        body: const Center(
          child: Text(
            'Inicia sesión para ver tu perfil.',
            style: TextStyle(color: Colors.white),
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: _navy,
      appBar: AppBar(
        backgroundColor: _navy,
        foregroundColor: Colors.white,
        title: const Text('Mi perfil'),
      ),
      body: StreamBuilder<Map<String, dynamic>?>(
        stream: _perfilService.observarPerfil(uid),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return _mensajeCentrado('No se pudo cargar el perfil.');
          }
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator(color: _gold));
          }

          final perfil = snapshot.data ?? <String, dynamic>{};
          return _contenido(uid, perfil);
        },
      ),
    );
  }

  Widget _contenido(String uid, Map<String, dynamic> perfil) {
    final usuario = _authService.currentUser;
    final nombre = _texto(perfil['display_name'] ?? perfil['nombre'])
        .ifEmpty(usuario?.displayName ?? 'Estudiante USC');
    final correo = _texto(perfil['email'] ?? perfil['correo'])
        .ifEmpty(usuario?.email ?? '');
    final fotoUrl = _texto(perfil['fotoPerfil']);
    final programa = _texto(perfil['programa'])
        .ifEmpty('Programa sin registrar');
    final semestre = (perfil['semestre'] as num?)?.toInt() ?? 1;
    final telefono = _texto(perfil['phone_number'] ?? perfil['telefono'])
        .ifEmpty('Teléfono sin registrar');
    final favoresCompletados = _numero(perfil['favoresCompletados']);
    final objetosDevueltos = _numero(perfil['objetosDevueltos']);
    final promedio =
        (perfil['promedioCalificacion'] as num?)?.toDouble() ??
        (perfil['promedio'] as num?)?.toDouble() ??
        0.0;
    final insignias = _insignias(perfil['insignias']);

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(18, 12, 18, 28),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 560),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _encabezado(nombre: nombre, correo: correo, fotoUrl: fotoUrl),
              const SizedBox(height: 18),
              _tarjeta(
                titulo: 'Información personal',
                icono: Icons.badge_outlined,
                child: Column(
                  children: [
                    _dato(Icons.school_outlined, 'Programa', programa),
                    const Divider(color: Colors.white12, height: 20),
                    _dato(
                      Icons.calendar_month_outlined,
                      'Semestre',
                      '$semestre',
                    ),
                    const Divider(color: Colors.white12, height: 20),
                    _dato(Icons.phone_outlined, 'Teléfono', telefono),
                    const SizedBox(height: 8),
                    Align(
                      alignment: Alignment.centerRight,
                      child: TextButton.icon(
                        onPressed: () => _editarDatosPersonales(
                          programa: _texto(perfil['programa']),
                          semestre: semestre,
                          telefono: _texto(
                            perfil['phone_number'] ?? perfil['telefono'],
                          ),
                        ),
                        icon: const Icon(Icons.edit_outlined, size: 17),
                        label: const Text('Editar información'),
                        style: TextButton.styleFrom(
                          foregroundColor: _gold,
                          textStyle: const TextStyle(
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              _tarjeta(
                titulo: 'Tu recorrido',
                icono: Icons.insights_rounded,
                child: Row(
                  children: [
                    Expanded(
                      child: _estadistica(
                        Icons.volunteer_activism_outlined,
                        '$favoresCompletados',
                        'Favores',
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _estadistica(
                        Icons.inventory_2_outlined,
                        '$objetosDevueltos',
                        'Objetos devueltos',
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _estadistica(
                        Icons.star_rounded,
                        promedio == 0 ? '—' : promedio.toStringAsFixed(1),
                        'Promedio',
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              _tarjeta(
                titulo: 'Insignias',
                icono: Icons.workspace_premium_outlined,
                child: insignias.isEmpty
                    ? const Text(
                        'Aún no tienes insignias.',
                        style: TextStyle(color: _softBlue),
                      )
                    : Wrap(
                        spacing: 9,
                        runSpacing: 9,
                        children: insignias.map(_insignia).toList(),
                      ),
              ),
              const SizedBox(height: 16),
              _seccionFavores(uid),
              const SizedBox(height: 26),
              SizedBox(
                height: 54,
                child: ElevatedButton.icon(
                  onPressed: _cerrandoSesion ? null : _cerrarSesion,
                  icon: _cerrandoSesion
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Icon(Icons.logout_rounded),
                  label: Text(
                    _cerrandoSesion ? 'Cerrando sesión…' : 'Cerrar sesión',
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFE34B4B),
                    foregroundColor: Colors.white,
                    disabledBackgroundColor: const Color(0xFF9B4747),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(18),
                    ),
                    textStyle: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _encabezado({
    required String nombre,
    required String correo,
    required String fotoUrl,
  }) {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 22, 20, 20),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        gradient: const LinearGradient(
          colors: [Color(0xFF28365F), Color(0xFF1A2852)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: Column(
        children: [
          Stack(
            children: [
              Container(
                padding: const EdgeInsets.all(4),
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  color: _gold,
                ),
                child: CircleAvatar(
                  radius: 55,
                  backgroundColor: _navy,
                  backgroundImage: fotoUrl.isEmpty
                      ? null
                      : NetworkImage(fotoUrl),
                  child: fotoUrl.isEmpty
                      ? const Icon(
                          Icons.person_rounded,
                          color: _softBlue,
                          size: 54,
                        )
                      : null,
                ),
              ),
              Positioned(
                right: 1,
                bottom: 1,
                child: Material(
                  color: _gold,
                  shape: const CircleBorder(),
                  child: InkWell(
                    onTap: _subiendoFoto ? null : _seleccionarFoto,
                    customBorder: const CircleBorder(),
                    child: Padding(
                      padding: const EdgeInsets.all(9),
                      child: _subiendoFoto
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: _navy,
                              ),
                            )
                          : const Icon(
                              Icons.camera_alt_rounded,
                              size: 18,
                              color: _navy,
                            ),
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Text(
            nombre,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 21,
              fontWeight: FontWeight.w800,
            ),
          ),
          if (correo.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(
              correo,
              textAlign: TextAlign.center,
              style: const TextStyle(color: _softBlue, fontSize: 13),
            ),
          ],
          const SizedBox(height: 10),
          OutlinedButton.icon(
            onPressed: _subiendoFoto ? null : _seleccionarFoto,
            icon: const Icon(Icons.photo_library_outlined, size: 17),
            label: Text(_subiendoFoto ? 'Subiendo foto…' : 'Cambiar foto'),
            style: OutlinedButton.styleFrom(
              foregroundColor: _gold,
              side: const BorderSide(color: Color(0x66FFD981)),
              shape: const StadiumBorder(),
              textStyle: const TextStyle(fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
    );
  }

  Widget _tarjeta({
    required String titulo,
    required IconData icono,
    required Widget child,
  }) {
    return Container(
      padding: const EdgeInsets.all(17),
      decoration: BoxDecoration(
        color: _panelBlue,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withValues(alpha: 0.07)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icono, color: _gold, size: 19),
              const SizedBox(width: 9),
              Text(
                titulo,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
          const SizedBox(height: 15),
          child,
        ],
      ),
    );
  }

  Widget _dato(IconData icono, String etiqueta, String valor) {
    return Row(
      children: [
        Icon(icono, color: _softBlue, size: 19),
        const SizedBox(width: 11),
        Expanded(
          child: Text(
            etiqueta,
            style: const TextStyle(color: _softBlue, fontSize: 13),
          ),
        ),
        Flexible(
          child: Text(
            valor,
            textAlign: TextAlign.end,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }

  Widget _estadistica(IconData icono, String valor, String etiqueta) {
    return Container(
      constraints: const BoxConstraints(minHeight: 92),
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 11),
      decoration: BoxDecoration(
        color: _navy.withValues(alpha: 0.45),
        borderRadius: BorderRadius.circular(15),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icono, color: _gold, size: 19),
          const SizedBox(height: 5),
          Text(
            valor,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.w800,
            ),
          ),
          Text(
            etiqueta,
            textAlign: TextAlign.center,
            maxLines: 2,
            style: const TextStyle(color: _softBlue, fontSize: 10),
          ),
        ],
      ),
    );
  }

  Widget _insignia(String codigo) {
    final etiqueta = codigo
        .replaceAll('_', ' ')
        .split(' ')
        .map(
          (palabra) => palabra.isEmpty
              ? palabra
              : '${palabra[0].toUpperCase()}${palabra.substring(1)}',
        )
        .join(' ');

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 8),
      decoration: BoxDecoration(
        color: _gold.withValues(alpha: 0.13),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _gold.withValues(alpha: 0.35)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.workspace_premium_rounded, size: 17, color: _gold),
          const SizedBox(width: 6),
          Text(
            etiqueta,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _seccionFavores(String uid) {
    return FutureBuilder<List<FavorModel>>(
      future: _favoresFuture ??= _perfilService.cargarFavores(uid),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return _tarjeta(
            titulo: 'Favores',
            icono: Icons.history_rounded,
            child: const Text(
              'No se pudo cargar el historial ahora.',
              style: TextStyle(color: _softBlue),
            ),
          );
        }
        if (!snapshot.hasData) {
          return const Padding(
            padding: EdgeInsets.all(22),
            child: Center(child: CircularProgressIndicator(color: _gold)),
          );
        }

        final favores = snapshot.data!;
        final enCurso = favores
            .where((favor) => favor.estado == 'Aceptado')
            .toList();
        final historial = favores
            .where((favor) => favor.estado == 'Entregado')
            .toList();
        return Column(
          children: [
            _tarjeta(
              titulo: 'Favores en curso',
              icono: Icons.hourglass_top_rounded,
              child: enCurso.isEmpty
                  ? _vacio('No tienes favores en curso.')
                  : Column(children: enCurso.map(_favorFila).toList()),
            ),
            const SizedBox(height: 16),
            _tarjeta(
              titulo: 'Historial',
              icono: Icons.history_rounded,
              child: historial.isEmpty
                  ? _vacio('Aquí aparecerán tus favores entregados.')
                  : Column(children: historial.map(_favorFila).toList()),
            ),
          ],
        );
      },
    );
  }

  Widget _favorFila(FavorModel favor) {
    final fecha = DateFormat('d/MM/yyyy').format(favor.fechaCreacion);
    return Padding(
      padding: const EdgeInsets.only(bottom: 11),
      child: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: _navy,
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(
              Icons.volunteer_activism_outlined,
              color: _gold,
              size: 19,
            ),
          ),
          const SizedBox(width: 11),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  favor.titulo.isEmpty ? favor.tipoServicio : favor.titulo,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  '${favor.estado} · $fecha',
                  style: const TextStyle(color: _softBlue, fontSize: 11),
                ),
              ],
            ),
          ),
          const Icon(Icons.chevron_right_rounded, color: _softBlue),
        ],
      ),
    );
  }

  Widget _vacio(String texto) =>
      Text(texto, style: const TextStyle(color: _softBlue, fontSize: 13));

  Widget _mensajeCentrado(String texto) => Center(
    child: Padding(
      padding: const EdgeInsets.all(24),
      child: Text(
        texto,
        textAlign: TextAlign.center,
        style: const TextStyle(color: Colors.white),
      ),
    ),
  );

  String _texto(dynamic valor) => valor is String ? valor.trim() : '';

  int _numero(dynamic valor) => valor is num ? valor.toInt() : 0;

  List<String> _insignias(dynamic valor) {
    if (valor is List) return valor.whereType<String>().toList();
    if (valor is String && valor.isNotEmpty) return [valor];
    return const [];
  }
}

class _EditarPerfilDialog extends StatefulWidget {
  const _EditarPerfilDialog({
    required this.programa,
    required this.semestre,
    required this.telefono,
    required this.onGuardar,
  });

  final String programa;
  final int semestre;
  final String telefono;
  final Future<void> Function(String programa, int semestre, String telefono)
  onGuardar;

  @override
  State<_EditarPerfilDialog> createState() => _EditarPerfilDialogState();
}

class _EditarPerfilDialogState extends State<_EditarPerfilDialog> {
  static const _navy = Color(0xFF111B43);
  static const _panelBlue = Color(0xFF28365F);
  static const _softBlue = Color(0xFFA9BDE9);
  static const _gold = Color(0xFFFFD981);

  final _formKey = GlobalKey<FormState>();
  late final _programaController = TextEditingController(text: widget.programa);
  late final _telefonoController = TextEditingController(text: widget.telefono);
  late int _semestre = widget.semestre.clamp(1, 20).toInt();
  bool _guardando = false;
  String? _error;

  @override
  void dispose() {
    _programaController.dispose();
    _telefonoController.dispose();
    super.dispose();
  }

  Future<void> _guardar() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _guardando = true;
      _error = null;
    });

    try {
      await widget.onGuardar(
        _programaController.text,
        _semestre,
        _telefonoController.text,
      );
      if (mounted) Navigator.of(context).pop(true);
    } catch (_) {
      if (mounted) {
        setState(
          () =>
              _error = 'No se pudieron guardar los cambios. Intenta de nuevo.',
        );
      }
    } finally {
      if (mounted) setState(() => _guardando = false);
    }
  }

  InputDecoration _decoracion(String etiqueta, IconData icono) {
    return InputDecoration(
      labelText: etiqueta,
      labelStyle: const TextStyle(color: _softBlue),
      prefixIcon: Icon(icono, color: _softBlue, size: 19),
      filled: true,
      fillColor: _navy.withValues(alpha: 0.45),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(15),
        borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.12)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(15),
        borderSide: const BorderSide(color: _gold, width: 1.5),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(15),
        borderSide: const BorderSide(color: AppTheme.errorColor),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(15),
        borderSide: const BorderSide(color: AppTheme.errorColor, width: 1.5),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: _panelBlue,
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      title: const Text(
        'Editar información',
        style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800),
      ),
      content: SizedBox(
        width: 380,
        child: SingleChildScrollView(
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  controller: _programaController,
                  enabled: !_guardando,
                  textCapitalization: TextCapitalization.words,
                  style: const TextStyle(color: Colors.white),
                  decoration: _decoracion(
                    'Programa académico',
                    Icons.school_outlined,
                  ),
                  validator: (valor) {
                    final texto = valor?.trim() ?? '';
                    if (texto.isEmpty) return 'Escribe tu programa académico';
                    if (texto.length > 120) return 'Máximo 120 caracteres';
                    return null;
                  },
                ),
                const SizedBox(height: 14),
                DropdownButtonFormField<int>(
                  initialValue: _semestre,
                  isExpanded: true,
                  dropdownColor: _navy,
                  style: const TextStyle(color: Colors.white),
                  decoration: _decoracion(
                    'Semestre actual',
                    Icons.calendar_month_outlined,
                  ),
                  items: List.generate(20, (index) => index + 1)
                      .map(
                        (semestre) => DropdownMenuItem(
                          value: semestre,
                          child: Text('Semestre $semestre'),
                        ),
                      )
                      .toList(),
                  onChanged: _guardando
                      ? null
                      : (valor) {
                          if (valor != null) setState(() => _semestre = valor);
                        },
                ),
                const SizedBox(height: 14),
                TextFormField(
                  controller: _telefonoController,
                  enabled: !_guardando,
                  keyboardType: TextInputType.phone,
                  style: const TextStyle(color: Colors.white),
                  decoration: _decoracion(
                    'Teléfono (opcional)',
                    Icons.phone_outlined,
                  ),
                  validator: (valor) => (valor?.trim().length ?? 0) > 30
                      ? 'Máximo 30 caracteres'
                      : null,
                ),
                if (_error != null) ...[
                  const SizedBox(height: 12),
                  Text(
                    _error!,
                    style: const TextStyle(color: Color(0xFFFFC3C9)),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _guardando ? null : () => Navigator.of(context).pop(),
          child: const Text('Cancelar', style: TextStyle(color: _softBlue)),
        ),
        ElevatedButton(
          onPressed: _guardando ? null : _guardar,
          style: ElevatedButton.styleFrom(
            backgroundColor: _gold,
            foregroundColor: _navy,
            shape: const StadiumBorder(),
            textStyle: const TextStyle(fontWeight: FontWeight.w800),
          ),
          child: _guardando
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: _navy,
                  ),
                )
              : const Text('Guardar'),
        ),
      ],
    );
  }
}

extension on String {
  String ifEmpty(String replacement) => isEmpty ? replacement : this;
}
