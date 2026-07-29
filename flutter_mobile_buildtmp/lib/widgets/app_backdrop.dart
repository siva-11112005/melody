import 'package:flutter/material.dart';

class AppBackdrop extends StatelessWidget {
  final bool showGlow;

  const AppBackdrop({super.key, this.showGlow = true});

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: RadialGradient(
          center: Alignment.topRight,
          radius: 1.4,
          colors: [Color(0xFF1A1A1A), Color(0xFF121212), Color(0xFF090909)],
        ),
      ),
      child: Stack(
        children: [
          if (showGlow)
            Positioned(
              top: -80,
              right: -60,
              child: Container(
                width: 180,
                height: 180,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [Color(0xFF1DB954).withValues(alpha: 0.18), Colors.transparent],
                  ),
                ),
              ),
            ),
          if (showGlow)
            Positioned(
              left: -90,
              top: 160,
              child: Container(
                width: 220,
                height: 220,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [Color(0xFF1DB954).withValues(alpha: 0.08), Colors.transparent],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}