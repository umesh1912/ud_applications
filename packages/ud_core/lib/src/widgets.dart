import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'l10n.dart';
import 'theme.dart';

/// Shrinks slightly while pressed, giving every tappable surface a tactile feel.
class UdPressable extends StatefulWidget {
  const UdPressable({
    super.key,
    required this.child,
    this.onTap,
    this.onLongPress,
    this.borderRadius = 24,
    this.color,
    this.border = true,
    this.padding = EdgeInsets.zero,
  });

  final Widget child;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  final double borderRadius;
  final Color? color;
  final bool border;
  final EdgeInsetsGeometry padding;

  @override
  State<UdPressable> createState() => _UdPressableState();
}

class _UdPressableState extends State<UdPressable> {
  bool _down = false;

  void _set(bool v) {
    if (_down != v) setState(() => _down = v);
  }

  @override
  Widget build(BuildContext context) {
    final t = UdTokens.of(context);
    final radius = BorderRadius.circular(widget.borderRadius);
    final enabled = widget.onTap != null || widget.onLongPress != null;
    return AnimatedScale(
      scale: _down ? 0.97 : 1,
      duration: const Duration(milliseconds: 120),
      curve: Curves.easeOut,
      child: Material(
        color: widget.color ?? t.card,
        shape: RoundedRectangleBorder(
          borderRadius: radius,
          side: widget.border
              ? BorderSide(color: t.line, width: 1)
              : BorderSide.none,
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: widget.onTap == null
              ? null
              : () {
                  HapticFeedback.selectionClick();
                  widget.onTap!();
                },
          onLongPress: widget.onLongPress == null
              ? null
              : () {
                  HapticFeedback.mediumImpact();
                  widget.onLongPress!();
                },
          onHighlightChanged: enabled ? _set : null,
          child: Padding(padding: widget.padding, child: widget.child),
        ),
      ),
    );
  }
}

/// Round outlined icon button used in page headers.
class UdIconButton extends StatelessWidget {
  const UdIconButton({
    super.key,
    required this.icon,
    required this.onTap,
    this.tooltip,
    this.filled = false,
  });

  final IconData icon;
  final VoidCallback onTap;
  final String? tooltip;
  final bool filled;

  @override
  Widget build(BuildContext context) {
    final t = UdTokens.of(context);
    final button = UdPressable(
      onTap: onTap,
      borderRadius: 22,
      color: filled ? t.accent : t.card,
      border: !filled,
      child: SizedBox(
        width: 44,
        height: 44,
        child: Icon(icon, size: 20, color: filled ? t.onAccent : t.ink),
      ),
    );
    return tooltip == null ? button : Tooltip(message: tooltip!, child: button);
  }
}

/// Editorial page layout: eyebrow, large serif title, content slivers and an
/// optional floating dock in the thumb zone.
class UdPage extends StatelessWidget {
  const UdPage({
    super.key,
    required this.title,
    this.eyebrow,
    this.subtitle,
    this.actions = const [],
    this.slivers = const [],
    this.dock,
    this.showBack,
    this.scrollable = true,
  });

  /// Turn off for pages with drawing surfaces so strokes don't scroll the page.
  final bool scrollable;
  final String title;
  final String? eyebrow;
  final String? subtitle;
  final List<Widget> actions;
  final List<Widget> slivers;
  final Widget? dock;
  final bool? showBack;

