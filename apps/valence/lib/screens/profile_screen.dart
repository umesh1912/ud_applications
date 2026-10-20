import 'package:flutter/material.dart';

import '../data/models.dart';
import '../data/sample_data.dart';
import '../state/app_state.dart';
import '../theme/tokens.dart';
import '../widgets/common.dart';
import '../widgets/graph_paper.dart';
import 'analytics_screen.dart';
import 'doubts_screen.dart';
import 'lesson_screen.dart';
import 'library_screen.dart';
import 'planner_screen.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    final p = state.profile;
    final vc = context.vc;
    final initials = p.name.isEmpty ? '?' : p.name.trim().substring(0, 1).toUpperCase();

    void open(Widget page) => Navigator.of(context).push(MaterialPageRoute(builder: (_) => page));

    return GraphPaper(
      child: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(Space.gutter, Space.l, Space.gutter, Space.xxl),
          children: [
            Row(
              children: [
                // The student as an "element" too.
                Container(
                  width: 64,
                  height: 64,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: vc.highlight,
                    borderRadius: BorderRadius.circular(Radii.tile),
                    border: Border.all(color: vc.ink, width: 1.6),
                  ),
                  child: Text(initials, style: context.text.displaySmall!.copyWith(color: vc.highlightInk)),
                ),
                const SizedBox(width: Space.l),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(p.name.isEmpty ? 'Student' : p.name, style: context.text.headlineSmall),
                      Text('${p.grade} · ${p.board} · ${p.stream}', style: context.text.bodySmall),
                      Text('Preparing for ${p.goal}', style: context.text.bodySmall),
                    ],
                  ),
                ),
                IconButton(
                  tooltip: 'Edit profile',
                  onPressed: () => open(const EditProfileScreen()),
                  icon: const Icon(Icons.edit_outlined),
                ),
              ],
            ),
            const SizedBox(height: Space.xl),
            PaperCard(
              padding: EdgeInsets.zero,
              child: Column(
                children: [
                  _Link(icon: Icons.insights_outlined, title: 'Progress and analytics', onTap: () => open(const AnalyticsScreen())),
                  _Link(icon: Icons.calendar_month_outlined, title: 'Study planner', onTap: () => open(const PlannerScreen())),
                  _Link(
                    icon: Icons.bookmark_border,
                    title: 'Revise later',
                    trailing: '${state.bookmarkedTopics.length + state.bookmarkedQuestions.length}',
                    onTap: () => open(const BookmarksScreen()),
                  ),
                  _Link(icon: Icons.forum_outlined, title: 'My doubts', trailing: '${state.doubts.length}', onTap: () => open(const DoubtsScreen())),
                  _Link(
                    icon: Icons.download_done_outlined,
                    title: 'Downloads',
                    trailing: '${SampleData.pdfs.where((x) => state.isDownloaded(x.id)).length}',
                    onTap: () => open(const LibraryScreen(offlineOnly: true)),
                    last: true,
                  ),
                ],
              ),
            ),
            const SectionTitle('Appearance'),
            SegmentedButton<ThemeMode>(
              segments: const [
                ButtonSegment(value: ThemeMode.system, label: Text('System'), icon: Icon(Icons.phone_android)),
                ButtonSegment(value: ThemeMode.light, label: Text('Paper'), icon: Icon(Icons.light_mode_outlined)),
                ButtonSegment(value: ThemeMode.dark, label: Text('Blackboard'), icon: Icon(Icons.dark_mode_outlined)),
              ],
              selected: {state.themeMode},
              showSelectedIcon: false,
              onSelectionChanged: (v) => state.setThemeMode(v.first),
            ),
            const SizedBox(height: Space.xl),
            Text('Signed in as ${p.contact}', style: context.text.bodySmall),
            const SizedBox(height: Space.s),
            OutlinedButton(
              onPressed: () async {
                final ok = await showDialog<bool>(
                  context: context,
                  builder: (ctx) => AlertDialog(
                    title: const Text('Sign out?'),
                    content: const Text('Downloaded PDFs stay on this phone.'),
                    actions: [
                      TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
                      TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Sign out')),
                    ],
                  ),
                );
                if (ok == true) state.signOut();
              },
              child: const Text('Sign out'),
            ),
          ],
        ),
      ),
    );
  }
}

class _Link extends StatelessWidget {
  const _Link({required this.icon, required this.title, required this.onTap, this.trailing, this.last = false});

  final IconData icon;
  final String title;
  final VoidCallback onTap;
  final String? trailing;
  final bool last;

  @override
  Widget build(BuildContext context) {
    final vc = context.vc;
    return Column(
      children: [
        ListTile(
          leading: Icon(icon),
          title: Text(title, style: context.text.titleSmall),
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (trailing != null) Text(trailing!, style: context.text.labelMedium!.copyWith(color: vc.muted)),
              const Icon(Icons.chevron_right),
            ],
          ),
          onTap: onTap,
        ),
        if (!last) Divider(height: 1, indent: 56, color: vc.rule),
      ],
    );
  }
}

