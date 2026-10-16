import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:ud_core/ud_core.dart';

import 'db.dart';
import 'gst.dart';

const green = Color(0xFF2F7D4F);
const amber = Color(0xFFB7791F);

Db get db => Db.i;

void go(BuildContext context, Widget page) =>
    Navigator.of(context).push(MaterialPageRoute(builder: (_) => page));

IconData typeIcon(TxnType t) => switch (t) {
      TxnType.sale => Icons.receipt_long_rounded,
      TxnType.purchase => Icons.shopping_bag_outlined,
      TxnType.paymentIn => Icons.south_west_rounded,
      TxnType.paymentOut => Icons.north_east_rounded,
      TxnType.expense => Icons.account_balance_wallet_outlined,
      TxnType.estimate => Icons.request_quote_outlined,
      TxnType.saleReturn => Icons.assignment_return_outlined,
      TxnType.purchaseReturn => Icons.assignment_returned_outlined,
      TxnType.saleOrder => Icons.pending_actions_rounded,
      TxnType.challan => Icons.local_shipping_outlined,
    };

String typeLabel(BuildContext context, TxnType t) => context.tr('t_${t.name}');

/// Colour for an amount: green money in, red money out.
Color flowColor(BuildContext context, TxnType t) {
  final tk = UdTokens.of(context);
  if (t.isDraftDoc) return tk.inkSoft;
  return t.cashSign >= 0 && t != TxnType.expense ? green : tk.danger;
}

String partyLabel(Txn t) => t.partyName.isNotEmpty ? t.partyName : '';

class Field extends StatelessWidget {
  const Field(this.controller, this.label,
      {super.key,
      this.type,
      this.hint,
      this.maxLines = 1,
      this.caps = TextCapitalization.sentences,
      this.onChanged,
      this.prefix,
      this.suffix,
      this.autofocus = false,
      this.formatters});
  final TextEditingController controller;
  final String label;
  final TextInputType? type;
  final String? hint;
  final int maxLines;
  final TextCapitalization caps;
  final ValueChanged<String>? onChanged;
  final String? prefix;
  final Widget? suffix;
  final bool autofocus;
  final List<TextInputFormatter>? formatters;

  static TextInputType get number => const TextInputType.numberWithOptions(decimal: true);

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Padding(padding: const EdgeInsets.only(left: 4, bottom: 6), child: Text(label, style: text.labelMedium)),
        TextField(
          controller: controller,
          keyboardType: type,
          maxLines: maxLines,
          autofocus: autofocus,
          textCapitalization: caps,
          onChanged: onChanged,
          inputFormatters: formatters,
          style: text.bodyLarge,
          decoration: udInputDecoration(context, hint: hint).copyWith(
            prefixText: prefix,
            suffixIcon: suffix,
          ),
        ),
      ]),
    );
  }
}

/// Labelled tappable value, used for pickers (date, party, state…).
class PickField extends StatelessWidget {
  const PickField({super.key, required this.label, required this.value, required this.onTap, this.icon, this.placeholder = false});
  final String label;
  final String value;
  final VoidCallback onTap;
  final IconData? icon;
  final bool placeholder;

  @override
  Widget build(BuildContext context) {
    final t = UdTokens.of(context);
    final text = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Padding(padding: const EdgeInsets.only(left: 4, bottom: 6), child: Text(label, style: text.labelMedium)),
        UdPressable(
          onTap: onTap,
          color: t.paper,
          borderRadius: 16,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
          child: Row(children: [
            if (icon != null) ...[Icon(icon, size: 20, color: t.inkSoft), const SizedBox(width: 10)],
            Expanded(
              child: Text(value,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: text.bodyLarge?.copyWith(color: placeholder ? t.inkFaint : t.ink)),
            ),
            Icon(Icons.expand_more_rounded, color: t.inkSoft),
          ]),
        ),
      ]),
    );
  }
}

class Card2 extends StatelessWidget {
  const Card2({super.key, required this.child, this.padding = const EdgeInsets.all(16), this.margin = const EdgeInsets.only(bottom: 12)});
  final Widget child;
  final EdgeInsets padding;
  final EdgeInsets margin;

  @override
  Widget build(BuildContext context) {
    final t = UdTokens.of(context);
    return Container(
      margin: margin,
      padding: padding,
      decoration: BoxDecoration(color: t.card, borderRadius: BorderRadius.circular(20), border: Border.all(color: t.line)),
      child: child,
    );
  }
}

