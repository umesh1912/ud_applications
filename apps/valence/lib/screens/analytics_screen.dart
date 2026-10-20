import 'package:flutter/material.dart';

import '../data/sample_data.dart';
import '../state/app_state.dart';
import '../theme/tokens.dart';
import '../widgets/common.dart';
import '../widgets/score_chart.dart';
import 'lesson_screen.dart';

class AnalyticsScreen extends StatelessWidget {
  const AnalyticsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    final vc = context.vc;
    final attempts = state.attempts;
    final acc = state.subjectAccuracy();
    final weak = state.weakTopics(limit: 4);
    final avg = attempts.isEmpty
        ? null
        : attempts.map((a) => a.percent).reduce((x, y) => x + y) / attempts.length;
    final best = attempts.isEmpty ? null : attempts.map((a) => a.percent).reduce((x, y) => x > y ? x : y);
    final topicsDone = state.completedTopics.length;
    final topicsAll = SampleData.subjects.fold<int>(0, (n, s) => n + s.topicCount);

    return Scaffold(
      appBar: AppBar(title: const Text('Your progress')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(Space.gutter, 0, Space.gutter, Space.xxl),
        children: [
          Row(
            children: [
              Expanded(child: _Big(value: avg == null ? '—' : '${(avg * 100).round()}%', label: 'Average score')),
              Expanded(child: _Big(value: best == null ? '—' : '${(best * 100).round()}%', label: 'Best score')),
              Expanded(child: _Big(value: '$topicsDone/$topicsAll', label: 'Topics done')),
            ],
          ),
          const SectionTitle('Score trend'),
          PaperCard(
            child: attempts.isEmpty
                ? const EmptyNote(title: 'No tests yet', body: 'Your scores will be plotted here after your first test.')
                : ScoreChart(values: attempts.map((a) => a.percent).toList()),
          ),
          const SectionTitle('Accuracy by subject'),
          PaperCard(
            child: Column(
              children: [
                for (final s in SampleData.subjects)
                  MeterRow(label: s.name, value: acc[s.id], color: s.color),
              ],
            ),
          ),
          const SizedBox(height: Space.s),
          Text('A dash means you haven\'t answered questions in that subject yet.', style: context.text.bodySmall),
          const SectionTitle('Revise next'),
          if (weak.isEmpty)
            Text('Nothing flagged yet. Take a test and we\'ll point out what to revise.',
                style: context.text.bodyMedium!.copyWith(color: vc.muted))
          else
            for (final t in weak)
              Padding(
                padding: const EdgeInsets.only(bottom: Space.s),
                child: PaperCard(
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => LessonScreen(topicId: t.id)),
                  ),
                  child: Row(
                    children: [
                      SubjectMark(t.subjectId),
                      const SizedBox(width: Space.m),
                      Expanded(child: Text(t.title, style: context.text.titleSmall)),
                      const Icon(Icons.chevron_right),
                    ],
                  ),
                ),
              ),
          const SectionTitle('Test history'),
          for (final a in attempts.reversed)
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(a.title, style: context.text.titleSmall),
              subtitle: Text('${relativeDay(a.date)} · ${formatDuration(a.secondsUsed)}'),
              trailing: Text('${a.score}/${a.maxMarks}', style: context.text.titleMedium),
            ),
        ],
      ),
    );
  }
}

class _Big extends StatelessWidget {
  const _Big({required this.value, required this.label});

  final String value;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(value, style: context.text.headlineMedium),
        Text(label, style: context.text.bodySmall),
      ],
    );
  }
}
