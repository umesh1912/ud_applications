import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import 'l10n.dart';
import 'settings.dart';
import 'settings_sheet.dart';
import 'theme.dart';
import 'widgets.dart';

/// Describes one app of the UD family.
class UdAppSpec {
  const UdAppSpec({
    required this.name,
    required this.taglineKey,
    required this.accent,
    required this.icon,
    required this.strings,
    required this.home,
  });

  /// Brand name, shown untranslated.
  final String name;

  /// Translation key for the one-line promise shown on the welcome screen.
  final String taglineKey;
  final Color accent;
  final IconData icon;
  final UdStringTable strings;
  final WidgetBuilder home;
}

Future<void> runUdApp(UdAppSpec spec) async {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    systemNavigationBarColor: Colors.transparent,
  ));
  SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
  final settings = await UdSettings.load();
  runApp(UdApp(spec: spec, settings: settings));
}

class UdApp extends StatelessWidget {
  const UdApp({super.key, required this.spec, required this.settings});
  final UdAppSpec spec;
  final UdSettings settings;

  @override
  Widget build(BuildContext context) {
    final table = mergeStrings([udCoreStrings, spec.strings]);
    return UdScope(
      settings: settings,
      child: ListenableBuilder(
        listenable: settings,
        builder: (context, _) {
          final lang = settings.lang;
          return MaterialApp(
            title: spec.name,
            debugShowCheckedModeBanner: false,
            themeMode: settings.themeMode,
            theme: UdTheme.build(
                accent: spec.accent, brightness: Brightness.light, lang: lang),
            darkTheme: UdTheme.build(
                accent: spec.accent, brightness: Brightness.dark, lang: lang),
            locale: Locale(lang),
            supportedLocales: [for (final l in udLanguages) Locale(l.code)],
            localizationsDelegates: const [
              GlobalMaterialLocalizations.delegate,
              GlobalWidgetsLocalizations.delegate,
              GlobalCupertinoLocalizations.delegate,
            ],
            builder: (context, child) => UdL10n(
              lang: lang,
              table: table,
              child: child ?? const SizedBox.shrink(),
            ),
            home: settings.hasChosenLanguage
                ? Builder(builder: spec.home)
                : _Welcome(spec: spec),
          );
        },
      ),
    );
  }
}

/// First-run screen: brand, promise and language choice in one step.
class _Welcome extends StatefulWidget {
  const _Welcome({required this.spec});
  final UdAppSpec spec;

  @override
  State<_Welcome> createState() => _WelcomeState();
}

class _WelcomeState extends State<_Welcome> {
  late String _lang = UdScope.of(context).lang;

  @override
  Widget build(BuildContext context) {
    final t = UdTokens.of(context);
    final text = Theme.of(context).textTheme;
    final l10n = UdL10n.of(context);
    String tr(String k) => l10n.table[_lang]?[k] ?? l10n.t(k);

    return Scaffold(
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(24, 32, 24, 24),
          children: [
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                color: t.accent,
                borderRadius: BorderRadius.circular(24),
              ),
              child: Icon(widget.spec.icon, color: t.onAccent, size: 36),
            ),
            const SizedBox(height: 28),
            Text(widget.spec.name, style: text.displayMedium),
            const SizedBox(height: 10),
            Text(tr(widget.spec.taglineKey),
                style: text.titleLarge?.copyWith(
                    color: t.inkSoft, fontWeight: FontWeight.w400)),
            const SizedBox(height: 36),
            Text(tr('choose_language'), style: text.headlineSmall),
            const SizedBox(height: 4),
            Text(tr('choose_language_sub'),
                style: text.bodyMedium?.copyWith(color: t.inkSoft)),
            const SizedBox(height: 18),
            UdLanguageChooser(
              selected: _lang,
              onSelect: (c) => setState(() => _lang = c),
            ),
            const SizedBox(height: 20),
            FilledButton(
              onPressed: () => UdScope.of(context).setLang(_lang),
              child: Text(tr('continue')),
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.lock_outline_rounded, size: 16, color: t.inkFaint),
                const SizedBox(width: 6),
                Flexible(
                  child: Text(tr('privacy_note'),
                      textAlign: TextAlign.center,
                      style: text.bodySmall?.copyWith(color: t.inkFaint)),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// Standard settings button for page headers.
class UdSettingsButton extends StatelessWidget {
  const UdSettingsButton({super.key, required this.appName});
  final String appName;

  @override
  Widget build(BuildContext context) => UdIconButton(
        icon: Icons.tune_rounded,
        tooltip: context.tr('settings'),
        onTap: () => showUdSettings(context, appName: appName),
      );
}
