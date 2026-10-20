import 'package:flutter/material.dart';

import '../data/models.dart';
import '../data/sample_data.dart';
import '../state/app_state.dart';
import '../theme/tokens.dart';
import '../widgets/common.dart';
import '../widgets/element_tile.dart';
import '../widgets/graph_paper.dart';
import 'lesson_screen.dart';

/// Subjects laid out as a small periodic table.
class SubjectsScreen extends StatefulWidget {
  const SubjectsScreen({super.key});

  @override
  State<SubjectsScreen> createState() => _SubjectsScreenState();
}

class _SubjectsScreenState extends State<SubjectsScreen> {
  String _query = '';

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    final results = _query.length < 2
        ? <Topic>[]
        : SampleData.subjects
            .expand((s) => s.topics)
            .where((t) => t.title.toLowerCase().contains(_query.toLowerCase()) ||
                t.notes.any((n) => n.toLowerCase().contains(_query.toLowerCase())))
            .toList();

    return GraphPaper(
      child: SafeArea(
        child: CustomScrollView(
          slivers: [
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(Space.gutter, Space.l, Space.gutter, 0),
              sliver: SliverList.list(children: [
                Text('Subjects', style: context.text.headlineMedium),
                const SizedBox(height: Space.l),
                TextField(
                  onChanged: (v) => setState(() => _query = v.trim()),
                  decoration: const InputDecoration(
                    prefixIcon: Icon(Icons.search),
                    hintText: 'Search topics, e.g. "chain rule"',
                  ),
                ),
                const SizedBox(height: Space.l),
              ]),
            ),
            if (_query.length >= 2)
              SliverPadding(
                padding: const EdgeInsets.symmetric(horizontal: Space.gutter),
                sliver: results.isEmpty
                    ? SliverToBoxAdapter(
                        child: EmptyNote(
                          icon: Icons.search_off,
                          title: 'No topics match "$_query"',
                          body: 'Try a shorter word, or browse a subject below.',
                        ),
                      )
                    : SliverList.separated(
                        itemCount: results.length,
                        separatorBuilder: (_, __) => const SizedBox(height: Space.s),
                        itemBuilder: (context, i) => _TopicRow(topic: results[i], showSubject: true),
                      ),
              )
            else
              SliverPadding(
                padding: const EdgeInsets.symmetric(horizontal: Space.gutter),
                sliver: SliverGrid.count(
                  crossAxisCount: 2,
                  mainAxisSpacing: Space.m,
                  crossAxisSpacing: Space.m,
                  childAspectRatio: 0.92,
                  children: [
                    for (final s in SampleData.subjects)
                      ElementTile(
                        subject: s,
                        progress: state.subjectProgress(s),
                        onTap: () => Navigator.of(context).push(
                          MaterialPageRoute(builder: (_) => SubjectScreen(subjectId: s.id)),
                        ),
                      ),
                  ],
                ),
              ),
            const SliverToBoxAdapter(child: SizedBox(height: Space.xxl)),
          ],
        ),
      ),
    );
  }
}

class SubjectScreen extends StatelessWidget {
  const SubjectScreen({super.key, required this.subjectId});

  final String subjectId;

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    final s = SampleData.subject(subjectId);
    final vc = context.vc;
    final progress = state.subjectProgress(s);
    final goal = state.profile.goal;

    return Scaffold(
      appBar: AppBar(title: Text(s.name)),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(Space.gutter, 0, Space.gutter, Space.xxl),
        children: [
          Row(
            children: [
              SizedBox(
                width: 96,
                height: 104,
                child: ElementTile(subject: s, progress: progress, compact: true),
              ),
              const SizedBox(width: Space.l),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('${(progress * 100).round()}% complete', style: context.text.titleLarge),
                    const SizedBox(height: Space.xs),
                    Text(
                      '${s.chapters.length} chapters · ${s.topicCount} topics',
                      style: context.text.bodyMedium!.copyWith(color: vc.muted),
                    ),
                  ],
                ),
              ),
            ],
          ),
          for (final c in s.chapters) ...[
            Padding(
              padding: const EdgeInsets.only(top: Space.xl, bottom: Space.s),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Expanded(child: Text(c.title, style: context.text.titleLarge)),
                  if (c.weightage[goal] != null)
                    Tooltip(
                      message: 'Approximate share of marks in $goal',
                      child: Text('~${c.weightage[goal]}% of $goal', style: context.text.labelSmall),
                    ),
                ],
              ),
            ),
            for (final t in c.topics)
              Padding(
                padding: const EdgeInsets.only(bottom: Space.s),
                child: _TopicRow(topic: t),
              ),
          ],
        ],
      ),
    );
  }
}

class _TopicRow extends StatelessWidget {
  const _TopicRow({required this.topic, this.showSubject = false});

  final Topic topic;
  final bool showSubject;

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    final done = state.completedTopics.contains(topic.id);
    final color = SampleData.subject(topic.subjectId).color;
    final vc = context.vc;

    return PaperCard(
      padding: const EdgeInsets.symmetric(horizontal: Space.l, vertical: Space.m),
      onTap: () => Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => LessonScreen(topicId: topic.id)),
      ),
      child: Row(
        children: [
          if (showSubject) ...[SubjectMark(topic.subjectId, size: 28), const SizedBox(width: Space.m)],
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(topic.title, style: context.text.titleSmall),
                const SizedBox(height: 2),
                Text(
                  '${topic.minutes} min · ${topic.examples.length} solved example${topic.examples.length == 1 ? '' : 's'}',
                  style: context.text.bodySmall,
                ),
              ],
            ),
          ),
          if (state.isTopicBookmarked(topic.id))
            Padding(
              padding: const EdgeInsets.only(right: Space.s),
              child: Icon(Icons.bookmark, size: 18, color: vc.muted),
            ),
          Icon(
            done ? Icons.check_circle : Icons.radio_button_unchecked,
            color: done ? color : vc.rule,
            semanticLabel: done ? 'Completed' : 'Not started',
          ),
        ],
      ),
    );
  }
}