  @override
  Widget build(BuildContext context) {
    final t = UdTokens.of(context);
    final text = Theme.of(context).textTheme;
    final canPop = showBack ?? Navigator.of(context).canPop();
    final big = !canPop;

    final header = Padding(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            height: 48,
            child: Row(
              children: [
                if (canPop)
                  UdIconButton(
                    icon: Icons.arrow_back_rounded,
                    onTap: () => Navigator.of(context).maybePop(),
                  ),
                const Spacer(),
                for (final a in actions)
                  Padding(padding: const EdgeInsets.only(left: 8), child: a),
              ],
            ),
          ),
          SizedBox(height: big ? 20 : 12),
          if (eyebrow != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Text(
                eyebrow!.toUpperCase(),
                style: text.labelSmall?.copyWith(
                  color: t.accent,
                  letterSpacing: 1.8,
                ),
              ),
            ),
          Text(title,
              style: big ? text.displaySmall : text.headlineLarge),
          if (subtitle != null)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(subtitle!,
                  style: text.bodyMedium?.copyWith(color: t.inkSoft)),
            ),
        ],
      ),
    );

    return Scaffold(
      body: Stack(
        children: [
          CustomScrollView(
            physics: scrollable
                ? const BouncingScrollPhysics(
                    parent: AlwaysScrollableScrollPhysics())
                : const NeverScrollableScrollPhysics(),
            slivers: [
              SliverSafeArea(
                bottom: false,
                sliver: SliverToBoxAdapter(child: header),
              ),
              ...slivers,
              SliverToBoxAdapter(
                child: SizedBox(
                    height: (dock != null ? 120 : 32) +
                        MediaQuery.of(context).padding.bottom),
              ),
            ],
          ),
          if (dock != null)
            Positioned(
              left: 16,
              right: 16,
              bottom: 0,
              child: SafeArea(
                top: false,
                child: Padding(
                  padding: const EdgeInsets.only(bottom: 14),
                  child: dock!,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// Sliver padding helper used by every page.
class UdSliverPad extends StatelessWidget {
  const UdSliverPad({super.key, required this.sliver, this.top = 0, this.bottom = 0});
  final Widget sliver;
  final double top;
  final double bottom;

  @override
  Widget build(BuildContext context) => SliverPadding(
        padding: EdgeInsets.fromLTRB(20, top, 20, bottom),
        sliver: sliver,
      );
}

/// Small uppercase section label.
class UdLabel extends StatelessWidget {
  const UdLabel(this.text, {super.key, this.trailing});
  final String text;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final t = UdTokens.of(context);
    return Padding(
      padding: const EdgeInsets.only(top: 8, bottom: 12),
      child: Row(
        children: [
          Expanded(
            child: Text(
              text.toUpperCase(),
              style: Theme.of(context)
                  .textTheme
                  .labelSmall
                  ?.copyWith(color: t.inkFaint, letterSpacing: 1.6),
            ),
          ),
          if (trailing != null) trailing!,
        ],
      ),
    );
  }
}

/// Floating dark pill with one big primary action and optional side actions.
/// Sits in the thumb zone so the main job is always one tap away.
class UdDock extends StatelessWidget {
  const UdDock({
    super.key,
    required this.label,
    required this.icon,
    required this.onPressed,
    this.extras = const [],
  });

  final String label;
  final IconData icon;
  final VoidCallback onPressed;
  final List<UdDockAction> extras;

  @override
  Widget build(BuildContext context) {
    final t = UdTokens.of(context);
    final text = Theme.of(context).textTheme;
    return Material(
      color: t.ink,
      borderRadius: BorderRadius.circular(28),
      elevation: 8,
      shadowColor: Colors.black.withValues(alpha: 0.25),
      child: Padding(
        padding: const EdgeInsets.all(8),
        child: Row(
          children: [
            for (final e in extras)
              Padding(
                padding: const EdgeInsets.only(right: 4),
                child: Tooltip(
                  message: e.label,
                  child: InkResponse(
                    onTap: () {
                      HapticFeedback.selectionClick();
                      e.onTap();
                    },
                    radius: 28,
                    child: SizedBox(
                      width: 52,
                      height: 52,
                      child: Icon(e.icon, color: t.paper, size: 22),
                    ),
                  ),
                ),
              ),
            Expanded(
              child: UdPressable(
                onTap: onPressed,
                color: t.accent,
                border: false,
                borderRadius: 22,
                child: SizedBox(
                  height: 52,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(icon, color: t.onAccent, size: 22),
                      const SizedBox(width: 10),
                      Flexible(
                        child: Text(
                          label,
                          overflow: TextOverflow.ellipsis,
                          style: text.labelLarge?.copyWith(color: t.onAccent),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class UdDockAction {
  const UdDockAction({required this.icon, required this.label, required this.onTap});
  final IconData icon;
  final String label;
  final VoidCallback onTap;
}

/// Square tile with tinted icon, used for tool grids.
class UdToolTile extends StatelessWidget {
  const UdToolTile({
    super.key,
    required this.icon,
    required this.title,
    this.subtitle,
    required this.onTap,
    this.highlight = false,
  });

  final IconData icon;
  final String title;
  final String? subtitle;
  final VoidCallback onTap;
  final bool highlight;

  @override
  Widget build(BuildContext context) {
    final t = UdTokens.of(context);
    final text = Theme.of(context).textTheme;
    return UdPressable(
      onTap: onTap,
      color: highlight ? t.accent : t.card,
      border: !highlight,
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: highlight
                  ? Colors.white.withValues(alpha: 0.18)
                  : t.accentSoft,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(icon,
                color: highlight ? t.onAccent : t.accent, size: 22),
          ),
          const Spacer(),
          Text(
            title,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: text.titleMedium
                ?.copyWith(color: highlight ? t.onAccent : t.ink),
          ),
          if (subtitle != null)
            Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Text(
                subtitle!,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: text.bodySmall?.copyWith(
                    color: highlight
                        ? t.onAccent.withValues(alpha: 0.8)
                        : t.inkSoft),
              ),
            ),
        ],
      ),
    );
  }
}

/// Row-style list item.
class UdRow extends StatelessWidget {
  const UdRow({
    super.key,
    required this.title,
    this.subtitle,
    this.leading,
    this.trailing,
    this.onTap,
    this.onLongPress,
  });

  final String title;
  final String? subtitle;
  final Widget? leading;
  final Widget? trailing;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;

  @override
  Widget build(BuildContext context) {
    final t = UdTokens.of(context);
    final text = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: UdPressable(
        onTap: onTap,
        onLongPress: onLongPress,
        borderRadius: 20,
        padding: const EdgeInsets.all(14),
        child: Row(
          children: [
            if (leading != null) ...[leading!, const SizedBox(width: 14)],
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: text.titleMedium),
                  if (subtitle != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 3),
                      child: Text(subtitle!,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: text.bodySmall?.copyWith(color: t.inkSoft)),
                    ),
                ],
              ),
            ),
            if (trailing != null) ...[const SizedBox(width: 8), trailing!],
          ],
        ),
      ),
    );
  }
}

/// Tinted rounded square holding an icon.
class UdBadgeIcon extends StatelessWidget {
  const UdBadgeIcon(this.icon, {super.key, this.size = 48, this.color});
  final IconData icon;
  final double size;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final t = UdTokens.of(context);
    final c = color ?? t.accent;
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: Color.alphaBlend(c.withValues(alpha: 0.13), t.card),
        borderRadius: BorderRadius.circular(size * 0.32),
      ),
      child: Icon(icon, color: c, size: size * 0.46),
    );
  }
}

/// Friendly empty state.
class UdEmpty extends StatelessWidget {
  const UdEmpty({
    super.key,
    required this.icon,
    required this.title,
    this.body,
  });

  final IconData icon;
  final String title;
  final String? body;

  @override
  Widget build(BuildContext context) {
    final t = UdTokens.of(context);
    final text = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 36, horizontal: 12),
      child: Column(
        children: [
          Container(
            width: 112,
            height: 112,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: t.accentSoft,
              border: Border.all(color: t.line),
            ),
            child: Icon(icon, size: 46, color: t.accent),
          ),
          const SizedBox(height: 22),
          Text(title,
              textAlign: TextAlign.center, style: text.headlineSmall),
          if (body != null)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(body!,
                  textAlign: TextAlign.center,
                  style: text.bodyMedium?.copyWith(color: t.inkSoft)),
            ),
        ],
      ),
    );
  }
}

