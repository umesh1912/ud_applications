import 'dart:ui' show FontFeature;

import 'package:flutter/material.dart';

import 'state.dart';
import 'theme.dart';

/// The core component: a card with a thick outline and a hard offset shadow.
/// When tappable it sinks into its shadow while pressed.
class Sticker extends StatefulWidget {
  const Sticker({
    super.key,
    required this.child,
    this.color,
    this.onTap,
    this.padding = const EdgeInsets.all(16),
    this.radius = 20,
    this.depth = 4,
    this.semanticLabel,
  });

  final Widget child;
  final Color? color;
  final VoidCallback? onTap;
  final EdgeInsetsGeometry padding;
  final double radius;
  final double depth;
  final String? semanticLabel;

  @override
  State<Sticker> createState() => _StickerState();
}

class _StickerState extends State<Sticker> {
  bool _down = false;

  @override
  Widget build(BuildContext context) {
    final sc = context.sc;
    final enabled = widget.onTap != null;
    final d = _down ? 1.0 : widget.depth;
    final box = AnimatedContainer(
      duration: const Duration(milliseconds: 90),
      curve: Curves.easeOut,
      transform: Matrix4.translationValues(0, widget.depth - d, 0),
      padding: widget.padding,
      decoration: BoxDecoration(
        color: widget.color ?? sc.card,
        borderRadius: BorderRadius.circular(widget.radius),
        border: Border.all(color: sc.line, width: sc.lineWidth),
        boxShadow: [BoxShadow(color: sc.shadow, offset: Offset(0, d), blurRadius: 0)],
      ),
      child: widget.child,
    );
    if (!enabled) return Padding(padding: EdgeInsets.only(bottom: widget.depth), child: box);
    return Semantics(
      button: true,
      label: widget.semanticLabel,
      child: Padding(
        padding: EdgeInsets.only(bottom: widget.depth),
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTapDown: (_) => setState(() => _down = true),
          onTapCancel: () => setState(() => _down = false),
          onTapUp: (_) => setState(() => _down = false),
          onTap: widget.onTap,
          child: box,
        ),
      ),
    );
  }
}

/// Primary call to action: a tangerine sticker with a label.
class BigButton extends StatelessWidget {
  const BigButton({super.key, required this.label, required this.onTap, this.icon, this.color});

  final String label;
  final VoidCallback? onTap;
  final IconData? icon;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final sc = context.sc;
    final disabled = onTap == null;
    return Opacity(
      opacity: disabled ? 0.5 : 1,
      child: Sticker(
        color: color ?? sc.primary,
        onTap: onTap,
        radius: 18,
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.max,
          children: [
            if (icon != null) ...[Icon(icon, color: sc.onPrimary), const SizedBox(width: 8)],
            Flexible(
              child: Text(label,
                  textAlign: TextAlign.center,
                  style: context.tt.labelLarge!.copyWith(color: color == null ? sc.onPrimary : const Color(0xFF1C1B2E))),
            ),
          ],
        ),
      ),
    );
  }
}

/// Secondary action: white sticker.
class SoftButton extends StatelessWidget {
  const SoftButton({super.key, required this.label, required this.onTap, this.icon});

  final String label;
  final VoidCallback? onTap;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    return Sticker(
      onTap: onTap,
      radius: 18,
      depth: 3,
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          if (icon != null) ...[Icon(icon, size: 20, color: context.sc.ink), const SizedBox(width: 8)],
          Flexible(child: Text(label, textAlign: TextAlign.center, style: context.tt.labelLarge)),
        ],
      ),
    );
  }
}

class AvatarDot extends StatelessWidget {
  const AvatarDot({super.key, required this.profile, this.size = 44});

  final Profile profile;
  final double size;

  @override
  Widget build(BuildContext context) {
    final a = profile.avatarData;
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: a.color,
        shape: BoxShape.circle,
        border: Border.all(color: context.sc.line, width: context.sc.lineWidth),
      ),
      child: Icon(a.icon, size: size * 0.5, color: const Color(0xFF1C1B2E)),
    );
  }
}

