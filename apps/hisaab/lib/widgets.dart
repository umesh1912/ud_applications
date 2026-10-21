import 'dart:ui' show FontFeature;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'format.dart';
import 'models.dart';
import 'store.dart';
import 'theme.dart';

void toast(BuildContext context, String msg, {SnackBarAction? action}) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(msg), action: action));
}

/// Section title with an optional action on the right.
class Section extends StatelessWidget {
  const Section(this.title, {super.key, this.action, this.onAction});

  final String title;
  final String? action;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(0, 24, 0, 8),
      child: Row(
        children: [
          Expanded(child: Text(title, style: context.tt.headlineSmall)),
          if (action != null) TextButton(onPressed: onAction, child: Text(action!)),
        ],
      ),
    );
  }
}

/// A plain sheet of paper with a hairline border.
class Paper extends StatelessWidget {
  const Paper({super.key, required this.child, this.padding = const EdgeInsets.all(16), this.onTap, this.color});

  final Widget child;
  final EdgeInsetsGeometry padding;
  final VoidCallback? onTap;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    return Card(
      color: color,
      clipBehavior: Clip.antiAlias,
      child: InkWell(onTap: onTap, child: Padding(padding: padding, child: child)),
    );
  }
}

class CategoryDot extends StatelessWidget {
  const CategoryDot(this.category, {super.key, this.size = 36});

  final Category category;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: category.color.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(size * 0.28),
      ),
      child: Icon(category.icon, size: size * 0.55, color: category.color),
    );
  }
}

/// Date stamp in the margin, like a bank's passbook stamp.
class DateStamp extends StatelessWidget {
  const DateStamp(this.date, {super.key});

  final DateTime date;

  @override
  Widget build(BuildContext context) {
    final hc = context.hc;
    return Container(
      width: 44,
      padding: const EdgeInsets.symmetric(vertical: 4),
      decoration: BoxDecoration(
        border: Border.all(color: hc.green.withValues(alpha: 0.5), width: 1.2),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Column(
        children: [
          Text('${date.day}', style: money(context, 20, color: hc.green)),
          Text(monthShort(date), style: context.tt.labelSmall!.copyWith(color: hc.green)),
        ],
      ),
    );
  }
}

/// One passbook entry.
class LedgerRow extends StatelessWidget {
  const LedgerRow({super.key, required this.txn, this.balanceAfter, this.onTap, this.showStamp = true});

  final Txn txn;
  final double? balanceAfter;
  final VoidCallback? onTap;
  final bool showStamp;

  @override
  Widget build(BuildContext context) {
    final store = context.store;
    final hc = context.hc;
    final t = txn;
    final cat = categoryById(t.category);
    final acc = store.accountById(t.accountId);
    final to = t.toAccountId == null ? null : store.accountById(t.toAccountId!);
    final isOut = t.type == TxnType.expense;
    final isIn = t.type == TxnType.income;
    final title = t.note.isNotEmpty ? t.note : (t.type == TxnType.transfer ? 'Transfer' : cat.name);
    final sub = t.type == TxnType.transfer
        ? '${acc?.name ?? '—'} → ${to?.name ?? '—'}'
        : '${cat.name} · ${acc?.name ?? '—'}';

    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 10),
        child: Row(
          children: [
            if (showStamp) ...[DateStamp(t.date), const SizedBox(width: 12)] else ...[
              t.type == TxnType.transfer
                  ? Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(color: hc.greenSoft, borderRadius: BorderRadius.circular(10)),
                      child: Icon(Icons.swap_horiz, color: hc.green, size: 20),
                    )
                  : CategoryDot(cat),
              const SizedBox(width: 12),
            ],
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, maxLines: 1, overflow: TextOverflow.ellipsis, style: context.tt.titleSmall),
                  const SizedBox(height: 2),
                  Text(sub, maxLines: 1, overflow: TextOverflow.ellipsis, style: context.tt.bodySmall),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  store.hideBalances ? '₹ ••' : '${isOut ? '−' : isIn ? '+' : ''}${inr(t.amount)}',
                  style: context.tt.titleSmall!.copyWith(
                    color: isOut ? hc.spend : isIn ? hc.earn : hc.ink,
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
                ),
                if (balanceAfter != null)
                  Text(store.money(balanceAfter!),
                      style: context.tt.labelSmall!.copyWith(fontFeatures: const [FontFeature.tabularFigures()])),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// Budget/goal progress: a ruled bar with a tick at 80%.
class Meter extends StatelessWidget {
  const Meter({super.key, required this.value, this.color, this.tick80 = false, this.height = 8});

  final double value; // 0..1+ (over 1 shows as full red)
  final Color? color;
  final bool tick80;
  final double height;

  @override
  Widget build(BuildContext context) {
    final hc = context.hc;
    final over = value >= 1;
    final c = over ? hc.spend : (value >= 0.8 && tick80 ? hc.brass : (color ?? hc.green));
    return SizedBox(
      height: height,
      child: LayoutBuilder(
        builder: (context, box) => Stack(
          children: [
            Container(decoration: BoxDecoration(color: hc.greenSoft, borderRadius: BorderRadius.circular(height))),
            Container(
              width: box.maxWidth * value.clamp(0.0, 1.0),
              decoration: BoxDecoration(color: c, borderRadius: BorderRadius.circular(height)),
            ),
            if (tick80)
              Positioned(
                left: box.maxWidth * 0.8 - 1,
                top: 0,
                bottom: 0,
                child: Container(width: 2, color: hc.card),
              ),
          ],
        ),
      ),
    );
  }
}

/// Amount input with ₹ prefix and digit filtering.
class AmountField extends StatelessWidget {
  const AmountField({super.key, required this.controller, this.label = 'Amount', this.autofocus = false, this.big = false, this.error});

  final TextEditingController controller;
  final String label;
  final bool autofocus;
  final bool big;
  final String? error;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      autofocus: autofocus,
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]'))],
      style: big ? money(context, 40) : context.tt.titleMedium,
      decoration: InputDecoration(
        labelText: big ? null : label,
        hintText: big ? '0' : null,
        prefixText: '₹ ',
        prefixStyle: big ? money(context, 40, color: context.hc.muted) : null,
        errorText: error,
      ),
    );
  }
}

/// Sheet scaffold used by all "add / edit" forms.
class FormSheet extends StatelessWidget {
  const FormSheet({super.key, required this.title, required this.children, this.actions = const []});

  final String title;
  final List<Widget> children;
  final List<Widget> actions;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(title, style: context.tt.headlineSmall),
              const SizedBox(height: 16),
              ...children,
              if (actions.isNotEmpty) ...[const SizedBox(height: 20), ...actions],
            ],
          ),
        ),
      ),
    );
  }
}

Future<T?> showForm<T>(BuildContext context, Widget sheet) =>
    showModalBottomSheet<T>(context: context, isScrollControlled: true, builder: (_) => sheet);

/// Asks a yes/no question; returns true for yes.
Future<bool> confirm(BuildContext context, String title, String body, String yes) async {
  final r = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text(title),
      content: Text(body),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
        TextButton(onPressed: () => Navigator.pop(ctx, true), child: Text(yes)),
      ],
    ),
  );
  return r ?? false;
}