InputDecoration udInputDecoration(BuildContext context, {String? hint, IconData? icon}) {
  final t = UdTokens.of(context);
  OutlineInputBorder b(Color c, [double w = 1.2]) => OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide(color: c, width: w),
      );
  return InputDecoration(
    hintText: hint,
    hintStyle: Theme.of(context).textTheme.bodyLarge?.copyWith(color: t.inkFaint),
    prefixIcon: icon == null ? null : Icon(icon, color: t.inkSoft),
    filled: true,
    fillColor: t.paper,
    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
    border: b(t.line),
    enabledBorder: b(t.line),
    focusedBorder: b(t.accent, 1.8),
  );
}

Future<T?> showUdSheet<T>(BuildContext context, WidgetBuilder builder) {
  return showModalBottomSheet<T>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (c) => Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(c).viewInsets.bottom),
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
        child: builder(c),
      ),
    ),
  );
}

Future<bool> udConfirm(BuildContext context,
    {String? title, String? body, String? confirmLabel, bool danger = true}) async {
  final res = await showUdSheet<bool>(context, (c) {
    final t = UdTokens.of(c);
    final text = Theme.of(c).textTheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title ?? c.tr('confirm_delete'), style: text.headlineSmall),
        const SizedBox(height: 8),
        Text(body ?? c.tr('confirm_delete_sub'),
            style: text.bodyMedium?.copyWith(color: t.inkSoft)),
        const SizedBox(height: 24),
        Row(
          children: [
            Expanded(
              child: OutlinedButton(
                onPressed: () => Navigator.pop(c, false),
                child: Text(c.tr('cancel')),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: FilledButton(
                style: danger
                    ? FilledButton.styleFrom(backgroundColor: t.danger)
                    : null,
                onPressed: () => Navigator.pop(c, true),
                child: Text(confirmLabel ?? c.tr('delete')),
              ),
            ),
          ],
        ),
      ],
    );
  });
  return res ?? false;
}

