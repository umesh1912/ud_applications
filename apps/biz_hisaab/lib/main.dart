import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:ud_core/ud_core.dart';

import 'business.dart';
import 'home.dart';
import 'items.dart';
import 'more.dart';
import 'parties.dart';
import 'strings.dart';
import 'txns.dart';
import 'ui.dart';

const appName = 'Hisaab';

void main() => runUdApp(UdAppSpec(
      name: appName,
      taglineKey: 'tagline',
      accent: const Color(0xFFB4235A),
      icon: Icons.receipt_long_rounded,
      strings: hisaabStrings,
      home: (_) => const Shell(),
    ));

class Shell extends StatefulWidget {
  const Shell({super.key});

  @override
  State<Shell> createState() => _ShellState();
}

class _ShellState extends State<Shell> {
  int _tab = 0;
  bool _unlocked = false;

  @override
  void initState() {
    super.initState();
    if (!db.loaded) db.load();
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: db,
      builder: (context, _) {
        if (!db.loaded) return const Scaffold(body: Center(child: CircularProgressIndicator()));
        if (!db.biz.isSetUp) return const BusinessPage(firstRun: true);
        if (db.biz.pin.isNotEmpty && !_unlocked) {
          return PinLock(onUnlock: () => setState(() => _unlocked = true));
        }
        final pages = [
          HomeTab(onTab: (i) => setState(() => _tab = i)),
          const TxnsTab(),
          const PartiesTab(),
          const ItemsTab(),
          const MoreTab(),
        ];
        return PopScope(
          canPop: _tab == 0,
          onPopInvokedWithResult: (didPop, _) {
            if (!didPop) setState(() => _tab = 0);
          },
          child: Scaffold(
            body: IndexedStack(index: _tab, children: pages),
            bottomNavigationBar: NavigationBar(
              selectedIndex: _tab,
              height: 68,
              backgroundColor: UdTokens.of(context).card,
              indicatorColor: UdTokens.of(context).accentSoft,
              onDestinationSelected: (i) {
                HapticFeedback.selectionClick();
                setState(() => _tab = i);
              },
              destinations: [
                NavigationDestination(icon: const Icon(Icons.space_dashboard_outlined), selectedIcon: const Icon(Icons.space_dashboard_rounded), label: context.tr('nav_home')),
                NavigationDestination(icon: const Icon(Icons.receipt_long_outlined), selectedIcon: const Icon(Icons.receipt_long_rounded), label: context.tr('nav_txns')),
                NavigationDestination(icon: const Icon(Icons.people_outline_rounded), selectedIcon: const Icon(Icons.people_rounded), label: context.tr('nav_parties')),
                NavigationDestination(icon: const Icon(Icons.inventory_2_outlined), selectedIcon: const Icon(Icons.inventory_2_rounded), label: context.tr('nav_items')),
                NavigationDestination(icon: const Icon(Icons.grid_view_outlined), selectedIcon: const Icon(Icons.grid_view_rounded), label: context.tr('nav_more')),
              ],
            ),
          ),
        );
      },
    );
  }
}

/// Asks for the 4-digit app PIN.
class PinLock extends StatefulWidget {
  const PinLock({super.key, required this.onUnlock});
  final VoidCallback onUnlock;

  @override
  State<PinLock> createState() => _PinLockState();
}

class _PinLockState extends State<PinLock> {
  String _entered = '';
  bool _wrong = false;

  void _tap(String d) {
    HapticFeedback.selectionClick();
    setState(() {
      _wrong = false;
      if (d == '<') {
        if (_entered.isNotEmpty) _entered = _entered.substring(0, _entered.length - 1);
        return;
      }
      if (_entered.length < 4) _entered += d;
    });
    if (_entered.length == 4) {
      if (_entered == db.biz.pin) {
        widget.onUnlock();
      } else {
        HapticFeedback.heavyImpact();
        setState(() {
          _entered = '';
          _wrong = true;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = UdTokens.of(context);
    final text = Theme.of(context).textTheme;
    return Scaffold(
      body: SafeArea(
        child: Column(children: [
          const Spacer(),
          Icon(Icons.lock_outline_rounded, size: 40, color: t.accent),
          const SizedBox(height: 16),
          Text(db.biz.name, style: text.headlineMedium),
          const SizedBox(height: 6),
          Text(_wrong ? context.tr('pin_wrong') : context.tr('pin_enter'),
              style: text.bodyMedium?.copyWith(color: _wrong ? t.danger : t.inkSoft)),
          const SizedBox(height: 24),
          Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            for (var i = 0; i < 4; i++)
              Container(
                margin: const EdgeInsets.symmetric(horizontal: 8),
                width: 16,
                height: 16,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: i < _entered.length ? t.accent : Colors.transparent,
                  border: Border.all(color: t.accent, width: 2),
                ),
              ),
          ]),
          const Spacer(),
          for (final row in const [['1', '2', '3'], ['4', '5', '6'], ['7', '8', '9'], ['', '0', '<']])
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 6),
              child: Row(children: [
                for (final d in row)
                  Expanded(
                    child: d.isEmpty
                        ? const SizedBox(height: 64)
                        : Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 6),
                            child: UdPressable(
                              onTap: () => _tap(d),
                              borderRadius: 32,
                              child: SizedBox(
                                height: 64,
                                child: Center(
                                  child: d == '<'
                                      ? const Icon(Icons.backspace_outlined)
                                      : Text(d, style: text.headlineMedium),
                                ),
                              ),
                            ),
                          ),
                  ),
              ]),
            ),
          const SizedBox(height: 24),
        ]),
      ),
    );
  }
}
