import 'dart:async';
import 'dart:ui' show FontFeature;

import 'package:flutter/material.dart';

import '../data/questions.dart';
import '../question_view.dart';
import '../speaker.dart';
import '../state.dart';
import '../theme.dart';
import '../widgets.dart';
import 'result_screen.dart';

class QuizConfig {
  const QuizConfig({
    required this.title,
    required this.mode,
    required this.questions,
    this.perQuestionSeconds,
    this.totalSeconds,
    this.lifelines = true,
    this.challengeCode,
    this.replay,
  });

  final String title;
  final String mode; // classic, daily, category, review, challenge, rapid
  final List<Q> questions;
  final int? perQuestionSeconds; // null = relaxed (no timer)
  final int? totalSeconds; // rapid fire: one clock for the whole round
  final bool lifelines;
  final String? challengeCode;
  final QuizConfig Function()? replay;

  bool get rapid => totalSeconds != null;
}

class QuizScreen extends StatefulWidget {
  const QuizScreen({super.key, required this.config});

  final QuizConfig config;

  @override
  State<QuizScreen> createState() => _QuizScreenState();
}

class _QuizScreenState extends State<QuizScreen> {
  late final List<Q> _qs = [...widget.config.questions];
  final List<AnswerRecord> _answers = [];
  int _i = 0;
  int? _chosen;
  String? _typed;
  bool _revealed = false;
  bool _lastCorrect = false;
  int _score = 0;
  int _streakInGame = 0;
  int? _left; // seconds left for this question
  int? _totalLeft;
  Timer? _timer;
  final Set<int> _hidden = {};
  bool _usedFifty = false, _usedSkip = false, _usedTime = false;
  final _watch = Stopwatch()..start();
  bool _finished = false;

  Q get _q => _qs[_i];

