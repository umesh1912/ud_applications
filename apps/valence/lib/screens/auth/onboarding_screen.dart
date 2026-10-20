import 'package:flutter/material.dart';

import '../../state/app_state.dart';
import '../../theme/tokens.dart';
import '../../widgets/common.dart';

/// Three short questions that personalise everything else:
/// name → class & board → goal & exam date.
class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final _pages = PageController();
  final _name = TextEditingController();
  int _step = 0;

  static const grades = ['Class 8', 'Class 9', 'Class 10', 'Class 11', 'Class 12', 'Dropper', 'College'];
  static const boards = ['CBSE', 'ICSE', 'State board', 'IB', 'Other'];
  static const streams = ['PCM', 'PCB', 'PCMB', 'Not yet'];
  static const goals = ['Boards', 'JEE', 'NEET', 'Olympiad', 'Just learning'];

  @override
  void dispose() {
    _pages.dispose();
    _name.dispose();
    super.dispose();
  }

  void _next() {
    final state = AppScope.read(context);
    if (_step == 0) {
      if (_name.text.trim().isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Add your first name so we can personalise your plan.')),
        );
        return;
      }
      state.updateProfile((p) => p.name = _name.text.trim());
    }
    if (_step == 2) {
      state.completeOnboarding();
      return;
    }
    setState(() => _step++);
    _pages.animateToPage(_step, duration: Motion.normal, curve: Motion.curve);
  }

  void _back() {
    if (_step == 0) return;
    setState(() => _step--);
    _pages.animateToPage(_step, duration: Motion.normal, curve: Motion.curve);
  }

  Future<void> _pickExamDate() async {
    final state = AppScope.read(context);
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: state.profile.examDate,
      firstDate: now,
      lastDate: DateTime(now.year + 3),
      helpText: 'When is your exam?',
    );
    if (picked != null) state.updateProfile((p) => p.examDate = picked);
  }

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    final p = state.profile;
    final vc = context.vc;

    return Scaffold(
      appBar: AppBar(
        leading: _step > 0
            ? IconButton(tooltip: 'Back', onPressed: _back, icon: const Icon(Icons.arrow_back))
            : null,
        title: Text('Step ${_step + 1} of 3', style: context.text.labelMedium!.copyWith(color: vc.muted)),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(4),
          child: LinearProgressIndicator(value: (_step + 1) / 3, minHeight: 3),
        ),
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: PageView(
                controller: _pages,
                physics: const NeverScrollableScrollPhysics(),
                children: [
                  _StepPage(
                    title: 'What should we call you?',
                    children: [
                      TextField(
                        controller: _name,
                        autofocus: true,
                        textCapitalization: TextCapitalization.words,
                        decoration: const InputDecoration(labelText: 'First name'),
                        onSubmitted: (_) => _next(),
                      ),
                    ],
                  ),
                  _StepPage(
                    title: 'Where are you studying?',
                    children: [
                      Text('Class', style: context.text.titleMedium),
                      const SizedBox(height: Space.s),
                      PillChoice(options: grades, selected: p.grade, onSelected: (v) => state.updateProfile((x) => x.grade = v)),
                      const SizedBox(height: Space.xl),
                      Text('Board', style: context.text.titleMedium),
                      const SizedBox(height: Space.s),
                      PillChoice(options: boards, selected: p.board, onSelected: (v) => state.updateProfile((x) => x.board = v)),
                      const SizedBox(height: Space.xl),
                      Text('Stream', style: context.text.titleMedium),
                      const SizedBox(height: Space.s),
                      PillChoice(options: streams, selected: p.stream, onSelected: (v) => state.updateProfile((x) => x.stream = v)),
                    ],
                  ),
                  _StepPage(
                    title: 'What are you preparing for?',
                    children: [
                      PillChoice(options: goals, selected: p.goal, onSelected: (v) => state.updateProfile((x) => x.goal = v)),
                      const SizedBox(height: Space.xl),
                      Text('Exam date', style: context.text.titleMedium),
                      const SizedBox(height: Space.s),
                      PaperCard(
                        onTap: _pickExamDate,
                        child: Row(
                          children: [
                            const Icon(Icons.event_outlined),
                            const SizedBox(width: Space.m),
                            Expanded(
                              child: Text(
                                MaterialLocalizations.of(context).formatFullDate(p.examDate),
                                style: context.text.titleMedium,
                              ),
                            ),
                            Text('Change', style: context.text.labelMedium),
                          ],
                        ),
                      ),
                      const SizedBox(height: Space.s),
                      Text(
                        'Your study planner counts back from this date.',
                        style: context.text.bodySmall,
                      ),
                    ],
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(Space.gutter, 0, Space.gutter, Space.l),
              child: FilledButton(
                onPressed: _next,
                style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(54)),
                child: Text(_step == 2 ? 'Build my plan' : 'Continue'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _StepPage extends StatelessWidget {
  const _StepPage({required this.title, required this.children});

  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(Space.gutter, Space.xl, Space.gutter, Space.xl),
      children: [
        Text(title, style: context.text.headlineMedium),
        const SizedBox(height: Space.xl),
        ...children,
      ],
    );
  }
}
