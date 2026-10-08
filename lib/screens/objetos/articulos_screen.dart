import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../config/app_theme.dart';
import '../../models/objeto_model.dart';
import '../../providers/objeto_provider.dart';
import '../../services/auth_service.dart';
import '../chat/chat_room_screen.dart';
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
  String _tabActiva = 'perdido'; // 'perdido' | 'encontrado'

  @override
  Widget build(BuildContext context) {
    final objetosAsync = ref.watch(objetosStreamProvider);
    final user = AuthService().currentUser;
    final miUid = user?.uid ?? '';

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        leading: Navigator.canPop(context)
            ? IconButton(
                icon: const Icon(Icons.arrow_back_ios_new, color: Color(0xFF1E293B), size: 20),
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
              // Menú o selector de filtro adicional
              ref.read(filtroObjetosTipoProvider.notifier).state =
                  _tabActiva == 'todos' ? 'todos' : _tabActiva;
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
                        ref.read(filtroObjetosTipoProvider.notifier).state = 'perdido';
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
                        ref.read(filtroObjetosTipoProvider.notifier).state = 'encontrado';
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
                    // Mostrar todos
                    setState(() => _tabActiva = 'todos');
                    ref.read(filtroObjetosTipoProvider.notifier).state = 'todos';
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
          Expanded(
            child: objetosAsync.when(
              data: (objetos) {
                // Filtrar según pestaña local si aplica
                final objetosFiltrados = _tabActiva == 'todos'
                    ? objetos
                    : objetos.where((o) => o.tipo.toLowerCase() == _tabActiva).toList();

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
                          style: TextStyle(
                            fontSize: 15,
                            color: Colors.grey.shade600,
                          ),
                        ),
                      ],
                    ),
                  );
                }

                return ListView.builder(
                  padding: const EdgeInsets.only(left: 16, right: 16, bottom: 84),
                  itemCount: objetosFiltrados.length,
                  itemBuilder: (context, index) {
                    final objeto = objetosFiltrados[index];
                    return _buildObjetoCard(objeto, miUid);
                  },
                );
              },
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => Center(child: Text('Error cargando artículos: $e')),
            ),
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
            Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const ReportarObjetoScreen()),
            );
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
                color: esActivo ? const Color(0xFF1E293B) : const Color(0xFF64748B),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildObjetoCard(ObjetoModel objeto, String miUid) {
    final esPerdido = objeto.esPerdido;
    final esDueno = objeto.idDueno == miUid;
    final badgeBg = esPerdido ? const Color(0xFFFFE4E6) : const Color(0xFFD1FAE5);
    final badgeText = esPerdido ? const Color(0xFFE11D48) : const Color(0xFF059669);

    return Container(
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
              child: objeto.urlFoto.isNotEmpty
                  ? CachedNetworkImage(
                      imageUrl: objeto.urlFoto,
                      fit: BoxFit.cover,
                      placeholder: (ctx, url) => Container(
                        color: Colors.grey.shade100,
                        child: const Center(child: CircularProgressIndicator(strokeWidth: 2)),
                      ),
                      errorWidget: (ctx, url, error) => _buildPlaceholderFoto(objeto),
                    )
                  : _buildPlaceholderFoto(objeto),
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
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
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
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
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
                    const Icon(Icons.location_on, size: 14, color: Color(0xFF94A3B8)),
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

                // Reportado por + Acciones (image12.png)
                Row(
                  children: [
                    CircleAvatar(
                      radius: 11,
                      backgroundColor: const Color(0xFFE2E8F0),
                      child: Text(
                        objeto.nombreDueno.isNotEmpty
                            ? objeto.nombreDueno.substring(0, 1).toUpperCase()
                            : 'U',
                        style: const TextStyle(
                          fontSize: 9.5,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF475569),
                        ),
                      ),
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        'Por ${objeto.nombreDueno.isNotEmpty ? objeto.nombreDueno : "Estudiante"}',
                        style: const TextStyle(
                          fontSize: 11,
                          color: Color(0xFF94A3B8),
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),

          // 3. Botones a la derecha: Chat y Acción ("Es mío" / "Yo tengo el objeto")
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              // Botón de Chat (RF07): Abre sala 1-a-1
              InkWell(
                onTap: () {
                  if (esDueno) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Este objeto fue reportado por ti.'),
                      ),
                    );
                    return;
                  }
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => ChatRoomScreen(
                        idReferencia: objeto.id,
                        tipoReferencia: 'objeto',
                        tituloReferencia: objeto.titulo,
                        otroUsuarioId: objeto.idDueno,
                        otroUsuarioNombre: objeto.nombreDueno.isNotEmpty
                            ? objeto.nombreDueno
                            : 'Reportante',
                      ),
                    ),
                  );
                },
                borderRadius: BorderRadius.circular(12),
                child: Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    color: const Color(0xFFEEF2FF),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(
                    Icons.chat_bubble_outline_rounded,
                    color: AppTheme.primaryColor,
                    size: 19,
                  ),
                ),
              ),
              const SizedBox(height: 10),

              // Botón de Reclamar ("Es mío" / "Yo tengo el objeto") (RF11, RF12)
              if (objeto.esPublicado && !esDueno)
                SizedBox(
                  height: 32,
                  child: ElevatedButton(
                    onPressed: () {
                      ReclamarObjetoModal.mostrar(context, objeto);
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.primaryColor,
                      padding: const EdgeInsets.symmetric(horizontal: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                    child: Text(
                      esPerdido ? 'Lo encontré' : 'Es mío',
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  ),
                )
              else if (esDueno)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF1F5F9),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Text(
                    'Tu reporte',
                    style: TextStyle(
                      fontSize: 10.5,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF64748B),
                    ),
                  ),
                ),
            ],
          ),
        ],
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
          objeto.esPerdido ? Icons.search_off_rounded : Icons.check_circle_outline_rounded,
          color: AppTheme.primaryColor,
          size: 32,
        ),
      ),
    );
  }
}
