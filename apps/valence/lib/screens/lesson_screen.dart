import 'package:flutter/material.dart';

import '../data/models.dart';
import '../data/sample_data.dart';
import '../state/app_state.dart';
import '../theme/tokens.dart';
import '../widgets/common.dart';
import 'doubts_screen.dart';
import 'test_runner_screen.dart';

/// A topic: short notes → the key formula (highlighted) → solved examples
/// revealed one step at a time → actions.
class LessonScreen extends StatefulWidget {
  const LessonScreen({super.key, required this.topicId});

  final String topicId;

  @override
  State<LessonScreen> createState() => _LessonScreenState();
}

class _LessonScreenState extends State<LessonScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) AppScope.read(context).openTopic(widget.topicId);
    });
  }

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    final topic = SampleData.topic(widget.topicId)!;
    final subject = SampleData.subject(topic.subjectId);
    final vc = context.vc;
    final done = state.completedTopics.contains(topic.id);
    final bookmarked = state.isTopicBookmarked(topic.id);
    final practiceIds = SampleData.questions.where((q) => q.topicId == topic.id).map((q) => q.id).toList();

    return Scaffold(
      appBar: AppBar(
        title: Text(subject.name, style: context.text.titleMedium!.copyWith(color: subject.color)),
        actions: [
          IconButton(
            tooltip: bookmarked ? 'Remove from Revise later' : 'Save to Revise later',
            onPressed: () {
              state.toggleTopicBookmark(topic.id);
              ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                content: Text(bookmarked ? 'Removed from Revise later' : 'Saved to Revise later'),
              ));
            },
            icon: Icon(bookmarked ? Icons.bookmark : Icons.bookmark_border),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(Space.gutter, Space.s, Space.gutter, 120),
        children: [
          Text(topic.title, style: context.text.displaySmall),
          const SizedBox(height: Space.s),
          Text('${topic.minutes} min read', style: context.text.bodySmall),
          const SizedBox(height: Space.xl),

          // Notes, as a numbered sequence — they are meant to be read in order.
          for (var i = 0; i < topic.notes.length; i++)
            Padding(
              padding: const EdgeInsets.only(bottom: Space.l),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(
                    width: 28,
                    child: Text('${i + 1}', style: context.text.titleMedium!.copyWith(color: subject.color)),
                  ),
                  Expanded(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 560),
                      child: Text(topic.notes[i], style: context.text.bodyLarge),
                    ),
                  ),
                ],
              ),
            ),

          if (topic.keyFormula != null) ...[
            const SizedBox(height: Space.s),
            Text('Key formula', style: context.text.titleMedium),
            const SizedBox(height: Space.s),
            Highlighted(topic.keyFormula!, style: context.text.titleLarge),
            if (topic.formulaNote != null) ...[
              const SizedBox(height: Space.s),
              Text(topic.formulaNote!, style: context.text.bodySmall),
            ],
          ],

          if (topic.examples.isNotEmpty) ...[
            const SectionTitle('Solved examples'),
            for (var i = 0; i < topic.examples.length; i++)
              Padding(
                padding: const EdgeInsets.only(bottom: Space.m),
                child: _ExampleCard(example: topic.examples[i], index: i + 1, color: subject.color),
              ),
          ],

          const SizedBox(height: Space.l),
          Wrap(
            spacing: Space.s,
            runSpacing: Space.s,
            children: [
              if (practiceIds.isNotEmpty)
                OutlinedButton.icon(
                  onPressed: () {
                    final quick = MockTest(
                      id: 'quick-${topic.id}',
                      title: 'Practice: ${topic.title}',
                      exam: 'Practice',
                      kind: 'Topic practice',
                      minutes: practiceIds.length * 2,
                      marksCorrect: 1,
                      marksWrong: 0,
                      questionIds: practiceIds,
                    );
                    Navigator.of(context).push(
                      MaterialPageRoute(builder: (_) => TestRunnerScreen(test: quick)),
                    );
                  },
                  icon: const Icon(Icons.quiz_outlined),
                  label: Text('Practise ${practiceIds.length} question${practiceIds.length == 1 ? '' : 's'}'),
                ),
              OutlinedButton.icon(
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => DoubtsScreen(startAsking: true, subjectId: topic.subjectId, prefill: 'About "${topic.title}": '),
                  ),
                ),
                icon: const Icon(Icons.help_outline),
                label: const Text('Ask a doubt'),
              ),
            ],
          ),
        ],
      ),
      bottomNavigationBar: SafeArea(
        child: Container(
          decoration: BoxDecoration(
            color: vc.sheet,
            border: Border(top: BorderSide(color: vc.rule)),
          ),
          padding: const EdgeInsets.fromLTRB(Space.gutter, Space.m, Space.gutter, Space.m),
          child: FilledButton.icon(
            onPressed: () => state.toggleTopicDone(topic.id),
            icon: Icon(done ? Icons.check_circle : Icons.check),
            label: Text(done ? 'Completed — tap to undo' : 'Mark as completed'),
            style: done
                ? FilledButton.styleFrom(
                    minimumSize: const Size.fromHeight(52),
                    backgroundColor: subject.color,
                    foregroundColor: Colors.white,
                  )
                : FilledButton.styleFrom(minimumSize: const Size.fromHeight(52)),
          ),
        ),
      ),
    );
  }
}