class EditProfileScreen extends StatefulWidget {
  const EditProfileScreen({super.key});

  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  late final _name = TextEditingController(text: AppScope.read(context).profile.name);

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    final p = state.profile;
    return Scaffold(
      appBar: AppBar(title: const Text('Edit profile')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(Space.gutter, 0, Space.gutter, Space.xxl),
        children: [
          TextField(
            controller: _name,
            textCapitalization: TextCapitalization.words,
            decoration: const InputDecoration(labelText: 'First name'),
            onChanged: (v) => state.updateProfile((x) => x.name = v.trim()),
          ),
          const SizedBox(height: Space.xl),
          Text('Class', style: context.text.titleMedium),
          const SizedBox(height: Space.s),
          PillChoice(
            options: const ['Class 8', 'Class 9', 'Class 10', 'Class 11', 'Class 12', 'Dropper', 'College'],
            selected: p.grade,
            onSelected: (v) => state.updateProfile((x) => x.grade = v),
          ),
          const SizedBox(height: Space.xl),
          Text('Board', style: context.text.titleMedium),
          const SizedBox(height: Space.s),
          PillChoice(
            options: const ['CBSE', 'ICSE', 'State board', 'IB', 'Other'],
            selected: p.board,
            onSelected: (v) => state.updateProfile((x) => x.board = v),
          ),
          const SizedBox(height: Space.xl),
          Text('Goal', style: context.text.titleMedium),
          const SizedBox(height: Space.s),
          PillChoice(
            options: const ['Boards', 'JEE', 'NEET', 'Olympiad', 'Just learning'],
            selected: p.goal,
            onSelected: (v) => state.updateProfile((x) => x.goal = v),
          ),
          const SizedBox(height: Space.xl),
          OutlinedButton.icon(
            onPressed: () async {
              final now = DateTime.now();
              final d = await showDatePicker(
                context: context,
                initialDate: p.examDate.isBefore(now) ? now : p.examDate,
                firstDate: now,
                lastDate: DateTime(now.year + 3),
              );
              if (d != null) state.updateProfile((x) => x.examDate = d);
            },
            icon: const Icon(Icons.event_outlined),
            label: Text('Exam date: ${MaterialLocalizations.of(context).formatMediumDate(p.examDate)}'),
          ),
        ],
      ),
    );
  }
}

class BookmarksScreen extends StatelessWidget {
  const BookmarksScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    final vc = context.vc;
    final topics = state.bookmarkedTopics.map(SampleData.topic).whereType<Topic>().toList();
    final questions = state.bookmarkedQuestions.map(SampleData.question).toList();

    return Scaffold(
      appBar: AppBar(title: const Text('Revise later')),
      body: topics.isEmpty && questions.isEmpty
          ? const EmptyNote(
              icon: Icons.bookmark_border,
              title: 'Nothing saved yet',
              body: 'Tap the bookmark on a lesson or a test question to save it here for revision.',
            )
          : ListView(
              padding: const EdgeInsets.fromLTRB(Space.gutter, 0, Space.gutter, Space.xxl),
              children: [
                if (topics.isNotEmpty) ...[
                  Text('Topics', style: context.text.titleLarge),
                  const SizedBox(height: Space.s),
                  for (final t in topics)
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
                            IconButton(
                              tooltip: 'Remove',
                              onPressed: () => state.toggleTopicBookmark(t.id),
                              icon: const Icon(Icons.bookmark_remove_outlined),
                            ),
                          ],
                        ),
                      ),
                    ),
                ],
                if (questions.isNotEmpty) ...[
                  const SizedBox(height: Space.l),
                  Text('Questions', style: context.text.titleLarge),
                  const SizedBox(height: Space.s),
                  for (final q in questions)
                    Padding(
                      padding: const EdgeInsets.only(bottom: Space.s),
                      child: PaperCard(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                SubjectMark(q.subjectId, size: 24),
                                const Spacer(),
                                IconButton(
                                  tooltip: 'Remove',
                                  visualDensity: VisualDensity.compact,
                                  onPressed: () => state.toggleQuestionBookmark(q.id),
                                  icon: const Icon(Icons.bookmark_remove_outlined, size: 20),
                                ),
                              ],
                            ),
                            Text(q.text, style: context.text.titleSmall),
                            const SizedBox(height: Space.s),
                            Highlighted(q.options[q.correct], style: context.text.bodyMedium),
                            const SizedBox(height: Space.s),
                            Text(q.explanation, style: context.text.bodyMedium!.copyWith(color: vc.muted)),
                          ],
                        ),
                      ),
                    ),
                ],
              ],
            ),
    );
  }
}
