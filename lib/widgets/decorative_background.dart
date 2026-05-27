import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

class DecorativeBackground extends StatelessWidget {
  final Widget? child;
  const DecorativeBackground({super.key, this.child});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDarkMode = theme.brightness == Brightness.dark;
    
    return CustomPaint(
      painter: _DecorativePainter(
        color1: SisapaTheme.blue.withValues(alpha: isDarkMode ? 0.15 : 0.1),
        color2: SisapaTheme.blue.withValues(alpha: isDarkMode ? 0.1 : 0.05),
      ),
      child: child,
    );
  }
}

class _DecorativePainter extends CustomPainter {
  final Color color1;
  final Color color2;

  _DecorativePainter({required this.color1, required this.color2});

  @override
  void paint(Canvas canvas, Size size) {
    final paint1 = Paint()..color = color1..style = PaintingStyle.fill;
    final paint2 = Paint()..color = color2..style = PaintingStyle.fill;

    // Top Right Circle (top: -100, right: -100, width: 300, height: 300)
    // Center of this circle is at (size.width + 100 - 150) = size.width - 50, Y = -100 + 150 = 50
    // Actually, if it's positioned top:-100 right:-100 with width 300, 
    // the top right corner is at (size.width + 100, -100).
    // The center is at (size.width + 100 - 150, -100 + 150) = (size.width - 50, 50).
    // Radius = 150.
    canvas.drawCircle(Offset(size.width - 50, 50), 150, paint1);

    // Bottom Left Circle (bottom: 150, left: -50, width: 200, height: 200)
    // The bottom edge is at size.height - 150.
    // Top of circle is at size.height - 150 - 200 = size.height - 350.
    // Center Y is size.height - 250.
    // Center X is -50 + 100 = 50.
    // Radius = 100.
    canvas.drawCircle(Offset(50, size.height - 250), 100, paint2);
  }

  @override
  bool shouldRepaint(covariant _DecorativePainter oldDelegate) {
    return oldDelegate.color1 != color1 || oldDelegate.color2 != color2;
  }
}
