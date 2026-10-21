import 'dart:async';
import 'dart:math';
import 'dart:ui' show FontFeature;

import 'package:flutter/material.dart';

import '../data/questions.dart';
import '../question_view.dart';
import '../speaker.dart';
import '../state.dart';
import '../theme.dart';
import '../widgets.dart';
import 'quiz_screen.dart';
import 'result_screen.dart';

enum BotLevel { easy, medium, hard }

extension BotLevelX on BotLevel {
  double get accuracy => const [0.5, 0.7, 0.88][index];
  (int, int) get answerWindow => const [(7, 14), (4, 11), (2, 7)][index];
  L get label => const [L('Easy', 'आसान'), L('Medium', 'मध्यम'), L('Hard', 'कठिन')][index];
}

/// 1-vs-1 against the computer, same questions, same clock.
class BattleScreen extends StatefulWidget {
  const BattleScreen({super.key, required this.level});

  final BotLevel level;

  @override
  State<BattleScreen> createState() => _BattleScreenState();
}

class _BattleScreenState extends State<BattleScreen> {
  static const perQ = 15;
  static const rounds = 7;
  final _rand = Random();
  late List<Q> _qs;
  final List<AnswerRecord> _answers = [];
  int _i = 0;
  int _you = 0, _bot = 0;
  int _left = perQ;
  int? _chosen;
  bool _revealed = false;
  late bool _botCorrect;
  late int _botAt; // second at which the bot locks in
  bool _botLocked = false;
  Timer? _timer;
  final _watch = Stopwatch()..start();
  bool _done = false;

