import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:ud_core/ud_core.dart';

/// Full-screen 4-digit PIN pad.
class PinPad extends StatefulWidget {
  const PinPad({super.key, required this.title, required this.onComplete, this.error});

  final String title;
  final String? error;

  /// Returns true if the PIN was accepted; false clears it and shakes.
  final Future<bool> Function(String pin) onComplete;

  @override
  State<PinPad> createState() => _PinPadState();
}

class _PinPadState extends State<PinPad> with SingleTickerProviderStateMixin {
  String _pin = '';
  late final _shake = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 380));

  @override
  void dispose() {
    _shake.dispose();
    super.dispose();
  }

  Future<void> _tap(String d) async {
    if (_pin.length >= 4) return;
    HapticFeedback.selectionClick();
    setState(() => _pin += d);
    if (_pin.length == 4) {
      final ok = await widget.onComplete(_pin);
      if (!mounted) return;
      if (!ok) {
        HapticFeedback.heavyImpact();
        _shake.forward(from: 0);
      }
      setState(() => _pin = '');
    }
  }

  void _back() {
    if (_pin.isEmpty) return;
    HapticFeedback.selectionClick();
    setState(() => _pin = _pin.substring(0, _pin.length - 1));
  }

  @override
  Widget build(BuildContext context) {
    final t = UdTokens.of(context);
    final text = Theme.of(context).textTheme;

    Widget key(String label, {VoidCallback? onTap, IconData? icon}) => Expanded(
          child: Padding(
            padding: const EdgeInsets.all(6),
            child: AspectRatio(
              aspectRatio: 1.5,
              child: label.isEmpty && icon == null
                  ? const SizedBox()
                  : UdPressable(
                      onTap: onTap ?? () => _tap(label),
                      borderRadius: 22,
                      child: Center(
                        child: icon != null
                            ? Icon(icon, color: t.ink)
                            : Text(label, style: text.headlineMedium),
                      ),
                    ),
            ),
          ),
        );

    return Column(
      children: [
        const Spacer(),
        Icon(Icons.lock_outline_rounded, size: 40, color: t.accent),
        const SizedBox(height: 18),
        Text(widget.title, style: text.headlineSmall, textAlign: TextAlign.center),
        const SizedBox(height: 24),
        AnimatedBuilder(
          animation: _shake,
          builder: (context, child) {
            final v = _shake.value;
            final dx = math.sin(v * math.pi * 6) * 10 * (1 - v);
            return Transform.translate(offset: Offset(dx, 0), child: child);
          },
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              for (var i = 0; i < 4; i++)
                AnimatedContainer(
                  duration: const Duration(milliseconds: 150),
                  margin: const EdgeInsets.symmetric(horizontal: 9),
                  width: 16,
                  height: 16,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: i < _pin.length ? t.accent : Colors.transparent,
                    border: Border.all(
                        color: i < _pin.length ? t.accent : t.inkFaint, width: 2),
                  ),
                ),
            ],
          ),
        ),
        SizedBox(
          height: 40,
          child: Center(
            child: widget.error == null
                ? null
                : Text(widget.error!,
                    style: text.bodyMedium?.copyWith(color: t.danger)),
          ),
        ),
        const Spacer(),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            children: [
              for (final row in const [
                ['1', '2', '3'],
                ['4', '5', '6'],
                ['7', '8', '9'],
              ])
                Row(children: [for (final d in row) key(d)]),
              Row(children: [
                key(''),
                key('0'),
                key('', icon: Icons.backspace_outlined, onTap: _back),
              ]),
            ],
          ),
        ),
        const SizedBox(height: 24),
      ],
    );
  }
}

/// Two-step "create then confirm" PIN flow. Pops with true when saved.
class SetPinPage extends StatefulWidget {
  const SetPinPage({super.key, required this.onSave});
  final Future<void> Function(String pin) onSave;

  @override
  State<SetPinPage> createState() => _SetPinPageState();
}

class _SetPinPageState extends State<SetPinPage> {
  String? _first;
  String? _error;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(backgroundColor: Colors.transparent, elevation: 0),
      body: SafeArea(
        child: PinPad(
          key: ValueKey(_first == null),
          title: context.tr(_first == null ? 'pin_set_title' : 'pin_confirm_title'),
          error: _error,
          onComplete: (pin) async {
            if (_first == null) {
              setState(() {
                _first = pin;
                _error = null;
              });
              return true;
            }
            if (pin == _first) {
              await widget.onSave(pin);
              if (context.mounted) Navigator.of(context).pop(true);
              return true;
            }
            setState(() {
              _first = null;
              _error = context.tr('pin_mismatch');
            });
            return false;
          },
        ),
      ),
    );
  }
}