Future<String?> udPrompt(BuildContext context,
    {required String title, String initial = '', String? hint}) {
  final ctrl = TextEditingController(text: initial);
  return showUdSheet<String>(context, (c) {
    final text = Theme.of(c).textTheme;
    void submit() {
      final v = ctrl.text.trim();
      if (v.isNotEmpty) Navigator.pop(c, v);
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: text.headlineSmall),
        const SizedBox(height: 16),
        TextField(
          controller: ctrl,
          autofocus: true,
          style: text.bodyLarge,
          decoration: udInputDecoration(c, hint: hint),
          onSubmitted: (_) => submit(),
        ),
        const SizedBox(height: 16),
        SizedBox(
          width: double.infinity,
          child: FilledButton(onPressed: submit, child: Text(c.tr('save'))),
        ),
      ],
    );
  });
}

class UdAction<T> {
  const UdAction(this.value, this.icon, this.label, {this.danger = false});
  final T value;
  final IconData icon;
  final String label;
  final bool danger;
}

Future<T?> showUdActions<T>(BuildContext context,
    {String? title, required List<UdAction<T>> actions}) {
  return showUdSheet<T>(context, (c) {
    final t = UdTokens.of(c);
    final text = Theme.of(c).textTheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (title != null)
          Padding(
            padding: const EdgeInsets.only(bottom: 14),
            child: Text(title,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: text.titleLarge),
          ),
        for (final a in actions)
          ListTile(
            contentPadding: const EdgeInsets.symmetric(horizontal: 4),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            leading: UdBadgeIcon(a.icon,
                size: 40, color: a.danger ? t.danger : null),
            title: Text(a.label,
                style: text.titleMedium
                    ?.copyWith(color: a.danger ? t.danger : t.ink)),
            onTap: () => Navigator.pop(c, a.value),
          ),
      ],
    );
  });
}

void udToast(BuildContext context, String message) {
  final m = ScaffoldMessenger.maybeOf(context);
  if (m == null) return;
  m
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(message)));
}

/// Full-screen blocking progress overlay for short jobs.
Future<T> udBusy<T>(BuildContext context, Future<T> Function() job) async {
  final nav = Navigator.of(context, rootNavigator: true);
  showDialog<void>(
    context: context,
    barrierDismissible: false,
    builder: (c) => const PopScope(
      canPop: false,
      child: Center(child: CircularProgressIndicator()),
    ),
  );
  try {
    return await job();
  } finally {
    nav.pop();
  }
}