  @override
  void initState() {
    super.initState();
    final store = StoreScope.read(context);
    _qs = store.pick(store.poolFor(types: {QType.mcq, QType.trueFalse, QType.picture}), rounds);
    _setupRound();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) => _tick());
  }

  @override
  void dispose() {
    _timer?.cancel();
    Speaker.stop();
    super.dispose();
  }

  void _setupRound() {
    _left = perQ;
    _chosen = null;
    _revealed = false;
    _botLocked = false;
    _botCorrect = _rand.nextDouble() < widget.level.accuracy;
    final (lo, hi) = widget.level.answerWindow;
    _botAt = lo + _rand.nextInt(hi - lo + 1);
  }

  void _tick() {
    if (!mounted || _done || _revealed) return;
    setState(() {
      _left--;
      if (perQ - _left >= _botAt) _botLocked = true;
    });
    if (_left <= 0) _resolve(null);
  }

  void _resolve(int? choice) {
    if (_revealed) return;
    final q = _qs[_i];
    final youRight = choice != null && choice == q.answer;
    setState(() {
      _chosen = choice;
      _revealed = true;
      _botLocked = true;
      if (youRight) _you += 10 + _left ~/ 3;
      if (_botCorrect) _bot += 10 + max(0, perQ - _botAt) ~/ 3;
      _answers.add(AnswerRecord(q, youRight, chosen: choice, seconds: perQ - _left));
    });
  }

  void _next() {
    if (_i >= _qs.length - 1) {
      _finish();
      return;
    }
    setState(() {
      _i++;
      _setupRound();
    });
  }

  void _finish() {
    if (_done) return;
    _done = true;
    _timer?.cancel();
    final store = StoreScope.read(context);
    final won = _you > _bot;
    final result = GameResult(mode: 'battle', answers: _answers, score: _you, seconds: _watch.elapsed.inSeconds, wonBattle: won);
    final rewards = store.record(result);
    final banner = won
        ? store.t('You beat the computer $_you – $_bot!', 'आपने कंप्यूटर को $_you – $_bot से हराया!')
        : _you == _bot
            ? store.t('A draw, $_you – $_bot.', 'बराबरी, $_you – $_bot.')
            : store.t('The computer won $_bot – $_you. Try again!', 'कंप्यूटर $_bot – $_you से जीता। फिर कोशिश करें!');
    Navigator.of(context).pushReplacement(MaterialPageRoute(
      builder: (_) => ResultScreen(
        result: result,
        rewards: rewards,
        banner: banner,
        config: QuizConfig(title: store.t('Battle', 'मुकाबला'), mode: 'battle', questions: _qs),
      ),
    ));
  }

  @override
  Widget build(BuildContext context) {
    final store = context.store;
    final sc = context.sc;
    final me = store.active!;
    if (_qs.isEmpty) {
      return Scaffold(
        appBar: AppBar(),
        body: Center(child: Text(store.t('No questions available yet.', 'अभी कोई सवाल उपलब्ध नहीं।'))),
      );
    }
    final q = _qs[_i];

    return PopScope(
      canPop: _done,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) {
          _done = true;
          _timer?.cancel();
          Navigator.of(context).pop();
        }
      },
      child: Scaffold(
        appBar: AppBar(title: Text('${store.t('Battle', 'मुकाबला')} · ${_i + 1}/${_qs.length}')),
        body: SafeArea(
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Row(
                  children: [
                    Expanded(
                      child: _Side(
                        avatar: AvatarDot(profile: me, size: 40),
                        name: me.name,
                        score: _you,
                        status: _revealed
                            ? (_answers.last.correct ? store.t('Right', 'सही') : store.t('Wrong', 'गलत'))
                            : store.t('Thinking…', 'सोच रहे हैं…'),
                      ),
                    ),
                    Container(
                      width: 52,
                      height: 52,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: _left <= 5 ? sc.wrong : const Color(0xFFFFD23F),
                        shape: BoxShape.circle,
                        border: Border.all(color: sc.line, width: 2.5),
                      ),
                      child: Text('$_left',
                          style: context.tt.headlineSmall!.copyWith(
                            color: const Color(0xFF1C1B2E),
                            fontFeatures: const [FontFeature.tabularFigures()],
                          )),
                    ),
                    Expanded(
                      child: _Side(
                        alignEnd: true,
                        avatar: const IconBlob(icon: Icons.smart_toy, color: Color(0xFF7C8CFF), size: 40),
                        name: store.t('Chatur (computer, ${widget.level.label.en})', 'चतुर (कंप्यूटर, ${widget.level.label.hi})'),
                        score: _bot,
                        status: _revealed
                            ? (_botCorrect ? store.t('Right', 'सही') : store.t('Wrong', 'गलत'))
                            : _botLocked
                                ? store.t('Answered', 'जवाब दे दिया')
                                : store.t('Thinking…', 'सोच रहा है…'),
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(20, 14, 20, 20),
                  children: [
                    QuestionView(
                      q: q,
                      revealed: _revealed,
                      chosen: _chosen,
                      onChoose: _resolve,
                      onType: (_) {},
                    ),
                  ],
                ),
              ),
              if (_revealed)
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                  child: BigButton(
                    label: _i >= _qs.length - 1 ? store.t('See who won', 'देखें कौन जीता') : store.t('Next round', 'अगला राउंड'),
                    icon: Icons.arrow_forward_rounded,
                    onTap: _next,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Side extends StatelessWidget {
  const _Side({required this.avatar, required this.name, required this.score, required this.status, this.alignEnd = false});

  final Widget avatar;
  final String name;
  final int score;
  final String status;
  final bool alignEnd;

  @override
  Widget build(BuildContext context) {
    final cross = alignEnd ? CrossAxisAlignment.end : CrossAxisAlignment.start;
    return Column(
      crossAxisAlignment: cross,
      children: [
        avatar,
        const SizedBox(height: 4),
        Text(name, maxLines: 1, overflow: TextOverflow.ellipsis, style: context.tt.labelMedium),
        Text('$score',
            style: context.tt.headlineMedium!.copyWith(fontFeatures: const [FontFeature.tabularFigures()])),
        Text(status, style: context.tt.labelSmall),
      ],
    );
  }
}

/// Picks bot difficulty, then starts the battle.
Future<void> startBattle(BuildContext context) async {
  final store = StoreScope.read(context);
  final level = await showModalBottomSheet<BotLevel>(
    context: context,
    builder: (ctx) => SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(store.t('How tough should the computer be?', 'कंप्यूटर कितना मुश्किल हो?'), style: ctx.tt.headlineSmall),
            const SizedBox(height: 6),
            Text(store.t('7 rounds, 15 seconds each. Faster right answers score more.',
                    '7 राउंड, हर एक 15 सेकंड। जल्दी सही जवाब पर ज़्यादा अंक।'),
                style: ctx.tt.bodyMedium),
            const SizedBox(height: 14),
            for (final l in BotLevel.values)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: SoftButton(label: l.label.of(store.lang), onTap: () => Navigator.pop(ctx, l)),
              ),
          ],
        ),
      ),
    ),
  );
  if (level != null && context.mounted) {
    Navigator.of(context).push(MaterialPageRoute(builder: (_) => BattleScreen(level: level)));
  }
}
