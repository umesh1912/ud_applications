import 'package:flutter/material.dart';

import 'screens/home_screen.dart';
import 'screens/onboarding_screen.dart';
import 'state.dart';
import 'theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final store = await Store.load();
  runApp(SawaalApp(store: store));
}

class SawaalApp extends StatelessWidget {
  const SawaalApp({super.key, required this.store});

  final Store store;

  @override
  Widget build(BuildContext context) {
    return StoreScope(
      store: store,
      child: ListenableBuilder(
        listenable: store,
        builder: (context, _) {
          final hc = store.settings.highContrast;
          return MaterialApp(
            title: 'Sawaal',
            debugShowCheckedModeBanner: false,
            theme: buildTheme(Brightness.light, highContrast: hc),
            darkTheme: buildTheme(Brightness.dark, highContrast: hc),
            themeMode: hc ? ThemeMode.light : ThemeMode.system,
            builder: (context, child) {
              final mq = MediaQuery.of(context);
              final scale = mq.textScaler.scale(1) * store.settings.textScale;
              return MediaQuery(
                data: mq.copyWith(textScaler: TextScaler.linear(scale.clamp(0.8, 2.2))),
                child: child!,
              );
            },
            home: store.profiles.isEmpty ? const OnboardingScreen() : const HomeScreen(),
          );
        },
      ),
    );
  }
}
