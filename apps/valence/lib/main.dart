import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'screens/auth/onboarding_screen.dart';
import 'screens/auth/welcome_screen.dart';
import 'screens/shell.dart';
import 'state/app_state.dart';
import 'theme/app_theme.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
  runApp(ValenceApp(state: AppState()));
}

class ValenceApp extends StatelessWidget {
  const ValenceApp({super.key, required this.state});

  final AppState state;

  @override
  Widget build(BuildContext context) {
    return AppScope(
      state: state,
      child: ListenableBuilder(
        listenable: state,
        builder: (context, _) => MaterialApp(
          title: 'Valence',
          debugShowCheckedModeBanner: false,
          theme: buildTheme(Brightness.light),
          darkTheme: buildTheme(Brightness.dark),
          themeMode: state.themeMode,
          home: _Gate(state: state),
        ),
      ),
    );
  }
}

/// Routes to sign-in → profile setup → app, based on state.
class _Gate extends StatelessWidget {
  const _Gate({required this.state});

  final AppState state;

  @override
  Widget build(BuildContext context) {
    final Widget child;
    if (!state.signedIn) {
      child = const WelcomeScreen(key: ValueKey('welcome'));
    } else if (!state.onboarded) {
      child = const OnboardingScreen(key: ValueKey('onboarding'));
    } else {
      child = const Shell(key: ValueKey('shell'));
    }
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 280),
      child: child,
    );
  }
}
