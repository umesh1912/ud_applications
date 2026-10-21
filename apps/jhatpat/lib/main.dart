import 'package:flutter/material.dart';

import 'screens/home_screen.dart';
import 'screens/other_screens.dart';
import 'store.dart';
import 'theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final store = await Store.load();
  runApp(JhatpatApp(store: store));
}

class JhatpatApp extends StatelessWidget {
  const JhatpatApp({super.key, required this.store});

  final Store store;

  @override
  Widget build(BuildContext context) {
    return StoreScope(
      store: store,
      child: MaterialApp(
        title: 'Jhatpat',
        debugShowCheckedModeBanner: false,
        theme: buildTheme(Brightness.light),
        darkTheme: buildTheme(Brightness.dark),
        home: const _Gate(),
      ),
    );
  }
}

class _Gate extends StatelessWidget {
  const _Gate();

  @override
  Widget build(BuildContext context) {
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 250),
      child: context.store.signedIn ? const Shell(key: ValueKey('shell')) : const SignInScreen(key: ValueKey('in')),
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
    final store = context.store;
    final unscratched = store.scratchCards.where((c) => !c.scratched).length;
    return Scaffold(
      body: IndexedStack(
        index: _tab,
        children: [
          HomeScreen(openTab: (i) => setState(() => _tab = i)),
          const HistoryScreen(),
          const RewardsScreen(),
          const AccountScreen(),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _tab,
        onDestinationSelected: (i) => setState(() => _tab = i),
        destinations: [
          const NavigationDestination(icon: Icon(Icons.bolt_outlined), selectedIcon: Icon(Icons.bolt), label: 'Pay'),
          const NavigationDestination(icon: Icon(Icons.receipt_long_outlined), selectedIcon: Icon(Icons.receipt_long), label: 'History'),
          NavigationDestination(
            icon: Badge(isLabelVisible: unscratched > 0, label: Text('$unscratched'), child: const Icon(Icons.card_giftcard_outlined)),
            selectedIcon: const Icon(Icons.card_giftcard),
            label: 'Rewards',
          ),
          const NavigationDestination(icon: Icon(Icons.person_outline), selectedIcon: Icon(Icons.person), label: 'Account'),
        ],
      ),
    );
  }
}
