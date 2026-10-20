import 'package:flutter/material.dart';

import '../data/models.dart';
import '../data/sample_data.dart';
import '../state/app_state.dart';
import '../theme/tokens.dart';
import '../widgets/common.dart';

/// Weekly study planner counting back from the exam date.
class PlannerScreen extends StatefulWidget {
  const PlannerScreen({super.key});

  @override
  State<PlannerScreen> createState() => _PlannerScreenState();
}

class _PlannerScreenState extends State<PlannerScreen> {
  int _day = DateTime.now().weekday;

  static const _dayNames = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];

  Future<void> _add() async {
    final s = await showModalBottomSheet<StudySession>(
      context: context,
      isScrollControlled: true,
      builder: (_) => _AddSessionSheet(weekday: _day),
    );
    if (s != null && mounted) AppScope.read(context).addSession(s);
  }

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    final vc = context.vc;
    final sessions = state.sessionsFor(_day);
    final weekMinutes = state.sessions.fold<int>(0, (n, s) => n + s.minutes);

    return Scaffold(
      appBar: AppBar(title: const Text('Study planner')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _add,
        backgroundColor: vc.highlight,
        foregroundColor: vc.highlightInk,
        icon: const Icon(Icons.add),
        label: const Text('Add session'),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(Space.gutter, 0, Space.gutter, 100),
        children: [
          Text(
            '${state.daysToExam} days to ${state.profile.goal} · ${(weekMinutes / 60).toStringAsFixed(1)} h planned this week',
            style: context.text.bodyMedium!.copyWith(color: vc.muted),
          ),
          const SizedBox(height: Space.l),
          Row(
            children: [
              for (var d = 1; d <= 7; d++)
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 2),
                    child: _DayCell(
                      label: _dayNames[d - 1],
                      count: state.sessionsFor(d).length,
                      selected: d == _day,
                      today: d == DateTime.now().weekday,
                      onTap: () => setState(() => _day = d),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: Space.xl),
          if (sessions.isEmpty)
            EmptyNote(
              icon: Icons.event_note_outlined,
              title: 'No sessions on ${_dayNames[_day - 1]}',
              body: 'Short, regular sessions work better than long cramming. Try 45 minutes.',
              action: 'Add session',
              onAction: _add,
            )
          else
            for (final s in sessions)
              Padding(
                padding: const EdgeInsets.only(bottom: Space.s),
                child: Dismissible(
                  key: ValueKey(s.id),
                  direction: DismissDirection.endToStart,
                  background: Container(
                    alignment: Alignment.centerRight,
                    padding: const EdgeInsets.only(right: Space.xl),
                    decoration: BoxDecoration(
                      color: Palette.wrong,
                      borderRadius: BorderRadius.circular(Radii.card),
                    ),
                    child: const Icon(Icons.delete_outline, color: Colors.white),
                  ),
                  onDismissed: (_) {
                    state.removeSession(s.id);
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: const Text('Session removed'),
                        action: SnackBarAction(label: 'Undo', onPressed: () => state.addSession(s)),
                      ),
                    );
                  },
                  child: PaperCard(
                    padding: const EdgeInsets.fromLTRB(Space.l, Space.m, Space.xs, Space.m),
                    child: Row(
                      children: [
                        SizedBox(
                          width: 64,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(formatTime(s.start), style: context.text.labelLarge),
                              Text('${s.minutes} min', style: context.text.bodySmall),
                            ],
                          ),
                        ),
                        Container(width: 3, height: 40, color: SampleData.subject(s.subjectId).color),
                        const SizedBox(width: Space.m),
                        Expanded(
                          child: Text(
                            s.label,
                            style: context.text.titleSmall!.copyWith(
                              decoration: s.done ? TextDecoration.lineThrough : null,
                            ),
                          ),
                        ),
                        IconButton(
                          tooltip: s.remind ? 'Turn reminder off' : 'Turn reminder on',
                          onPressed: () => state.toggleReminder(s),
                          icon: Icon(s.remind ? Icons.notifications_active : Icons.notifications_off_outlined),
                        ),
                        Checkbox(value: s.done, onChanged: (_) => state.toggleSessionDone(s)),
                      ],
                    ),
                  ),
                ),
              ),
          if (sessions.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: Space.s),
              child: Text('Swipe left on a session to remove it.', style: context.text.bodySmall),
            ),
        ],
      ),
    );
  }
}

