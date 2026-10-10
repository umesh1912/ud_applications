import 'package:flutter/material.dart';

import 'l10n.dart';
import 'theme.dart';
import 'widgets.dart';

/// Language tiles showing each language in its own script.
class UdLanguageChooser extends StatelessWidget {
  const UdLanguageChooser({super.key, required this.selected, required this.onSelect});
  final String selected;
  final ValueChanged<String> onSelect;

  @override
  Widget build(BuildContext context) {
    final t = UdTokens.of(context);
    final text = Theme.of(context).textTheme;
    return Column(
      children: [
        for (final l in udLanguages)
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: UdPressable(
              onTap: () => onSelect(l.code),
              color: l.code == selected ? t.accentSoft : t.card,
              borderRadius: 20,
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(l.nativeName, style: text.titleLarge),
                        if (l.nativeName != l.englishName)
                          Text(l.englishName,
                              style: text.bodySmall?.copyWith(color: t.inkSoft)),
                      ],
                    ),
                  ),
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 180),
                    width: 26,
                    height: 26,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: l.code == selected ? t.accent : Colors.transparent,
                      border: Border.all(
                          color: l.code == selected ? t.accent : t.line, width: 2),
                    ),
                    child: l.code == selected
                        ? Icon(Icons.check_rounded, size: 16, color: t.onAccent)
                        : null,
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }
}

Future<void> showUdSettings(BuildContext context, {required String appName, String version = '1.0.0'}) {
  return showUdSheet<void>(context, (c) => _SettingsBody(appName: appName, version: version));
}

class _SettingsBody extends StatelessWidget {
  const _SettingsBody({required this.appName, required this.version});
  final String appName;
  final String version;

  @override
  Widget build(BuildContext context) {
    final settings = context.udSettings;
    final t = UdTokens.of(context);
    final text = Theme.of(context).textTheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(context.tr('settings'), style: text.headlineMedium),
        const SizedBox(height: 20),
        UdLabel(context.tr('language')),
        UdLanguageChooser(
          selected: settings.lang,
          onSelect: (code) => settings.setLang(code),
        ),
        const SizedBox(height: 8),
        UdLabel(context.tr('appearance')),
        SizedBox(
          width: double.infinity,
          child: SegmentedButton<ThemeMode>(
            showSelectedIcon: false,
            segments: [
              ButtonSegment(
                  value: ThemeMode.system,
                  icon: const Icon(Icons.brightness_auto_rounded),
                  label: Text(context.tr('theme_system'))),
              ButtonSegment(
                  value: ThemeMode.light,
                  icon: const Icon(Icons.light_mode_rounded),
                  label: Text(context.tr('theme_light'))),
              ButtonSegment(
                  value: ThemeMode.dark,
                  icon: const Icon(Icons.dark_mode_rounded),
                  label: Text(context.tr('theme_dark'))),
            ],
            selected: {settings.themeMode},
            onSelectionChanged: (s) => settings.setThemeMode(s.first),
          ),
        ),
        const SizedBox(height: 24),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: t.paper,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: t.line),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(children: [
                Icon(Icons.lock_outline_rounded, size: 18, color: t.accent),
                const SizedBox(width: 8),
                Expanded(child: Text(context.tr('privacy_note'), style: text.bodyMedium)),
              ]),
              const SizedBox(height: 12),
              Text('$appName · ${context.tr('version')} $version',
                  style: text.bodySmall),
              Text(context.tr('made_in_india'), style: text.bodySmall),
            ],
          ),
        ),
      ],
    );
  }
}