class CoinPill extends StatelessWidget {
  const CoinPill({super.key, required this.coins});

  final int coins;

  @override
  Widget build(BuildContext context) {
    final sc = context.sc;
    return Semantics(
      label: '$coins coins',
      child: Container(
        padding: const EdgeInsets.fromLTRB(6, 4, 12, 4),
        decoration: BoxDecoration(
          color: const Color(0xFFFFD23F),
          borderRadius: BorderRadius.circular(99),
          border: Border.all(color: sc.line, width: 2),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 22,
              height: 22,
              decoration: BoxDecoration(
                color: const Color(0xFFFFB13B),
                shape: BoxShape.circle,
                border: Border.all(color: sc.line, width: 1.6),
              ),
              alignment: Alignment.center,
              child: const Text('₹', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w900, color: Color(0xFF1C1B2E))),
            ),
            const SizedBox(width: 6),
            Text('$coins',
                style: context.tt.labelLarge!.copyWith(
                  color: const Color(0xFF1C1B2E),
                  fontFeatures: const [FontFeature.tabularFigures()],
                )),
          ],
        ),
      ),
    );
  }
}

class Heading extends StatelessWidget {
  const Heading(this.text, {super.key, this.trailing});

  final String text;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 22, bottom: 10),
      child: Row(
        children: [
          Expanded(child: Text(text, style: context.tt.headlineSmall)),
          if (trailing != null) trailing!,
        ],
      ),
    );
  }
}

class IconBlob extends StatelessWidget {
  const IconBlob({super.key, required this.icon, required this.color, this.size = 48});

  final IconData icon;
  final Color color;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(size * 0.32),
        border: Border.all(color: context.sc.line, width: 2),
      ),
      child: Icon(icon, size: size * 0.55, color: const Color(0xFF1C1B2E)),
    );
  }
}

void toast(BuildContext context, String msg) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(msg)));
}

/// Asks for the parent PIN. Returns true if correct (or no PIN set).
Future<bool> askParentPin(BuildContext context) async {
  final store = StoreScope.read(context);
  final pin = store.settings.parentPin;
  if (pin == null) return true;
  final ctrl = TextEditingController();
  String? error;
  final ok = await showDialog<bool>(
    context: context,
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, setS) => AlertDialog(
        title: Text(store.t('Parent PIN', 'अभिभावक पिन')),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          obscureText: true,
          maxLength: 4,
          keyboardType: TextInputType.number,
          decoration: InputDecoration(
            hintText: store.t('4-digit PIN', '4 अंकों का पिन'),
            errorText: error,
            counterText: '',
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(store.t('Cancel', 'रद्द करें'))),
          TextButton(
            onPressed: () {
              if (ctrl.text == pin) {
                Navigator.pop(ctx, true);
              } else {
                setS(() => error = store.t('That PIN is wrong. Try again.', 'पिन गलत है। फिर से कोशिश करें।'));
              }
            },
            child: Text(store.t('Unlock', 'खोलें')),
          ),
        ],
      ),
    ),
  );
  return ok ?? false;
}

/// Two-column layout whose rows grow with their content (safe at large text
/// sizes, unlike a fixed-ratio grid).
class Pairs extends StatelessWidget {
  const Pairs({super.key, required this.children, this.gap = 12});

  final List<Widget> children;
  final double gap;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        for (var i = 0; i < children.length; i += 2)
          Padding(
            padding: EdgeInsets.only(bottom: i + 2 < children.length ? gap / 2 : 0),
            child: IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Expanded(child: children[i]),
                  SizedBox(width: gap),
                  Expanded(child: i + 1 < children.length ? children[i + 1] : const SizedBox()),
                ],
              ),
            ),
          ),
      ],
    );
  }
}
