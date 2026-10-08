import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import '../../config/app_theme.dart';
import '../../models/objeto_model.dart';
import '../../providers/objeto_provider.dart';
import '../../services/auth_service.dart';
import '../chat/chat_room_screen.dart';

/// Modal para Reclamación de Objeto ("Yo tengo el objeto" / "Es mío") (RF11, RF12)
/// - Adjuntar obligatoriamente una foto como prueba para continuar
/// - Bloquea inmediatamente a otros usuarios cambiando a estado "Pendiente"
/// - Crea chat 1-a-1 e inserta mensaje automático con la foto al dueño
class ReclamarObjetoModal extends ConsumerStatefulWidget {
  final ObjetoModel objeto;

  const ReclamarObjetoModal({super.key, required this.objeto});

  static Future<void> mostrar(BuildContext context, ObjetoModel objeto) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => ReclamarObjetoModal(objeto: objeto),
    );
  }

  @override
  ConsumerState<ReclamarObjetoModal> createState() =>
      _ReclamarObjetoModalState();
}

class _ReclamarObjetoModalState extends ConsumerState<ReclamarObjetoModal> {
  final _mensajeController = TextEditingController();
  File? _fotoPrueba;
  bool _isSubmitting = false;
  final ImagePicker _picker = ImagePicker();

  @override
  void dispose() {
    _mensajeController.dispose();
    super.dispose();
  }

  Future<void> _tomarFoto(ImageSource source) async {
    try {
      final picked = await _picker.pickImage(
        source: source,
        imageQuality: 80,
      );
      if (picked != null) {
        setState(() {
          _fotoPrueba = File(picked.path);
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

  Future<void> _enviarReclamacion() async {
    // Validación estricta RF11: Foto obligatoria como prueba
    if (_fotoPrueba == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('⚠️ Debes adjuntar obligatoriamente una foto como prueba (RF11).'),
          backgroundColor: AppTheme.errorColor,
        ),
      );
      return;
    }

    final user = AuthService().currentUser;
    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Debes iniciar sesión para reclamar un objeto.'),
          backgroundColor: AppTheme.warningColor,
        ),
      );
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      final objetoService = ref.read(objetoServiceProvider);
      final nombreReclamante = user.displayName ??
          user.email?.split('@').first ??
          'Estudiante USC';

      await objetoService.reclamarObjeto(
        idObjeto: widget.objeto.id,
        idReclamante: user.uid,
        nombreReclamante: nombreReclamante,
        fotoPrueba: _fotoPrueba!,
        mensajeAdicional: _mensajeController.text.trim(),
      );

      if (!mounted) return;
      Navigator.pop(context); // Cerrar modal

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            '¡Reclamación enviada! El objeto quedó en revisión y se abrió el chat.',
          ),
          backgroundColor: AppTheme.successColor,
        ),
      );

      // Redirigir a la sala de chat vinculada
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => ChatRoomScreen(
            idReferencia: widget.objeto.id,
            tipoReferencia: 'objeto',
            tituloReferencia: widget.objeto.titulo,
            otroUsuarioId: widget.objeto.idDueno,
            otroUsuarioNombre: widget.objeto.nombreDueno.isNotEmpty
                ? widget.objeto.nombreDueno
                : 'Reportante',
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _isSubmitting = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error al enviar reclamación: $e'),
          backgroundColor: AppTheme.errorColor,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    final esPerdido = widget.objeto.esPerdido;
    final accionTitulo = esPerdido ? 'Yo tengo el objeto' : 'Reclamar: Es mío';

    return Container(
      padding: EdgeInsets.fromLTRB(20, 20, 20, 20 + bottomInset),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 48,
                height: 5,
                decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Título
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: AppTheme.primaryColor.withOpacity(0.1),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.verified_user_outlined,
                    color: AppTheme.primaryColor,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        accionTitulo,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF1E293B),
                        ),
                      ),
                      Text(
                        widget.objeto.titulo,
                        style: const TextStyle(
                          fontSize: 13,
                          color: Color(0xFF64748B),
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 18),

            // Banner explicativo de prueba obligatoria (RF11)
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFF1F5F9),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: const Row(
                children: [
                  Icon(Icons.camera_alt_outlined, color: AppTheme.primaryColor, size: 22),
                  SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Por seguridad de la comunidad USC, debes adjuntar una foto del objeto para validar tu identidad o tenencia.',
                      style: TextStyle(
                        fontSize: 12.5,
                        color: Color(0xFF334155),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Selector / Vista previa de la foto de prueba
            const Text(
              'Foto de Prueba (Obligatoria) *',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 14,
                color: Color(0xFF1E293B),
              ),
            ),
            const SizedBox(height: 8),

            if (_fotoPrueba != null)
              Stack(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(16),
                    child: Image.file(
                      _fotoPrueba!,
                      height: 160,
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
                        onPressed: () => setState(() => _fotoPrueba = null),
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
                      onPressed: () => _tomarFoto(ImageSource.camera),
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
                      onPressed: () => _tomarFoto(ImageSource.gallery),
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
            const SizedBox(height: 16),

            // Mensaje opcional
            const Text(
              'Mensaje para el dueño / reportante (Opcional)',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 14,
                color: Color(0xFF1E293B),
              ),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _mensajeController,
              maxLines: 2,
              decoration: InputDecoration(
                hintText: 'Ej: Lo tengo guardado en mi casillero del Bloque 3...',
                filled: true,
                fillColor: const Color(0xFFF8FAFC),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
            const SizedBox(height: 20),

            // Botón de Enviar
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                onPressed: _isSubmitting ? null : _enviarReclamacion,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primaryColor,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(25),
                  ),
                ),
                child: _isSubmitting
                    ? const SizedBox(
                        height: 22,
                        width: 22,
                        child: CircularProgressIndicator(
                          strokeWidth: 2.5,
                          color: Colors.white,
                        ),
                      )
                    : const Text(
                        'Confirmar y Enviar Reclamación',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
