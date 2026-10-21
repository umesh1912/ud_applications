import 'package:flutter/material.dart';

import '../data/questions.dart';
import '../state.dart';
import '../theme.dart';
import '../widgets.dart';
import 'battle_screen.dart';
import 'quiz_screen.dart';

/// Checks the kids' daily time limit before any game starts.
/// Returns true if play may continue.
Future<bool> checkPlayTime(BuildContext context) async {
  final store = StoreScope.read(context);
  final p = store.active;
  if (p == null || !p.limitReached) return true;
  final unlock = await showModalBottomSheet<bool>(
    context: context,
    builder: (ctx) => SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Icon(Icons.bedtime_rounded, size: 56, color: ctx.sc.ink),
            const SizedBox(height: 8),
            Text(store.t('That\'s all for today, ${p.name}!', 'आज के लिए इतना ही, ${p.name}!'),
                textAlign: TextAlign.center, style: ctx.tt.headlineSmall),
            const SizedBox(height: 6),
            Text(
              store.t('You\'ve played your ${p.dailyLimitMin} minutes. Come back tomorrow to keep your streak.',
                  'आपने अपने ${p.dailyLimitMin} मिनट खेल लिए। स्ट्रीक बनाए रखने के लिए कल फिर आइए।'),
              textAlign: TextAlign.center,
              style: ctx.tt.bodyLarge,
            ),
            const SizedBox(height: 18),
            BigButton(label: store.t('OK', 'ठीक है'), onTap: () => Navigator.pop(ctx, false)),
            const SizedBox(height: 6),
            TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: Text(store.t('Parent: allow 15 more minutes', 'अभिभावक: 15 मिनट और दें')),
            ),
          ],
        ),
      ),
    ),
  );
  if (unlock != true || !context.mounted) return false;
  if (store.settings.parentPin == null) {
    toast(context, store.t('Set a parent PIN in Settings first.', 'पहले सेटिंग्स में अभिभावक पिन बनाएँ।'));
    return false;
  }
  if (!await askParentPin(context)) return false;
  p.secondsToday = ((p.dailyLimitMin! - 15).clamp(0, 9999)) * 60;
  store.changed();
  return true;
}

Future<void> startQuiz(BuildContext context, QuizConfig config) async {
  final store = StoreScope.read(context);
  if (config.questions.isEmpty) {
    toast(context, store.t('No questions here for your age group yet.', 'आपके आयु समूह के लिए अभी यहाँ सवाल नहीं हैं।'));
    return;
  }
  if (!await checkPlayTime(context) || !context.mounted) return;
  Navigator.of(context).push(MaterialPageRoute(builder: (_) => QuizScreen(config: config)));
}

int? _perQ(Store s) => s.settings.timer ? s.active?.group.secondsPerQuestion : null;

QuizConfig quickPlay(Store s) => QuizConfig(
      title: s.t('Quick play', 'झटपट खेल'),
      mode: 'classic',
      questions: s.pick(s.poolFor(), 10),
      perQuestionSeconds: _perQ(s),
      replay: () => quickPlay(s),
    );

QuizConfig categoryPlay(Store s, Cat c) => QuizConfig(
      title: c.name.of(s.lang),
      mode: 'category',
      questions: s.pick(s.poolFor(cat: c), 8),
      perQuestionSeconds: _perQ(s),
      replay: () => categoryPlay(s, c),
    );

QuizConfig dailyPlay(Store s) => QuizConfig(
      title: s.t('Daily quiz', 'आज का क्विज़'),
      mode: 'daily',
      questions: s.dailyQuestions(),
      perQuestionSeconds: _perQ(s),
    );

QuizConfig rapidPlay(Store s) => QuizConfig(
      title: s.t('Rapid fire', 'रैपिड फ़ायर'),
      mode: 'rapid',
      questions: s.pick(s.poolFor(types: {QType.mcq, QType.trueFalse, QType.picture}), 40),
      totalSeconds: 60,
      lifelines: false,
      replay: () => rapidPlay(s),
    );

QuizConfig reviewPlay(Store s) => QuizConfig(
      title: s.t('Practise missed questions', 'छूटे सवालों का अभ्यास'),
      mode: 'review',
      questions: s.active!.missed
          .map((id) => questionBank.where((q) => q.id == id).firstOrNull)
          .whereType<Q>()
          .take(10)
          .toList(),
      perQuestionSeconds: null,
      lifelines: false,
    );

Future<void> startBattleGuarded(BuildContext context) async {
  if (!await checkPlayTime(context) || !context.mounted) return;
  await startBattle(context);
}
