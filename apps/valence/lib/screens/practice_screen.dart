import 'package:flutter/material.dart';

import '../data/models.dart';
import '../data/sample_data.dart';
import '../state/app_state.dart';
import '../theme/tokens.dart';
import '../widgets/common.dart';
import '../widgets/graph_paper.dart';
import '../widgets/score_chart.dart';
import 'analytics_screen.dart';
import 'test_runner_screen.dart';

/// Exam preparation hub: pick an exam, see what carries the most marks,
/// then take mock tests, chapter tests or past papers.
class PracticeScreen extends StatefulWidget {
  const PracticeScreen({super.key});

  @override
  State<PracticeScreen> createState() => _PracticeScreenState();
}

class _PracticeScreenState extends State<PracticeScreen> {
  String? _exam;

  static const exams = ['Boards', 'JEE', 'NEET'];

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    final exam = _exam ?? (exams.contains(state.profile.goal) ? state.profile.goal : 'Boards');
    final tests = SampleData.tests.where((t) => t.exam == exam).toList();

    // Top chapters by weightage for this exam.
    final weighted = <(Chapter, Subject)>[
      for (final s in SampleData.subjects)
        for (final c in s.chapters)
          if (c.weightage[exam] != null) (c, s),
    ]..sort((a, b) => b.$1.weightage[exam]!.compareTo(a.$1.weightage[exam]!));
    final maxW = weighted.isEmpty ? 1 : weighted.first.$1.weightage[exam]!;

    final last = state.attempts.isEmpty ? null : state.attempts.last;

    return GraphPaper(
      child: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(Space.gutter, Space.l, Space.gutter, Space.xxl),
          children: [
            Text('Practice', style: context.text.headlineMedium),
            const SizedBox(height: Space.l),
            SegmentedButton<String>(
              segments: [for (final e in exams) ButtonSegment(value: e, label: Text(e))],
              selected: {exam},
              showSelectedIcon: false,
              onSelectionChanged: (v) => setState(() => _exam = v.first),
            ),

            if (last != null) ...[
              const SizedBox(height: Space.l),
              PaperCard(
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const AnalyticsScreen()),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Last test', style: context.text.bodySmall),
                          Text('${last.score} / ${last.maxMarks}', style: context.text.headlineSmall),
                          Text(last.title, style: context.text.bodySmall, maxLines: 1, overflow: TextOverflow.ellipsis),
                        ],
                      ),
                    ),
                    Text('See analysis', style: context.text.labelMedium),
                    const Icon(Icons.chevron_right),
                  ],
                ),
              ),
            ],

            const SectionTitle('Where the marks are'),
            Text(
              'Approximate share of $exam marks by chapter. Start at the top.',
              style: context.text.bodySmall,
            ),
            const SizedBox(height: Space.s),
            PaperCard(
              child: Column(
                children: [
                  for (final (c, s) in weighted.take(6))
                    MeterRow(
                      label: c.title,
                      value: c.weightage[exam]! / maxW,
                      color: s.color,
                      trailing: '~${c.weightage[exam]}%',
                    ),
                ],
              ),
            ),

            const SectionTitle('Tests'),
            if (tests.isEmpty)
              const EmptyNote(title: 'No tests yet', body: 'New tests for this exam are added every week.')
            else
              for (final t in tests)
                Padding(
                  padding: const EdgeInsets.only(bottom: Space.s),
                  child: _TestCard(test: t, attempts: state.attempts.where((a) => a.testId == t.id).length),
                ),
          ],
        ),
      ),
    );
  }
}

class _TestCard extends StatelessWidget {
  const _TestCard({required this.test, required this.attempts});

  final MockTest test;
  final int attempts;

  @override
  Widget build(BuildContext context) {
    final vc = context.vc;
    final marking = test.marksWrong == 0
        ? '+${test.marksCorrect} per correct · no negative marking'
        : '+${test.marksCorrect} correct · ${test.marksWrong} wrong';
    return PaperCard(
      onTap: () => _confirmStart(context),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(test.kind, style: context.text.labelSmall),
              const Spacer(),
              if (attempts > 0) Text('Attempted $attempts×', style: context.text.labelSmall),
            ],
          ),
          const SizedBox(height: Space.xs),
          Text(test.title, style: context.text.titleMedium),
          const SizedBox(height: Space.s),
          Wrap(
            spacing: Space.l,
            runSpacing: Space.xs,
            children: [
              _Fact(icon: Icons.timer_outlined, text: '${test.minutes} min'),
              _Fact(icon: Icons.format_list_numbered, text: '${test.questionIds.length} questions'),
              _Fact(icon: Icons.score_outlined, text: '${test.maxMarks} marks'),
            ],
          ),
          const SizedBox(height: Space.xs),
          Text(marking, style: context.text.bodySmall!.copyWith(color: vc.muted)),
        ],
      ),
    );
  }

  void _confirmStart(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(Space.gutter, 0, Space.gutter, Space.l),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(test.title, style: ctx.text.headlineSmall),
              const SizedBox(height: Space.m),
              Text(
                '${test.questionIds.length} questions in ${test.minutes} minutes. The timer starts when you tap Start. '
                '${test.marksWrong == 0 ? 'Wrong answers don\'t lose marks.' : 'Each wrong answer costs ${-test.marksWrong} mark — skip if unsure.'}',
                style: ctx.text.bodyMedium,
              ),
              const SizedBox(height: Space.xl),
              FilledButton(
                style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(52)),
                onPressed: () {
                  Navigator.of(ctx).pop();
                  Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => TestRunnerScreen(test: test)),
                  );
                },
                child: const Text('Start test'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Fact extends StatelessWidget {
  const _Fact({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 16, color: context.vc.muted),
        const SizedBox(width: 4),
        Text(text, style: context.text.bodyMedium),
      ],
    );
  }
}
