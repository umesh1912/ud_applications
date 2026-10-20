import 'package:flutter/material.dart';

import '../data/models.dart';
import '../theme/tokens.dart';

/// The signature component: a subject drawn as a periodic-table cell.
/// Top-left: position number. Top-right: topic count ("mass").
/// Centre: two-letter symbol. Bottom: name and a progress "fill line".
class ElementTile extends StatelessWidget {
  const ElementTile({
    super.key,
    required this.subject,
    required this.progress,
    this.onTap,
    this.compact = false,
  });

  final Subject subject;
  final double progress;
  final VoidCallback? onTap;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final vc = context.vc;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final c = subject.color;
    final bg = Color.alphaBlend(c.withValues(alpha: isDark ? 0.18 : 0.10), vc.sheet);

    return Semantics(
      button: onTap != null,
      label: '${subject.name}, ${(progress * 100).round()} percent done',
      child: Material(
        color: bg,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(Radii.tile),
          side: BorderSide(color: c, width: 1.6),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: EdgeInsets.fromLTRB(10, 8, 10, compact ? 8 : 10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text('${subject.number}',
                        style: context.text.labelMedium!.copyWith(color: c)),
                    const Spacer(),
                    Text('${subject.topicCount} topics', style: context.text.labelSmall),
                  ],
                ),
                Expanded(
                  child: Center(
                    child: FittedBox(
                      child: Text(
                        subject.symbol,
                        style: context.text.displayLarge!.copyWith(
                          color: c,
                          fontSize: compact ? 40 : 56,
                          height: 1,
                        ),
                      ),
                    ),
                  ),
                ),
                Text(
                  subject.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: context.text.titleSmall,
                ),
                const SizedBox(height: 6),
                ClipRRect(
                  borderRadius: BorderRadius.circular(2),
                  child: LinearProgressIndicator(
                    value: progress,
                    minHeight: 4,
                    color: c,
                    backgroundColor: c.withValues(alpha: 0.18),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
