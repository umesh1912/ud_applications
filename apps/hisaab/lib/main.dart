import 'package:flutter/material.dart';

import 'screens/home_screen.dart';
import 'screens/lock_screen.dart';
import 'screens/more_screen.dart';
import 'screens/passbook_screen.dart';
import 'screens/plan_screen.dart';
import 'screens/txn_sheet.dart';
import 'screens/wealth_screen.dart';
import 'store.dart';
import 'theme.dart';
import 'widgets.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final store = await Store.load();
  runApp(HisaabApp(store: store));
}

class HisaabApp extends StatefulWidget {
  const HisaabApp({super.key, required this.store});

  final Store store;

  @override
  State<HisaabApp> createState() => _HisaabAppState();
}

class _HisaabAppState extends State<HisaabApp> with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused) widget.store.onPaused();
    if (state == AppLifecycleState.resumed) widget.store.onResumed();
  }

  @override
  Widget build(BuildContext context) {
    final store = widget.store;
    return StoreScope(
      store: store,
      child: ListenableBuilder(
        listenable: store,
        builder: (context, _) => MaterialApp(
          title: 'Hisaab',
          debugShowCheckedModeBanner: false,
          theme: buildTheme(Brightness.light),
          darkTheme: buildTheme(Brightness.dark),
          home: AnimatedSwitcher(
            duration: const Duration(milliseconds: 250),
            child: store.unlocked ? const Shell(key: ValueKey('shell')) : const LockScreen(key: ValueKey('lock')),
          ),
        ),
      ),
    );
  }
}

class Shell extends StatefulWidget {
  const Shell({super.key});

  @override
  State<Shell> createState() => _ShellState();
}

class _ShellState extends State<Shell> {
  int _tab = 0;

  @override
  Widget build(BuildContext context) {
    final pages = [
      HomeScreen(openTab: (i) => setState(() => _tab = i)),
      const PassbookScreen(),
      const PlanScreen(),
      const WealthScreen(),
      const MoreScreen(),
    ];
    return Scaffold(
      body: IndexedStack(index: _tab, children: pages),
      floatingActionButton: _tab <= 1
          ? FloatingActionButton.extended(
              onPressed: () => showForm(context, const TxnSheet()),
              icon: const Icon(Icons.add),
              label: const Text('Add entry'),
            )
          : null,
      bottomNavigationBar: NavigationBar(
        selectedIndex: _tab,
        onDestinationSelected: (i) => setState(() => _tab = i),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.space_dashboard_outlined), selectedIcon: Icon(Icons.space_dashboard), label: 'Home'),
          NavigationDestination(icon: Icon(Icons.menu_book_outlined), selectedIcon: Icon(Icons.menu_book), label: 'Passbook'),
          NavigationDestination(icon: Icon(Icons.event_note_outlined), selectedIcon: Icon(Icons.event_note), label: 'Plan'),
          NavigationDestination(icon: Icon(Icons.trending_up_outlined), selectedIcon: Icon(Icons.trending_up), label: 'Wealth'),
          NavigationDestination(icon: Icon(Icons.more_horiz), label: 'More'),
        ],
      ),
    );
  }
}