/// Solved example with progressive reveal: students try each step
/// before seeing it — the "show next step" interaction.
class _ExampleCard extends StatefulWidget {
  const _ExampleCard({required this.example, required this.index, required this.color});

  final SolvedExample example;
  final int index;
  final Color color;

  @override
  State<_ExampleCard> createState() => _ExampleCardState();
}

class _ExampleCardState extends State<_ExampleCard> {
  int _shown = 0;

  @override
  Widget build(BuildContext context) {
    final e = widget.example;
    final vc = context.vc;
    final allShown = _shown >= e.steps.length;

    return PaperCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text('Example ${widget.index}', style: context.text.labelMedium!.copyWith(color: widget.color)),
              const SizedBox(width: Space.s),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  border: Border.all(color: vc.rule),
                  borderRadius: BorderRadius.circular(Radii.pill),
                ),
                child: Text(e.level, style: context.text.labelSmall),
              ),
            ],
          ),
          const SizedBox(height: Space.s),
          Text(e.question, style: context.text.titleMedium),
          const SizedBox(height: Space.m),
          AnimatedSize(
            duration: Motion.normal,
            curve: Motion.curve,
            alignment: Alignment.topCenter,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (var i = 0; i < _shown && i < e.steps.length; i++)
                  Padding(
                    padding: const EdgeInsets.only(bottom: Space.s),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          width: 22,
                          height: 22,
                          alignment: Alignment.center,
                          margin: const EdgeInsets.only(right: Space.s, top: 1),
                          decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: widget.color)),
                          child: Text('${i + 1}', style: context.text.labelSmall!.copyWith(color: widget.color)),
                        ),
                        Expanded(child: Text(e.steps[i], style: context.text.bodyMedium)),
                      ],
                    ),
                  ),
                if (allShown) ...[
                  const SizedBox(height: Space.xs),
                  Highlighted('Answer: ${e.answer}'),
                ],
              ],
            ),
          ),
          if (!allShown) ...[
            const SizedBox(height: Space.xs),
            Row(
              children: [
                TextButton.icon(
                  onPressed: () => setState(() => _shown++),
                  icon: const Icon(Icons.expand_more),
                  label: Text(_shown == 0 ? 'Show first step' : 'Show next step'),
                ),
                const Spacer(),
                TextButton(
                  onPressed: () => setState(() => _shown = e.steps.length),
                  child: const Text('Show all'),
                ),
              ],
            ),
          ] else
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                onPressed: () => setState(() => _shown = 0),
                child: const Text('Hide steps'),
              ),
            ),
        ],
      ),
    );
  }
}
