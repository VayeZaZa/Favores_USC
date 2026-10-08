import 'package:flutter/material.dart';

class FavoresBrand extends StatelessWidget {
  const FavoresBrand({
    super.key,
    required this.foregroundColor,
    required this.accentColor,
    required this.surfaceColor,
  });

  final Color foregroundColor;
  final Color accentColor;
  final Color surfaceColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 7),
      decoration: BoxDecoration(
        color: surfaceColor,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: accentColor.withValues(alpha: 0.45)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.handshake_rounded, color: accentColor, size: 21),
          const SizedBox(width: 7),
          Text(
            'FAVORES USC',
            style: TextStyle(
              color: foregroundColor,
              fontSize: 11,
              fontWeight: FontWeight.w900,
              letterSpacing: 1.25,
            ),
          ),
        ],
      ),
    );
  }
}
