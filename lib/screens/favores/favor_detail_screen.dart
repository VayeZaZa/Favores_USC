import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:timeago/timeago.dart' as timeago;

import '../../config/app_theme.dart';
import '../../models/favor_model.dart';
import '../../providers/favor_provider.dart';
import '../../services/auth_service.dart';
import '../chat/chat_room_screen.dart';
import '../widgets/confirmar_borrado.dart';
import 'widgets/calificar_favor_sheet.dart';
import 'widgets/favor_presentacion.dart';

/// Pantalla de Consultar / Detalle del Favor ajustada 100% a la maqueta visual (image8.png, image9.png)
class FavorDetailScreen extends ConsumerStatefulWidget {
  final String favorId;

  const FavorDetailScreen({super.key, required this.favorId});

  @override
  ConsumerState<FavorDetailScreen> createState() => _FavorDetailScreenState();
}

class _FavorDetailScreenState extends ConsumerState<FavorDetailScreen> {
  bool _isProcessing = false;

  Future<void> _eliminarFavor(FavorModel favor, String uid) async {
    if (_isProcessing) return;
    final confirmado = await confirmarBorradoPublicacion(
      context,
      tipo: 'favor',
      titulo: favor.titulo,
    );
    if (!confirmado || !mounted || _isProcessing) return;
    setState(() => _isProcessing = true);
    try {
      await ref
          .read(favorServiceProvider)
          .eliminarFavor(favor.id, idAutor: uid);
      if (!mounted) return;
      ref.invalidate(favoresFeedProvider);
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Favor borrado.')));
      Navigator.pop(context);
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(error.toString().replaceFirst('Exception: ', '')),
        ),
      );
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  Future<void> _cancelarAceptacion(FavorModel favor, String uid) async {
    if (_isProcessing) return;
    final confirmado = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('¿Cancelar tu aceptación?'),
        content: const Text(
          'El favor volverá a estar disponible y el chat de este encuentro se cerrará.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Volver'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Cancelar aceptación'),
          ),
        ],
      ),
    );
    if (confirmado != true || !mounted) return;
    await _realizarAccion(() async {
      await ref
          .read(favorServiceProvider)
          .cancelarAceptacion(favorId: favor.id, idAyudante: uid);
      if (mounted) ref.invalidate(favoresFeedProvider);
    }, 'El favor volvió a estar disponible.');
  }

  Future<void> _realizarAccion(
    Future<void> Function() accion,
    String exito,
  ) async {
    if (_isProcessing || !mounted) return;
    setState(() => _isProcessing = true);
    try {
      await accion();
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(exito)));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(e.toString().replaceFirst('Exception: ', '')),
          backgroundColor: AppTheme.errorColor,
        ),
      );
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  Future<void> _mostrarDialogoCalificacion(FavorModel favor) async {
    final uid = AuthService().currentUser?.uid;
    if (uid == null || !favor.puedeCalificar(uid) || _isProcessing) return;

    final destino = favor.otroParticipante(uid);
    if (destino == null || destino.isEmpty) return;
    final calificaAlAutor = destino == favor.idAutor;
    final nombre = calificaAlAutor ? favor.nombreAutor : favor.nombreAyudante;
    final foto = calificaAlAutor ? favor.fotoAutor : favor.fotoAyudante;
    final servicio = ref.read(favorServiceProvider);
    final guardado = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      isDismissible: false,
      enableDrag: false,
      useSafeArea: true,
      backgroundColor: AppTheme.surfaceColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(26)),
      ),
      builder: (_) => CalificarFavorSheet(
        tituloFavor: favor.titulo,
        nombre: nombre.isEmpty ? 'Estudiante USC' : nombre,
        foto: foto,
        enviar: (estrellas, comentario) => servicio.calificarUsuario(
          favorId: favor.id,
          idAutorCalificador: uid,
          idDestinatario: destino,
          estrellas: estrellas,
          comentario: comentario,
        ),
      ),
    );
    if (guardado == true && mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('¡Calificación guardada!')));
    }
  }

  Future<void> _mostrarDialogoReporte(FavorModel favor) async {
    final uid = AuthService().currentUser?.uid;
    if (uid == null ||
        !favor.esEntregado ||
        !favor.esParticipante(uid) ||
        _isProcessing) {
      return;
    }
    String motivo = 'Incumplimiento';
    String descripcion = '';
    final enviar = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Reportar al participante'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              DropdownButtonFormField<String>(
                initialValue: motivo,
                isExpanded: true,
                decoration: const InputDecoration(labelText: 'Motivo'),
                items:
                    const [
                          'Incumplimiento',
                          'Conducta inadecuada',
                          'Fraude',
                          'Otro',
                        ]
                        .map((m) => DropdownMenuItem(value: m, child: Text(m)))
                        .toList(),
                onChanged: (valor) => motivo = valor ?? motivo,
              ),
              const SizedBox(height: 12),
              TextField(
                maxLength: 1000,
                maxLines: 3,
                onChanged: (valor) => descripcion = valor,
                decoration: const InputDecoration(
                  labelText: 'Detalles del reporte',
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Enviar reporte'),
          ),
        ],
      ),
    );
    if (enviar != true || !mounted) return;
    await _realizarAccion(
      () => ref
          .read(favorServiceProvider)
          .crearReporte(
            favorId: favor.id,
            idReportante: uid,
            idReportado: favor.otroParticipante(uid)!,
            motivo: motivo,
            descripcion: descripcion,
          ),
      'Reporte enviado a administración.',
    );
  }

  Future<void> _abrirChat(FavorModel favor) async {
    final uid = AuthService().currentUser?.uid;
    if (uid == null || !favor.puedeAbrirChat(uid) || _isProcessing) return;
    setState(() => _isProcessing = true);
    try {
      final salaId = await ref
          .read(favorServiceProvider)
          .prepararChatFavor(favor.id, idUsuario: uid);
      if (!mounted) return;
      await Navigator.push(
        context,
        MaterialPageRoute<void>(
          builder: (_) => ChatRoomScreen(
            salaId: salaId,
            idReferencia: favor.id,
            tipoReferencia: 'favor',
            tituloReferencia: favor.titulo,
            otroUsuarioId: favor.otroParticipante(uid)!,
            otroUsuarioNombre: uid == favor.idAutor
                ? (favor.nombreAyudante.isEmpty
                      ? 'Ayudante'
                      : favor.nombreAyudante)
                : (favor.nombreAutor.isEmpty
                      ? 'Solicitante'
                      : favor.nombreAutor),
          ),
        ),
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.toString().replaceFirst('Exception: ', ''))),
        );
      }
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  Future<void> _aceptarFavor(FavorModel favor) async {
    final currentUser = AuthService().currentUser;
    if (currentUser == null) return;

    final confirmar = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('¿Aceptar Favor?'),
        content: Text(
          '¿Estás seguro de asumir este favor por \$${NumberFormat("#,##0", "es_CO").format(favor.pago)} COP?\n\n'
          'Ubicación: ${favor.ubicacion}',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(c, false),
            child: const Text('CANCELAR'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(c, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.primaryColor,
            ),
            child: const Text('ACEPTAR', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirmar != true || !mounted) return;

    setState(() => _isProcessing = true);

    try {
      final favorService = ref.read(favorServiceProvider);
      await favorService.aceptarFavor(
        favorId: favor.id,
        idAyudante: currentUser.uid,
      );

      if (mounted) {
        ref.invalidate(favoresFeedProvider);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              '¡Favor aceptado exitosamente! Ya puedes coordinar la entrega.',
            ),
            backgroundColor: AppTheme.successColor,
          ),
        );
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
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  Future<void> _confirmarPago(FavorModel favor) async {
    final currentUser = AuthService().currentUser;
    if (currentUser == null || _isProcessing) return;
    final confirmar = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('¿Ya recibiste el pago?'),
        content: const Text(
          'Confirma únicamente cuando hayas recibido el pago por fuera de la app. El favor quedará finalizado y el chat pasará a solo lectura.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Volver'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Sí, recibí el pago'),
          ),
        ],
      ),
    );
    if (confirmar != true || !mounted) return;

    setState(() => _isProcessing = true);

    try {
      final favorService = ref.read(favorServiceProvider);
      await favorService.confirmarPagoYEntregar(
        favorId: favor.id,
        idAyudante: currentUser.uid,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('¡Pago confirmado! Favor finalizado con éxito.'),
            backgroundColor: AppTheme.successColor,
          ),
        );
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
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final currentUser = AuthService().currentUser;
    final favorAsync = ref.watch(favorDetailStreamProvider(widget.favorId));
    final calificados = currentUser == null
        ? null
        : ref.watch(favoresCalificadosProvider(currentUser.uid)).valueOrNull;

    return Scaffold(
      backgroundColor: AppTheme.surfaceColor,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded, color: Color(0xFF1E293B)),
          onPressed: () => Navigator.pop(context),
        ),
        title: favorAsync.when(
          data: (favor) => Text(
            favor?.esAceptado == true
                ? 'Favor en curso'
                : favor?.esEntregado == true
                ? 'Favor entregado'
                : 'Detalle del favor',
          ),
          loading: () => const Text('Detalle del favor'),
          error: (_, _) => const Text('Detalle del favor'),
        ),
        actions: [
          favorAsync.when(
            data: (favor) {
              final uid = currentUser?.uid ?? '';
              if (favor == null) return const SizedBox.shrink();
              if (favor.puedeEliminar(uid)) {
                return IconButton(
                  tooltip: 'Borrar favor',
                  icon: const Icon(
                    Icons.delete_outline_rounded,
                    color: AppTheme.errorColor,
                  ),
                  onPressed: _isProcessing
                      ? null
                      : () => _eliminarFavor(favor, uid),
                );
              }
              if (!favor.esEntregado || !favor.esParticipante(uid)) {
                return const SizedBox.shrink();
              }
              return IconButton(
                icon: const Icon(Icons.outlined_flag, color: Color(0xFF64748B)),
                onPressed: () => _mostrarDialogoReporte(favor),
              );
            },
            loading: () => const SizedBox.shrink(),
            error: (_, errorStack) => const SizedBox.shrink(),
          ),
        ],
      ),
      body: favorAsync.when(
        data: (favor) {
          if (favor == null) {
            return const Center(
              child: Text('El favor no se encuentra disponible.'),
            );
          }

          final esAutor = currentUser?.uid == favor.idAutor;
          final esAyudante = currentUser?.uid == favor.idAyudante;
          final uid = currentUser?.uid ?? '';
          final yaCalificado =
              favor.calificadoPor.contains(uid) ||
              (calificados?.contains(favor.id) ?? false);
          final puedeCalificar =
              favor.puedeCalificar(uid) && calificados != null && !yaCalificado;

          return Column(
            children: [
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 10,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (!yaCalificado)
                        Card(
                          color: AppTheme.doradoClaro,
                          margin: const EdgeInsets.only(bottom: 16),
                          child: Padding(
                            padding: const EdgeInsets.all(16),
                            child: FavorProgreso(favor: favor),
                          ),
                        ),
                      // Fotos superior (Mockup image9.png)
                      if (favor.urlFotos.isNotEmpty)
                        SizedBox(
                          height: 180,
                          child: ListView.builder(
                            scrollDirection: Axis.horizontal,
                            itemCount: favor.urlFotos.length,
                            itemBuilder: (context, index) {
                              return Container(
                                width: 220,
                                margin: const EdgeInsets.only(right: 12),
                                clipBehavior: Clip.antiAlias,
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(16),
                                ),
                                child: CachedNetworkImage(
                                  imageUrl: favor.urlFotos[index],
                                  fit: BoxFit.cover,
                                ),
                              );
                            },
                          ),
                        ),
                      const SizedBox(height: 16),

                      // Título y Precio (Mockup image9.png)
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: Text(
                              favor.titulo.isEmpty
                                  ? favor.descripcion.split('\n').first
                                  : favor.titulo,
                              style: const TextStyle(
                                fontSize: 22,
                                fontWeight: FontWeight.w800,
                                color: Color(0xFF1E293B),
                              ),
                            ),
                          ),
                          Text(
                            '\$${NumberFormat("#,##0", "es_CO").format(favor.pago)}',
                            style: const TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.w800,
                              color: AppTheme.primaryColor,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Publicado ${timeago.format(favor.fechaCreacion, locale: 'es')}',
                        style: const TextStyle(
                          color: Color(0xFF94A3B8),
                          fontSize: 13,
                        ),
                      ),
                      const SizedBox(height: 20),

                      // Tarjeta 1: Categoría (Mockup image8.png)
                      _buildInfoCard(
                        icon: Icons.category_outlined,
                        title: 'Categoría',
                        subtitle: favor.tipo,
                      ),
                      const SizedBox(height: 12),

                      // Tarjeta 2: Ubicación (Mockup image8.png)
                      _buildInfoCard(
                        icon: Icons.location_on_outlined,
                        title: 'Ubicación',
                        subtitle: favor.ubicacion,
                      ),
                      const SizedBox(height: 12),

                      // Tarjeta 3: Solicitante (Mockup image8.png)
                      _buildInfoCard(
                        icon: Icons.person_outline_rounded,
                        title: 'Solicitante',
                        subtitle: favor.nombreAutor.isEmpty
                            ? (esAutor ? 'Tú' : 'Estudiante USC')
                            : favor.nombreAutor,
                        foto: favor.fotoAutor,
                      ),
                      if (favor.idAyudante?.isNotEmpty == true) ...[
                        const SizedBox(height: 12),
                        _buildInfoCard(
                          icon: Icons.person_outline_rounded,
                          title: 'Ayudante',
                          subtitle: favor.nombreAyudante.isEmpty
                              ? (esAyudante ? 'Tú' : 'Estudiante USC')
                              : favor.nombreAyudante,
                          foto: favor.fotoAyudante,
                        ),
                      ],
                      const SizedBox(height: 24),

                      // Descripción detallada
                      const Text(
                        'Descripción',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF1E293B),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        favor.descripcion,
                        style: const TextStyle(
                          fontSize: 14,
                          color: Color(0xFF475569),
                          height: 1.5,
                        ),
                      ),
                      const SizedBox(height: 24),
                    ],
                  ),
                ),
              ),

              Container(
                decoration: const BoxDecoration(
                  color: Colors.white,
                  border: Border(top: BorderSide(color: Color(0xFFE4EBF5))),
                ),
                child: SafeArea(
                  top: false,
                  minimum: const EdgeInsets.fromLTRB(16, 12, 16, 10),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: _botonAccion(
                              icono: Icons.chat_bubble_outline_rounded,
                              texto: 'Chat',
                              onPressed:
                                  !_isProcessing && favor.puedeAbrirChat(uid)
                                  ? () => _abrirChat(favor)
                                  : null,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _isProcessing
                                ? const Center(
                                    child: CircularProgressIndicator(),
                                  )
                                : favor.esPublicado &&
                                      !esAutor &&
                                      uid.isNotEmpty
                                ? _botonAccion(
                                    icono: Icons.check_circle_outline,
                                    texto: 'Aceptar',
                                    dorado: true,
                                    onPressed: () => _aceptarFavor(favor),
                                  )
                                : favor.puedeCancelarAceptacion(uid)
                                ? _botonAccion(
                                    icono: Icons.task_alt_rounded,
                                    texto: 'Confirmar pago',
                                    dorado: true,
                                    onPressed: () => _confirmarPago(favor),
                                  )
                                : puedeCalificar
                                ? _botonAccion(
                                    icono: Icons.star_rounded,
                                    texto: 'Calificar',
                                    dorado: true,
                                    onPressed: () =>
                                        _mostrarDialogoCalificacion(favor),
                                  )
                                : Center(
                                    child: Chip(
                                      backgroundColor: yaCalificado
                                          ? AppTheme.doradoClaro
                                          : AppTheme.surfaceColor,
                                      label: Text(
                                        yaCalificado
                                            ? 'Calificado'
                                            : favor.estado,
                                      ),
                                    ),
                                  ),
                          ),
                        ],
                      ),
                      if (favor.puedeCancelarAceptacion(uid)) ...[
                        const SizedBox(height: 4),
                        TextButton.icon(
                          onPressed: _isProcessing
                              ? null
                              : () => _cancelarAceptacion(favor, uid),
                          style: TextButton.styleFrom(
                            foregroundColor: AppTheme.errorColor,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 10,
                            ),
                          ),
                          icon: const Icon(Icons.undo_rounded, size: 18),
                          label: const Text('Cancelar aceptación'),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ],
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, stack) =>
            Center(child: Text('Error cargando favor: $err')),
      ),
    );
  }

  Widget _botonAccion({
    required IconData icono,
    required String texto,
    required VoidCallback? onPressed,
    bool dorado = false,
  }) => FilledButton.icon(
    onPressed: onPressed,
    icon: Icon(icono, size: 19),
    label: Text(texto, textAlign: TextAlign.center),
    style: FilledButton.styleFrom(
      minimumSize: const Size(0, 52),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      backgroundColor: dorado ? AppTheme.accentColor : AppTheme.primaryColor,
      foregroundColor: dorado ? AppTheme.primaryColor : Colors.white,
      textStyle: const TextStyle(fontWeight: FontWeight.w700),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
    ),
  );

  Widget _buildInfoCard({
    required IconData icon,
    required String title,
    required String subtitle,
    String? foto,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Row(
        children: [
          if (foto != null)
            FavorAvatar(foto: foto, radius: 21)
          else
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: AppTheme.primaryColor.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: AppTheme.primaryColor, size: 22),
            ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 12,
                    color: Color(0xFF64748B),
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: const TextStyle(
                    fontSize: 14,
                    color: Color(0xFF1E293B),
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
