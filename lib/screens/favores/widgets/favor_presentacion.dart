import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../../../config/app_theme.dart';
import '../../../models/favor_model.dart';

class FavorAvatar extends StatelessWidget {
  const FavorAvatar({super.key, required this.foto, this.radius = 16});

  final String foto;
  final double radius;

  @override
  Widget build(BuildContext context) => CircleAvatar(
    radius: radius,
    backgroundColor: AppTheme.surfaceColor,
    foregroundImage: foto.isEmpty ? null : CachedNetworkImageProvider(foto),
    onForegroundImageError: foto.isEmpty ? null : (_, _) {},
    child: Icon(
      Icons.person_outline,
      size: radius,
      color: AppTheme.primaryColor,
    ),
  );
}

class FavorProgreso extends StatelessWidget {
  const FavorProgreso({super.key, required this.favor});

  final FavorModel favor;

  @override
  Widget build(BuildContext context) {
    if (favor.esCancelado) return const Text('Favor cancelado');
    final paso = favor.esEntregado ? 2 : (favor.esAceptado ? 1 : 0);
    const etiquetas = ['Publicado', 'Aceptado', 'Entregado'];
    const iconos = [
      Icons.assignment_outlined,
      Icons.handshake_outlined,
      Icons.task_alt,
    ];
    const duracion = Duration(milliseconds: 250);

    return Semantics(
      label: 'Estado del favor: ${etiquetas[paso]}',
      child: Column(
        children: [
          LayoutBuilder(
            builder: (context, limites) => Stack(
              alignment: Alignment.center,
              children: [
                SizedBox(
                  width: limites.maxWidth * 2 / 3,
                  child: TweenAnimationBuilder<double>(
                    duration: duracion,
                    tween: Tween(begin: 0, end: paso / 2),
                    builder: (_, valor, _) => LinearProgressIndicator(
                      value: valor,
                      color: AppTheme.primaryColor,
                      backgroundColor: AppTheme.doradoSuave,
                      borderRadius: BorderRadius.circular(6),
                    ),
                  ),
                ),
                Row(
                  children: [
                    for (var i = 0; i < iconos.length; i++)
                      Expanded(
                        child: Center(
                          child: AnimatedContainer(
                            duration: duracion,
                            width: 34,
                            height: 34,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: i <= paso
                                  ? AppTheme.primaryColor
                                  : AppTheme.doradoSuave,
                            ),
                            child: Icon(
                              iconos[i],
                              size: 18,
                              color: i <= paso
                                  ? Colors.white
                                  : AppTheme.textSecondary,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              for (var i = 0; i < etiquetas.length; i++)
                Expanded(
                  child: Text(
                    etiquetas[i],
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: i == paso
                          ? FontWeight.bold
                          : FontWeight.normal,
                    ),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}
