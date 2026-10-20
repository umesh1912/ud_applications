import 'package:flutter/material.dart';

import '../data/sample_data.dart';
import '../state/app_state.dart';
import '../theme/tokens.dart';
import '../widgets/common.dart';
import '../widgets/graph_paper.dart';
import 'doubts_screen.dart';
import 'lesson_screen.dart';
import 'planner_screen.dart';
import 'shell.dart';

class TodayScreen extends StatelessWidget {
  const TodayScreen({super.key, required this.onOpenTab});

  final ValueChanged<int> onOpenTab;

  String _greeting() {
    final h = DateTime.now().hour;
    if (h < 12) return 'Good morning';
    if (h < 17) return 'Good afternoon';
    return 'Good evening';
  }

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    final vc = context.vc;
    final today = state.sessionsFor(DateTime.now().weekday);
    final done = today.where((s) => s.done).length;
    final lastTopic = state.lastTopicId == null ? null : SampleData.topic(state.lastTopicId!);
    final weak = state.weakTopics();
    final name = state.profile.name.isEmpty ? '' : ', ${state.profile.name}';

    return GraphPaper(
      child: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(Space.gutter, Space.l, Space.gutter, Space.xxl),
          children: [
            Row(
              children: [
                Expanded(
                  child: Text('${_greeting()}$name', style: context.text.headlineMedium),
                ),
                IconButton.filledTonal(
                  tooltip: 'Ask a doubt',
                  onPressed: () => Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const DoubtsScreen(startAsking: true)),
                  ),
                  icon: const Icon(Icons.help_outline),
                ),
              ],
            ),
            const SizedBox(height: Space.l),

            // Countdown + streak — the "lab bench" readout.
            Row(
              children: [
                Expanded(
                  child: _Readout(
                    value: '${state.daysToExam}',
                    label: 'days to ${state.profile.goal}',
                  ),
                ),
                const SizedBox(width: Space.m),
                Expanded(
                  child: _Readout(
                    value: '${state.streakDays}',
                    label: 'day study streak',
                    highlight: true,
                  ),
                ),
              ],
            ),

            SectionTitle(
              'Today\'s plan',
              action: 'Planner',
              onAction: () => Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const PlannerScreen()),
              ),
            ),
            if (today.isEmpty)
              PaperCard(
                child: EmptyNote(
                  icon: Icons.event_available_outlined,
                  title: 'Nothing planned for today',
                  body: 'Add a study session and we\'ll remind you when it\'s time.',
                  action: 'Add a session',
                  onAction: () => Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const PlannerScreen()),
                  ),
                ),
              )
            else ...[
              Text('$done of ${today.length} done', style: context.text.bodySmall),
              const SizedBox(height: Space.s),
              PaperCard(
                padding: EdgeInsets.zero,
                child: Column(
                  children: [
                    for (var i = 0; i < today.length; i++) ...[
                      if (i > 0) Divider(height: 1, color: vc.rule),
                      CheckboxListTile(
                        value: today[i].done,
                        onChanged: (_) => state.toggleSessionDone(today[i]),
                        controlAffinity: ListTileControlAffinity.leading,
                        secondary: SubjectMark(today[i].subjectId, size: 28),
                        title: Text(
                          today[i].label,
                          style: context.text.titleSmall!.copyWith(
                            decoration: today[i].done ? TextDecoration.lineThrough : null,
                            color: today[i].done ? vc.muted : null,
                          ),
                        ),
                        subtitle: Text('${formatTime(today[i].start)} · ${today[i].minutes} min'),
                      ),
                    ],
                  ],
                ),
              ),
            ],

            if (lastTopic != null) ...[
              const SectionTitle('Pick up where you left off'),
              PaperCard(
                borderColor: SampleData.subject(lastTopic.subjectId).color,
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => LessonScreen(topicId: lastTopic.id)),
                ),
                child: Row(
                  children: [
                    SubjectMark(lastTopic.subjectId, size: 44),
                    const SizedBox(width: Space.m),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(lastTopic.title, style: context.text.titleMedium),
                          const SizedBox(height: 2),
                          Text(
                            '${SampleData.subject(lastTopic.subjectId).name} · ${lastTopic.minutes} min · ${lastTopic.examples.length} solved examples',
                            style: context.text.bodySmall,
                          ),
                        ],
                      ),
                    ),
                    const Icon(Icons.play_circle_fill, size: 36),
                  ],
                ),
              ),
            ],

            SectionTitle(
              'Weak spots',
              action: 'All subjects',
              onAction: () => onOpenTab(Tabs.subjects),
            ),
            if (weak.isEmpty)
              PaperCard(
                child: EmptyNote(
                  icon: Icons.insights_outlined,
                  title: 'Take a test to find weak spots',
                  body: 'We\'ll list the topics you get wrong most often here.',
                  action: 'Go to practice',
                  onAction: () => onOpenTab(Tabs.practice),
                ),
              )
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
                        Text('Revise', style: context.text.labelMedium),
                        const Icon(Icons.chevron_right),
                      ],
                    ),
                  ),
                ),
          ],
        ),
      ),
    );
  }
}

class _Readout extends StatelessWidget {
  const _Readout({required this.value, required this.label, this.highlight = false});

  final String value;
  final String label;
  final bool highlight;

  @override
  Widget build(BuildContext context) {
    final vc = context.vc;
    final fg = highlight ? vc.highlightInk : vc.ink;
    return PaperCard(
      color: highlight ? vc.highlight : vc.sheet,
      borderColor: highlight ? vc.highlight : vc.rule,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(value, style: context.text.displaySmall!.copyWith(color: fg)),
          Text(label, style: context.text.bodySmall!.copyWith(color: fg.withValues(alpha: 0.8))),
        ],
      ),
    );
  }
}
