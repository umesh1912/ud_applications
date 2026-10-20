import 'package:flutter/material.dart';

import '../data/models.dart';
import '../data/sample_data.dart';
import '../state/app_state.dart';
import '../theme/tokens.dart';
import '../widgets/common.dart';
import 'lesson_screen.dart';
import 'test_runner_screen.dart';

class TestResultScreen extends StatefulWidget {
  const TestResultScreen({super.key, required this.test, required this.attempt, this.timedOut = false});

  final MockTest test;
  final TestAttempt attempt;
  final bool timedOut;

  @override
  State<TestResultScreen> createState() => _TestResultScreenState();
}

class _TestResultScreenState extends State<TestResultScreen> {
  String _filter = 'All';

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    final vc = context.vc;
    final a = widget.attempt;
    final qs = a.questionIds.map(SampleData.question).toList();
    final right = qs.where((q) => a.answers[q.id] == q.correct).length;
    final wrong = qs.where((q) => a.answers[q.id] != null && a.answers[q.id] != q.correct).length;
    final skipped = qs.length - right - wrong;
    final attempted = right + wrong;
    final accuracy = attempted == 0 ? 0 : (right / attempted * 100).round();
    final lostToNegative = wrong * -widget.test.marksWrong;

    final shown = switch (_filter) {
      'Wrong' => qs.where((q) => a.answers[q.id] != null && a.answers[q.id] != q.correct).toList(),
      'Skipped' => qs.where((q) => a.answers[q.id] == null).toList(),
      _ => qs,
    };

    return Scaffold(
      appBar: AppBar(title: const Text('Result')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(Space.gutter, 0, Space.gutter, Space.xxl),
        children: [
          if (widget.timedOut)
            Padding(
              padding: const EdgeInsets.only(bottom: Space.m),
              child: Text('Time ran out, so we submitted your answers automatically.', style: context.text.bodySmall),
            ),
          Text(widget.test.title, style: context.text.titleMedium!.copyWith(color: vc.muted)),
          const SizedBox(height: Space.s),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text('${a.score}', style: context.text.displayLarge),
              Padding(
                padding: const EdgeInsets.only(bottom: 8, left: 6),
                child: Text('/ ${a.maxMarks}', style: context.text.headlineSmall!.copyWith(color: vc.muted)),
              ),
              const Spacer(),
              Highlighted('${(a.percent * 100).round()}%', style: context.text.headlineSmall),
            ],
          ),
          const SizedBox(height: Space.l),
          PaperCard(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _Stat('$right', 'Correct', Palette.correct),
                _Stat('$wrong', 'Wrong', Palette.wrong),
                _Stat('$skipped', 'Skipped', vc.muted),
                _Stat('$accuracy%', 'Accuracy', vc.ink),
                _Stat(formatDuration(a.secondsUsed), 'Time', vc.ink),
              ],
            ),
          ),
          if (lostToNegative > 0) ...[
            const SizedBox(height: Space.m),
            Text(
              'Negative marking cost you $lostToNegative mark${lostToNegative == 1 ? '' : 's'}. If you can\'t rule out two options, skipping is usually safer.',
              style: context.text.bodyMedium,
            ),
          ],
          const SizedBox(height: Space.l),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () => Navigator.of(context).pushReplacement(
                    MaterialPageRoute(builder: (_) => TestRunnerScreen(test: widget.test)),
                  ),
                  child: const Text('Retake'),
                ),
              ),
              const SizedBox(width: Space.m),
              Expanded(
                child: FilledButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Done'),
                ),
              ),
            ],
          ),
          const SectionTitle('Review answers'),
          PillChoice(
            options: const ['All', 'Wrong', 'Skipped'],
            selected: _filter,
            onSelected: (v) => setState(() => _filter = v),
          ),
          const SizedBox(height: Space.m),
          if (shown.isEmpty)
            EmptyNote(
              icon: Icons.task_alt,
              title: _filter == 'Wrong' ? 'No wrong answers' : 'Nothing skipped',
              body: 'Switch to All to review every question.',
            ),
          for (final q in shown)
            Padding(
              padding: const EdgeInsets.only(bottom: Space.m),
              child: _ReviewCard(
                question: q,
                chosen: a.answers[q.id],
                number: qs.indexOf(q) + 1,
                bookmarked: state.isQuestionBookmarked(q.id),
                onBookmark: () => state.toggleQuestionBookmark(q.id),
              ),
            ),
        ],
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat(this.value, this.label, this.color);

  final String value;
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(value, style: context.text.titleLarge!.copyWith(color: color)),
        Text(label, style: context.text.labelSmall),
      ],
    );
  }
}

class _ReviewCard extends StatelessWidget {
  const _ReviewCard({
    required this.question,
    required this.chosen,
    required this.number,
    required this.bookmarked,
    required this.onBookmark,
  });

  final Question question;
  final int? chosen;
  final int number;
  final bool bookmarked;
  final VoidCallback onBookmark;

  @override
  Widget build(BuildContext context) {
    final vc = context.vc;
    final q = question;
    final isRight = chosen == q.correct;
    final status = chosen == null ? 'Skipped' : (isRight ? 'Correct' : 'Wrong');
    final statusColor = chosen == null ? vc.muted : (isRight ? Palette.correct : Palette.wrong);

    return PaperCard(
      borderColor: chosen == null ? vc.rule : statusColor.withValues(alpha: 0.6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text('Q$number', style: context.text.labelMedium),
              const SizedBox(width: Space.s),
              Text(status, style: context.text.labelMedium!.copyWith(color: statusColor)),
              const Spacer(),
              IconButton(
                visualDensity: VisualDensity.compact,
                tooltip: bookmarked ? 'Remove from Revise later' : 'Save to Revise later',
                onPressed: onBookmark,
                icon: Icon(bookmarked ? Icons.bookmark : Icons.bookmark_border, size: 20),
              ),
            ],
          ),
          Text(q.text, style: context.text.titleSmall),
          const SizedBox(height: Space.s),
          for (var o = 0; o < q.options.length; o++)
            Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Row(
                children: [
                  Icon(
                    o == q.correct
                        ? Icons.check_circle
                        : (o == chosen ? Icons.cancel : Icons.circle_outlined),
                    size: 18,
                    color: o == q.correct ? Palette.correct : (o == chosen ? Palette.wrong : vc.rule),
                  ),
                  const SizedBox(width: Space.s),
                  Expanded(
                    child: Text(
                      q.options[o],
                      style: context.text.bodyMedium!.copyWith(
                        fontWeight: o == q.correct || o == chosen ? FontWeight.w700 : null,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          const SizedBox(height: Space.s),
          Text(q.explanation, style: context.text.bodyMedium!.copyWith(color: vc.muted)),
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton(
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => LessonScreen(topicId: q.topicId)),
              ),
              child: Text('Open topic: ${SampleData.topic(q.topicId)?.title ?? ''}'),
            ),
          ),
        ],
      ),
    );
  }
}
