import 'dart:math';

import 'package:flutter/material.dart';

import 'data.dart';
import 'theme.dart';

// ── Formatting ───────────────────────────────────────────────────────
String _groupIndian(String d) {
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

String _groupWestern(String d) {
  final b = StringBuffer();
  for (var i = 0; i < d.length; i++) {
    if (i > 0 && (d.length - i) % 3 == 0) b.write(',');
    b.write(d[i]);
  }
  return b.toString();
}

String inr(num v, {bool paise = false}) {
  final n = v.abs();
  final whole = n.truncate();
  var s = '₹${_groupIndian(whole.toString())}';
  if (paise) s += '.${((n - whole) * 100).round().clamp(0, 99).toString().padLeft(2, '0')}';
  return v < 0 ? '−$s' : s;
}

String fx(num v, String code) {
  final c = currencyByCode(code);
  final n = v.abs();
  final whole = n.truncate();
  var s = _groupWestern(whole.toString());
  if (c.decimals > 0) s += '.${((n - whole) * 100).round().clamp(0, 99).toString().padLeft(2, '0')}';
  return '${v < 0 ? '−' : ''}$s $code';
}

String rateText(double inrPerUnit, String code) =>
    '1 $code = ₹${inrPerUnit.toStringAsFixed(inrPerUnit < 5 ? 4 : 2)}';

const _m = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
String shortDate(DateTime d) => '${d.day} ${_m[d.month - 1]}';
String dateTime(DateTime d) =>
    '${d.day} ${_m[d.month - 1]}, ${d.hour % 12 == 0 ? 12 : d.hour % 12}:${d.minute.toString().padLeft(2, '0')} ${d.hour < 12 ? 'am' : 'pm'}';

double? parseNum(String s) {
  final c = s.replaceAll(RegExp(r'[₹,\s]'), '');
  return c.isEmpty ? null : double.tryParse(c);
}

void toast(BuildContext context, String msg) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(msg)));
}

// ── Signature: airmail border ───────────────────────────────────────
/// Wraps content that is about to cross a border in the red–blue chevron
/// stripes of an airmail envelope.
class Airmail extends StatelessWidget {
  const Airmail({super.key, required this.child, this.padding = const EdgeInsets.all(18), this.stripe = 8});

  final Widget child;
  final EdgeInsetsGeometry padding;
  final double stripe;

  @override
  Widget build(BuildContext context) {
    final pc = context.pc;
    return CustomPaint(
      painter: _AirmailPainter(red: pc.red, blue: pc.blue, paper: pc.card, stripe: stripe),
      child: Padding(
        padding: EdgeInsets.all(stripe + 2),
        child: Container(
          decoration: BoxDecoration(color: pc.card, borderRadius: BorderRadius.circular(4)),
          padding: padding,
          child: child,
        ),
      ),
    );
  }
}

class _AirmailPainter extends CustomPainter {
  _AirmailPainter({required this.red, required this.blue, required this.paper, required this.stripe});

  final Color red;
  final Color blue;
  final Color paper;
  final double stripe;

