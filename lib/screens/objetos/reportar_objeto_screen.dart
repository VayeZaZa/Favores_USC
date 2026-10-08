import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import '../../config/app_constants.dart';
import '../../config/app_theme.dart';
import '../../providers/objeto_provider.dart';
import '../../services/auth_service.dart';

/// Pantalla para Publicar Objeto Perdido o Encontrado (RF10)
/// - Obligatoriedad de foto para "Encontrado"
/// - Foto opcional para "Perdido"
/// - Etiquetado por colores
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

  String _tipoSeleccionado = 'perdido'; // 'perdido' | 'encontrado'
  String _colorSeleccionado = 'rojo';
  String? _lugarSeleccionado;
  File? _imagenArchivo;
  bool _isLoading = false;

  final ImagePicker _picker = ImagePicker();

  final List<Map<String, dynamic>> _coloresDisponibles = [
    {'nombre': 'rojo', 'color': const Color(0xFFEF4444), 'label': 'Rojo'},
    {'nombre': 'azul', 'color': const Color(0xFF3B82F6), 'label': 'Azul'},
    {'nombre': 'verde', 'color': const Color(0xFF10B981), 'label': 'Verde'},
    {'nombre': 'amarillo', 'color': const Color(0xFFF59E0B), 'label': 'Amarillo'},
    {'nombre': 'morado', 'color': const Color(0xFF8B5CF6), 'label': 'Morado'},
    {'nombre': 'negro', 'color': const Color(0xFF1E293B), 'label': 'Negro'},
  ];

  @override
  void dispose() {
    _tituloController.dispose();
    _descripcionController.dispose();
    super.dispose();
  }

  Future<void> _seleccionarFoto(ImageSource source) async {
    try {
      final picked = await _picker.pickImage(
        source: source,
        imageQuality: 85,
      );
      if (picked != null) {
        setState(() {
          _imagenArchivo = File(picked.path);
        });
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error seleccionando imagen: $e'),
          backgroundColor: AppTheme.errorColor,
        ),
      );
    }
  }

  Future<void> _publicarObjeto() async {
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
    if (_tipoSeleccionado == 'encontrado' && _imagenArchivo == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            '⚠️ Para reportar un objeto ENCONTRADO la fotografía es obligatoria (RF10).',
          ),
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
      final nombreDueno = user.displayName ??
          user.email?.split('@').first ??
          'Estudiante USC';

      await objetoService.publicarObjeto(
        idDueno: user.uid,
        nombreDueno: nombreDueno,
        titulo: _tituloController.text.trim(),
        descripcion: _descripcionController.text.trim(),
        tipo: _tipoSeleccionado,
        etiquetaColor: _colorSeleccionado,
        lugarCampus: _lugarSeleccionado!,
        imagenArchivo: _imagenArchivo,
      );

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('¡Objeto publicado con éxito!'),
          backgroundColor: AppTheme.successColor,
        ),
      );
      Navigator.pop(context);
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
      backgroundColor: const Color(0xFFF8FAFC),
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
                  hintText: esEncontrado ? 'Ej: Calculadora Casio fx-570' : 'Ej: Llaves con llavero rojo',
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

              // 3. Etiquetado por Color (RF10)
              const Text(
                'Color representativo (Etiquetado)',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                  color: Color(0xFF1E293B),
                ),
              ),
              const SizedBox(height: 8),
              SizedBox(
                height: 48,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: _coloresDisponibles.length,
                  separatorBuilder: (_, __) => const SizedBox(width: 10),
                  itemBuilder: (context, index) {
                    final item = _coloresDisponibles[index];
                    final seleccionado = _colorSeleccionado == item['nombre'];
                    return InkWell(
                      onTap: () => setState(() => _colorSeleccionado = item['nombre']),
                      borderRadius: BorderRadius.circular(24),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                        decoration: BoxDecoration(
                          color: seleccionado ? AppTheme.primaryColor.withOpacity(0.1) : Colors.white,
                          borderRadius: BorderRadius.circular(24),
                          border: Border.all(
                            color: seleccionado ? AppTheme.primaryColor : Colors.grey.shade300,
                            width: seleccionado ? 2 : 1,
                          ),
                        ),
                        child: Row(
                          children: [
                            CircleAvatar(
                              radius: 8,
                              backgroundColor: item['color'] as Color,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              item['label'] as String,
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: seleccionado ? FontWeight.bold : FontWeight.normal,
                                color: const Color(0xFF1E293B),
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
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
              DropdownButtonFormField<String>(
                value: _lugarSeleccionado,
                decoration: InputDecoration(
                  filled: true,
                  fillColor: Colors.white,
                  prefixIcon: const Icon(Icons.location_on_outlined, color: AppTheme.primaryColor),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: BorderSide(color: Colors.grey.shade300),
                  ),
                ),
                hint: const Text('Selecciona punto del campus'),
                items: AppConstants.puntosCampus.map((lugar) {
                  return DropdownMenuItem(value: lugar, child: Text(lugar, style: const TextStyle(fontSize: 13.5)));
                }).toList(),
                onChanged: (val) => setState(() => _lugarSeleccionado = val),
              ),
              const SizedBox(height: 20),

              // 5. Fotografía (RF10: obligatoria para encontrado, opcional para perdido)
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    esEncontrado ? 'Fotografía (Obligatoria) *' : 'Fotografía (Opcional)',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                      color: Color(0xFF1E293B),
                    ),
                  ),
                  if (esEncontrado)
                    const Text(
                      'Requerida por RF10',
                      style: TextStyle(
                        fontSize: 11,
                        color: Color(0xFFEF4444),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                ],
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
                          icon: const Icon(Icons.close, color: Colors.white, size: 18),
                          onPressed: () => setState(() => _imagenArchivo = null),
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
                        onPressed: () => _seleccionarFoto(ImageSource.camera),
                        icon: const Icon(Icons.camera_alt, color: AppTheme.primaryColor),
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
                        onPressed: () => _seleccionarFoto(ImageSource.gallery),
                        icon: const Icon(Icons.photo_library, color: AppTheme.primaryColor),
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
                  onPressed: _isLoading ? null : _publicarObjeto,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primaryColor,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(30),
                    ),
                    elevation: 4,
                  ),
                  child: _isLoading
                      ? const CircularProgressIndicator(color: Colors.white)
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
            Icon(icono, color: seleccionado ? colorActivo : const Color(0xFF64748B), size: 28),
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
