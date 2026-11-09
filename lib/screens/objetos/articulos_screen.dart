import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../config/app_theme.dart';
import '../../models/objeto_model.dart';
import '../../providers/objeto_provider.dart';
import '../../services/auth_service.dart';
import '../chat/chat_room_screen.dart';
import '../widgets/confirmar_borrado.dart';
import 'objetos_demostracion.dart';
import 'reclamar_objeto_modal.dart';
import 'reportar_objeto_screen.dart';

/// Pantalla Principal de Artículos Perdidos y Encontrados (RF10, RF11, RF12, RF13)
/// Ajustada al Mockup visual (image12.png) y especificaciones:
/// - Pestañas limpias "Perdidos" / "Encontrados"
/// - Se removió el cuadro redundante de "perdido & encontrado"
/// - Botón "+ Reportar Objeto" CENTRADO en la parte inferior
class ArticulosScreen extends ConsumerStatefulWidget {
  const ArticulosScreen({super.key});

  @override
  ConsumerState<ArticulosScreen> createState() => _ArticulosScreenState();
}

class _ArticulosScreenState extends ConsumerState<ArticulosScreen> {
  String _tabActiva = 'perdido'; // 'perdido' | 'encontrado' | 'todos'
  String? _borrandoId;

  Future<void> _eliminarReporte(ObjetoModel objeto) async {
    if (_borrandoId != null) return;
    final confirmado = await confirmarBorradoPublicacion(
      context,
      tipo: 'reporte',
      titulo: objeto.titulo,
    );
    if (!confirmado || !mounted || _borrandoId != null) return;
    setState(() => _borrandoId = objeto.id);
    try {
      await ref.read(objetoServiceProvider).eliminarObjeto(objeto.id);
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Reporte borrado.')));
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(error.toString().replaceFirst('Exception: ', '')),
        ),
      );
    } finally {
      if (mounted) setState(() => _borrandoId = null);
    }
  }

  Widget _listaObjetos(List<ObjetoModel> objetos, String miUid) {
    final objetosConMuestras = [
      ...crearObjetosDemostracion(),
      ...objetos.where(
        (objeto) =>
            !(objeto.titulo.trim().toLowerCase() == 'llaves con llavero usc' &&
                objeto.nombreDueno.trim().toLowerCase() == 'valeria martínez'),
      ),
    ];
    final objetosFiltrados = _tabActiva == 'todos'
        ? objetosConMuestras
        : objetosConMuestras
              .where((o) => o.tipo.toLowerCase() == _tabActiva)
              .toList();

    if (objetosFiltrados.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              _tabActiva == 'perdido'
                  ? Icons.search_off_rounded
                  : Icons.inventory_2_outlined,
              size: 64,
              color: Colors.grey.shade400,
            ),
            const SizedBox(height: 12),
            Text(
              _tabActiva == 'perdido'
                  ? 'No hay objetos perdidos reportados.'
                  : 'No hay objetos encontrados reportados.',
              style: TextStyle(fontSize: 15, color: Colors.grey.shade600),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      key: ValueKey(_tabActiva),
      primary: false,
      padding: const EdgeInsets.only(left: 16, right: 16, bottom: 84),
      itemCount: objetosFiltrados.length,
      itemBuilder: (context, index) =>
          _buildObjetoCard(objetosFiltrados[index], miUid),
    );
  }

  @override
  Widget build(BuildContext context) {
    final objetosAsync = ref.watch(objetosStreamProvider);
    final user = AuthService().currentUser;
    final miUid = user?.uid ?? '';

    return Scaffold(
      backgroundColor: AppTheme.surfaceColor,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        leading: Navigator.canPop(context)
            ? IconButton(
                icon: const Icon(
                  Icons.arrow_back_ios_new,
                  color: Color(0xFF1E293B),
                  size: 20,
                ),
                onPressed: () => Navigator.pop(context),
              )
            : null,
        title: const Text(
          'Artículos',
          style: TextStyle(
            color: Color(0xFF1E293B),
            fontSize: 22,
            fontWeight: FontWeight.bold,
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.tune_rounded, color: Color(0xFF1E293B)),
            onPressed: () {
              setState(() => _tabActiva = 'todos');
            },
          ),
        ],
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 8),

          // 1. Selector de Pestañas Perdidos vs Encontrados (image12.png)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Container(
              height: 52,
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: const Color(0xFFEDF2F7),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: _buildTabButton(
                      titulo: 'Perdidos',
                      icono: Icons.search_off_rounded,
                      colorActivo: const Color(0xFFEF4444),
                      esActivo: _tabActiva == 'perdido',
                      onTap: () {
                        setState(() => _tabActiva = 'perdido');
                      },
                    ),
                  ),
                  const SizedBox(width: 4),
                  Expanded(
                    child: _buildTabButton(
                      titulo: 'Encontrados',
                      icono: Icons.check_circle_outline_rounded,
                      colorActivo: const Color(0xFF10B981),
                      esActivo: _tabActiva == 'encontrado',
                      onTap: () {
                        setState(() => _tabActiva = 'encontrado');
                      },
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 18),

          // 2. Encabezado "Reportes Recientes"
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 18),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Reportes Recientes',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF1E293B),
                  ),
                ),
                TextButton(
                  onPressed: () {
                    setState(() => _tabActiva = 'todos');
                  },
                  child: const Text(
                    'Ver todo',
                    style: TextStyle(
                      color: AppTheme.primaryColor,
                      fontWeight: FontWeight.w600,
                      fontSize: 13,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 6),

          // 3. Lista de Tarjetas de Objetos (image12.png)
          if (objetosAsync.hasError)
            Center(
              child: TextButton(
                onPressed: () => ref.invalidate(objetosStreamProvider),
                child: const Text('Reintentar cargar reportes'),
              ),
            )
          else if (objetosAsync.isLoading)
            const LinearProgressIndicator(),
          Expanded(
            child: _listaObjetos(objetosAsync.valueOrNull ?? const [], miUid),
          ),
        ],
      ),
      // 4. Botón Reportar Objeto CENTRADO EN LA PARTE INFERIOR (Especificación del documento)
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
      floatingActionButton: Container(
        height: 52,
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: ElevatedButton.icon(
          onPressed: () {
            Navigator.push<bool>(
              context,
              MaterialPageRoute<bool>(
                builder: (_) => const ReportarObjetoScreen(),
              ),
            ).then((publicado) {
              if (publicado == true && mounted) {
                setState(() => _tabActiva = 'todos');
              }
            });
          },
          icon: const Icon(Icons.add, color: Colors.white, size: 22),
          label: const Text(
            'Reportar Objeto',
            style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
              fontSize: 16,
            ),
          ),
          style: ElevatedButton.styleFrom(
            backgroundColor: AppTheme.primaryColor,
            elevation: 5,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(30),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 12),
          ),
        ),
      ),
    );
  }

  Widget _buildTabButton({
    required String titulo,
    required IconData icono,
    required Color colorActivo,
    required bool esActivo,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        decoration: BoxDecoration(
          color: esActivo ? Colors.white : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
          boxShadow: esActivo
              ? [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.06),
                    blurRadius: 4,
                    offset: const Offset(0, 2),
                  ),
                ]
              : null,
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icono,
              size: 18,
              color: esActivo ? colorActivo : const Color(0xFF64748B),
            ),
            const SizedBox(width: 8),
            Text(
              titulo,
              style: TextStyle(
                fontSize: 14,
                fontWeight: esActivo ? FontWeight.bold : FontWeight.w500,
                color: esActivo
                    ? const Color(0xFF1E293B)
                    : const Color(0xFF64748B),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String? _autorVisible(ObjetoModel objeto) {
    final nombre = objeto.nombreDueno.trim();
    const nombresGenericos = {'', 'estudiante', 'estudiante usc'};
    return nombresGenericos.contains(nombre.toLowerCase()) ? null : nombre;
  }

  String? _fotoIlustrativa(ObjetoModel objeto) {
    final titulo = objeto.titulo.toLowerCase();
    if (titulo.contains('llave')) {
      return 'assets/images/objetos_llaves_demo.png';
    }
    if (titulo.contains('cartera rosada')) {
      return 'assets/images/objetos_cartera_demo.png';
    }
    return null;
  }

  Widget _fotoObjeto(ObjetoModel objeto, {BoxFit fit = BoxFit.cover}) {
    final ilustracion = _fotoIlustrativa(objeto);
    final alternativa = ilustracion == null
        ? _buildPlaceholderFoto(objeto)
        : Image.asset(
            ilustracion,
            fit: fit,
            errorBuilder: (_, _, _) => _buildPlaceholderFoto(objeto),
          );
    final url = objeto.urlFoto.trim();
    return url.isEmpty
        ? alternativa
        : CachedNetworkImage(
            imageUrl: url,
            fit: fit,
            placeholder: (_, _) => _buildPlaceholderFoto(objeto),
            errorWidget: (_, _, _) => alternativa,
          );
  }

  Future<void> _mostrarDetalle(ObjetoModel objeto, String miUid) async {
    final autor = _autorVisible(objeto);
    final esDueno = !objeto.esDemostracion && objeto.idDueno == miUid;
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      showDragHandle: true,
      builder: (detalleContext) {
        final tema = Theme.of(detalleContext);
        return FractionallySizedBox(
          heightFactor: .90,
          child: SafeArea(
            top: false,
            child: Column(
              children: [
                Expanded(
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(16),
                        child: AspectRatio(
                          aspectRatio: 4 / 3,
                          child: _fotoObjeto(objeto, fit: BoxFit.contain),
                        ),
                      ),
                      if (!objeto.esDemostracion &&
                          objeto.urlFoto.trim().isEmpty &&
                          _fotoIlustrativa(objeto) != null)
                        const Text('Imagen ilustrativa'),
                      const SizedBox(height: 16),
                      Text(
                        objeto.esPerdido ? 'Perdido' : 'Encontrado',
                        style: tema.textTheme.labelLarge,
                      ),
                      const SizedBox(height: 4),
                      Text(objeto.titulo, style: tema.textTheme.headlineSmall),
                      if (autor != null) Text('Por $autor'),
                      const SizedBox(height: 12),
                      Text(
                        objeto.lugarCampus,
                        style: tema.textTheme.titleSmall,
                      ),
                      if (objeto.descripcion.trim().isNotEmpty) ...[
                        const SizedBox(height: 8),
                        Text(objeto.descripcion),
                      ],
                      if (objeto.esEncontrado && objeto.dondeQuedo.isNotEmpty)
                        Text(objeto.dondeQuedo),
                      if (!objeto.esPublicado)
                        Text('Estado: ${objeto.estadoActual}'),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      if (esDueno)
                        const Text('Tu reporte', textAlign: TextAlign.center),
                      if (objeto.puedeEliminar(miUid) && esDueno)
                        TextButton.icon(
                          onPressed: _borrandoId == null
                              ? () {
                                  Navigator.pop(detalleContext);
                                  _eliminarReporte(objeto);
                                }
                              : null,
                          icon: const Icon(Icons.delete_outline_rounded),
                          label: const Text('Borrar reporte'),
                        ),
                      if (!objeto.esDemostracion && !esDueno)
                        TextButton.icon(
                          onPressed: () {
                            Navigator.of(detalleContext).push(
                              MaterialPageRoute<void>(
                                builder: (_) => ChatRoomScreen(
                                  idReferencia: objeto.id,
                                  tipoReferencia: 'objeto',
                                  tituloReferencia: objeto.titulo,
                                  otroUsuarioId: objeto.idDueno,
                                  otroUsuarioNombre: autor ?? 'Reportante',
                                ),
                              ),
                            );
                          },
                          icon: const Icon(Icons.chat_bubble_outline_rounded),
                          label: const Text('Chat'),
                        ),
                      if (objeto.esPublicado && !esDueno)
                        ElevatedButton(
                          onPressed: () => ReclamarObjetoModal.mostrar(
                            detalleContext,
                            objeto,
                          ),
                          child: Text(
                            objeto.esPerdido ? 'Lo encontré' : 'Es mío',
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildObjetoCard(ObjetoModel objeto, String miUid) {
    final esPerdido = objeto.esPerdido;
    final autor = _autorVisible(objeto);
    final badgeBg = esPerdido
        ? const Color(0xFFFFE4E6)
        : const Color(0xFFD1FAE5);
    final badgeText = esPerdido
        ? const Color(0xFFE11D48)
        : const Color(0xFF059669);

    return InkWell(
      onTap: () => _mostrarDetalle(objeto, miUid),
      borderRadius: BorderRadius.circular(20),
      child: Container(
        margin: const EdgeInsets.only(bottom: 14),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.03),
              blurRadius: 8,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 1. Miniatura de imagen
            ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: SizedBox(
                width: 88,
                height: 88,
                child: _fotoObjeto(objeto),
              ),
            ),
            const SizedBox(width: 14),

            // 2. Información del objeto
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Badge Tipo (PERDIDO / ENCONTRADO)
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 3,
                        ),
                        decoration: BoxDecoration(
                          color: badgeBg,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          esPerdido ? 'PERDIDO' : 'ENCONTRADO',
                          style: TextStyle(
                            color: badgeText,
                            fontSize: 10.5,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      const Spacer(),
                      // Badge de estado si no está en 'Publicado'
                      if (!objeto.esPublicado)
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: objeto.esEntregado
                                ? const Color(0xFFE2E8F0)
                                : const Color(0xFFFEF3C7),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            objeto.estadoActual,
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              color: objeto.esEntregado
                                  ? const Color(0xFF475569)
                                  : const Color(0xFFD97706),
                            ),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 6),

                  // Título
                  Text(
                    objeto.titulo,
                    style: const TextStyle(
                      fontSize: 15.5,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF1E293B),
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),

                  // Ubicación del Campus (Pin icon)
                  Row(
                    children: [
                      const Icon(
                        Icons.location_on,
                        size: 14,
                        color: Color(0xFF94A3B8),
                      ),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          objeto.lugarCampus,
                          style: const TextStyle(
                            fontSize: 12,
                            color: Color(0xFF64748B),
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),

                  if (objeto.esEncontrado && objeto.dondeQuedo.isNotEmpty) ...[
                    Text(
                      objeto.dondeQuedo,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 11,
                        color: Color(0xFF475569),
                      ),
                    ),
                    const SizedBox(height: 6),
                  ],

                  if (autor != null)
                    Text(
                      'Por $autor',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                ],
              ),
            ),
            const SizedBox(width: 8),

            const Icon(Icons.chevron_right_rounded),
          ],
        ),
      ),
    );
  }

  Widget _buildPlaceholderFoto(ObjetoModel objeto) {
    Color colorFondo;
    switch (objeto.etiquetaColor.toLowerCase()) {
      case 'rojo':
        colorFondo = const Color(0xFFFEE2E2);
        break;
      case 'verde':
        colorFondo = const Color(0xFFDCFCE7);
        break;
      case 'azul':
        colorFondo = const Color(0xFFDBEAFE);
        break;
      case 'amarillo':
        colorFondo = const Color(0xFFFEF3C7);
        break;
      case 'morado':
        colorFondo = const Color(0xFFEDE9FE);
        break;
      default:
        colorFondo = const Color(0xFFF1F5F9);
    }

    return Container(
      color: colorFondo,
      child: Center(
        child: Icon(
          objeto.esPerdido
              ? Icons.search_off_rounded
              : Icons.check_circle_outline_rounded,
          color: AppTheme.primaryColor,
          size: 32,
        ),
      ),
    );
  }
}
