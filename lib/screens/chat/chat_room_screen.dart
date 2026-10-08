import 'dart:io';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import '../../config/app_theme.dart';
import '../../models/chat_model.dart';
import '../../models/mensaje_model.dart';
import '../../providers/chat_provider.dart';
import '../../providers/objeto_provider.dart';
import '../../services/auth_service.dart';
import '../../services/cloudinary_service.dart';

/// Pantalla de Sala de Chat 1-a-1 en Tiempo Real (RF07)
/// Cumple con especificación del documento:
/// - Remueve el campo "Estado del Caso" superior.
/// - Sala exclusiva entre los 2 involucrados.
/// - Modo "solo lectura" automático cuando el caso se entrega/cierra.
/// - Permite al dueño gestionar las transiciones de estado (RF13).
class ChatRoomScreen extends ConsumerStatefulWidget {
  final String idReferencia;
  final String tipoReferencia;
  final String tituloReferencia;
  final String otroUsuarioId;
  final String otroUsuarioNombre;

  const ChatRoomScreen({
    super.key,
    required this.idReferencia,
    this.tipoReferencia = 'objeto',
    required this.tituloReferencia,
    required this.otroUsuarioId,
    required this.otroUsuarioNombre,
  });

  @override
  ConsumerState<ChatRoomScreen> createState() => _ChatRoomScreenState();
}

class _ChatRoomScreenState extends ConsumerState<ChatRoomScreen> {
  final _textoController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final ImagePicker _picker = ImagePicker();
  final CloudinaryService _cloudinaryService = CloudinaryService();

  String? _chatId;
  bool _isLoadingChat = true;
  bool _isSending = false;

  @override
  void initState() {
    super.initState();
    _inicializarSala();
  }

