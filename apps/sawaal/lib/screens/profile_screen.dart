import 'package:flutter/material.dart';

import '../data/questions.dart';
import '../state.dart';
import '../theme.dart';
import '../widgets.dart';
import 'launcher.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final store = context.store;
    final p = store.active!;
    final sc = context.sc;
    final lang = store.lang;
    final accuracy = p.answered == 0 ? null : (p.correct / p.answered * 100).round();

    return Scaffold(
      appBar: AppBar(title: Text(store.t('My progress', 'मेरी प्रगति'))),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 32),
        children: [
          Row(
            children: [
              AvatarDot(profile: p, size: 64),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(p.name, style: context.tt.headlineMedium),
                    Text('${p.group.label.of(lang)} · ${store.t('Level ${p.level}', 'लेवल ${p.level}')}', style: context.tt.bodySmall),
                    Text(store.t('${250 - (p.xp % 250)} XP to the next level', 'अगले लेवल के लिए ${250 - (p.xp % 250)} XP'),
                        style: context.tt.bodySmall),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Pairs(
            children: [
              _Stat(value: '${p.answered}', label: store.t('Questions answered', 'जवाब दिए सवाल')),
              _Stat(value: accuracy == null ? '—' : '$accuracy%', label: store.t('Right answers', 'सही जवाब')),
              _Stat(value: '${p.streak}', label: store.t('Day streak', 'लगातार दिन')),
              _Stat(value: '${p.bestRapid}', label: store.t('Best rapid fire', 'सबसे अच्छा रैपिड फ़ायर')),
            ],
          ),
          Heading(store.t('Badges', 'बैज'), trailing: Text('${p.badges.length}/${badges.length}', style: context.tt.labelLarge)),
          Pairs(
            children: [
              for (final b in badges)
                Opacity(
                  opacity: p.badges.contains(b.id) ? 1 : 0.5,
                  child: Sticker(
                    depth: p.badges.contains(b.id) ? 3 : 0,
                    color: p.badges.contains(b.id) ? const Color(0xFFFFD23F) : null,
                    padding: const EdgeInsets.all(12),
                    semanticLabel: '${b.name.of(lang)}. ${p.badges.contains(b.id) ? 'Earned' : b.how.of(lang)}',
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(p.badges.contains(b.id) ? b.icon : Icons.lock_outline_rounded,
                            color: p.badges.contains(b.id) ? const Color(0xFF1C1B2E) : sc.ink),
                        const SizedBox(height: 6),
                        Text(b.name.of(lang),
                            style: context.tt.titleSmall!.copyWith(color: p.badges.contains(b.id) ? const Color(0xFF1C1B2E) : null)),
                        Text(b.how.of(lang),
                            style: context.tt.bodySmall!.copyWith(color: p.badges.contains(b.id) ? const Color(0xFF1C1B2E) : null)),
                      ],
                    ),
                  ),
                ),
            ],
          ),
          Heading(store.t('By topic', 'विषय के अनुसार')),
          Sticker(
            child: Column(
              children: [
                for (final c in Cat.values)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 5),
                    child: _TopicBar(
                      cat: c,
                      answered: p.catAnswered[c.name.en] ?? 0,
                      correct: p.catCorrect[c.name.en] ?? 0,
                    ),
                  ),
              ],
            ),
          ),
          Heading(store.t('Learn mode', 'सीखो मोड')),
          if (p.missed.isEmpty)
            Text(store.t('Questions you get wrong will appear here so you can practise them.',
                    'जो सवाल गलत होंगे वे यहाँ दिखेंगे ताकि आप उनका अभ्यास कर सकें।'),
                style: context.tt.bodyMedium)
          else
            BigButton(
              icon: Icons.school_rounded,
              label: store.t('Practise ${p.missed.length} missed questions', '${p.missed.length} छूटे सवालों का अभ्यास करें'),
              onTap: () => startQuiz(context, reviewPlay(store)),
            ),
        ],
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat({required this.value, required this.label});

  final String value;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Sticker(
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(value, style: context.tt.headlineMedium),
          Text(label, style: context.tt.bodySmall),
        ],
      ),
    );
  }
}

class _TopicBar extends StatelessWidget {
  const _TopicBar({required this.cat, required this.answered, required this.correct});

  final Cat cat;
  final int answered;
  final int correct;

  @override
  Widget build(BuildContext context) {
    final sc = context.sc;
    final lang = context.store.lang;
    final frac = answered == 0 ? 0.0 : correct / answered;
    return Row(
      children: [
        Icon(cat.icon, size: 20, color: sc.ink),
        const SizedBox(width: 8),
        SizedBox(width: 110, child: Text(cat.name.of(lang), maxLines: 1, overflow: TextOverflow.ellipsis, style: context.tt.bodyMedium)),
        Expanded(
          child: Container(
            height: 14,
            decoration: BoxDecoration(
              color: sc.bg,
              borderRadius: BorderRadius.circular(99),
              border: Border.all(color: sc.line, width: 1.6),
            ),
            child: FractionallySizedBox(
              alignment: Alignment.centerLeft,
              widthFactor: frac,
              child: Container(decoration: BoxDecoration(color: cat.color, borderRadius: BorderRadius.circular(99))),
            ),
          ),
        ),
        SizedBox(
          width: 52,
          child: Text(answered == 0 ? '—' : '${(frac * 100).round()}%', textAlign: TextAlign.right, style: context.tt.labelMedium),
        ),
      ],
    );
  }
}
