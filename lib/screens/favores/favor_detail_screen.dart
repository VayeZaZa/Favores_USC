import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_rating_bar/flutter_rating_bar.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:timeago/timeago.dart' as timeago;

import '../../config/app_theme.dart';
import '../../models/favor_model.dart';
import '../../providers/favor_provider.dart';
import '../../services/auth_service.dart';
import '../chat/chat_room_screen.dart';

/// Pantalla de Consultar / Detalle del Favor ajustada 100% a la maqueta visual (image8.png, image9.png)
class FavorDetailScreen extends ConsumerStatefulWidget {
  final String favorId;

  const FavorDetailScreen({super.key, required this.favorId});

  @override
  ConsumerState<FavorDetailScreen> createState() => _FavorDetailScreenState();
}

class _FavorDetailScreenState extends ConsumerState<FavorDetailScreen> {
  bool _isProcessing = false;

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
    int estrellas = 5;
    String comentario = '';
    final enviar = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Calificar el favor'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('¿Cómo fue tu experiencia con el otro participante?'),
              const SizedBox(height: 16),
              RatingBar.builder(
                initialRating: 5,
                minRating: 1,
                allowHalfRating: false,
                itemCount: 5,
                itemSize: 32,
                itemBuilder: (_, index) =>
                    const Icon(Icons.star, color: Colors.amber),
                onRatingUpdate: (valor) => estrellas = valor.toInt(),
              ),
              const SizedBox(height: 16),
              TextField(
                maxLength: 300,
                maxLines: 3,
                onChanged: (valor) => comentario = valor,
                decoration: const InputDecoration(
                  labelText: 'Comentario opcional',
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
            child: const Text('Enviar'),
          ),
        ],
      ),
    );
    if (enviar != true || !mounted) return;
    await _realizarAccion(
      () => ref
          .read(favorServiceProvider)
          .calificarUsuario(
            favorId: favor.id,
            idAutorCalificador: uid,
            idDestinatario: favor.otroParticipante(uid)!,
            estrellas: estrellas,
            comentario: comentario,
          ),
      '¡Calificación enviada correctamente!',
    );
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
      await ref
          .read(favorServiceProvider)
          .prepararChatFavor(favor.id, idUsuario: uid);
      if (!mounted) return;
      await Navigator.push(
        context,
        MaterialPageRoute<void>(
          builder: (_) => ChatRoomScreen(
            idReferencia: favor.id,
            tipoReferencia: 'favor',
            tituloReferencia: favor.titulo,
            otroUsuarioId: favor.otroParticipante(uid)!,
            otroUsuarioNombre: uid == favor.idAutor
                ? 'Ayudante'
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

    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded, color: Color(0xFF1E293B)),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          favorAsync.when(
            data: (favor) {
              if (favor == null ||
                  !favor.esEntregado ||
                  !favor.esParticipante(currentUser?.uid ?? '')) {
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
                        subtitle: esAutor
                            ? 'Tú (Autor del favor)'
                            : 'Estudiante USC',
                      ),
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

                      // Seguimiento del Caso (Timeline / Stepper del Mockup image8.png)
                      Container(
                        padding: const EdgeInsets.all(18),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: Colors.grey.shade200),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Seguimiento del caso',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF1E293B),
                              ),
                            ),
                            const SizedBox(height: 16),
                            _buildTimelineStep(
                              label: 'Favor publicado con éxito',
                              isDone: true,
                              color: Colors.green,
                            ),
                            _buildTimelineStep(
                              label: favor.esPublicado
                                  ? 'Esperando que un ayudante acepte'
                                  : 'Favor aceptado por un ayudante',
                              isDone: favor.esAceptado || favor.esEntregado,
                              color: AppTheme.primaryColor,
                            ),
                            _buildTimelineStep(
                              label: favor.esEntregado
                                  ? 'Entrega realizada con éxito'
                                  : 'Entrega en camino',
                              isDone: favor.esEntregado,
                              color: favor.esEntregado
                                  ? Colors.green
                                  : Colors.grey.shade300,
                              isLast: true,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              // Sticky Bottom Action Bar con Botón Chat y Acciones (Mockup image8.png)
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.05),
                      blurRadius: 10,
                      offset: const Offset(0, -4),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    // Botón "Chat con Solicitante" (Mockup image8.png)
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed:
                            !_isProcessing &&
                                favor.puedeAbrirChat(currentUser?.uid ?? '')
                            ? () => _abrirChat(favor)
                            : null,
                        icon: const Icon(
                          Icons.chat_bubble_outline_rounded,
                          color: Colors.white,
                        ),
                        label: const Text(
                          'Chat',
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF1D4ED8),
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),

                    // Botón Acción según Estado (Aceptar / Confirmar Pago / Calificar)
                    Expanded(
                      child: _isProcessing
                          ? const Center(child: CircularProgressIndicator())
                          : favor.esPublicado && !esAutor
                          ? ElevatedButton.icon(
                              onPressed: () => _aceptarFavor(favor),
                              icon: const Icon(
                                Icons.check_circle_outline,
                                color: Colors.white,
                              ),
                              label: const Text(
                                'Aceptar',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppTheme.primaryColor,
                                padding: const EdgeInsets.symmetric(
                                  vertical: 14,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(16),
                                ),
                              ),
                            )
                          : favor.esAceptado && esAyudante
                          ? ElevatedButton.icon(
                              onPressed: () => _confirmarPago(favor),
                              icon: const Icon(
                                Icons.task_alt_rounded,
                                color: Colors.white,
                              ),
                              label: const Text(
                                'Confirmar pago recibido',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.green,
                                padding: const EdgeInsets.symmetric(
                                  vertical: 14,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(16),
                                ),
                              ),
                            )
                          : favor.puedeCalificar(currentUser?.uid ?? '')
                          ? ElevatedButton.icon(
                              onPressed: () =>
                                  _mostrarDialogoCalificacion(favor),
                              icon: const Icon(Icons.star, color: Colors.white),
                              label: const Text(
                                'Calificar',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.amber.shade800,
                                padding: const EdgeInsets.symmetric(
                                  vertical: 14,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(16),
                                ),
                              ),
                            )
                          : OutlinedButton(
                              onPressed: null,
                              child: Text(favor.estado),
                            ),
                    ),
                  ],
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

  Widget _buildInfoCard({
    required IconData icon,
    required String title,
    required String subtitle,
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

  Widget _buildTimelineStep({
    required String label,
    required bool isDone,
    required Color color,
    bool isLast = false,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Column(
          children: [
            Container(
              width: 14,
              height: 14,
              decoration: BoxDecoration(
                color: isDone ? color : Colors.grey.shade300,
                shape: BoxShape.circle,
              ),
            ),
            if (!isLast)
              Container(
                width: 2,
                height: 24,
                color: isDone
                    ? color.withValues(alpha: 0.5)
                    : Colors.grey.shade200,
              ),
          ],
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.only(top: 0),
            child: Text(
              label,
              style: TextStyle(
                fontSize: 13,
                fontWeight: isDone ? FontWeight.bold : FontWeight.normal,
                color: isDone
                    ? const Color(0xFF1E293B)
                    : const Color(0xFF94A3B8),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