  @override
  void paint(Canvas canvas, Size size) {
    final rr = RRect.fromRectAndRadius(Offset.zero & size, const Radius.circular(10));
    canvas.save();
    canvas.clipRRect(rr);
    canvas.drawRRect(rr, Paint()..color = paper);
    // diagonal stripes across the whole card; the inner panel covers the middle
    final w = stripe * 1.6;
    final diag = size.width + size.height;
    final paints = [Paint()..color = red, Paint()..color = paper, Paint()..color = blue, Paint()..color = paper];
    var i = 0;
    for (double x = -size.height; x < diag; x += w) {
      final p = Path()
        ..moveTo(x, 0)
        ..lineTo(x + w, 0)
        ..lineTo(x + w - size.height, size.height)
        ..lineTo(x - size.height, size.height)
        ..close();
      canvas.drawPath(p, paints[i % 4]);
      i++;
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(_AirmailPainter old) => old.red != red || old.blue != blue || old.paper != paper;
}

/// A round postmark showing a transfer's status.
class Postmark extends StatelessWidget {
  const Postmark({super.key, required this.label, required this.color, this.date, this.size = 74});

  final String label;
  final Color color;
  final DateTime? date;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'Status: $label',
      child: Transform.rotate(
        angle: -0.18,
        child: Container(
          width: size,
          height: size,
          decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: color, width: 2)),
          padding: const EdgeInsets.all(3),
          child: Container(
            decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: color, width: 1)),
            alignment: Alignment.center,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(label.toUpperCase(),
                    textAlign: TextAlign.center,
                    style: context.tt.labelSmall!.copyWith(color: color, fontSize: size * 0.12, letterSpacing: 0.6)),
                if (date != null)
                  Text(shortDate(date!), style: context.tt.labelSmall!.copyWith(color: color, fontSize: size * 0.11)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Clear "this is a demo" strip shown on money screens.
class DemoNote extends StatelessWidget {
  const DemoNote({super.key, this.text = 'Demo app: rates are simulated and no real money moves.'});

  final String text;

  @override
  Widget build(BuildContext context) {
    final pc = context.pc;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: pc.warn.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: pc.warn.withValues(alpha: 0.4)),
      ),
      child: Row(
        children: [
          Icon(Icons.science_outlined, size: 16, color: pc.warn),
          const SizedBox(width: 8),
          Expanded(child: Text(text, style: context.tt.bodySmall!.copyWith(color: pc.ink))),
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
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(onTap: onTap, child: Padding(padding: padding, child: child)),
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
      padding: const EdgeInsets.only(top: 24, bottom: 8),
      child: Row(
        children: [
          Expanded(child: Text(title, style: context.tt.headlineSmall)),
          if (action != null) TextButton(onPressed: onAction, child: Text(action!)),
        ],
      ),
    );
  }
}

class Flag extends StatelessWidget {
  const Flag(this.code, {super.key, this.size = 26});

  final String code;
  final double size;

  @override
  Widget build(BuildContext context) {
    final f = code == 'INR' ? '🇮🇳' : currencyByCode(code).flag;
    return Text(f, style: TextStyle(fontSize: size, height: 1.1));
  }
}

/// A key–value line in a price breakdown.
class Line extends StatelessWidget {
  const Line(this.label, this.value, {super.key, this.strong = false, this.hint, this.color});

  final String label;
  final String value;
  final bool strong;
  final String? hint;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: strong ? context.tt.titleSmall : context.tt.bodyMedium),
                if (hint != null) Text(hint!, style: context.tt.bodySmall),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Text(value,
              style: (strong ? context.tt.titleMedium : context.tt.bodyMedium)!.copyWith(color: color, fontFeatures: tabular)),
        ],
      ),
    );
  }
}

/// Vertical timeline of a transfer's steps.
class StepTimeline extends StatelessWidget {
  const StepTimeline({super.key, required this.transfer});

  final Transfer transfer;

  @override
  Widget build(BuildContext context) {
    final pc = context.pc;
    final step = transfer.step;
    return Column(
      children: [
        for (var k = 0; k < transferSteps.length; k++)
          IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                SizedBox(
                  width: 28,
                  child: Column(
                    children: [
                      Container(
                        width: 18,
                        height: 18,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: k <= step && !transfer.cancelled ? pc.blue : pc.card,
                          border: Border.all(color: k <= step && !transfer.cancelled ? pc.blue : pc.rule, width: 2),
                        ),
                        child: k <= step && !transfer.cancelled
                            ? Icon(Icons.check, size: 12, color: Theme.of(context).colorScheme.onPrimary)
                            : null,
                      ),
                      if (k < transferSteps.length - 1)
                        Expanded(child: Container(width: 2, color: k < step && !transfer.cancelled ? pc.blue : pc.rule)),
                    ],
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.only(bottom: 16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(transferSteps[k],
                            style: context.tt.titleSmall!.copyWith(color: k <= step && !transfer.cancelled ? pc.ink : pc.muted)),
                        if (k <= step && !transfer.cancelled)
                          Text(dateTime(transfer.stepTime(k)), style: context.tt.bodySmall)
                        else if (k == step + 1 && !transfer.cancelled)
                          Text('Next', style: context.tt.bodySmall),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

Color statusColor(BuildContext context, Transfer t) {
  final pc = context.pc;
  if (t.cancelled) return pc.muted;
  if (t.delivered) return pc.ok;
  return pc.blue;
}

String statusLabel(Transfer t) {
  if (t.cancelled) return 'Cancelled';
  if (t.delivered) return 'Delivered';
  return const ['Created', 'Paid', 'Converted', 'On its way', 'Delivered'][min(t.step, 4)];
}

Future<T?> showForm<T>(BuildContext context, Widget sheet) =>
    showModalBottomSheet<T>(context: context, isScrollControlled: true, builder: (_) => sheet);

class FormSheet extends StatelessWidget {
  const FormSheet({super.key, required this.title, required this.children, this.actions = const []});

  final String title;
  final List<Widget> children;
  final List<Widget> actions;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(title, style: context.tt.headlineSmall),
              const SizedBox(height: 14),
              ...children,
              if (actions.isNotEmpty) ...[const SizedBox(height: 18), ...actions],
            ],
          ),
        ),
      ),
    );
  }
}
