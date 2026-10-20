import 'package:flutter/material.dart';

import '../data/sample_data.dart';
import '../theme/tokens.dart';

/// Text marked with a highlighter swipe — used for the one thing on a screen
/// that matters most (key formula, today's target, the right answer).
class Highlighted extends StatelessWidget {
  const Highlighted(this.text, {super.key, this.style});

  final String text;
  final TextStyle? style;

  @override
  Widget build(BuildContext context) {
    final vc = context.vc;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: vc.highlight,
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(3),
          topRight: Radius.circular(10),
          bottomLeft: Radius.circular(10),
          bottomRight: Radius.circular(3),
        ),
      ),
      child: Text(
        text,
        style: (style ?? context.text.titleMedium)!.copyWith(color: vc.highlightInk),
      ),
    );
  }
}

/// Section heading with an optional trailing action.
class SectionTitle extends StatelessWidget {
  const SectionTitle(this.title, {super.key, this.action, this.onAction});

  final String title;
  final String? action;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: Space.xl, bottom: Space.m),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Expanded(child: Text(title, style: context.text.headlineSmall)),
          if (action != null)
            TextButton(onPressed: onAction, child: Text(action!)),
        ],
      ),
    );
  }
}

/// Small subject marker: a coloured square with the element symbol.
class SubjectMark extends StatelessWidget {
  const SubjectMark(this.subjectId, {super.key, this.size = 32});

  final String subjectId;
  final double size;

  @override
  Widget build(BuildContext context) {
    final s = SampleData.subject(subjectId);
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: s.color,
        borderRadius: BorderRadius.circular(Radii.tile - 1),
      ),
      child: Text(
        s.symbol,
        style: context.text.labelMedium!.copyWith(
          color: Colors.white,
          fontSize: size * 0.4,
        ),
      ),
    );
  }
}

/// Plain sheet surface with a hairline border. Cards in Valence don't float;
/// they sit on the paper like taped-in pages.
class PaperCard extends StatelessWidget {
  const PaperCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(Space.l),
    this.onTap,
    this.borderColor,
    this.color,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final VoidCallback? onTap;
  final Color? borderColor;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final vc = context.vc;
    return Material(
      color: color ?? vc.sheet,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(Radii.card),
        side: BorderSide(color: borderColor ?? vc.rule),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(padding: padding, child: child),
      ),
    );
  }
}

/// Empty state: says what to do next, not how it feels.
class EmptyNote extends StatelessWidget {
  const EmptyNote({
    super.key,
    required this.title,
    required this.body,
    this.action,
    this.onAction,
    this.icon = Icons.science_outlined,
  });

  final String title;
  final String body;
  final String? action;
  final VoidCallback? onAction;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final vc = context.vc;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: Space.xxl, horizontal: Space.xl),
      child: Column(
        children: [
          Icon(icon, size: 40, color: vc.muted),
          const SizedBox(height: Space.m),
          Text(title, style: context.text.titleLarge, textAlign: TextAlign.center),
          const SizedBox(height: Space.s),
          Text(body, style: context.text.bodyMedium!.copyWith(color: vc.muted), textAlign: TextAlign.center),
          if (action != null) ...[
            const SizedBox(height: Space.l),
            FilledButton(onPressed: onAction, child: Text(action!)),
          ],
        ],
      ),
    );
  }
}

/// A row of selectable pills (single choice).
class PillChoice extends StatelessWidget {
  const PillChoice({
    super.key,
    required this.options,
    required this.selected,
    required this.onSelected,
  });

  final List<String> options;
  final String selected;
  final ValueChanged<String> onSelected;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: Space.s,
      runSpacing: Space.s,
      children: [
        for (final o in options)
          ChoiceChip(
            label: Text(o),
            selected: o == selected,
            onSelected: (_) => onSelected(o),
          ),
      ],
    );
  }
}

String formatDuration(int seconds) {
  final m = seconds ~/ 60;
  final s = seconds % 60;
  return '$m:${s.toString().padLeft(2, '0')}';
}

String relativeDay(DateTime d) {
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  final day = DateTime(d.year, d.month, d.day);
  final diff = today.difference(day).inDays;
  if (diff == 0) return 'Today';
  if (diff == 1) return 'Yesterday';
  if (diff < 7) return '$diff days ago';
  const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
  return '${d.day} ${months[d.month - 1]}';
}

String formatTime(TimeOfDay t) {
  final h = t.hourOfPeriod == 0 ? 12 : t.hourOfPeriod;
  final m = t.minute.toString().padLeft(2, '0');
  return '$h:$m ${t.period == DayPeriod.am ? 'am' : 'pm'}';
}