/// Key/value row inside summaries.
class KV extends StatelessWidget {
  const KV(this.k, this.v, {super.key, this.bold = false, this.color});
  final String k;
  final String v;
  final bool bold;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final t = UdTokens.of(context);
    final text = Theme.of(context).textTheme;
    final style = bold ? text.titleMedium : text.bodyMedium;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(children: [
        Expanded(child: Text(k, style: style?.copyWith(color: bold ? t.ink : t.inkSoft))),
        Text(v, style: style?.copyWith(color: color ?? t.ink, fontFeatures: const [FontFeature.tabularFigures()])),
      ]),
    );
  }
}

class StatusChip extends StatelessWidget {
  const StatusChip(this.status, {super.key});
  final PayStatus status;

  @override
  Widget build(BuildContext context) {
    final t = UdTokens.of(context);
    final c = switch (status) {
      PayStatus.paid => green,
      PayStatus.partial => amber,
      PayStatus.unpaid => t.inkSoft,
      PayStatus.overdue => t.danger,
    };
    return Pill(context.tr('st_${status.name}'), c);
  }
}

class Pill extends StatelessWidget {
  const Pill(this.label, this.color, {super.key});
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
        decoration: BoxDecoration(color: color.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(10)),
        child: Text(label, style: Theme.of(context).textTheme.labelSmall?.copyWith(color: color)),
      );
}

/// Choice chips in a wrap.
class Chips<T> extends StatelessWidget {
  const Chips({super.key, required this.values, required this.selected, required this.label, required this.onSelect});
  final List<T> values;
  final T selected;
  final String Function(T) label;
  final ValueChanged<T> onSelect;

  @override
  Widget build(BuildContext context) {
    final t = UdTokens.of(context);
    return Wrap(spacing: 8, runSpacing: 8, children: [
      for (final v in values)
        ChoiceChip(
          label: Text(label(v)),
          selected: v == selected,
          showCheckmark: false,
          selectedColor: t.accentSoft,
          side: BorderSide(color: v == selected ? t.accent : t.line),
          onSelected: (_) => onSelect(v),
        ),
    ]);
  }
}

/// One transaction as a list row.
class TxnRow extends StatelessWidget {
  const TxnRow(this.t, {super.key, required this.onTap, this.showParty = true});
  final Txn t;
  final VoidCallback onTap;
  final bool showParty;

  @override
  Widget build(BuildContext context) {
    final tk = UdTokens.of(context);
    final text = Theme.of(context).textTheme;
    final total = db.totalOf(t);
    final status = (t.type == TxnType.sale || t.type == TxnType.purchase) ? db.docStatus(t) : null;
    final who = showParty && t.partyName.isNotEmpty
        ? t.partyName
        : t.type == TxnType.expense
            ? context.tr('ec_${t.category.isEmpty ? 'other_exp' : t.category}')
            : (t.type == TxnType.sale && t.partyName.isEmpty ? context.tr('cash_sale') : typeLabel(context, t.type));
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: UdPressable(
        onTap: onTap,
        borderRadius: 20,
        padding: const EdgeInsets.all(14),
        child: Row(children: [
          UdBadgeIcon(typeIcon(t.type), size: 44, color: flowColor(context, t.type)),
          const SizedBox(width: 12),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(who, maxLines: 1, overflow: TextOverflow.ellipsis, style: text.titleMedium),
              const SizedBox(height: 3),
              Text('${typeLabel(context, t.type)} ${t.number} · ${dmy(t.date)}',
                  maxLines: 1, overflow: TextOverflow.ellipsis, style: text.bodySmall?.copyWith(color: tk.inkSoft)),
            ]),
          ),
          const SizedBox(width: 8),
          Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
            Text(money(total), style: text.titleMedium?.copyWith(fontFeatures: const [FontFeature.tabularFigures()])),
            const SizedBox(height: 4),
            if (status != null)
              StatusChip(status.statusOn(t.dueDate))
            else if (t.type.isDraftDoc && t.convertedTo.isNotEmpty)
              Pill(context.tr('converted'), green),
          ]),
        ]),
      ),
    );
  }
}

Future<DateTime?> pickDate(BuildContext context, DateTime initial) => showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(2015),
      lastDate: DateTime(2100),
    );

