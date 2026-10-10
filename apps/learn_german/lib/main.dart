import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:ud_core/ud_core.dart';

import 'course.dart';
import 'strings.dart';

const appName = 'Deutsch Dost';

void main() => runUdApp(UdAppSpec(
      name: appName,
      taglineKey: 'tagline',
      accent: const Color(0xFF3E6B48),
      icon: Icons.translate_rounded,
      strings: deStrings,
      home: (_) => const HomePage(),
    ));

/// German pronunciation through the phone's text-to-speech engine.
class Voice {
  static final FlutterTts _tts = FlutterTts();
  static bool _ready = false;

  static Future<void> say(String text) async {
    try {
      if (!_ready) {
        await _tts.setLanguage('de-DE');
        await _tts.setSpeechRate(0.42);
        _ready = true;
      }
      await _tts.stop();
      await _tts.speak(text.replaceAll('…', '').trim());
    } catch (_) {}
  }
}

/// Stars per unit, XP and daily streak.
class Progress extends ChangeNotifier {
  Progress._(this._p);
  final SharedPreferences _p;

  static Progress? _instance;
  static Future<Progress> get() async =>
      _instance ??= Progress._(await SharedPreferences.getInstance());

  int stars(String unit) => _p.getInt('de.stars.$unit') ?? 0;
  int get xp => _p.getInt('de.xp') ?? 0;

  int get streak {
    final last = _p.getString('de.last');
    if (last == null) return 0;
    final d = DateTime.parse(last);
    final gap = _today().difference(d).inDays;
    return gap > 1 ? 0 : (_p.getInt('de.streak') ?? 0);
  }

  static DateTime _today() {
    final n = DateTime.now();
    return DateTime(n.year, n.month, n.day);
  }

