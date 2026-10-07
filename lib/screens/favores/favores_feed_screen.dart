import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:timeago/timeago.dart' as timeago;
import '../../config/app_constants.dart';
import '../../config/app_theme.dart';
import '../../models/favor_model.dart';
import '../../providers/favor_provider.dart';
import '../../services/auth_service.dart';
import 'crear_favor_screen.dart';
import 'favor_detail_screen.dart';

/// Feed Paginado de Favores ajustado 100% al Mockup (image7.png) y especificaciones del documento
class FavoresFeedScreen extends ConsumerStatefulWidget {
  const FavoresFeedScreen({super.key});

  @override
  ConsumerState<FavoresFeedScreen> createState() => _FavoresFeedScreenState();
}

class _FavoresFeedScreenState extends ConsumerState<FavoresFeedScreen> {
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(() {
      if (_scrollController.position.pixels >=
          _scrollController.position.maxScrollExtent - 200) {
        ref.read(favoresFeedProvider.notifier).cargarMas();
      }
    });
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final feedState = ref.watch(favoresFeedProvider);
    final currentUser = AuthService().currentUser;
    final nombreUsuario = currentUser?.displayName ??
        currentUser?.email?.split('@').first ??
        'Estudiante';

    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        automaticallyImplyLeading: false,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Saludo personalizado al usuario (Documento: ¡Hola David!)
            Text(
              '¡Hola, $nombreUsuario! 👋',
              style: const TextStyle(
                color: Color(0xFF1E293B),
                fontSize: 22,
                fontWeight: FontWeight.bold,
              ),
            ),
            const Text(
              'Comunidad Universidad Santiago de Cali',
              style: TextStyle(
                color: Color(0xFF64748B),
                fontSize: 13,
              ),
            ),
          ],
        ),
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 12),

          // 1. Bar de Filtros por Categoría con Íconos (Mockup image7.png)
          SizedBox(
            height: 46,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              children: [
                _buildCategoryChip('Todos', Icons.grid_view_rounded, feedState.filtroTipo),
                _buildCategoryChip('Objetos', Icons.inventory_2_outlined, feedState.filtroTipo),
                _buildCategoryChip('Apuntes', Icons.description_outlined, feedState.filtroTipo),
                _buildCategoryChip('Domicilio', Icons.directions_bike_outlined, feedState.filtroTipo),
                ...AppConstants.tiposFavores
                    .where((t) => !['Objetos', 'Apuntes', 'Domicilio'].contains(t))
                    .map((t) => _buildCategoryChip(t, Icons.category_outlined, feedState.filtroTipo)),
              ],
            ),
          ),

          const SizedBox(height: 16),

          // 2. Banner de Estadísticas (Gradiente Azul a Dorado del Mockup)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 24),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(20),
                gradient: const LinearGradient(
                  colors: [Color(0xFF0D47A1), Color(0xFFE6A100)],
                  begin: Alignment.centerLeft,
                  end: Alignment.centerRight,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.blue.withOpacity(0.2),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Row(
                children: [
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Text(
                          '12',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        SizedBox(height: 2),
                        Text(
                          'Mis Favores',
                          style: TextStyle(
                            color: Colors.white70,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    height: 35,
                    width: 1,
                    color: Colors.white30,
                  ),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              '4.8',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 24,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            SizedBox(width: 4),
                            Icon(Icons.star, color: Colors.amber, size: 20),
                          ],
                        ),
                        SizedBox(height: 2),
                        Text(
                          'Rating',
                          style: TextStyle(
                            color: Colors.white70,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 20),

          // 3. Encabezado "Favores Recientes"
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 16.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Favores Recientes',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF1E293B),
                  ),
                ),
                Text(
                  'Ver todo',
                  style: TextStyle(
                    fontSize: 13,
                    color: AppTheme.primaryColor,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 12),

          // 4. Lista Paginada de Tarjetas de Favor (Mockup UI)
          Expanded(
            child: RefreshIndicator(
              onRefresh: () async {
                await ref.read(favoresFeedProvider.notifier).cargarInicial();
              },
              child: feedState.favores.isEmpty && !feedState.isLoading
                  ? const Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.inbox_outlined, size: 64, color: Colors.grey),
                          SizedBox(height: 12),
                          Text(
                            'No hay favores disponibles en esta categoría.',
                            style: TextStyle(fontSize: 15, color: Colors.grey),
                          ),
                        ],
                      ),
                    )
                  : ListView.builder(
                      controller: _scrollController,
                      padding: const EdgeInsets.only(left: 16, right: 16, bottom: 80),
                      itemCount: feedState.favores.length + (feedState.isLoading ? 1 : 0),
                      itemBuilder: (context, index) {
                        if (index == feedState.favores.length) {
                          return const Padding(
                            padding: EdgeInsets.symmetric(vertical: 16),
                            child: Center(child: CircularProgressIndicator()),
                          );
                        }

                        final favor = feedState.favores[index];
                        return _FavorCardMockup(favor: favor);
                      },
                    ),
            ),
          ),
        ],
      ),
      // 5. Botón de Crear Favor CENTRADO ABAJO (Especificación explícita del documento)
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
      floatingActionButton: Container(
        height: 52,
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: ElevatedButton.icon(
          onPressed: () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const CrearFavorScreen()),
            );
          },
          icon: const Icon(Icons.add_rounded, color: Colors.white, size: 22),
          label: const Text(
            'Crear Favor',
            style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
              fontSize: 16,
            ),
          ),
          style: ElevatedButton.styleFrom(
            backgroundColor: AppTheme.primaryColor,
            elevation: 6,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(30),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 12),
          ),
        ),
      ),
    );
  }

  Widget _buildCategoryChip(String label, IconData icon, String filtroActual) {
    final isSelected = filtroActual == label;
    return Padding(
      padding: const EdgeInsets.only(right: 8.0),
      child: InkWell(
        onTap: () {
          ref.read(favoresFeedProvider.notifier).cambiarFiltro(label);
        },
        borderRadius: BorderRadius.circular(25),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          decoration: BoxDecoration(
            color: isSelected ? AppTheme.primaryColor : Colors.white,
            borderRadius: BorderRadius.circular(25),
            border: Border.all(
              color: isSelected ? AppTheme.primaryColor : Colors.grey.shade300,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                icon,
                size: 18,
                color: isSelected ? Colors.white : const Color(0xFF475569),
              ),
              const SizedBox(width: 6),
              Text(
                label,
                style: TextStyle(
                  color: isSelected ? Colors.white : const Color(0xFF475569),
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                  fontSize: 13,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Tarjeta de Favor idéntica a la maqueta visual (image7.png)
class _FavorCardMockup extends StatelessWidget {
  final FavorModel favor;

  const _FavorCardMockup({required this.favor});

  @override
  Widget build(BuildContext context) {
    final hasImage = favor.urlFotos.isNotEmpty;

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Banner de Imagen con Pills (Categoría arriba izq, Precio abajo der)
          Stack(
            children: [
              Container(
                height: 170,
                width: double.infinity,
                clipBehavior: Clip.antiAlias,
                decoration: const BoxDecoration(
                  borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
                  color: Color(0xFFE2E8F0),
                ),
                child: hasImage
                    ? CachedNetworkImage(
                        imageUrl: favor.urlFotos.first,
                        fit: BoxFit.cover,
                        placeholder: (context, url) => Container(
                          color: Colors.grey.shade200,
                          child: const Center(child: CircularProgressIndicator()),
                        ),
                        errorWidget: (context, url, err) => const Icon(Icons.broken_image),
                      )
                    : Container(
                        color: AppTheme.primaryColor.withOpacity(0.08),
                        child: const Icon(
                          Icons.volunteer_activism,
                          size: 48,
                          color: AppTheme.primaryColor,
                        ),
                      ),
              ),
              // Pill de Categoría (Azul arriba a la izquierda)
              Positioned(
                top: 14,
                left: 14,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                  decoration: BoxDecoration(
                    color: AppTheme.primaryColor,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    favor.tipo,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                  ),
                ),
              ),
              // Pill de Precio (Blanco con texto verde abajo a la derecha)
              Positioned(
                bottom: 14,
                right: 14,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.1),
                        blurRadius: 4,
                      ),
                    ],
                  ),
                  child: Text(
                    '\$${NumberFormat("#,##0", "es_CO").format(favor.pago)}',
                    style: const TextStyle(
                      color: Color(0xFF10B981),
                      fontWeight: FontWeight.w800,
                      fontSize: 15,
                    ),
                  ),
                ),
              ),
            ],
          ),

          // Detalles del Favor (Título, Ubicación, Usuario y Botón Ver Favor)
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Título e Ícono de Bookmark
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Text(
                        favor.descripcion,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF1E293B),
                        ),
                      ),
                    ),
                    const Icon(
                      Icons.bookmark_border_rounded,
                      color: Color(0xFF94A3B8),
                    ),
                  ],
                ),
                const SizedBox(height: 6),

                // Ubicación Fija del Campus (RNF04)
                Row(
                  children: [
                    const Icon(Icons.location_on_outlined, size: 16, color: Color(0xFF64748B)),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        favor.ubicacion,
                        style: const TextStyle(fontSize: 13, color: Color(0xFF64748B)),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),

                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 12.0),
                  child: Divider(height: 1, color: Color(0xFFF1F5F9)),
                ),

                // Fila Inferior: Avatar + Nombre + Tiempo + Botón Ver Favor
                Row(
                  children: [
                    CircleAvatar(
                      radius: 18,
                      backgroundColor: AppTheme.primaryColor.withOpacity(0.15),
                      child: const Text(
                        'USC',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: AppTheme.primaryColor,
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Estudiante USC',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF334155),
                            ),
                          ),
                          Text(
                            timeago.format(favor.fechaCreacion, locale: 'es'),
                            style: const TextStyle(fontSize: 11, color: Color(0xFF94A3B8)),
                          ),
                        ],
                      ),
                    ),

                    // Botón "Ver Favor"
                    OutlinedButton(
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => FavorDetailScreen(favorId: favor.id),
                          ),
                        );
                      },
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(color: Color(0xFFCBD5E1)),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(20),
                        ),
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      ),
                      child: const Text(
                        'Ver Favor',
                        style: TextStyle(
                          color: Color(0xFF334155),
                          fontWeight: FontWeight.w600,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
