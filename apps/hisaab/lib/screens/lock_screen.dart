import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../store.dart';
import '../theme.dart';

/// First run: name + PIN (+ sample data choice). Later: unlock with the PIN.
class LockScreen extends StatefulWidget {
  const LockScreen({super.key});

  @override
  State<LockScreen> createState() => _LockScreenState();
}

class _LockScreenState extends State<LockScreen> {
  String _entry = '';
  String? _firstPin; // during setup: the PIN typed the first time
  String? _error;
  int _setupStep = 0; // 0 = name, 1 = pin
  final _name = TextEditingController();
  bool _sample = true;

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  void _press(String d) {
    if (_entry.length >= 4) return;
    HapticFeedback.selectionClick();
    setState(() {
      _error = null;
      _entry += d;
    });
    if (_entry.length == 4) _complete();
  }

  void _back() {
    if (_entry.isEmpty) return;
    setState(() => _entry = _entry.substring(0, _entry.length - 1));
  }

  void _complete() {
    final store = StoreScope.read(context);
    if (store.isSetUp) {
      if (!store.tryUnlock(_entry)) {
        HapticFeedback.heavyImpact();
        setState(() {
          _error = 'Wrong PIN. Try again.';
          _entry = '';
        });
      }
      return;
    }
    if (_firstPin == null) {
      setState(() {
        _firstPin = _entry;
        _entry = '';
      });
    } else if (_firstPin == _entry) {
      store.setUp(name: _name.text.trim(), pin: _entry, sample: _sample);
    } else {
      setState(() {
        _error = 'The PINs didn\'t match. Choose your PIN again.';
        _firstPin = null;
        _entry = '';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final store = context.store;
    final hc = context.hc;
    final setup = !store.isSetUp;

    if (setup && _setupStep == 0) {
      return Scaffold(
        body: SafeArea(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(24, 48, 24, 24),
            children: [
              Text('Hisaab', style: context.tt.displayLarge!.copyWith(color: hc.green)),
              const SizedBox(height: 8),
              Text(
                'Every account, bill, goal and investment in one passbook. Your data stays on this phone.',
                style: context.tt.bodyLarge!.copyWith(color: hc.muted),
              ),
              const SizedBox(height: 32),
              TextField(
                controller: _name,
                textCapitalization: TextCapitalization.words,
                decoration: const InputDecoration(labelText: 'Your first name'),
              ),
              const SizedBox(height: 16),
              Card(
                child: SwitchListTile(
                  value: _sample,
                  onChanged: (v) => setState(() => _sample = v),
                  title: Text('Start with sample data', style: context.tt.titleSmall),
                  subtitle: Text('See how Hisaab works with example accounts. Delete them any time from More → Reset.',
                      style: context.tt.bodySmall),
                ),
              ),
              const SizedBox(height: 24),
              FilledButton(
                onPressed: () {
                  if (_name.text.trim().isEmpty) {
                    setState(() => _error = 'Add your name to continue.');
                    return;
                  }
                  setState(() {
                    _error = null;
                    _setupStep = 1;
                  });
                },
                child: const Text('Continue'),
              ),
              if (_error != null) ...[
                const SizedBox(height: 10),
                Text(_error!, style: context.tt.bodyMedium!.copyWith(color: hc.spend)),
              ],
            ],
          ),
        ),
      );
    }

    final title = setup
        ? (_firstPin == null ? 'Choose a 4-digit PIN' : 'Type the PIN again')
        : 'Welcome back${store.name.isEmpty ? '' : ', ${store.name}'}';
    final sub = setup ? 'You\'ll use it to open Hisaab.' : 'Enter your PIN to unlock.';

    return Scaffold(
      backgroundColor: hc.band,
      body: SafeArea(
        child: Column(
          children: [
            const Spacer(flex: 2),
            Icon(Icons.lock_outline, color: hc.onBand, size: 32),
            const SizedBox(height: 12),
            Text(title, textAlign: TextAlign.center, style: context.tt.headlineSmall!.copyWith(color: hc.onBand)),
            const SizedBox(height: 6),
            Text(sub, style: context.tt.bodyMedium!.copyWith(color: hc.onBand.withValues(alpha: 0.75))),
            const SizedBox(height: 24),
            Semantics(
              label: '${_entry.length} of 4 digits entered',
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  for (var i = 0; i < 4; i++)
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 120),
                      margin: const EdgeInsets.symmetric(horizontal: 10),
                      width: 16,
                      height: 16,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: i < _entry.length ? hc.onBand : Colors.transparent,
                        border: Border.all(color: hc.onBand, width: 1.6),
                      ),
                    ),
                ],
              ),
            ),
            SizedBox(
              height: 40,
              child: Center(
                child: _error == null
                    ? null
                    : Text(_error!, style: context.tt.bodyMedium!.copyWith(color: const Color(0xFFFFC2B3))),
              ),
            ),
            const Spacer(),
            _Keypad(onDigit: _press, onBack: _back, color: hc.onBand),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }
}

class _Keypad extends StatelessWidget {
  const _Keypad({required this.onDigit, required this.onBack, required this.color});

  final ValueChanged<String> onDigit;
  final VoidCallback onBack;
  final Color color;

  @override
  Widget build(BuildContext context) {
    Widget key(String d) => SizedBox(
          width: 84,
          height: 68,
          child: TextButton(
            onPressed: () => onDigit(d),
            style: TextButton.styleFrom(foregroundColor: color, shape: const CircleBorder()),
            child: Text(d, style: money(context, 34, color: color)),
          ),
        );
    return Column(
      children: [
        for (final row in const [['1', '2', '3'], ['4', '5', '6'], ['7', '8', '9']])
          Row(mainAxisAlignment: MainAxisAlignment.center, children: [for (final d in row) key(d)]),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const SizedBox(width: 84, height: 68),
            key('0'),
            SizedBox(
              width: 84,
              height: 68,
              child: IconButton(
                tooltip: 'Delete digit',
                onPressed: onBack,
                icon: Icon(Icons.backspace_outlined, color: color),
              ),
            ),
          ],
        ),
      ],
    );
  }
}
