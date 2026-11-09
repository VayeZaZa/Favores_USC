import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import '../../config/app_theme.dart';
import '../../providers/objeto_provider.dart';
import '../../services/auth_service.dart';
import '../widgets/campus_picker.dart';

/// Pantalla para Publicar Objeto Perdido o Encontrado (RF10)
/// - Obligatoriedad de foto para "Encontrado"
/// - Foto opcional para "Perdido"
/// - Compresión previa y subida a Cloudinary
class ReportarObjetoScreen extends ConsumerStatefulWidget {
  const ReportarObjetoScreen({super.key});

  @override
  ConsumerState<ReportarObjetoScreen> createState() =>
      _ReportarObjetoScreenState();
}

class _ReportarObjetoScreenState extends ConsumerState<ReportarObjetoScreen> {
  final _formKey = GlobalKey<FormState>();
  final _tituloController = TextEditingController();
  final _descripcionController = TextEditingController();
  final _ubicacionActualController = TextEditingController();

  String _tipoSeleccionado = 'perdido'; // 'perdido' | 'encontrado'
  String _dondeQuedo = 'Lo tengo conmigo';
  String? _lugarSeleccionado;
  File? _imagenArchivo;
  bool _isLoading = false;
  bool _eligiendoFoto = false;

  final ImagePicker _picker = ImagePicker();

  @override
  void initState() {
    super.initState();
    if (Platform.isAndroid) _recuperarFoto();
  }

  @override
  void dispose() {
    _tituloController.dispose();
    _descripcionController.dispose();
    _ubicacionActualController.dispose();
    super.dispose();
  }