class _DayCell extends StatelessWidget {
  const _DayCell({
    required this.label,
    required this.count,
    required this.selected,
    required this.today,
    required this.onTap,
  });

  final String label;
  final int count;
  final bool selected;
  final bool today;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final vc = context.vc;
    return Semantics(
      selected: selected,
      button: true,
      label: '$label, $count sessions${today ? ', today' : ''}',
      child: Material(
        color: selected ? vc.ink : vc.sheet,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(Radii.tile),
          side: BorderSide(color: today && !selected ? vc.ink : vc.rule),
        ),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(Radii.tile),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: Space.m),
            child: Column(
              children: [
                Text(label, style: context.text.labelSmall!.copyWith(color: selected ? vc.paper : vc.muted)),
                const SizedBox(height: 4),
                Text('$count', style: context.text.titleMedium!.copyWith(color: selected ? vc.paper : vc.ink)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _AddSessionSheet extends StatefulWidget {
  const _AddSessionSheet({required this.weekday});

  final int weekday;

  @override
  State<_AddSessionSheet> createState() => _AddSessionSheetState();
}

class _AddSessionSheetState extends State<_AddSessionSheet> {
  String _subjectId = 'phy';
  TimeOfDay _start = const TimeOfDay(hour: 18, minute: 0);
  int _minutes = 45;
  final _label = TextEditingController();

  @override
  void dispose() {
    _label.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(Space.gutter, 0, Space.gutter, MediaQuery.of(context).viewInsets.bottom + Space.l),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('New study session', style: context.text.headlineSmall),
          const SizedBox(height: Space.l),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                for (final s in SampleData.subjects) ...[
                  ChoiceChip(
                    avatar: SubjectMark(s.id, size: 20),
                    label: Text(s.name),
                    selected: _subjectId == s.id,
                    onSelected: (_) => setState(() => _subjectId = s.id),
                  ),
                  const SizedBox(width: Space.s),
                ],
              ],
            ),
          ),
          const SizedBox(height: Space.m),
          TextField(
            controller: _label,
            textCapitalization: TextCapitalization.sentences,
            decoration: const InputDecoration(labelText: 'What will you study?', hintText: 'e.g. Chapter 3 notes + 20 questions'),
          ),
          const SizedBox(height: Space.m),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () async {
                    final t = await showTimePicker(context: context, initialTime: _start);
                    if (t != null) setState(() => _start = t);
                  },
                  icon: const Icon(Icons.schedule),
                  label: Text(formatTime(_start)),
                ),
              ),
            ],
          ),
          const SizedBox(height: Space.m),
          Text('Length', style: context.text.titleSmall),
          const SizedBox(height: Space.s),
          Wrap(
            spacing: Space.s,
            children: [
              for (final m in const [25, 45, 60, 90])
                ChoiceChip(
                  label: Text(m < 60 ? '$m min' : (m == 60 ? '1 hour' : '1.5 hours')),
                  selected: _minutes == m,
                  onSelected: (_) => setState(() => _minutes = m),
                ),
            ],
          ),
          const SizedBox(height: Space.xl),
          FilledButton(
            style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(52)),
            onPressed: () {
              final subject = SampleData.subject(_subjectId);
              Navigator.of(context).pop(StudySession(
                id: 's${DateTime.now().microsecondsSinceEpoch}',
                weekday: widget.weekday,
                start: _start,
                minutes: _minutes,
                subjectId: _subjectId,
                label: _label.text.trim().isEmpty ? '${subject.name} study' : _label.text.trim(),
              ));
            },
            child: const Text('Add session'),
          ),
        ],
      ),
    );
  }
}
