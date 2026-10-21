import 'package:flutter/material.dart';

import 'screens/account_screen.dart';
import 'screens/home_screen.dart';
import 'screens/onboarding.dart';
import 'screens/rates_screen.dart';
import 'screens/send_flow.dart';
import 'store.dart';
import 'theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final store = await Store.load();
  runApp(PulApp(store: store));
}

class PulApp extends StatelessWidget {
  const PulApp({super.key, required this.store});

  final Store store;

  @override
  Widget build(BuildContext context) {
    return StoreScope(
      store: store,
      child: MaterialApp(
        title: 'Pul',
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
    final store = context.store;
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 250),
      child: store.signedIn ? const Shell(key: ValueKey('shell')) : const SignInScreen(key: ValueKey('signin')),
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
      const ActivityScreen(),
      const RatesScreen(),
      const AccountScreen(),
    ];
    return Scaffold(
      body: IndexedStack(index: _tab, children: pages),
      floatingActionButton: _tab == 1
          ? FloatingActionButton.extended(
              onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const SendFlow())),
              icon: const Icon(Icons.flight_takeoff),
              label: const Text('Send'),
            )
          : null,
      bottomNavigationBar: NavigationBar(
        selectedIndex: _tab,
        onDestinationSelected: (i) => setState(() => _tab = i),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.home_outlined), selectedIcon: Icon(Icons.home), label: 'Home'),
          NavigationDestination(icon: Icon(Icons.local_post_office_outlined), selectedIcon: Icon(Icons.local_post_office), label: 'Activity'),
          NavigationDestination(icon: Icon(Icons.show_chart), label: 'Rates'),
          NavigationDestination(icon: Icon(Icons.person_outline), selectedIcon: Icon(Icons.person), label: 'Account'),
        ],
      ),
    );
  }
}
