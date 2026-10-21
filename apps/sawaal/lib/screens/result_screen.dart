import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../data/questions.dart';
import '../state.dart';
import '../theme.dart';
import '../widgets.dart';
import 'quiz_screen.dart';

class ResultScreen extends StatelessWidget {
  const ResultScreen({super.key, required this.result, required this.rewards, required this.config, this.banner});

  final GameResult result;
  final RewardSummary rewards;
  final QuizConfig config;
  final String? banner; // e.g. battle outcome

  String _headline(Store s) {
    final n = result.answers.length;
    if (n == 0) return s.t('No answers this time', 'इस बार कोई जवाब नहीं');
    final pct = result.right / n;
    if (result.perfect) return s.t('Full marks!', 'पूरे अंक!');
    if (pct >= 0.7) return s.t('Great going!', 'बहुत बढ़िया!');
    if (pct >= 0.4) return s.t('Good try!', 'अच्छी कोशिश!');
    return s.t('Keep practising', 'अभ्यास करते रहें');
  }

  @override
  Widget build(BuildContext context) {
    final store = context.store;
    final sc = context.sc;
    final lang = store.lang;
    final missed = result.answers.where((a) => !a.correct).toList();

    return Scaffold(
      appBar: AppBar(automaticallyImplyLeading: false, title: Text(config.title)),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 4, 20, 32),
          children: [
            Sticker(
              color: sc.primary,
              child: Column(
                children: [
                  Text(_headline(store),
                      textAlign: TextAlign.center,
                      style: context.tt.headlineMedium!.copyWith(color: const Color(0xFF1C1B2E))),
                  const SizedBox(height: 4),
                  Text('${result.score}',
                      style: context.tt.displayLarge!.copyWith(color: const Color(0xFF1C1B2E))),
                  Text(
                    store.t('points · ${result.right} of ${result.answers.length} right',
                        'अंक · ${result.answers.length} में से ${result.right} सही'),
                    style: context.tt.titleMedium!.copyWith(color: const Color(0xFF1C1B2E)),
                  ),
                ],
              ),
            ),
            if (banner != null) ...[
              const SizedBox(height: 4),
              Sticker(
                color: const Color(0xFF7C8CFF),
                child: Text(banner!, style: context.tt.titleLarge!.copyWith(color: const Color(0xFF1C1B2E))),
              ),
            ],
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(child: _Gain(icon: Icons.toll, label: store.t('Coins', 'सिक्के'), value: '+${rewards.coins}')),
                const SizedBox(width: 10),
                Expanded(child: _Gain(icon: Icons.trending_up, label: 'XP', value: '+${rewards.xp}')),
              ],
            ),
            if (rewards.levelUp)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Sticker(
                  color: const Color(0xFF7BD957),
                  child: Text(
                    store.t('Level up! You are now level ${store.active!.level}.', 'लेवल बढ़ा! अब आप लेवल ${store.active!.level} पर हैं।'),
                    style: context.tt.titleMedium!.copyWith(color: const Color(0xFF1C1B2E)),
                  ),
                ),
              ),
            for (final b in rewards.newBadges)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Sticker(
                  color: const Color(0xFFFFD23F),
                  child: Row(
                    children: [
                      Icon(b.icon, size: 32, color: const Color(0xFF1C1B2E)),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(store.t('New badge: ${b.name.en}', 'नया बैज: ${b.name.hi}'),
                                style: context.tt.titleMedium!.copyWith(color: const Color(0xFF1C1B2E))),
                            Text(b.how.of(lang), style: context.tt.bodyMedium!.copyWith(color: const Color(0xFF1C1B2E))),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            if (config.challengeCode != null) ...[
              const SizedBox(height: 8),
              SoftButton(
                icon: Icons.copy_rounded,
                label: store.t('Copy challenge message', 'चुनौती संदेश कॉपी करें'),
                onTap: () {
                  Clipboard.setData(ClipboardData(
                    text: store.t(
                      'I scored ${result.score} on Sawaal challenge ${config.challengeCode}. Open Sawaal → Challenge a friend → Enter code, and try to beat me!',
                      'मैंने सवाल चुनौती ${config.challengeCode} में ${result.score} अंक बनाए। सवाल खोलें → दोस्त को चुनौती → कोड डालें, और मुझे हराकर दिखाएँ!',
                    ),
                  ));
                  toast(context, store.t('Copied. Paste it in WhatsApp or SMS.', 'कॉपी हो गया। WhatsApp या SMS में पेस्ट करें।'));
                },
              ),
            ],
            const SizedBox(height: 12),
            Row(
              children: [
                if (config.replay != null) ...[
                  Expanded(
                    child: SoftButton(
                      icon: Icons.replay_rounded,
                      label: store.t('Play again', 'फिर से खेलें'),
                      onTap: () => Navigator.of(context).pushReplacement(
                        MaterialPageRoute(builder: (_) => QuizScreen(config: config.replay!())),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                ],
                Expanded(
                  child: BigButton(
                    label: store.t('Home', 'होम'),
                    icon: Icons.home_rounded,
                    onTap: () => Navigator.of(context).pop(),
                  ),
                ),
              ],
            ),
            if (missed.isNotEmpty) ...[
              Heading(store.t('Learn from these', 'इनसे सीखें')),
              for (final a in missed)
                Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: _MissedCard(record: a),
                ),
            ],
          ],
        ),
      ),
    );
  }
}

class _Gain extends StatelessWidget {
  const _Gain({required this.icon, required this.label, required this.value});

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Sticker(
      child: Row(
        children: [
          Icon(icon, size: 28, color: context.sc.ink),
          const SizedBox(width: 10),
          Expanded(child: Text(label, style: context.tt.titleMedium)),
          Text(value, style: context.tt.headlineSmall),
        ],
      ),
    );
  }
}

class _MissedCard extends StatelessWidget {
  const _MissedCard({required this.record});

  final AnswerRecord record;

  @override
  Widget build(BuildContext context) {
    final store = context.store;
    final lang = store.lang;
    final q = record.q;
    final yours = q.type == QType.fill
        ? (record.typed ?? '—')
        : (record.chosen == null ? store.t('No answer', 'कोई जवाब नहीं') : q.options[record.chosen!].of(lang));
    final right = q.type == QType.fill ? q.accept.first : q.options[q.answer].of(lang);
    return Sticker(
      depth: 2,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (q.picture != null) Text(q.picture!, style: const TextStyle(fontSize: 36)),
          Text(q.text.of(lang), style: context.tt.titleMedium),
          const SizedBox(height: 6),
          Text('${store.t('You said', 'आपका जवाब')}: $yours', style: context.tt.bodyMedium!.copyWith(color: context.sc.wrong)),
          Text('${store.t('Answer', 'सही जवाब')}: $right', style: context.tt.titleSmall),
          const SizedBox(height: 4),
          Text(q.explain.of(lang), style: context.tt.bodySmall),
        ],
      ),
    );
  }
}
