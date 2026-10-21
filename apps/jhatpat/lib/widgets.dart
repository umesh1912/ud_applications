import 'package:flutter/material.dart';

import 'data.dart';
import 'theme.dart';

String _group(String d) {
  if (d.length <= 3) return d;
  final last3 = d.substring(d.length - 3);
  var rest = d.substring(0, d.length - 3);
  final parts = <String>[];
  while (rest.length > 2) {
    parts.insert(0, rest.substring(rest.length - 2));
    rest = rest.substring(0, rest.length - 2);
  }
  if (rest.isNotEmpty) parts.insert(0, rest);
  return '${parts.join(',')},$last3';
}

String inr(num v) {
  final n = v.abs();
  final whole = n.truncate();
  final paise = ((n - whole) * 100).round();
  final s = '₹${_group(whole.toString())}${paise > 0 ? '.${paise.toString().padLeft(2, '0')}' : ''}';
  return v < 0 ? '−$s' : s;
}

const _m = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
String dMon(DateTime d) => '${d.day} ${_m[d.month - 1]}';
String dMonTime(DateTime d) =>
    '${d.day} ${_m[d.month - 1]}, ${d.hour % 12 == 0 ? 12 : d.hour % 12}:${d.minute.toString().padLeft(2, '0')} ${d.hour < 12 ? 'am' : 'pm'}';

String dueText(DateTime due, {bool expiry = false}) {
  final now = DateTime.now();
  final days = DateTime(due.year, due.month, due.day).difference(DateTime(now.year, now.month, now.day)).inDays;
  final what = expiry ? 'Expires' : 'Due';
  if (days < 0) return expiry ? 'Expired ${-days}d ago' : 'Overdue by ${-days}d';
  if (days == 0) return '$what today';
  if (days == 1) return '$what tomorrow';
  return '$what in $days days';
}

void toast(BuildContext context, String msg) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(msg)));
}

/// The signature component: a ticket. With a [bottom] stub it gets notched
/// sides and a perforated tear line, like a bus or cinema ticket.
class Ticket extends StatelessWidget {
  const Ticket({super.key, required this.top, this.bottom, this.color, this.onTap, this.highlight = false});

  final Widget top;
  final Widget? bottom;
  final Color? color;
  final VoidCallback? onTap;
  final bool highlight;

  @override
  Widget build(BuildContext context) {
    final jc = context.jc;
    final bg = color ?? (highlight ? jc.saffronSoft : jc.card);
    const r = Radius.circular(16);
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: const BorderRadius.all(r),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              decoration: BoxDecoration(
                color: bg,
                borderRadius: bottom == null ? const BorderRadius.all(r) : const BorderRadius.vertical(top: r),
              ),
              padding: const EdgeInsets.fromLTRB(18, 16, 18, 14),
              child: top,
            ),
            if (bottom != null) ...[
              SizedBox(height: 18, child: CustomPaint(painter: _PerfPainter(bg, jc.bg, jc.rule))),
              Container(
                decoration: BoxDecoration(color: bg, borderRadius: const BorderRadius.vertical(bottom: r)),
                padding: const EdgeInsets.fromLTRB(18, 4, 18, 14),
                child: bottom,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _PerfPainter extends CustomPainter {
  _PerfPainter(this.card, this.page, this.line);
  final Color card;
  final Color page;
  final Color line;

  @override
  void paint(Canvas canvas, Size size) {
    final mid = size.height / 2;
    canvas.drawRect(Offset.zero & size, Paint()..color = card);
    final notch = Paint()..color = page;
    canvas.drawCircle(Offset(0, mid), 9, notch);
    canvas.drawCircle(Offset(size.width, mid), 9, notch);
    final p = Paint()
      ..color = line
      ..strokeWidth = 1.6
      ..strokeCap = StrokeCap.round;
    for (double x = 18; x < size.width - 18; x += 9) {
      canvas.drawLine(Offset(x, mid), Offset(x + 4, mid), p);
    }
  }

  @override
  bool shouldRepaint(_PerfPainter old) => old.card != card || old.page != page || old.line != line;
}

/// Receipt paper with a torn zigzag bottom edge.
class Receipt extends StatelessWidget {
  const Receipt({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final jc = context.jc;
    return CustomPaint(
      painter: _ReceiptPainter(jc.card),
      child: Padding(padding: const EdgeInsets.fromLTRB(20, 20, 20, 30), child: child),
    );
  }
}

class _ReceiptPainter extends CustomPainter {
  _ReceiptPainter(this.color);
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    const tooth = 10.0;
    final path = Path()
      ..moveTo(0, 12)
      ..quadraticBezierTo(0, 0, 12, 0)
      ..lineTo(size.width - 12, 0)
      ..quadraticBezierTo(size.width, 0, size.width, 12)
      ..lineTo(size.width, size.height - tooth);
    var x = size.width;
    var up = false;
    while (x > 0) {
      x -= tooth;
      path.lineTo(x.clamp(0, size.width), up ? size.height - tooth : size.height);
      up = !up;
    }
    path
      ..lineTo(0, size.height - tooth)
      ..close();
    canvas.drawPath(path, Paint()..color = color);
  }

  @override
  bool shouldRepaint(_ReceiptPainter old) => old.color != color;
}

class KindIcon extends StatelessWidget {
  const KindIcon(this.kind, {super.key, this.size = 44});

  final Kind kind;
  final double size;

  @override
  Widget build(BuildContext context) {
    final jc = context.jc;
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(color: jc.saffronSoft, borderRadius: BorderRadius.circular(size * 0.3)),
      child: Icon(kind.icon, size: size * 0.52, color: jc.ink),
    );
  }
}

class Section extends StatelessWidget {
  const Section(this.title, {super.key, this.action, this.onAction});

  final String title;
  final String? action;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 24, bottom: 10),
      child: Row(
        children: [
          Expanded(child: Text(title, style: context.tt.headlineSmall)),
          if (action != null) TextButton(onPressed: onAction, child: Text(action!)),
        ],
      ),
    );
  }
}