  Future<void> _seleccionarFoto(ImageSource source) async {
    if (_isLoading || _eligiendoFoto) return;
    setState(() => _eligiendoFoto = true);
    try {
      final picked = await _picker.pickImage(
        source: source,
        maxWidth: 1600,
        maxHeight: 1600,
        imageQuality: 85,
      );
      if (mounted && picked != null) {
        setState(() {
          _imagenArchivo = File(picked.path);
        });
      }
    } catch (error) {
      if (!mounted) return;
      debugPrint('No se pudo seleccionar una foto: $error');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text(
            'No pude abrir la foto. Intenta desde la galería.',
          ),
          backgroundColor: AppTheme.errorColor,
        ),
      );
    } finally {
      if (mounted) setState(() => _eligiendoFoto = false);
    }
  }

  Future<void> _recuperarFoto() async {
    try {
      final respuesta = await _picker.retrieveLostData();
      final archivos = respuesta.files;
      if (mounted &&
          _imagenArchivo == null &&
          archivos != null &&
          archivos.isNotEmpty) {
        setState(() => _imagenArchivo = File(archivos.first.path));
      }
    } catch (error) {
      debugPrint('No se pudo recuperar la foto del reporte: $error');
    }
  }

  Future<void> _publicarObjeto() async {
    if (_isLoading || _eligiendoFoto) return;
    if (!_formKey.currentState!.validate()) return;

    if (_lugarSeleccionado == null || _lugarSeleccionado!.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Por favor selecciona una ubicación del campus.'),
          backgroundColor: AppTheme.warningColor,
        ),
      );
      return;
    }

    // Validación RF10: Foto obligatoria para objetos "encontrados"
    final esEncontrado = _tipoSeleccionado == 'encontrado';
    if (esEncontrado && _imagenArchivo == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Agrega una foto del objeto que encontraste.'),
          backgroundColor: AppTheme.errorColor,
        ),
      );
      return;
    }

    final user = AuthService().currentUser;
    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Debes iniciar sesión para publicar.'),
          backgroundColor: AppTheme.warningColor,
        ),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      final objetoService = ref.read(objetoServiceProvider);
      final nombreDueno =
          user.displayName ?? user.email?.split('@').first ?? 'Estudiante USC';
      final detalleUbicacion = _ubicacionActualController.text.trim();

      await objetoService.publicarObjeto(
        idDueno: user.uid,
        nombreDueno: nombreDueno,
        titulo: _tituloController.text.trim(),
        descripcion: _descripcionController.text.trim(),
        tipo: _tipoSeleccionado,
        etiquetaColor: 'sin_color',
        lugarCampus: _lugarSeleccionado!,
        dondeQuedo: esEncontrado
            ? [
                _dondeQuedo,
                if (detalleUbicacion.isNotEmpty) detalleUbicacion,
              ].join(': ')
            : '',
        imagenArchivo: _imagenArchivo,
      );

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('¡Objeto publicado con éxito!'),
          backgroundColor: AppTheme.successColor,
        ),
      );
      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error publicando objeto: $e'),
          backgroundColor: AppTheme.errorColor,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final esEncontrado = _tipoSeleccionado == 'encontrado';

    return Scaffold(
      backgroundColor: AppTheme.surfaceColor,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.close_rounded, color: Color(0xFF1E293B)),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Reportar Objeto',
          style: TextStyle(
            color: Color(0xFF1E293B),
            fontWeight: FontWeight.bold,
            fontSize: 18,
          ),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 1. Selector de Tipo (Perdido vs Encontrado)
              const Text(
                '¿Qué deseas reportar?',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF1E293B),
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: _buildTipoCard(
                      tipo: 'perdido',
                      label: 'Perdí algo',
                      icono: Icons.search_off_rounded,
                      colorActivo: const Color(0xFFEF4444),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: _buildTipoCard(
                      tipo: 'encontrado',
                      label: 'Encontré algo',
                      icono: Icons.check_circle_outline_rounded,
                      colorActivo: const Color(0xFF10B981),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),

              // 2. Título
              const Text(
                'Título del Objeto',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                  color: Color(0xFF1E293B),
                ),
              ),
              const SizedBox(height: 8),
              TextFormField(
                controller: _tituloController,
                decoration: InputDecoration(
                  hintText: esEncontrado
                      ? 'Ej: Calculadora Casio fx-570'
                      : 'Ej: Llaves con llavero rojo',
                  filled: true,
                  fillColor: Colors.white,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: BorderSide(color: Colors.grey.shade300),
                  ),
                ),
                validator: (val) {
                  if (val == null || val.trim().isEmpty) {
                    return 'El título es obligatorio';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 20),

              // 4. Ubicación en el Campus
              const Text(
                'Lugar del Campus',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                  color: Color(0xFF1E293B),
                ),
              ),
              const SizedBox(height: 8),
              CampusPicker(
                punto: _lugarSeleccionado,
                onChanged: (val) => setState(() => _lugarSeleccionado = val),
              ),
              if (esEncontrado) ...[
                const SizedBox(height: 20),
                DropdownButtonFormField<String>(
                  initialValue: _dondeQuedo,
                  isExpanded: true,
                  decoration: const InputDecoration(
                    labelText: '¿Dónde está el objeto?',
                    prefixIcon: Icon(Icons.inventory_2_outlined),
                    filled: true,
                    fillColor: Colors.white,
                  ),
                  items: const [
                    DropdownMenuItem(
                      value: 'Lo tengo conmigo',
                      child: Text('Lo tengo conmigo'),
                    ),
                    DropdownMenuItem(
                      value: 'Lo dejé en objetos perdidos USC',
                      child: Text('Lo dejé en objetos perdidos USC'),
                    ),
                    DropdownMenuItem(
                      value: 'Lo dejé en otro lugar',
                      child: Text('Lo dejé en otro lugar'),
                    ),
                  ],
                  onChanged: (valor) {
                    if (valor != null) setState(() => _dondeQuedo = valor);
                  },
                ),
                const SizedBox(height: 8),
                TextFormField(
                  controller: _ubicacionActualController,
                  maxLength: 140,
                  decoration: const InputDecoration(
                    labelText: 'Detalle (opcional)',
                    hintText: 'Ej. Caseta de objetos perdidos, parqueadero del Bloque 8',
                    filled: true,
                    fillColor: Colors.white,
                  ),
                ),
              ],
              const SizedBox(height: 20),

              Text(
                esEncontrado ? 'Foto (obligatoria)' : 'Foto (opcional)',
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                  color: Color(0xFF1E293B),
                ),
              ),
              const SizedBox(height: 8),

              if (_imagenArchivo != null)
                Stack(
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(16),
                      child: Image.file(
                        _imagenArchivo!,
                        height: 180,
                        width: double.infinity,
                        fit: BoxFit.cover,
                      ),
                    ),
                    Positioned(
                      top: 8,
                      right: 8,
                      child: CircleAvatar(
                        backgroundColor: Colors.black54,
                        radius: 18,
                        child: IconButton(
                          icon: const Icon(
                            Icons.close,
                            color: Colors.white,
                            size: 18,
                          ),
                          onPressed: () =>
                              setState(() => _imagenArchivo = null),
                        ),
                      ),
                    ),
                  ],
                )
              else
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: _eligiendoFoto
                            ? null
                            : () => _seleccionarFoto(ImageSource.camera),
                        icon: const Icon(
                          Icons.camera_alt,
                          color: AppTheme.primaryColor,
                        ),
                        label: const Text('Cámara'),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: _eligiendoFoto
                            ? null
                            : () => _seleccionarFoto(ImageSource.gallery),
                        icon: const Icon(
                          Icons.photo_library,
                          color: AppTheme.primaryColor,
                        ),
                        label: const Text('Galería'),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              const SizedBox(height: 20),

              // 6. Descripción
              const Text(
                'Descripción Detallada',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                  color: Color(0xFF1E293B),
                ),
              ),
              const SizedBox(height: 8),
              TextFormField(
                controller: _descripcionController,
                maxLines: 3,
                decoration: InputDecoration(
                  hintText: 'Describe características, marcas particulares, horario aproximado...',
                  filled: true,
                  fillColor: Colors.white,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: BorderSide(color: Colors.grey.shade300),
                  ),
                ),
                validator: (val) {
                  if (val == null || val.trim().isEmpty) {
                    return 'La descripción es obligatoria';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 32),

              // 7. Botón Publicar
              SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton(
                  onPressed: _isLoading || _eligiendoFoto
                      ? null
                      : _publicarObjeto,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primaryColor,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(30),
                    ),
                    elevation: 4,
                  ),
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 200),
                    child: _isLoading
                        ? const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              SizedBox.square(
                                dimension: 16,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              ),
                              SizedBox(width: 10),
                              Text('Publicando reporte…'),
                            ],
                          )
                        : const Text(
                            'Publicar Objeto',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
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

  Widget _buildTipoCard({
    required String tipo,
    required String label,
    required IconData icono,
    required Color colorActivo,
  }) {
    final seleccionado = _tipoSeleccionado == tipo;
    return InkWell(
      onTap: () => setState(() => _tipoSeleccionado = tipo),
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
        decoration: BoxDecoration(
          color: seleccionado ? colorActivo.withOpacity(0.08) : Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: seleccionado ? colorActivo : Colors.grey.shade200,
            width: seleccionado ? 2 : 1,
          ),
        ),
        child: Column(
          children: [
            Icon(
              icono,
              color: seleccionado ? colorActivo : const Color(0xFF64748B),
              size: 28,
            ),
            const SizedBox(height: 8),
            Text(
              label,
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 14,
                color: seleccionado ? colorActivo : const Color(0xFF64748B),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