/// Searchable picker sheet.
Future<T?> pickFrom<T>(
  BuildContext context, {
  required String title,
  required List<T> items,
  required String Function(T) label,
  String Function(T)? sub,
  Widget Function(T)? trailing,
  String? addLabel,
  Future<T?> Function()? onAdd,
}) {
  return showModalBottomSheet<T>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (c) => _PickSheet<T>(
        title: title, items: items, label: label, sub: sub, trailing: trailing, addLabel: addLabel, onAdd: onAdd),
  );
}

class _PickSheet<T> extends StatefulWidget {
  const _PickSheet({required this.title, required this.items, required this.label, this.sub, this.trailing, this.addLabel, this.onAdd});
  final String title;
  final List<T> items;
  final String Function(T) label;
  final String Function(T)? sub;
  final Widget Function(T)? trailing;
  final String? addLabel;
  final Future<T?> Function()? onAdd;

  @override
  State<_PickSheet<T>> createState() => _PickSheetState<T>();
}

class _PickSheetState<T> extends State<_PickSheet<T>> {
  String _q = '';

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final t = UdTokens.of(context);
    final q = _q.toLowerCase();
    final list = widget.items
        .where((e) => q.isEmpty || widget.label(e).toLowerCase().contains(q) || (widget.sub?.call(e).toLowerCase().contains(q) ?? false))
        .toList();
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: SizedBox(
        height: MediaQuery.of(context).size.height * 0.78,
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
            child: Text(widget.title, style: text.headlineSmall),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: TextField(
              autofocus: widget.items.length > 8,
              onChanged: (v) => setState(() => _q = v),
              decoration: udInputDecoration(context, hint: context.tr('search'), icon: Icons.search_rounded),
            ),
          ),
          if (widget.onAdd != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
              child: UdPressable(
                onTap: () async {
                  final v = await widget.onAdd!();
                  if (v != null && context.mounted) Navigator.pop(context, v);
                },
                color: t.accentSoft,
                borderRadius: 16,
                border: false,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                child: Row(children: [
                  Icon(Icons.add_rounded, color: t.accent),
                  const SizedBox(width: 10),
                  Text(widget.addLabel ?? context.tr('add_new'), style: text.titleMedium?.copyWith(color: t.accent)),
                ]),
              ),
            ),
          const SizedBox(height: 8),
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 24),
              itemCount: list.length,
              itemBuilder: (c, i) {
                final e = list[i];
                return ListTile(
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  title: Text(widget.label(e), style: text.titleMedium),
                  subtitle: widget.sub == null ? null : Text(widget.sub!(e), style: text.bodySmall),
                  trailing: widget.trailing?.call(e),
                  onTap: () => Navigator.pop(context, e),
                );
              },
            ),
          ),
        ]),
      ),
    );
  }
}

/// Dark summary tile with up to three figures.
class Summary extends StatelessWidget {
  const Summary({super.key, required this.cells});
  final List<(String, String, Color?)> cells;

  @override
  Widget build(BuildContext context) {
    final t = UdTokens.of(context);
    final text = Theme.of(context).textTheme;
    return Container(
      padding: const EdgeInsets.all(18),
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(color: t.ink, borderRadius: BorderRadius.circular(24)),
      child: Row(children: [
        for (var i = 0; i < cells.length; i++) ...[
          if (i > 0) Container(width: 1, height: 40, color: t.paper.withValues(alpha: 0.15), margin: const EdgeInsets.symmetric(horizontal: 12)),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(cells[i].$1, maxLines: 1, overflow: TextOverflow.ellipsis, style: text.labelSmall?.copyWith(color: t.paper.withValues(alpha: 0.7))),
              const SizedBox(height: 6),
              FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerLeft,
                child: Text(cells[i].$2, style: text.titleLarge?.copyWith(color: cells[i].$3 ?? t.paper)),
              ),
            ]),
          ),
        ],
      ]),
    );
  }
}

String stateName(String code) => gstStates[code] ?? '';

Future<String?> pickState(BuildContext context, {String? title}) => pickFrom<String>(
      context,
      title: title ?? context.tr('state'),
      items: gstStates.keys.toList()..sort((a, b) => gstStates[a]!.compareTo(gstStates[b]!)),
      label: (c) => gstStates[c]!,
      sub: (c) => c,
    );

String numText(double v) => v == 0 ? '' : (v == v.roundToDouble() ? v.toInt().toString() : v.toString());

double numOf(TextEditingController c) => udParseNum(c.text) ?? 0;
