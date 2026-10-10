import 'dart:math';

import 'package:flutter/material.dart';

import 'game.dart';

const kLudoColors = [
  Color(0xFFC8412F), // red
  Color(0xFF2F7D4F), // green
  Color(0xFFD9A11E), // yellow
  Color(0xFF2D5DA8), // blue
];

/// Paints the 15×15 board: yards, track, home columns, stars and centre.
class LudoBoardPainter extends CustomPainter {
  LudoBoardPainter({required this.paper, required this.line, required this.ink});
  final Color paper;
  final Color line;
  final Color ink;

  @override
  void paint(Canvas canvas, Size size) {
    final cell = size.width / 15;
    Rect rc(num r, num c, [num h = 1, num w = 1]) =>
        Rect.fromLTWH(c * cell, r * cell, w * cell, h * cell);

    final bg = Paint()..color = paper;
    canvas.drawRRect(
        RRect.fromRectAndRadius(Offset.zero & size, Radius.circular(cell * 0.6)), bg);

    final border = Paint()
      ..color = line
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;

    // Track squares.
    for (final (r, c) in kTrack) {
      canvas.drawRect(rc(r, c), Paint()..color = Colors.white);
      canvas.drawRect(rc(r, c), border);
    }
    // Home columns and start squares.
    for (var color = 0; color < 4; color++) {
      final fill = Paint()..color = kLudoColors[color].withValues(alpha: 0.85);
      for (final (r, c) in kHomeColumn[color]) {
        canvas.drawRect(rc(r, c), fill);
        canvas.drawRect(rc(r, c), border);
      }
      final (sr, sc) = kTrack[kStartIndex[color]];
      canvas.drawRect(rc(sr, sc), fill);
      canvas.drawRect(rc(sr, sc), border);
    }
    // Stars on safe squares.
    for (final i in kSafe) {
      if (kStartIndex.contains(i)) continue;
      final (r, c) = kTrack[i];
      _star(canvas, rc(r, c).center, cell * 0.32, Paint()..color = ink.withValues(alpha: 0.35));
    }

    // Yards.
    for (var color = 0; color < 4; color++) {
      final (r, c) = kYardOrigin[color];
      final outer = rc(r, c, 6, 6);
      canvas.drawRRect(
          RRect.fromRectAndRadius(outer.deflate(cell * 0.12), Radius.circular(cell * 0.7)),
          Paint()..color = kLudoColors[color]);
      final inner = outer.deflate(cell * 0.9);
      canvas.drawRRect(RRect.fromRectAndRadius(inner, Radius.circular(cell * 0.5)),
          Paint()..color = Colors.white);
      const slots = [(1.6, 1.6), (1.6, 3.4), (3.4, 1.6), (3.4, 3.4)];
      for (final (dr, dc) in slots) {
        canvas.drawCircle(
            Offset((c + dc) * cell, (r + dr) * cell),
            cell * 0.52,
            Paint()..color = kLudoColors[color].withValues(alpha: 0.18));
      }
    }

    // Centre: four triangles meeting in the middle.
    final centre = Offset(7.5 * cell, 7.5 * cell);
    final corners = [
      Offset(6 * cell, 6 * cell),
      Offset(9 * cell, 6 * cell),
      Offset(9 * cell, 9 * cell),
      Offset(6 * cell, 9 * cell),
    ];
    // Red (left), Green (top), Yellow (right), Blue (bottom).
    final tri = [
      [corners[3], corners[0]],
      [corners[0], corners[1]],
      [corners[1], corners[2]],
      [corners[2], corners[3]],
    ];
    for (var color = 0; color < 4; color++) {
      final path = Path()
        ..moveTo(tri[color][0].dx, tri[color][0].dy)
        ..lineTo(tri[color][1].dx, tri[color][1].dy)
        ..lineTo(centre.dx, centre.dy)
        ..close();
      canvas.drawPath(path, Paint()..color = kLudoColors[color]);
    }
    canvas.drawRect(rc(6, 6, 3, 3), border);
  }

  void _star(Canvas canvas, Offset c, double r, Paint p) {
    final path = Path();
    for (var i = 0; i < 10; i++) {
      final rr = i.isEven ? r : r * 0.45;
      final a = -pi / 2 + i * pi / 5;
      final pt = Offset(c.dx + rr * cos(a), c.dy + rr * sin(a));
      i == 0 ? path.moveTo(pt.dx, pt.dy) : path.lineTo(pt.dx, pt.dy);
    }
    path.close();
    canvas.drawPath(path, p);
  }

  @override
  bool shouldRepaint(covariant LudoBoardPainter old) =>
      old.paper != paper || old.line != line || old.ink != ink;
}

/// A glossy pawn-like token.
class LudoToken extends StatelessWidget {
  const LudoToken({super.key, required this.color, required this.size, this.active = false});
  final Color color;
  final double size;
  final bool active;

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 220),
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: Colors.white,
        border: Border.all(color: active ? Colors.black87 : Colors.white, width: active ? 2.5 : 1.5),
        boxShadow: [
          BoxShadow(
            color: active ? color.withValues(alpha: 0.7) : Colors.black26,
            blurRadius: active ? 10 : 3,
            spreadRadius: active ? 2 : 0,
            offset: const Offset(0, 1.5),
          ),
        ],
      ),
      padding: EdgeInsets.all(size * 0.12),
      child: DecoratedBox(
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: RadialGradient(
            center: const Alignment(-0.35, -0.4),
            colors: [Color.lerp(color, Colors.white, 0.35)!, color],
          ),
        ),
      ),
    );
  }
}

/// Dice face with pips.
class DiceFace extends StatelessWidget {
  const DiceFace({super.key, required this.value, required this.size, required this.color});
  final int value;
  final double size;
  final Color color;

  @override
  Widget build(BuildContext context) {
    const layouts = {
      1: [(1, 1)],
      2: [(0, 0), (2, 2)],
      3: [(0, 0), (1, 1), (2, 2)],
      4: [(0, 0), (0, 2), (2, 0), (2, 2)],
      5: [(0, 0), (0, 2), (1, 1), (2, 0), (2, 2)],
      6: [(0, 0), (0, 2), (1, 0), (1, 2), (2, 0), (2, 2)],
    };
    final pip = size * 0.17;
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(size * 0.22),
        border: Border.all(color: color, width: 2.5),
        boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 8, offset: Offset(0, 3))],
      ),
      child: Stack(
        children: [
          for (final (r, c) in layouts[value.clamp(1, 6)]!)
            Positioned(
              left: size * 0.16 + c * (size * 0.68 - pip) / 2,
              top: size * 0.16 + r * (size * 0.68 - pip) / 2,
              child: Container(
                width: pip,
                height: pip,
                decoration: BoxDecoration(shape: BoxShape.circle, color: color),
              ),
            ),
        ],
      ),
    );
  }
}