class Paper extends StatelessWidget {
  const Paper({super.key, required this.child, this.padding = const EdgeInsets.all(16), this.onTap});

  final Widget child;
  final EdgeInsetsGeometry padding;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Card(clipBehavior: Clip.antiAlias, child: InkWell(onTap: onTap, child: Padding(padding: padding, child: child)));
  }
}

class KV extends StatelessWidget {
  const KV(this.k, this.v, {super.key, this.strong = false, this.color});

  final String k;
  final String v;
  final bool strong;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(child: Text(k, style: strong ? context.tt.titleSmall : context.tt.bodyMedium!.copyWith(color: context.jc.muted))),
          const SizedBox(width: 12),
          Flexible(
            child: Text(v,
                textAlign: TextAlign.right,
                style: (strong ? context.tt.titleMedium : context.tt.bodyMedium)!.copyWith(color: color, fontFeatures: tabular)),
          ),
        ],
      ),
    );
  }
}

class DemoNote extends StatelessWidget {
  const DemoNote({super.key});

  @override
  Widget build(BuildContext context) {
    return Text(
      'Demo app: bills and plans are sample data and no real payment is made.',
      textAlign: TextAlign.center,
      style: context.tt.bodySmall,
    );
  }
}

/// Scratch to reveal: drag a finger to clear the foil.
class ScratchArea extends StatefulWidget {
  const ScratchArea({super.key, required this.child, required this.onRevealed, this.size = 220});

  final Widget child;
  final VoidCallback onRevealed;
  final double size;

  @override
  State<ScratchArea> createState() => _ScratchAreaState();
}

class _ScratchAreaState extends State<ScratchArea> {
  final List<Offset> _points = [];
  final Set<int> _cells = {};
  bool _done = false;

  void _add(Offset p) {
    if (_done) return;
    setState(() => _points.add(p));
    final s = widget.size;
    const grid = 8;
    final cx = (p.dx / s * grid).floor().clamp(0, grid - 1);
    final cy = (p.dy / s * grid).floor().clamp(0, grid - 1);
    _cells.add(cy * grid + cx);
    if (_cells.length > grid * grid * 0.45) {
      setState(() => _done = true);
      widget.onRevealed();
    }
  }

  @override
  Widget build(BuildContext context) {
    final jc = context.jc;
    return SizedBox(
      width: widget.size,
      height: widget.size,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(18),
        child: Stack(
          fit: StackFit.expand,
          children: [
            widget.child,
            if (!_done)
              Semantics(
                button: true,
                label: 'Scratch card. Drag to scratch, or double tap to reveal.',
                child: GestureDetector(
                  onPanStart: (d) => _add(d.localPosition),
                  onPanUpdate: (d) => _add(d.localPosition),
                  onDoubleTap: () {
                    setState(() => _done = true);
                    widget.onRevealed();
                  },
                  child: CustomPaint(painter: _FoilPainter(_points, jc.saffron, jc.onSaffron)),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _FoilPainter extends CustomPainter {
  _FoilPainter(this.points, this.foil, this.ink);
  final List<Offset> points;
  final Color foil;
  final Color ink;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.saveLayer(Offset.zero & size, Paint());
    canvas.drawRect(Offset.zero & size, Paint()..color = foil);
    // pattern so it reads as foil
    final dots = Paint()..color = ink.withValues(alpha: 0.12);
    for (double y = 10; y < size.height; y += 18) {
      for (double x = (y ~/ 18).isEven ? 10 : 19; x < size.width; x += 18) {
        canvas.drawCircle(Offset(x, y), 2.2, dots);
      }
    }
    final tp = TextPainter(
      text: TextSpan(text: 'Scratch here', style: TextStyle(color: ink, fontSize: 18, fontWeight: FontWeight.w800)),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(canvas, Offset((size.width - tp.width) / 2, (size.height - tp.height) / 2));
    final clear = Paint()
      ..blendMode = BlendMode.clear
      ..strokeWidth = 38
      ..strokeCap = StrokeCap.round;
    for (var i = 0; i < points.length; i++) {
      canvas.drawCircle(points[i], 19, clear);
      if (i > 0 && (points[i] - points[i - 1]).distance < 60) canvas.drawLine(points[i - 1], points[i], clear);
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(_FoilPainter old) => true;
}

Future<T?> showForm<T>(BuildContext context, Widget sheet) =>
    showModalBottomSheet<T>(context: context, isScrollControlled: true, builder: (_) => sheet);
