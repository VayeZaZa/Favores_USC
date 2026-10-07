import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import '../../config/app_constants.dart';
import '../../config/app_theme.dart';
import '../../providers/favor_provider.dart';
import '../../services/auth_service.dart';

/// Pantalla Crear Favor ajustada 100% a la maqueta visual (image5.jpeg)
class CrearFavorScreen extends ConsumerStatefulWidget {
  const CrearFavorScreen({super.key});

  @override
  ConsumerState<CrearFavorScreen> createState() => _CrearFavorScreenState();
}

class _CrearFavorScreenState extends ConsumerState<CrearFavorScreen> {
  final _formKey = GlobalKey<FormState>();
  final _tituloController = TextEditingController();
  final _descripcionController = TextEditingController();
  final _pagoController = TextEditingController(text: '1000');

  String _tipoSeleccionado = 'Objeto';
  String? _ubicacionSeleccionada;
  final List<File> _imagenesSeleccionadas = [];
  bool _isLoading = false;

  final ImagePicker _picker = ImagePicker();

  @override
  void dispose() {
    _tituloController.dispose();
    _descripcionController.dispose();
    _pagoController.dispose();
    super.dispose();
  }

  Future<void> _seleccionarImagen() async {
    if (_imagenesSeleccionadas.length >= AppConstants.maxFotosFavor) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Solo se permiten máximo 3 fotos por favor.'),
          backgroundColor: AppTheme.warningColor,
        ),
      );
      return;
    }

    try {
      final XFile? pickedFile = await _picker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 85,
      );

      if (pickedFile != null) {
        setState(() {
          _imagenesSeleccionadas.add(File(pickedFile.path));
        });
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error seleccionando imagen: $e')),
      );
    }
  }

  void _eliminarImagen(int index) {
    setState(() {
      _imagenesSeleccionadas.removeAt(index);
    });
  }

  Future<void> _publicarFavor() async {
    if (!_formKey.currentState!.validate()) return;

    if (_ubicacionSeleccionada == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Por favor selecciona una ubicación del campus.')),
      );
      return;
    }

    final currentUser = AuthService().currentUser;
    if (currentUser == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Debes iniciar sesión para publicar.')),
      );
      return;
    }

    final pago = int.tryParse(_pagoController.text.trim()) ?? 0;
    final descripcionCompleta = '${_tituloController.text.trim()}\n\n${_descripcionController.text.trim()}';

    setState(() => _isLoading = true);

    try {
      final favorService = ref.read(favorServiceProvider);
      await favorService.crearFavor(
        idAutor: currentUser.uid,
        titulo: _tituloController.text.trim(),
        tipo: _tipoSeleccionado,
        descripcion: _descripcionController.text.trim(),
        ubicacion: _ubicacionSeleccionada!,
        pago: pago,
        imagenesLocales: _imagenesSeleccionadas,
      );

      if (mounted) {
        ref.read(favoresFeedProvider.notifier).cargarInicial();

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('¡Favor publicado con éxito en el campus!'),
            backgroundColor: AppTheme.successColor,
          ),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(e.toString().replaceAll('Exception: ', '')),
            backgroundColor: AppTheme.errorColor,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.close, color: Color(0xFF1E293B)),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Nuevo Favor',
          style: TextStyle(
            color: Color(0xFF1E293B),
            fontWeight: FontWeight.bold,
            fontSize: 20,
          ),
        ),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 1. Selector de Tipo de Favor (Tarjetas como en Maqueta image5.jpeg)
              const Text(
                '¿Qué tipo de favor buscas?',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF1E293B),
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(child: _buildTipoCard('Objeto', Icons.shopping_bag_outlined)),
                  const SizedBox(width: 12),
                  Expanded(child: _buildTipoCard('Apuntes', Icons.description_outlined)),
                  const SizedBox(width: 12),
                  Expanded(child: _buildTipoCard('Domicilio', Icons.home_outlined)),
                ],
              ),
              const SizedBox(height: 24),

              // 2. Título y descripción (Mockup image5.jpeg)
              const Text(
                'Título y descripción',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF1E293B),
                ),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _tituloController,
                decoration: InputDecoration(
                  hintText: 'Ej: Apuntes de Cálculo II',
                  hintStyle: TextStyle(color: Colors.grey.shade400, fontSize: 14),
                  filled: true,
                  fillColor: Colors.white,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: Colors.grey.shade300),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: Colors.grey.shade200),
                  ),
                ),
                validator: (val) => val == null || val.trim().isEmpty ? 'Ingresa el título del favor' : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _descripcionController,
                maxLines: 3,
                decoration: InputDecoration(
                  hintText: 'Describe detalladamente lo que necesitas...',
                  hintStyle: TextStyle(color: Colors.grey.shade400, fontSize: 14),
                  filled: true,
                  fillColor: Colors.white,
                  contentPadding: const EdgeInsets.all(16),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: Colors.grey.shade300),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: Colors.grey.shade200),
                  ),
                ),
                validator: (val) => val == null || val.trim().length < 5 ? 'Describe lo que necesitas' : null,
              ),
              const SizedBox(height: 24),

              // 3. Fotos (Máximo 3) (Mockup image5.jpeg)
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Fotos (Máximo 3)',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF1E293B),
                    ),
                  ),
                  Text(
                    'Opcional',
                    style: TextStyle(fontSize: 12, color: Colors.grey.shade500),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  for (int i = 0; i < 3; i++) ...[
                    if (i < _imagenesSeleccionadas.length)
                      Stack(
                        children: [
                          Container(
                            width: 90,
                            height: 90,
                            margin: const EdgeInsets.only(right: 12),
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(16),
                              image: DecorationImage(
                                image: FileImage(_imagenesSeleccionadas[i]),
                                fit: BoxFit.cover,
                              ),
                            ),
                          ),
                          Positioned(
                            top: 4,
                            right: 16,
                            child: InkWell(
                              onTap: () => _eliminarImagen(i),
                              child: Container(
                                padding: const EdgeInsets.all(3),
                                decoration: const BoxDecoration(
                                  color: Colors.red,
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(Icons.close, size: 14, color: Colors.white),
                              ),
                            ),
                          ),
                        ],
                      )
                    else
                      InkWell(
                        onTap: _seleccionarImagen,
                        child: Container(
                          width: 90,
                          height: 90,
                          margin: const EdgeInsets.only(right: 12),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: Colors.grey.shade300),
                          ),
                          child: const Icon(Icons.add_a_photo_outlined, color: AppTheme.primaryColor),
                        ),
                      ),
                  ],
                ],
              ),
              const SizedBox(height: 24),

              // 4. Ubicación Institucional (Mockup image5.jpeg & RNF04 Puntos fijos)
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: Colors.grey.shade200),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Ubicación Institucional',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF64748B),
                      ),
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String>(
                      value: _ubicacionSeleccionada,
                      isExpanded: true,
                      decoration: InputDecoration(
                        prefixIcon: const Icon(Icons.location_on, color: AppTheme.primaryColor),
                        filled: true,
                        fillColor: const Color(0xFFF8FAFC),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide: BorderSide.none,
                        ),
                      ),
                      hint: const Text('Selecciona punto de encuentro USC'),
                      items: AppConstants.puntosCampus.map((punto) {
                        return DropdownMenuItem(
                          value: punto,
                          child: Text(punto, style: const TextStyle(fontSize: 14)),
                        );
                      }).toList(),
                      onChanged: (val) => setState(() => _ubicacionSeleccionada = val),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),

              // 5. Valor Ofrecido (COP) (RF03)
              TextFormField(
                controller: _pagoController,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  labelText: 'Pago ofrecido en COP (Mínimo \$1.000)',
                  prefixIcon: const Icon(Icons.attach_money, color: Colors.green),
                  filled: true,
                  fillColor: Colors.white,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: BorderSide(color: Colors.grey.shade300),
                  ),
                ),
                validator: (val) {
                  final monto = int.tryParse(val ?? '');
                  if (monto == null || monto < AppConstants.minPagoFavor) {
                    return 'El pago mínimo es \$${AppConstants.minPagoFavor} COP';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 30),

              // Botón Publicar Favor
              SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _publicarFavor,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primaryColor,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  child: _isLoading
                      ? const CircularProgressIndicator(color: Colors.white)
                      : const Text(
                          'Publicar Favor',
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

  Widget _buildTipoCard(String label, IconData icon) {
    final isSelected = _tipoSeleccionado == label;

    return InkWell(
      onTap: () => setState(() => _tipoSeleccionado = label),
      borderRadius: BorderRadius.circular(16),
      child: Container(
        height: 100,
        decoration: BoxDecoration(
          color: isSelected ? AppTheme.primaryColor : Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected ? AppTheme.primaryColor : Colors.grey.shade200,
          ),
          boxShadow: [
            if (isSelected)
              BoxShadow(
                color: AppTheme.primaryColor.withOpacity(0.2),
                blurRadius: 8,
                offset: const Offset(0, 4),
              ),
          ],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              color: isSelected ? Colors.white : const Color(0xFF475569),
              size: 28,
            ),
            const SizedBox(height: 8),
            Text(
              label,
              style: TextStyle(
                color: isSelected ? Colors.white : const Color(0xFF475569),
                fontWeight: FontWeight.bold,
                fontSize: 13,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
