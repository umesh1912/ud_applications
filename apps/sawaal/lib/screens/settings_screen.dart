import 'package:flutter/material.dart';

import '../data/questions.dart';
import '../state.dart';
import '../theme.dart';
import '../widgets.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final store = context.store;
    final s = store.settings;

    Widget toggle(String title, String sub, bool value, ValueChanged<bool> onChanged) => Padding(
          padding: const EdgeInsets.only(bottom: 6),
          child: Sticker(
            depth: 2,
            padding: const EdgeInsets.fromLTRB(16, 8, 8, 8),
            child: SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(title, style: context.tt.titleMedium),
              subtitle: Text(sub, style: context.tt.bodySmall),
              value: value,
              onChanged: (v) {
                onChanged(v);
                store.changed();
              },
            ),
          ),
        );

    return Scaffold(
      appBar: AppBar(title: Text(store.t('Settings', 'सेटिंग्स'))),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 32),
        children: [
          Heading(store.t('Language', 'भाषा')),
          _Segments(
            options: const ['English', 'हिन्दी'],
            selected: s.lang == 'hi' ? 1 : 0,
            onSelect: (i) {
              s.lang = i == 1 ? 'hi' : 'en';
              store.changed();
            },
          ),
          Heading(store.t('Text size', 'अक्षरों का आकार')),
          _Segments(
            options: [store.t('Normal', 'सामान्य'), store.t('Large', 'बड़ा'), store.t('Extra large', 'बहुत बड़ा')],
            selected: s.textSize,
            onSelect: (i) {
              s.textSize = i;
              store.changed();
            },
          ),
          Heading(store.t('Playing', 'खेलना')),
          toggle(store.t('Question timer', 'सवाल का टाइमर'),
              store.t('Turn off for relaxed play with no clock.', 'बिना घड़ी के आराम से खेलने के लिए बंद करें।'), s.timer, (v) => s.timer = v),
          toggle(store.t('Read questions aloud', 'सवाल पढ़कर सुनाएँ'),
              store.t('Uses your phone\'s voice. Helpful for young kids and older eyes.', 'फ़ोन की आवाज़ का उपयोग। छोटे बच्चों और बुज़ुर्गों के लिए मददगार।'),
              s.readAloud, (v) => s.readAloud = v),
          toggle(store.t('Explain each answer', 'हर जवाब समझाएँ'),
              store.t('Show a short fact after every question.', 'हर सवाल के बाद एक छोटा तथ्य दिखाएँ।'), s.explanations, (v) => s.explanations = v),
          toggle(store.t('High contrast', 'हाई कंट्रास्ट'),
              store.t('Black on white with thicker outlines.', 'मोटी रेखाओं के साथ सफ़ेद पर काला।'), s.highContrast, (v) => s.highContrast = v),
          Heading(store.t('Parent controls', 'अभिभावक नियंत्रण')),
          const _ParentControls(),
          Heading(store.t('Players on this phone', 'इस फ़ोन पर खिलाड़ी')),
          for (final p in store.profiles)
            Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Sticker(
                depth: 2,
                padding: const EdgeInsets.fromLTRB(12, 8, 4, 8),
                child: Row(
                  children: [
                    AvatarDot(profile: p, size: 36),
                    const SizedBox(width: 10),
                    Expanded(child: Text(p.name, style: context.tt.titleMedium)),
                    if (store.profiles.length > 1)
                      IconButton(
                        tooltip: store.t('Delete player', 'खिलाड़ी हटाएँ'),
                        icon: const Icon(Icons.delete_outline_rounded),
                        onPressed: () async {
                          if (!await askParentPin(context) || !context.mounted) return;
                          final ok = await showDialog<bool>(
                            context: context,
                            builder: (ctx) => AlertDialog(
                              title: Text(store.t('Delete ${p.name}?', '${p.name} को हटाएँ?')),
                              content: Text(store.t('Their coins, badges and progress will be removed.', 'उनके सिक्के, बैज और प्रगति हट जाएँगे।')),
                              actions: [
                                TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(store.t('Cancel', 'रद्द करें'))),
                                TextButton(onPressed: () => Navigator.pop(ctx, true), child: Text(store.t('Delete', 'हटाएँ'))),
                              ],
                            ),
                          );
                          if (ok == true) store.removeProfile(p);
                        },
                      ),
                  ],
                ),
              ),
            ),
          const SizedBox(height: 16),
          Text(
            store.t('Sawaal has no chat and no ads. Scores stay on this phone.', 'सवाल में कोई चैट और विज्ञापन नहीं है। स्कोर इसी फ़ोन पर रहते हैं।'),
            style: context.tt.bodySmall,
          ),
        ],
      ),
    );
  }
}

class _Segments extends StatelessWidget {
  const _Segments({required this.options, required this.selected, required this.onSelect});