  @override
  void initState() {
    super.initState();
    _totalLeft = widget.config.totalSeconds;
    _startQuestion();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) => _tick());
  }

  @override
  void dispose() {
    _timer?.cancel();
    Speaker.stop();
    super.dispose();
  }

  void _startQuestion() {
    _chosen = null;
    _typed = null;
    _revealed = false;
    _hidden.clear();
    _left = widget.config.rapid ? null : widget.config.perQuestionSeconds;
    final store = StoreScope.read(context);
    if (_q.type == QType.listen || store.settings.readAloud) {
      final lang = store.lang;
      final opts = _q.options.isEmpty ? '' : '. ${_q.options.map((o) => o.of(lang)).join(', ')}';
      Speaker.say('${_q.text.of(lang)}$opts', lang);
    }
  }

  void _tick() {
    if (!mounted || _finished) return;
    if (_totalLeft != null) {
      _totalLeft = _totalLeft! - 1;
      if (_totalLeft! <= 0) {
        _finish();
        return;
      }
    }
    if (_left != null && !_revealed) {
      _left = _left! - 1;
      if (_left! <= 0) {
        _answer(timedOut: true);
        return;
      }
    }
    setState(() {});
  }

  void _answer({int? choice, String? typed, bool timedOut = false}) {
    if (_revealed) return;
    final correct = timedOut
        ? false
        : _q.type == QType.fill
            ? _q.checkTyped(typed ?? '')
            : choice == _q.answer;
    setState(() {
      _chosen = choice;
      _typed = typed;
      _revealed = true;
      _lastCorrect = correct;
      if (correct) {
        _streakInGame++;
        final bonus = widget.config.rapid ? 0 : ((_left ?? 10) ~/ 2);
        _score += 10 + bonus;
      } else {
        _streakInGame = 0;
      }
      final spent = widget.config.perQuestionSeconds == null || _left == null
          ? 0
          : widget.config.perQuestionSeconds! - _left!;
      _answers.add(AnswerRecord(_q, correct, chosen: choice, typed: typed, seconds: spent));
    });
    if (widget.config.rapid) {
      Future.delayed(const Duration(milliseconds: 650), () {
        if (mounted && !_finished) _next();
      });
    }
  }

  void _next() {
    if (_i >= _qs.length - 1) {
      if (widget.config.rapid) {
        // Rapid fire keeps going: reshuffle the pool.
        final more = [..._qs]..shuffle();
        _qs.addAll(more);
      } else {
        _finish();
        return;
      }
    }
    setState(() {
      _i++;
      _startQuestion();
    });
  }

  void _finish() {
    if (_finished) return;
    _finished = true;
    _timer?.cancel();
    Speaker.stop();
    final store = StoreScope.read(context);
    final result = GameResult(
      mode: widget.config.mode,
      answers: _answers,
      score: _score,
      seconds: _watch.elapsed.inSeconds,
    );
    final rewards = store.record(result);
    Navigator.of(context).pushReplacement(MaterialPageRoute(
      builder: (_) => ResultScreen(result: result, rewards: rewards, config: widget.config),
    ));
  }

  void _useFifty() {
    if (_usedFifty || _revealed || _q.options.length < 4) return;
    final wrong = [for (var i = 0; i < _q.options.length; i++) if (i != _q.answer) i]..shuffle();
    setState(() {
      _usedFifty = true;
      _hidden.addAll(wrong.take(2));
    });
  }

  void _useSkip() {
    if (_usedSkip || _revealed) return;
    setState(() => _usedSkip = true);
    if (_i >= _qs.length - 1) {
      _finish();
    } else {
      setState(() {
        _i++;
        _startQuestion();
      });
    }
  }

  void _useTime() {
    if (_usedTime || _revealed || _left == null) return;
    setState(() {
      _usedTime = true;
      _left = _left! + 10;
    });
  }

  Future<bool> _confirmQuit() async {
    final store = StoreScope.read(context);
    final quit = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(store.t('Quit this quiz?', 'क्विज़ छोड़ें?')),
        content: Text(store.t('Your score for this round will not be saved.', 'इस राउंड का स्कोर सेव नहीं होगा।')),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(store.t('Keep playing', 'खेलते रहें'))),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: Text(store.t('Quit', 'छोड़ें'))),
        ],
      ),
    );
    return quit ?? false;
  }

  @override
  Widget build(BuildContext context) {
    final store = context.store;
    final sc = context.sc;
    final cfg = widget.config;
    final total = cfg.rapid ? null : _qs.length;
    final clock = cfg.rapid ? _totalLeft : _left;
    final clockMax = cfg.rapid ? cfg.totalSeconds : cfg.perQuestionSeconds;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;
        final nav = Navigator.of(context);
        if (await _confirmQuit()) {
          _finished = true;
          _timer?.cancel();
          nav.pop();
        }
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text(cfg.title),
          actions: [
            Padding(
              padding: const EdgeInsets.only(right: 16),
              child: Center(
                child: Text(
                  '${store.t('Score', 'स्कोर')} $_score',
                  style: context.tt.labelLarge!.copyWith(fontFeatures: const [FontFeature.tabularFigures()]),
                ),
              ),
            ),
          ],
        ),
        body: SafeArea(
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Row(
                  children: [
                    Text(
                      total == null
                          ? store.t('${_answers.where((a) => a.correct).length} right', '${_answers.where((a) => a.correct).length} सही')
                          : '${_i + 1} / $total',
                      style: context.tt.titleMedium,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: clock == null
                          ? Text(store.t('Relaxed mode — no timer', 'आराम मोड — कोई टाइमर नहीं'), style: context.tt.bodySmall)
                          : _ClockBar(value: clock, max: clockMax ?? 1),
                    ),
                    if (clock != null) ...[
                      const SizedBox(width: 10),
                      Semantics(
                        liveRegion: clock <= 5,
                        label: '$clock seconds left',
                        child: Text(
                          '$clock',
                          style: context.tt.headlineSmall!.copyWith(
                            color: clock <= 5 ? sc.wrong : sc.ink,
                            fontFeatures: const [FontFeature.tabularFigures()],
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              if (_streakInGame >= 3 && !cfg.rapid)
                Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Text(store.t('$_streakInGame in a row!', 'लगातार $_streakInGame सही!'),
                      style: context.tt.labelLarge!.copyWith(color: sc.primary)),
                ),
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
                  children: [
                    QuestionView(
                      q: _q,
                      revealed: _revealed,
                      chosen: _chosen,
                      typed: _typed,
                      hidden: _hidden,
                      onChoose: (i) => _answer(choice: i),
                      onType: (t) => _answer(typed: t),
                    ),
                    if (_revealed && !cfg.rapid) ...[
                      const SizedBox(height: 8),
                      _Feedback(
                        correct: _lastCorrect,
                        timedOut: _chosen == null && _typed == null,
                        explain: store.settings.explanations ? _q.explain.of(store.lang) : null,
                      ),
                    ],
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
                decoration: BoxDecoration(
                  color: sc.card,
                  border: Border(top: BorderSide(color: sc.line, width: sc.lineWidth)),
                ),
                child: _revealed && !cfg.rapid
                    ? BigButton(
                        label: _i >= _qs.length - 1 ? store.t('See results', 'नतीजे देखें') : store.t('Next question', 'अगला सवाल'),
                        icon: Icons.arrow_forward_rounded,
                        onTap: _next,
                      )
                    : cfg.lifelines && !cfg.rapid
                        ? Row(
                            children: [
                              Expanded(
                                child: _Lifeline(
                                  label: '50 : 50',
                                  used: _usedFifty || _q.options.length < 4,
                                  onTap: _useFifty,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(child: _Lifeline(label: store.t('Skip', 'छोड़ें'), used: _usedSkip, onTap: _useSkip)),
                              const SizedBox(width: 8),
                              Expanded(
                                child: _Lifeline(
                                  label: store.t('+10 sec', '+10 सेकंड'),
                                  used: _usedTime || _left == null,
                                  onTap: _useTime,
                                ),
                              ),
                            ],
                          )
                        : Text(
                            cfg.rapid
                                ? store.t('Answer as many as you can before time runs out.', 'समय खत्म होने से पहले जितने हो सकें, जवाब दें।')
                                : store.t('Pick an answer.', 'एक जवाब चुनें।'),
                            textAlign: TextAlign.center,
                            style: context.tt.bodyMedium,
                          ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ClockBar extends StatelessWidget {
  const _ClockBar({required this.value, required this.max});

  final int value;
  final int max;

  @override
  Widget build(BuildContext context) {
    final sc = context.sc;
    final frac = (value / max).clamp(0.0, 1.0);
    return Container(
      height: 16,
      decoration: BoxDecoration(
        color: sc.card,
        borderRadius: BorderRadius.circular(99),
        border: Border.all(color: sc.line, width: 2),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(99),
        child: Align(
          alignment: Alignment.centerLeft,
          child: AnimatedFractionallySizedBox(
            duration: const Duration(milliseconds: 900),
            widthFactor: frac,
            heightFactor: 1,
            child: Container(color: value <= 5 ? sc.wrong : sc.primary),
          ),
        ),
      ),
    );
  }
}

class _Lifeline extends StatelessWidget {
  const _Lifeline({required this.label, required this.used, required this.onTap});

  final String label;
  final bool used;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: used ? 0.4 : 1,
      child: Sticker(
        color: const Color(0xFFFFD23F),
        depth: 3,
        radius: 14,
        padding: const EdgeInsets.symmetric(vertical: 10),
        onTap: used ? null : onTap,
        semanticLabel: used ? '$label, used' : 'Lifeline $label',
        child: Text(label,
            textAlign: TextAlign.center,
            style: context.tt.labelLarge!.copyWith(
              color: const Color(0xFF1C1B2E),
              decoration: used ? TextDecoration.lineThrough : null,
            )),
      ),
    );
  }
}

class _Feedback extends StatelessWidget {
  const _Feedback({required this.correct, required this.timedOut, this.explain});

  final bool correct;
  final bool timedOut;
  final String? explain;

  @override
  Widget build(BuildContext context) {
    final store = context.store;
    final sc = context.sc;
    final title = correct
        ? store.t('Correct!', 'सही जवाब!')
        : timedOut
            ? store.t('Time\'s up', 'समय खत्म')
            : store.t('Not quite', 'गलत जवाब');
    return Sticker(
      color: correct ? sc.right.withValues(alpha: 0.25) : sc.wrong.withValues(alpha: 0.2),
      depth: 0,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: context.tt.titleLarge),
          if (explain != null) ...[
            const SizedBox(height: 4),
            Text(explain!, style: context.tt.bodyLarge),
          ],
        ],
      ),
    );
  }
}