  @override
  void dispose() {
    _textoController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _inicializarSala() async {
    final user = AuthService().currentUser;
    if (user == null) return;

    try {
      final chatService = ref.read(chatServiceProvider);
      final miNombre = user.displayName ??
          user.email?.split('@').first ??
          'Estudiante USC';

      final chat = await chatService.obtenerOCrearChat1a1(
        idReferencia: widget.idReferencia,
        tipoReferencia: widget.tipoReferencia,
        tituloReferencia: widget.tituloReferencia,
        usuarioAId: user.uid,
        usuarioANombre: miNombre,
        usuarioBId: widget.otroUsuarioId,
        usuarioBNombre: widget.otroUsuarioNombre,
      );

      if (mounted) {
        setState(() {
          _chatId = chat.id;
          _isLoadingChat = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoadingChat = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error abriendo chat: $e'),
            backgroundColor: AppTheme.errorColor,
          ),
        );
      }
    }
  }

  Future<void> _enviarMensaje({String? urlFoto}) async {
    if (_chatId == null) return;
    final user = AuthService().currentUser;
    if (user == null) return;

    final texto = _textoController.text.trim();
    if (texto.isEmpty && (urlFoto == null || urlFoto.isEmpty)) return;

    _textoController.clear();
    setState(() => _isSending = true);

    try {
      final chatService = ref.read(chatServiceProvider);
      final miNombre = user.displayName ??
          user.email?.split('@').first ??
          'Estudiante USC';

      await chatService.enviarMensaje(
        chatId: _chatId!,
        idEmisor: user.uid,
        nombreEmisor: miNombre,
        texto: texto,
        urlFoto: urlFoto,
      );

      // Auto-scroll al final
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_scrollController.hasClients) {
          _scrollController.animateTo(
            _scrollController.position.maxScrollExtent + 100,
            duration: const Duration(milliseconds: 250),
            curve: Curves.easeOut,
          );
        }
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('No se pudo enviar el mensaje: $e'),
          backgroundColor: AppTheme.errorColor,
        ),
      );
    } finally {
      if (mounted) setState(() => _isSending = false);
    }
  }

  Future<void> _adjuntarFoto() async {
    try {
      final picked = await _picker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 80,
      );
      if (picked == null) return;

      setState(() => _isSending = true);
      final subida = await _cloudinaryService.subirImagenObjeto(
        File(picked.path),
        folder: 'chat_adjuntos',
      );

      if (subida != null && subida.isNotEmpty) {
        await _enviarMensaje(urlFoto: subida);
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error enviando foto: $e'),
          backgroundColor: AppTheme.errorColor,
        ),
      );
    } finally {
      if (mounted) setState(() => _isSending = false);
    }
  }

  // Opciones de gestión del estado del objeto (RF13) desde el menú contextual
  Future<void> _gestionarEstadoObjeto(String nuevoEstado, {bool esRechazo = false}) async {
    final user = AuthService().currentUser;
    if (user == null) return;

    try {
      final objetoService = ref.read(objetoServiceProvider);
      await objetoService.cambiarEstadoObjeto(
        idObjeto: widget.idReferencia,
        nuevoEstadoStr: nuevoEstado,
        idUsuarioAccion: user.uid,
        esRechazo: esRechazo,
      );

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            esRechazo
                ? 'Reclamación rechazada. El objeto volvió a estar Publicado.'
                : 'Estado actualizado a: $nuevoEstado',
          ),
          backgroundColor: AppTheme.successColor,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error al cambiar estado: $e'),
          backgroundColor: AppTheme.errorColor,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final currentUser = AuthService().currentUser;
    final miUid = currentUser?.uid ?? '';

    // Si aún está cargando la sala
    if (_isLoadingChat || _chatId == null) {
      return Scaffold(
        appBar: AppBar(
          title: Text(widget.otroUsuarioNombre),
          backgroundColor: Colors.white,
        ),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    final chatAsync = ref.watch(chatEstadoStreamProvider(_chatId!));
    final mensajesAsync = ref.watch(chatMensajesStreamProvider(_chatId!));
    final objetoAsync = widget.tipoReferencia == 'objeto'
        ? ref.watch(objetoDetalleProvider(widget.idReferencia))
        : null;

    final chat = chatAsync.value;
    final esSoloLectura = chat?.soloLectura ?? false;

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 1,
        titleSpacing: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, color: Color(0xFF1E293B), size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        title: Row(
          children: [
            Stack(
              children: [
                CircleAvatar(
                  backgroundColor: AppTheme.primaryColor.withOpacity(0.15),
                  radius: 20,
                  child: Text(
                    widget.otroUsuarioNombre.isNotEmpty
                        ? widget.otroUsuarioNombre[0].toUpperCase()
                        : 'U',
                    style: const TextStyle(
                      color: AppTheme.primaryColor,
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                ),
                Positioned(
                  bottom: 0,
                  right: 0,
                  child: Container(
                    width: 11,
                    height: 11,
                    decoration: BoxDecoration(
                      color: const Color(0xFF10B981),
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white, width: 2),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.otroUsuarioNombre,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF1E293B),
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                  Text(
                    esSoloLectura ? 'Caso Finalizado' : 'En línea • USC',
                    style: TextStyle(
                      fontSize: 12,
                      color: esSoloLectura ? const Color(0xFFEF4444) : const Color(0xFF64748B),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          // Menú de opciones de la máquina de estados si el usuario es el dueño (RF13)
          if (objetoAsync?.value != null && objetoAsync!.value!.idDueno == miUid)
            PopupMenuButton<String>(
              icon: const Icon(Icons.more_vert, color: Color(0xFF1E293B)),
              onSelected: (valor) {
                if (valor == 'confirmar') {
                  _gestionarEstadoObjeto('Confirmado');
                } else if (valor == 'entregar') {
                  _gestionarEstadoObjeto('Entregado');
                } else if (valor == 'rechazar') {
                  _gestionarEstadoObjeto('Publicado', esRechazo: true);
                }
              },
              itemBuilder: (context) {
                final obj = objetoAsync.value!;
                final items = <PopupMenuEntry<String>>[];

                if (obj.esPendiente) {
                  items.add(const PopupMenuItem(
                    value: 'confirmar',
                    child: Text('✅ Aceptar prueba (Confirmado)'),
                  ));
                  items.add(const PopupMenuItem(
                    value: 'rechazar',
                    child: Text('❌ Rechazar prueba (Volver a Publicado)'),
                  ));
                } else if (obj.esConfirmado) {
                  items.add(const PopupMenuItem(
                    value: 'entregar',
                    child: Text('📦 Marcar como Entregado (Cerrar caso)'),
                  ));
                  items.add(const PopupMenuItem(
                    value: 'rechazar',
                    child: Text('↩ Cancelar entrega (Volver a Publicado)'),
                  ));
                }
                return items;
              },
            ),
        ],
      ),
      body: Column(
        children: [
          // NOTA: Se eliminó el cuadro de "Estado del Caso" superior para cumplir con el diseño exacto.

          // Lista de Mensajes en tiempo real (RF07)
          Expanded(
            child: mensajesAsync.when(
              data: (mensajes) {
                if (mensajes.isEmpty) {
                  return const Center(
                    child: Text(
                      'No hay mensajes aún. ¡Comienza la conversación!',
                      style: TextStyle(color: Color(0xFF94A3B8), fontSize: 14),
                    ),
                  );
                }

                return ListView.builder(
                  controller: _scrollController,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  itemCount: mensajes.length + 1, // +1 para divisor "HOY"
                  itemBuilder: (context, index) {
                    if (index == 0) {
                      return Center(
                        child: Container(
                          margin: const EdgeInsets.symmetric(vertical: 12),
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
                          decoration: BoxDecoration(
                            color: const Color(0xFFE2E8F0),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Text(
                            'HOY',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF64748B),
                            ),
                          ),
                        ),
                      );
                    }

                    final mensaje = mensajes[index - 1];
                    final esMio = mensaje.idEmisor == miUid;

                    if (mensaje.esSistema) {
                      return _buildSystemMessagePill(mensaje);
                    }

                    return _buildMessageBubble(mensaje, esMio);
                  },
                );
              },
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => Center(child: Text('Error: $e')),
            ),
          ),

          // Barra inferior: Si está en Solo Lectura se deshabilita (RF07)
          if (esSoloLectura)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              color: const Color(0xFFFEE2E2),
              child: const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.lock_outline, color: Color(0xFFDC2626), size: 18),
                  SizedBox(width: 8),
                  Text(
                    'Caso finalizado. El chat está en modo solo lectura.',
                    style: TextStyle(
                      color: Color(0xFFDC2626),
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            )
          else
            _buildInputBottomBar(),
        ],
      ),
    );
  }

  Widget _buildSystemMessagePill(MensajeModel mensaje) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFEEF2FF),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFC7D2FE)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.info_outline, color: AppTheme.primaryColor, size: 18),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  mensaje.texto,
                  style: const TextStyle(
                    fontSize: 13,
                    color: Color(0xFF1E293B),
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
          if (mensaje.urlFoto != null && mensaje.urlFoto!.isNotEmpty) ...[
            const SizedBox(height: 8),
            ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: CachedNetworkImage(
                imageUrl: mensaje.urlFoto!,
                height: 140,
                width: double.infinity,
                fit: BoxFit.cover,
                placeholder: (_, __) => Container(
                  height: 140,
                  color: Colors.grey.shade200,
                  child: const Center(child: CircularProgressIndicator()),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildMessageBubble(MensajeModel mensaje, bool esMio) {
    final hora = DateFormat('hh:mm a').format(mensaje.timestamp);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment:
            esMio ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (!esMio) ...[
            CircleAvatar(
              radius: 14,
              backgroundColor: const Color(0xFFE2E8F0),
              child: Text(
                mensaje.nombreEmisor.isNotEmpty
                    ? mensaje.nombreEmisor[0].toUpperCase()
                    : 'U',
                style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF475569),
                ),
              ),
            ),
            const SizedBox(width: 8),
          ],
          Flexible(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: esMio ? AppTheme.primaryColor : Colors.white,
                borderRadius: BorderRadius.only(
                  topLeft: const Radius.circular(18),
                  topRight: const Radius.circular(18),
                  bottomLeft: Radius.circular(esMio ? 18 : 4),
                  bottomRight: Radius.circular(esMio ? 4 : 18),
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.04),
                    blurRadius: 4,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment:
                    esMio ? CrossAxisAlignment.end : CrossAxisAlignment.start,
                children: [
                  if (mensaje.urlFoto != null && mensaje.urlFoto!.isNotEmpty) ...[
                    ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: CachedNetworkImage(
                        imageUrl: mensaje.urlFoto!,
                        width: 200,
                        fit: BoxFit.cover,
                      ),
                    ),
                    const SizedBox(height: 6),
                  ],
                  if (mensaje.texto.isNotEmpty)
                    Text(
                      mensaje.texto,
                      style: TextStyle(
                        fontSize: 14.5,
                        color: esMio ? Colors.white : const Color(0xFF1E293B),
                        height: 1.3,
                      ),
                    ),
                  const SizedBox(height: 4),
                  Text(
                    hora,
                    style: TextStyle(
                      fontSize: 10,
                      color: esMio
                          ? Colors.white.withOpacity(0.7)
                          : const Color(0xFF94A3B8),
                    ),
                  ),
                ],
              ),
            ),
          ),
          if (esMio) ...[
            const SizedBox(width: 8),
            CircleAvatar(
              radius: 14,
              backgroundColor: AppTheme.primaryColor.withOpacity(0.2),
              child: Text(
                mensaje.nombreEmisor.isNotEmpty
                    ? mensaje.nombreEmisor[0].toUpperCase()
                    : 'M',
                style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.primaryColor,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildInputBottomBar() {
    return Container(
      padding: EdgeInsets.fromLTRB(
        12,
        8,
        12,
        8 + MediaQuery.of(context).viewInsets.bottom,
      ),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: Color(0xFFE2E8F0))),
      ),
      child: SafeArea(
        top: false,
        child: Row(
          children: [
            // Botón + para fotos (image6.jpeg)
            IconButton(
              icon: const Icon(Icons.add_circle_outline, color: AppTheme.primaryColor, size: 28),
              onPressed: _isSending ? null : _adjuntarFoto,
            ),
            Expanded(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 14),
                decoration: BoxDecoration(
                  color: const Color(0xFFF1F5F9),
                  borderRadius: BorderRadius.circular(24),
                ),
                child: TextField(
                  controller: _textoController,
                  minLines: 1,
                  maxLines: 4,
                  textCapitalization: TextCapitalization.sentences,
                  decoration: const InputDecoration(
                    hintText: 'Escribe un mensaje...',
                    hintStyle: TextStyle(color: Color(0xFF94A3B8), fontSize: 14),
                    border: InputBorder.none,
                    isDense: true,
                    contentPadding: EdgeInsets.symmetric(vertical: 10),
                  ),
                  onSubmitted: (_) => _enviarMensaje(),
                ),
              ),
            ),
            const SizedBox(width: 8),
            // Botón Enviar azul circular (image6.jpeg)
            InkWell(
              onTap: _isSending ? null : () => _enviarMensaje(),
              borderRadius: BorderRadius.circular(24),
              child: Container(
                width: 44,
                height: 44,
                decoration: const BoxDecoration(
                  color: AppTheme.primaryColor,
                  shape: BoxShape.circle,
                ),
                child: _isSending
                    ? const Padding(
                        padding: EdgeInsets.all(12),
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Icon(
                        Icons.send_rounded,
                        color: Colors.white,
                        size: 20,
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
