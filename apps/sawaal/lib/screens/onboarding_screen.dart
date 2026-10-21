import 'package:flutter/material.dart';

import '../state.dart';
import '../theme.dart';
import '../widgets.dart';

/// Create a player: language → name, age group, avatar.
/// The same screen adds extra players later (family sharing one phone).
class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key, this.addingPlayer = false});

  final bool addingPlayer;

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final _name = TextEditingController();
  AgeGroup? _group;
  int _avatar = 0;
  String? _error;

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  void _create() {
    final store = StoreScope.read(context);
    if (_name.text.trim().isEmpty) {
      setState(() => _error = store.t('Type a name to show on scores.', 'स्कोर पर दिखाने के लिए नाम लिखें।'));
      return;
    }
    if (_group == null) {
      setState(() => _error = store.t('Pick an age group so the questions fit.', 'आयु समूह चुनें ताकि सवाल सही स्तर के हों।'));
      return;
    }
    store.addProfile(_name.text.trim(), _group!, _avatar);
    if (widget.addingPlayer) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final store = context.store;
    final sc = context.sc;
    final lang = store.lang;

    return Scaffold(
      appBar: widget.addingPlayer ? AppBar(title: Text(store.t('New player', 'नया खिलाड़ी'))) : null,
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
          children: [
            if (!widget.addingPlayer) ...[
              Row(
                children: [
                  Transform.rotate(
                    angle: -0.08,
                    child: Sticker(
                      color: sc.primary,
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                      child: Text('Sawaal', style: context.tt.displayMedium!.copyWith(color: const Color(0xFF1C1B2E))),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Transform.rotate(
                    angle: 0.12,
                    child: const Sticker(
                      color: Color(0xFFFFD23F),
                      padding: EdgeInsets.symmetric(horizontal: 12, vertical: 2),
                      child: Text('?', style: TextStyle(fontSize: 44, fontWeight: FontWeight.w900, color: Color(0xFF1C1B2E))),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              Text(
                store.t('General knowledge quizzes for everyone — kids, students, parents and grandparents.',
                    'सबके लिए सामान्य ज्ञान क्विज़ — बच्चे, विद्यार्थी, माता-पिता और दादा-दादी।'),
                style: context.tt.bodyLarge,
              ),
              Heading(store.t('Language', 'भाषा')),
              Row(
                children: [
                  for (final (code, label) in const [('en', 'English'), ('hi', 'हिन्दी')]) ...[
                    Expanded(
                      child: Sticker(
                        depth: 3,
                        color: lang == code ? const Color(0xFFFFD23F) : null,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        onTap: () {
                          store.settings.lang = code;
                          store.changed();
                        },
                        semanticLabel: lang == code ? '$label, selected' : label,
                        child: Text(label,
                            textAlign: TextAlign.center,
                            style: context.tt.titleLarge!.copyWith(color: lang == code ? const Color(0xFF1C1B2E) : null)),
                      ),
                    ),
                    if (code == 'en') const SizedBox(width: 12),
                  ],
                ],
              ),
            ],
            Heading(store.t('Player name', 'खिलाड़ी का नाम')),
            TextField(
              controller: _name,
              textCapitalization: TextCapitalization.words,
              style: context.tt.titleLarge,
              decoration: InputDecoration(hintText: store.t('e.g. Aarav', 'जैसे आरव')),
            ),
            Heading(store.t('Age group', 'आयु समूह')),
            for (final g in AgeGroup.values)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Sticker(
                  depth: 3,
                  color: _group == g ? const Color(0xFF7BD957) : null,
                  onTap: () => setState(() => _group = g),
                  semanticLabel: _group == g ? '${g.label.of(lang)}, selected' : g.label.of(lang),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(g.label.of(lang),
                            style: context.tt.titleMedium!.copyWith(color: _group == g ? const Color(0xFF1C1B2E) : null)),
                      ),
                      if (_group == g) const Icon(Icons.check_circle_rounded, color: Color(0xFF1C1B2E)),
                    ],
                  ),
                ),
              ),
            if (_group == AgeGroup.kids)
              Text(
                store.t('Kids get easier questions, no chat, and a 30-minute daily limit you can change in Settings.',
                    'बच्चों को आसान सवाल मिलते हैं, कोई चैट नहीं, और 30 मिनट की रोज़ाना सीमा जिसे सेटिंग्स में बदल सकते हैं।'),
                style: context.tt.bodySmall,
              ),
            Heading(store.t('Pick a sticker', 'स्टिकर चुनें')),
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                for (var i = 0; i < avatars.length; i++)
                  Semantics(
                    button: true,
                    selected: _avatar == i,
                    label: 'Avatar ${i + 1}',
                    child: GestureDetector(
                      onTap: () => setState(() => _avatar = i),
                      child: Container(
                        width: 58,
                        height: 58,
                        decoration: BoxDecoration(
                          color: avatars[i].color,
                          shape: BoxShape.circle,
                          border: Border.all(color: sc.line, width: _avatar == i ? 4 : 2),
                          boxShadow: _avatar == i ? [BoxShadow(color: sc.shadow, offset: const Offset(0, 3))] : null,
                        ),
                        child: Icon(avatars[i].icon, color: const Color(0xFF1C1B2E)),
                      ),
                    ),
                  ),
              ],
            ),
            if (_error != null) ...[
              const SizedBox(height: 14),
              Text(_error!, style: context.tt.titleSmall!.copyWith(color: sc.wrong)),
            ],
            const SizedBox(height: 22),
            BigButton(
              label: widget.addingPlayer ? store.t('Add player', 'खिलाड़ी जोड़ें') : store.t('Let\'s play', 'चलो खेलें'),
              icon: Icons.play_arrow_rounded,
              onTap: _create,
            ),
          ],
        ),
      ),
    );
  }
}
