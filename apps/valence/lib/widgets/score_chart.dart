import 'package:flutter/material.dart';

import '../theme/tokens.dart';

/// Score trend plotted like a lab reading: points joined by a ruled line,
/// the latest reading circled with a highlighter.
class ScoreChart extends StatelessWidget {
  const ScoreChart({super.key, required this.values, this.height = 160});

  /// Values 0..1, oldest first.
  final List<double> values;
  final double height;

  @override
  Widget build(BuildContext context) {
    final vc = context.vc;
    final scheme = Theme.of(context).colorScheme;
    return Semantics(
      label: values.isEmpty
          ? 'No test scores yet'
          : 'Score trend. Latest ${(values.last * 100).round()} percent across ${values.length} tests',
      child: SizedBox(
        height: height,
        width: double.infinity,
        child: CustomPaint(
          painter: _ChartPainter(
            values: values,
            line: scheme.primary,
            rule: vc.rule,
            highlight: vc.highlight,
            labelStyle: context.text.labelSmall!,
          ),
        ),
      ),
    );
  }
}

class _ChartPainter extends CustomPainter {
  _ChartPainter({
    required this.values,
    required this.line,
    required this.rule,
    required this.highlight,
    required this.labelStyle,
  });

  final List<double> values;
  final Color line;
  final Color rule;
  final Color highlight;
  final TextStyle labelStyle;

  @override
  void paint(Canvas canvas, Size size) {
    const left = 32.0;
    const bottom = 8.0;
    const top = 10.0;
    final w = size.width - left - 12;
    final h = size.height - top - bottom;

    final rulePaint = Paint()
      ..color = rule
      ..strokeWidth = 1;
    for (final pct in [0.0, 0.5, 1.0]) {
      final y = top + h * (1 - pct);
      canvas.drawLine(Offset(left, y), Offset(size.width, y), rulePaint);
      final tp = TextPainter(
        text: TextSpan(text: '${(pct * 100).round()}%', style: labelStyle),
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(canvas, Offset(0, y - tp.height / 2));
    }

    if (values.isEmpty) return;

    Offset pt(int i) {
      final x = values.length == 1 ? left + w / 2 : left + w * i / (values.length - 1);
      return Offset(x, top + h * (1 - values[i].clamp(0.0, 1.0)));
    }

    final path = Path()..moveTo(pt(0).dx, pt(0).dy);
    for (var i = 1; i < values.length; i++) {
      path.lineTo(pt(i).dx, pt(i).dy);
    }
    canvas.drawPath(
      path,
      Paint()
        ..color = line
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.4
        ..strokeJoin = StrokeJoin.round,
    );

    final last = pt(values.length - 1);
    canvas.drawCircle(last, 11, Paint()..color = highlight);
    for (var i = 0; i < values.length; i++) {
      canvas.drawCircle(pt(i), 4, Paint()..color = line);
    }
  }

  @override
  bool shouldRepaint(_ChartPainter old) => old.values != values || old.line != line;
}

/// Horizontal bar for subject strength / chapter weightage.
class MeterRow extends StatelessWidget {
  const MeterRow({
    super.key,
    required this.label,
    required this.value,
    required this.color,
    this.trailing,
  });

  final String label;
  final double? value; // null = no data yet
  final Color color;
  final String? trailing;

  @override
  Widget build(BuildContext context) {
    final vc = context.vc;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          SizedBox(width: 112, child: Text(label, style: context.text.bodyMedium, maxLines: 1, overflow: TextOverflow.ellipsis)),
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(3),
              child: LinearProgressIndicator(
                value: value ?? 0,
                minHeight: 10,
                color: color,
                backgroundColor: vc.rule.withValues(alpha: 0.6),
              ),
            ),
          ),
          SizedBox(
            width: 52,
            child: Text(
              trailing ?? (value == null ? '—' : '${(value! * 100).round()}%'),
              textAlign: TextAlign.right,
              style: context.text.labelMedium,
            ),
          ),
        ],
      ),
    );
  }
}
