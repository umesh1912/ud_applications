import 'package:flutter/material.dart';

import '../theme/tokens.dart';

/// Faint lab-notebook grid behind a screen. Used on top-level screens only,
/// so reading surfaces (lessons, PDFs) stay clean.
class GraphPaper extends StatelessWidget {
  const GraphPaper({super.key, required this.child, this.cell = 24});

  final Widget child;
  final double cell;

  @override
  Widget build(BuildContext context) {
    final vc = context.vc;
    return CustomPaint(
      painter: _GridPainter(
        color: vc.rule.withValues(alpha: Theme.of(context).brightness == Brightness.dark ? 0.35 : 0.55),
        cell: cell,
      ),
      child: child,
    );
  }
}

class _GridPainter extends CustomPainter {
  _GridPainter({required this.color, required this.cell});

  final Color color;
  final double cell;

  @override
  void paint(Canvas canvas, Size size) {
    final p = Paint()
      ..color = color
      ..strokeWidth = 0.6;
    for (double x = 0; x <= size.width; x += cell) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), p);
    }
    for (double y = 0; y <= size.height; y += cell) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), p);
    }
  }

  @override
  bool shouldRepaint(_GridPainter old) => old.color != color || old.cell != cell;
}
