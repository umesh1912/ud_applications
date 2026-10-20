import 'dart:async';
import 'dart:ui' show FontFeature;

import 'package:flutter/material.dart';

import '../data/models.dart';
import '../data/sample_data.dart';
import '../state/app_state.dart';
import '../theme/tokens.dart';
import '../widgets/common.dart';
import 'test_result_screen.dart';

/// Timed test runner with question palette, mark-for-review,
/// auto-submit at zero and negative marking.
class TestRunnerScreen extends StatefulWidget {
  const TestRunnerScreen({super.key, required this.test});

  final MockTest test;

  @override
  State<TestRunnerScreen> createState() => _TestRunnerScreenState();
}

class _TestRunnerScreenState extends State<TestRunnerScreen> {
  late final List<Question> _qs = widget.test.questionIds.map(SampleData.question).toList();
  final Map<String, int> _answers = {};
  final Set<String> _review = {};
  int _i = 0;
  late int _secondsLeft = widget.test.minutes * 60;
  Timer? _timer;
  bool _submitted = false;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (_secondsLeft <= 1) {
        _submit(auto: true);
      } else {
        setState(() => _secondsLeft--);
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _submit({bool auto = false}) {
    if (_submitted) return;
    _submitted = true;
    _timer?.cancel();
    final t = widget.test;
    var score = 0;
    for (final q in _qs) {
      final c = _answers[q.id];
      if (c == null) continue;
      score += c == q.correct ? t.marksCorrect : t.marksWrong;
    }
    final attempt = TestAttempt(
      testId: t.id,
      title: t.title,
      date: DateTime.now(),
      answers: Map.of(_answers),
      questionIds: t.questionIds,
      score: score,
      maxMarks: t.maxMarks,
      secondsUsed: t.minutes * 60 - _secondsLeft,
    );
    AppScope.read(context).recordAttempt(attempt);
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (_) => TestResultScreen(test: t, attempt: attempt, timedOut: auto)),
    );
  }

  Future<void> _confirmSubmit() async {
    final unanswered = _qs.length - _answers.length;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Submit test?'),
        content: Text(unanswered == 0
            ? 'You\'ve answered every question.'
            : '$unanswered question${unanswered == 1 ? '' : 's'} not answered. Unanswered questions score zero.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Keep going')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Submit')),
        ],
      ),
    );
    if (ok == true) _submit();
  }

  Future<bool> _confirmLeave() async {
    final leave = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Leave this test?'),
        content: const Text('Your answers won\'t be saved and the attempt won\'t count.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Stay')),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Leave test')),
        ],
      ),
    );
    return leave ?? false;
  }

  @override
  Widget build(BuildContext context) {
    final q = _qs[_i];
    final vc = context.vc;
    final low = _secondsLeft <= 60;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;
        final nav = Navigator.of(context);
        if (await _confirmLeave()) {
          _timer?.cancel();
          nav.pop();
        }
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text(widget.test.title, style: context.text.titleSmall, maxLines: 1, overflow: TextOverflow.ellipsis),
          actions: [
            Semantics(
              liveRegion: low,
              label: 'Time left ${formatDuration(_secondsLeft)}',
              child: Container(
                margin: const EdgeInsets.only(right: Space.l),
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: low ? Palette.wrong : vc.highlight,
                  borderRadius: BorderRadius.circular(Radii.pill),
                ),
                child: Row(
                  children: [
                    Icon(Icons.timer_outlined, size: 16, color: low ? Colors.white : vc.highlightInk),
                    const SizedBox(width: 4),
                    Text(
                      formatDuration(_secondsLeft),
                      style: context.text.labelLarge!.copyWith(
                        color: low ? Colors.white : vc.highlightInk,
                        fontFeatures: const [FontFeature.tabularFigures()],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
        body: Column(
          children: [
            // Question palette
            SizedBox(
              height: 52,
              child: ListView.separated(
                padding: const EdgeInsets.symmetric(horizontal: Space.gutter, vertical: Space.s),
                scrollDirection: Axis.horizontal,
                itemCount: _qs.length,
                separatorBuilder: (_, __) => const SizedBox(width: Space.s),
                itemBuilder: (context, i) {
                  final id = _qs[i].id;
                  final answered = _answers.containsKey(id);
                  final review = _review.contains(id);
                  final current = i == _i;
                  final Color bg = review
                      ? Palette.review
                      : answered
                          ? vc.ink
                          : vc.sheet;
                  final Color fg = (review || answered) ? vc.paper : vc.ink;
                  return Semantics(
                    button: true,
                    label: 'Question ${i + 1}${answered ? ', answered' : ''}${review ? ', marked for review' : ''}',
                    child: InkWell(
                      onTap: () => setState(() => _i = i),
                      borderRadius: BorderRadius.circular(Radii.tile),
                      child: Container(
                        width: 36,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: bg,
                          borderRadius: BorderRadius.circular(Radii.tile),
                          border: Border.all(color: current ? vc.highlight : vc.rule, width: current ? 3 : 1),
                        ),
                        child: Text('${i + 1}', style: context.text.labelMedium!.copyWith(color: fg)),
                      ),
                    ),
                  );
                },
              ),
            ),
            Divider(height: 1, color: vc.rule),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(Space.gutter, Space.l, Space.gutter, Space.l),
                children: [
                  Row(
                    children: [
                      SubjectMark(q.subjectId, size: 24),
                      const SizedBox(width: Space.s),
                      Text('Question ${_i + 1} of ${_qs.length}', style: context.text.labelMedium),
                    ],
                  ),
                  const SizedBox(height: Space.m),
                  Text(q.text, style: context.text.titleLarge),
                  const SizedBox(height: Space.l),
                  for (var o = 0; o < q.options.length; o++)
                    Padding(
                      padding: const EdgeInsets.only(bottom: Space.s),
                      child: _OptionTile(
                        letter: String.fromCharCode(65 + o),
                        text: q.options[o],
                        selected: _answers[q.id] == o,
                        onTap: () => setState(() {
                          if (_answers[q.id] == o) {
                            _answers.remove(q.id); // tap again to clear
                          } else {
                            _answers[q.id] = o;
                          }
                        }),
                      ),
                    ),
                  const SizedBox(height: Space.s),
                  Text('Tap a selected option again to clear it.', style: context.text.bodySmall),
                ],
              ),
            ),
          ],
        ),
        bottomNavigationBar: SafeArea(
          child: Container(
            decoration: BoxDecoration(color: vc.sheet, border: Border(top: BorderSide(color: vc.rule))),
            padding: const EdgeInsets.fromLTRB(Space.m, Space.s, Space.m, Space.s),
            child: Row(
              children: [
                IconButton(
                  tooltip: 'Previous question',
                  onPressed: _i == 0 ? null : () => setState(() => _i--),
                  icon: const Icon(Icons.chevron_left),
                ),
                TextButton.icon(
                  onPressed: () => setState(() {
                    if (!_review.remove(q.id)) _review.add(q.id);
                  }),
                  icon: Icon(_review.contains(q.id) ? Icons.flag : Icons.outlined_flag, color: Palette.review),
                  label: Text(_review.contains(q.id) ? 'Marked' : 'Review later'),
                ),
                const Spacer(),
                if (_i < _qs.length - 1)
                  FilledButton(
                    style: FilledButton.styleFrom(minimumSize: const Size(96, 46)),
                    onPressed: () => setState(() => _i++),
                    child: const Text('Next'),
                  )
                else
                  FilledButton(
                    style: FilledButton.styleFrom(minimumSize: const Size(96, 46)),
                    onPressed: _confirmSubmit,
                    child: const Text('Submit'),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _OptionTile extends StatelessWidget {
  const _OptionTile({required this.letter, required this.text, required this.selected, required this.onTap});

  final String letter;
  final String text;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final vc = context.vc;
    return Semantics(
      selected: selected,
      button: true,
      child: AnimatedContainer(
        duration: Motion.quick,
        decoration: BoxDecoration(
          color: selected ? vc.ink : vc.sheet,
          borderRadius: BorderRadius.circular(Radii.card),
          border: Border.all(color: selected ? vc.ink : vc.rule, width: 1.4),
        ),
        child: Material(
          type: MaterialType.transparency,
          child: InkWell(
            borderRadius: BorderRadius.circular(Radii.card),
            onTap: onTap,
            child: Padding(
              padding: const EdgeInsets.all(Space.l),
              child: Row(
                children: [
                  Container(
                    width: 28,
                    height: 28,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: selected ? vc.highlight : Colors.transparent,
                      shape: BoxShape.circle,
                      border: Border.all(color: selected ? vc.highlight : vc.rule),
                    ),
                    child: Text(letter,
                        style: context.text.labelMedium!.copyWith(color: selected ? vc.highlightInk : vc.ink)),
                  ),
                  const SizedBox(width: Space.m),
                  Expanded(
                    child: Text(text,
                        style: context.text.bodyLarge!.copyWith(color: selected ? vc.paper : vc.ink)),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