  Future<void> record(String unit, int correct, int total) async {
    final s = correct >= total * 0.9
        ? 3
        : correct >= total * 0.7
            ? 2
            : correct >= total * 0.5
                ? 1
                : 0;
    if (s > stars(unit)) await _p.setInt('de.stars.$unit', s);
    await _p.setInt('de.xp', xp + correct * 10);
    final today = _today();
    final last = _p.getString('de.last');
    final gap = last == null ? 99 : today.difference(DateTime.parse(last)).inDays;
    if (gap >= 1) {
      await _p.setInt('de.streak', gap == 1 ? streak + 1 : 1);
      await _p.setString('de.last', today.toIso8601String());
    } else if (_p.getInt('de.streak') == null) {
      await _p.setInt('de.streak', 1);
      await _p.setString('de.last', today.toIso8601String());
    }
    notifyListeners();
  }
}

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  Progress? _progress;

  @override
  void initState() {
    super.initState();
    Progress.get().then((p) {
      if (mounted) setState(() => _progress = p);
    });
  }

  @override
  Widget build(BuildContext context) {
    final p = _progress;
    if (p == null) return const Scaffold(body: Center(child: CircularProgressIndicator()));
    return ListenableBuilder(
      listenable: p,
      builder: (context, _) {
        final t = UdTokens.of(context);
        final text = Theme.of(context).textTheme;
        final next = course.firstWhere((u) => p.stars(u.id) < 3, orElse: () => course.first);
        return UdPage(
          eyebrow: appName,
          title: context.tr('home_title'),
          subtitle: context.tr('home_sub'),
          actions: const [UdSettingsButton(appName: appName)],
          dock: UdDock(
            label: context.tr('continue_learning'),
            icon: Icons.play_arrow_rounded,
            onPressed: () => _openUnit(context, next, p),
          ),
          slivers: [
            UdSliverPad(
              bottom: 18,
              sliver: SliverToBoxAdapter(
                child: Container(
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(color: t.ink, borderRadius: BorderRadius.circular(24)),
                  child: Row(
                    children: [
                      const Text('🔥', style: TextStyle(fontSize: 30)),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(context.tr('streak', {'n': '${p.streak}'}),
                            style: text.titleLarge?.copyWith(color: t.paper)),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(color: t.accent, borderRadius: BorderRadius.circular(14)),
                        child: Text(context.tr('xp', {'n': '${p.xp}'}),
                            style: text.labelLarge?.copyWith(color: t.onAccent)),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            UdSliverPad(
              sliver: SliverList.list(children: [
                for (var i = 0; i < course.length; i++)
                  UdRow(
                    leading: Stack(
                      clipBehavior: Clip.none,
                      children: [
                        UdBadgeIcon(course[i].icon),
                        Positioned(
                          right: -4,
                          top: -4,
                          child: CircleAvatar(
                            radius: 10,
                            backgroundColor: t.ink,
                            child: Text('${i + 1}', style: TextStyle(fontSize: 11, color: t.paper)),
                          ),
                        ),
                      ],
                    ),
                    title: context.tr('u_${course[i].id}'),
                    subtitle: context.tr('words', {'n': '${course[i].words.length}'}),
                    trailing: _Stars(p.stars(course[i].id)),
                    onTap: () => _openUnit(context, course[i], p),
                  ),
              ]),
            ),
          ],
        );
      },
    );
  }

  void _openUnit(BuildContext context, Unit u, Progress p) =>
      Navigator.of(context).push(MaterialPageRoute(builder: (_) => UnitPage(unit: u, progress: p)));
}

class _Stars extends StatelessWidget {
  const _Stars(this.n);
  final int n;

  @override
  Widget build(BuildContext context) {
    final t = UdTokens.of(context);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (var i = 0; i < 3; i++)
          Icon(i < n ? Icons.star_rounded : Icons.star_outline_rounded,
              size: 20, color: i < n ? const Color(0xFFD9A11E) : t.inkFaint),
      ],
    );
  }
}

class UnitPage extends StatelessWidget {
  const UnitPage({super.key, required this.unit, required this.progress});
  final Unit unit;
  final Progress progress;

  @override
  Widget build(BuildContext context) {
    final t = UdTokens.of(context);
    final text = Theme.of(context).textTheme;
    final lang = context.udSettings.lang;
    void go(Widget page) => Navigator.of(context).push(MaterialPageRoute(builder: (_) => page));

    return UdPage(
      title: context.tr('u_${unit.id}'),
      subtitle: context.tr('words', {'n': '${unit.words.length}'}),
      slivers: [
        UdSliverPad(
          sliver: SliverGrid.count(
            crossAxisCount: 3,
            mainAxisSpacing: 10,
            crossAxisSpacing: 10,
            childAspectRatio: 0.82,
            children: [
              UdToolTile(
                icon: Icons.style_outlined,
                title: context.tr('learn'),
                subtitle: context.tr('learn_sub'),
                highlight: true,
                onTap: () => go(FlashcardsPage(unit: unit)),
              ),
              UdToolTile(
                icon: Icons.quiz_outlined,
                title: context.tr('quiz'),
                subtitle: context.tr('quiz_sub'),
                onTap: () => go(QuizPage(unit: unit, progress: progress)),
              ),
              UdToolTile(
                icon: Icons.hearing_outlined,
                title: context.tr('listen'),
                subtitle: context.tr('listen_sub'),
                onTap: () => go(QuizPage(unit: unit, progress: progress, listening: true)),
              ),
            ],
          ),
        ),
        UdSliverPad(
          top: 20,
          sliver: SliverList.list(children: [
            UdLabel(context.tr('all_words'), trailing: Text(context.tr('articles'), style: text.labelSmall)),
            for (final w in unit.words)
              UdRow(
                title: w.de,
                subtitle: w.meaning(lang),
                leading: Container(
                  width: 6,
                  height: 36,
                  decoration: BoxDecoration(
                    color: articleColors[w.article] ?? t.line,
                    borderRadius: BorderRadius.circular(3),
                  ),
                ),
                trailing: Icon(Icons.volume_up_rounded, color: t.accent),
                onTap: () => Voice.say(w.de),
              ),
          ]),
        ),
      ],
    );
  }
}

class FlashcardsPage extends StatefulWidget {
  const FlashcardsPage({super.key, required this.unit});
  final Unit unit;

  @override
  State<FlashcardsPage> createState() => _FlashcardsPageState();
}

class _FlashcardsPageState extends State<FlashcardsPage> {
  final _pager = PageController(viewportFraction: 0.88);
  int _index = 0;
  final _flipped = <int>{};

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => Voice.say(widget.unit.words.first.de));
  }

  @override
  void dispose() {
    _pager.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final t = UdTokens.of(context);
    final text = Theme.of(context).textTheme;
    final words = widget.unit.words;
    final lang = context.udSettings.lang;

    return UdPage(
      title: context.tr('u_${widget.unit.id}'),
      subtitle: context.tr('tap_flip'),
      dock: UdDock(
        label: _index == words.length - 1 ? context.tr('finish') : context.tr('next'),
        icon: Icons.arrow_forward_rounded,
        onPressed: () {
          if (_index == words.length - 1) {
            Navigator.of(context).pop();
          } else {
            _pager.nextPage(duration: const Duration(milliseconds: 320), curve: Curves.easeOut);
          }
        },
        extras: [
          UdDockAction(
            icon: Icons.volume_up_rounded,
            label: context.tr('listen'),
            onTap: () => Voice.say(words[_index].de),
          ),
        ],
      ),
      slivers: [
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: (_index + 1) / words.length,
                minHeight: 6,
                backgroundColor: t.line,
                color: t.accent,
              ),
            ),
          ),
        ),
        SliverToBoxAdapter(
          child: SizedBox(
            height: MediaQuery.of(context).size.height * 0.5,
            child: PageView.builder(
              controller: _pager,
              itemCount: words.length,
              onPageChanged: (i) {
                setState(() => _index = i);
                Voice.say(words[i].de);
              },
              itemBuilder: (context, i) {
                final w = words[i];
                final flipped = _flipped.contains(i);
                final color = articleColors[w.article] ?? t.accent;
                return Padding(
                  padding: const EdgeInsets.fromLTRB(6, 20, 6, 10),
                  child: UdPressable(
                    onTap: () => setState(() => flipped ? _flipped.remove(i) : _flipped.add(i)),
                    color: flipped ? t.accentSoft : t.card,
                    borderRadius: 28,
                    child: AnimatedSwitcher(
                      duration: const Duration(milliseconds: 280),
                      transitionBuilder: (child, anim) => ScaleTransition(scale: anim, child: child),
                      child: Center(
                        key: ValueKey(flipped),
                        child: Padding(
                          padding: const EdgeInsets.all(24),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              if (w.article != null && !flipped)
                                Container(
                                  margin: const EdgeInsets.only(bottom: 12),
                                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: color.withValues(alpha: 0.12),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Text(w.article!, style: text.labelLarge?.copyWith(color: color)),
                                ),
                              Text(
                                flipped ? w.meaning(lang) : w.de,
                                textAlign: TextAlign.center,
                                style: (flipped ? text.headlineMedium : text.displaySmall)
                                    ?.copyWith(color: flipped ? t.ink : color),
                              ),
                              if (flipped)
                                Padding(
                                  padding: const EdgeInsets.only(top: 12),
                                  child: Text(w.de, style: text.titleMedium?.copyWith(color: t.inkSoft)),
                                ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ),
        SliverToBoxAdapter(
          child: Center(
            child: Text('${_index + 1} / ${words.length}', style: text.labelMedium?.copyWith(color: t.inkSoft)),
          ),
        ),
      ],
    );
  }
}

class _Question {
  _Question(this.word, this.options, this.reverse);
  final Word word;
  final List<Word> options;
  final bool reverse; // true: show meaning, choose German
}

class QuizPage extends StatefulWidget {
  const QuizPage({super.key, required this.unit, required this.progress, this.listening = false});
  final Unit unit;
  final Progress progress;
  final bool listening;

  @override
  State<QuizPage> createState() => _QuizPageState();
}

class _QuizPageState extends State<QuizPage> {
  final _rng = Random();
  late List<_Question> _qs;
  int _i = 0;
  int _correct = 0;
  Word? _picked;
  bool _done = false;

  @override
  void initState() {
    super.initState();
    _build();
  }

  void _build() {
    final words = [...widget.unit.words]..shuffle(_rng);
    final picks = words.take(min(10, words.length)).toList();
    _qs = [
      for (var k = 0; k < picks.length; k++)
        _Question(
          picks[k],
          ([picks[k], ...([...widget.unit.words]..remove(picks[k])..shuffle(_rng)).take(3)])..shuffle(_rng),
          !widget.listening && k.isOdd,
        ),
    ];
    _i = 0;
    _correct = 0;
    _picked = null;
    _done = false;
    if (widget.listening) {
      WidgetsBinding.instance.addPostFrameCallback((_) => Voice.say(_qs.first.word.de));
    }
  }

  void _pick(Word w) {
    if (_picked != null) return;
    final ok = w == _qs[_i].word;
    ok ? HapticFeedback.lightImpact() : HapticFeedback.heavyImpact();
    setState(() {
      _picked = w;
      if (ok) _correct++;
    });
    if (!widget.listening && !_qs[_i].reverse) Voice.say(_qs[_i].word.de);
  }

  Future<void> _next() async {
    if (_i == _qs.length - 1) {
      await widget.progress.record(widget.unit.id, _correct, _qs.length);
      setState(() => _done = true);
      return;
    }
    setState(() {
      _i++;
      _picked = null;
    });
    if (widget.listening) Voice.say(_qs[_i].word.de);
  }

  @override
  Widget build(BuildContext context) {
    final t = UdTokens.of(context);
    final text = Theme.of(context).textTheme;
    final lang = context.udSettings.lang;

    if (_done) {
      final ratio = _correct / _qs.length;
      return UdPage(
        title: context.tr(ratio >= 0.9 ? 'great' : ratio >= 0.6 ? 'good' : 'keep'),
        subtitle: context.tr('score', {'a': '$_correct', 'b': '${_qs.length}'}),
        dock: UdDock(
          label: context.tr('back_units'),
          icon: Icons.check_rounded,
          onPressed: () => Navigator.of(context).pop(),
          extras: [
            UdDockAction(
                icon: Icons.replay_rounded, label: context.tr('again'), onTap: () => setState(_build)),
          ],
        ),
        slivers: [
          SliverToBoxAdapter(
            child: Center(
              child: Padding(
                padding: const EdgeInsets.all(30),
                child: Text(ratio >= 0.9 ? '🏆' : ratio >= 0.6 ? '🎉' : '💪', style: const TextStyle(fontSize: 96)),
              ),
            ),
          ),
        ],
      );
    }

    final q = _qs[_i];
    String label(Word w) => (q.reverse || widget.listening) ? w.de : w.meaning(lang);
    final prompt = widget.listening
        ? context.tr('what_heard')
        : q.reverse
            ? context.tr('which_german')
            : context.tr('what_means');

    return UdPage(
      title: prompt,
      subtitle: context.tr('question', {'a': '${_i + 1}', 'b': '${_qs.length}'}),
      dock: _picked == null
          ? null
          : UdDock(
              label: _i == _qs.length - 1 ? context.tr('finish') : context.tr('next'),
              icon: Icons.arrow_forward_rounded,
              onPressed: _next,
            ),
      slivers: [
        UdSliverPad(
          sliver: SliverList.list(children: [
            UdPressable(
              onTap: widget.listening || !q.reverse ? () => Voice.say(q.word.de) : null,
              color: t.accentSoft,
              padding: const EdgeInsets.symmetric(vertical: 34, horizontal: 20),
              child: Center(
                child: widget.listening
                    ? Icon(Icons.volume_up_rounded, size: 64, color: t.accent)
                    : Text(
                        q.reverse ? q.word.meaning(lang) : q.word.de,
                        textAlign: TextAlign.center,
                        style: text.headlineLarge,
                      ),
              ),
            ),
            const SizedBox(height: 18),
            for (final o in q.options)
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: UdPressable(
                  onTap: () => _pick(o),
                  borderRadius: 18,
                  color: _picked == null
                      ? t.card
                      : o == q.word
                          ? const Color(0xFF2F7D4F).withValues(alpha: 0.16)
                          : o == _picked
                              ? t.danger.withValues(alpha: 0.14)
                              : t.card,
                  padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
                  child: Row(
                    children: [
                      Expanded(child: Text(label(o), style: text.titleMedium)),
                      if (_picked != null && o == q.word)
                        const Icon(Icons.check_circle_rounded, color: Color(0xFF2F7D4F)),
                      if (_picked != null && o == _picked && o != q.word)
                        Icon(Icons.cancel_rounded, color: t.danger),
                    ],
                  ),
                ),
              ),
            if (_picked != null)
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Text(
                  _picked == q.word
                      ? context.tr('correct')
                      : context.tr('wrong', {'a': '${q.word.de} = ${q.word.meaning(lang)}'}),
                  style: text.titleMedium?.copyWith(
                      color: _picked == q.word ? const Color(0xFF2F7D4F) : t.danger),
                ),
              ),
          ]),
        ),
      ],
    );
  }
}