  final List<String> options;
  final int selected;
  final ValueChanged<int> onSelect;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        for (var i = 0; i < options.length; i++) ...[
          Expanded(
            child: Sticker(
              depth: 3,
              color: i == selected ? const Color(0xFFFFD23F) : null,
              padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 4),
              onTap: () => onSelect(i),
              semanticLabel: i == selected ? '${options[i]}, selected' : options[i],
              child: Text(options[i],
                  textAlign: TextAlign.center,
                  style: context.tt.labelLarge!.copyWith(color: i == selected ? const Color(0xFF1C1B2E) : null)),
            ),
          ),
          if (i < options.length - 1) const SizedBox(width: 8),
        ],
      ],
    );
  }
}

class _ParentControls extends StatelessWidget {
  const _ParentControls();

  Future<void> _setPin(BuildContext context) async {
    final store = StoreScope.read(context);
    if (store.settings.parentPin != null && !await askParentPin(context)) return;
    if (!context.mounted) return;
    final ctrl = TextEditingController();
    String? error;
    final pin = await showDialog<String>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setS) => AlertDialog(
          title: Text(store.t('New parent PIN', 'नया अभिभावक पिन')),
          content: TextField(
            controller: ctrl,
            autofocus: true,
            obscureText: true,
            maxLength: 4,
            keyboardType: TextInputType.number,
            decoration: InputDecoration(hintText: store.t('4 digits', '4 अंक'), errorText: error, counterText: ''),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: Text(store.t('Cancel', 'रद्द करें'))),
            TextButton(
              onPressed: () {
                if (RegExp(r'^\d{4}$').hasMatch(ctrl.text)) {
                  Navigator.pop(ctx, ctrl.text);
                } else {
                  setS(() => error = store.t('Use exactly 4 digits.', 'ठीक 4 अंक डालें।'));
                }
              },
              child: Text(store.t('Save PIN', 'पिन सेव करें')),
            ),
          ],
        ),
      ),
    );
    if (pin != null) {
      store.settings.parentPin = pin;
      store.changed();
      if (context.mounted) toast(context, store.t('Parent PIN saved', 'अभिभावक पिन सेव हुआ'));
    }
  }

  @override
  Widget build(BuildContext context) {
    final store = context.store;
    final kids = store.profiles.where((p) => p.isKid).toList();
    final lang = store.lang;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SoftButton(
          icon: Icons.lock_outline_rounded,
          label: store.settings.parentPin == null ? store.t('Set a parent PIN', 'अभिभावक पिन बनाएँ') : store.t('Change parent PIN', 'अभिभावक पिन बदलें'),
          onTap: () => _setPin(context),
        ),
        const SizedBox(height: 4),
        Text(
          store.t('The PIN is needed to switch away from a kid\'s profile, extend play time or delete players.',
              'बच्चे की प्रोफ़ाइल से बदलने, खेलने का समय बढ़ाने या खिलाड़ी हटाने के लिए पिन ज़रूरी है।'),
          style: context.tt.bodySmall,
        ),
        if (kids.isEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 10),
            child: Text(store.t('Add a player in the Kids group to set a daily time limit.', 'रोज़ाना समय सीमा के लिए बच्चों के समूह में खिलाड़ी जोड़ें।'),
                style: context.tt.bodyMedium),
          ),
        for (final k in kids) ...[
          const SizedBox(height: 10),
          Sticker(
            depth: 2,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    AvatarDot(profile: k, size: 34),
                    const SizedBox(width: 10),
                    Expanded(child: Text(k.name, style: context.tt.titleMedium)),
                  ],
                ),
                const SizedBox(height: 8),
                Text(store.t('Daily play limit', 'रोज़ाना खेल सीमा'), style: context.tt.labelMedium),
                const SizedBox(height: 6),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    for (final m in const [15, 30, 45, 60, 0])
                      ChoiceChip(
                        label: Text(m == 0 ? store.t('No limit', 'कोई सीमा नहीं') : store.t('$m min', '$m मिनट')),
                        selected: (k.dailyLimitMin ?? 0) == m,
                        onSelected: (_) async {
                          if (!await askParentPin(context)) return;
                          k.dailyLimitMin = m == 0 ? null : m;
                          store.changed();
                        },
                      ),
                  ],
                ),
                const SizedBox(height: 10),
                Text(store.t('Report', 'रिपोर्ट'), style: context.tt.labelMedium),
                Text(
                  store.t(
                    'Played ${k.minutesUsedToday()} min today · ${k.answered} questions answered · '
                        '${k.answered == 0 ? 0 : (k.correct / k.answered * 100).round()}% right · ${k.streak}-day streak',
                    'आज ${k.minutesUsedToday()} मिनट खेले · ${k.answered} सवालों के जवाब · '
                        '${k.answered == 0 ? 0 : (k.correct / k.answered * 100).round()}% सही · ${k.streak} दिन लगातार',
                  ),
                  style: context.tt.bodyMedium,
                ),
                if (k.catAnswered.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    '${store.t('Favourite topic', 'पसंदीदा विषय')}: ${_fav(k, lang)}',
                    style: context.tt.bodySmall,
                  ),
                ],
              ],
            ),
          ),
        ],
      ],
    );
  }

  String _fav(Profile k, String lang) {
    final top = k.catAnswered.entries.reduce((a, b) => a.value >= b.value ? a : b).key;
    final cat = Cat.values.where((c) => c.name.en == top).firstOrNull;
    return cat?.name.of(lang) ?? top;
  }
}
