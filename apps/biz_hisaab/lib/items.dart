import 'package:flutter/material.dart';
import 'package:ud_core/ud_core.dart';

import 'db.dart';
import 'gst.dart';
import 'txn_view.dart';
import 'ui.dart';

class ItemsTab extends StatefulWidget {
  const ItemsTab({super.key});

  @override
  State<ItemsTab> createState() => _ItemsTabState();
}

class _ItemsTabState extends State<ItemsTab> {
  String _q = '';
  String _filter = 'all'; // all, low, service

  @override
  Widget build(BuildContext context) {
    final t = UdTokens.of(context);
    final text = Theme.of(context).textTheme;
    final q = _q.toLowerCase();
    final low = db.lowStockItems.map((e) => e.id).toSet();
    final list = db.items
        .where((i) => switch (_filter) { 'low' => low.contains(i.id), 'service' => i.isService, 'product' => !i.isService, _ => true })
        .where((i) => q.isEmpty || i.name.toLowerCase().contains(q) || i.code.toLowerCase().contains(q) || i.hsn.contains(q) || i.category.toLowerCase().contains(q))
        .toList()
      ..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
    return UdPage(
      title: context.tr('nav_items'),
      subtitle: context.tr('items_sub', {'n': '${db.items.length}'}),
      showBack: false,
      dock: UdDock(label: context.tr('add_item_catalog'), icon: Icons.add_rounded, onPressed: () => go(context, const ItemForm())),
      slivers: [
        UdSliverPad(
          sliver: SliverList.list(children: [
            Summary(cells: [
              (context.tr('stock_value'), money(db.stockValue, decimals: 0), null),
              (context.tr('low_stock'), '${low.length}', low.isEmpty ? null : const Color(0xFFFFC66B)),
            ]),
            TextField(
              onChanged: (v) => setState(() => _q = v),
              decoration: udInputDecoration(context, hint: context.tr('search_items'), icon: Icons.search_rounded),
            ),
            const SizedBox(height: 12),
            Chips<String>(
              values: const ['all', 'product', 'service', 'low'],
              selected: _filter,
              label: (f) => context.tr('if_$f'),
              onSelect: (f) => setState(() => _filter = f),
            ),
            const SizedBox(height: 14),
            if (db.items.isEmpty)
              UdEmpty(icon: Icons.inventory_2_outlined, title: context.tr('empty_items'), body: context.tr('empty_items_sub'))
            else
              for (final i in list)
                UdRow(
                  leading: UdBadgeIcon(i.isService ? Icons.handyman_outlined : Icons.inventory_2_outlined, size: 44, color: low.contains(i.id) ? amber : null),
                  title: i.name,
                  subtitle: [
                    '${context.tr('sale')} ${money(i.salePrice)}',
                    if (i.purchasePrice > 0) '${context.tr('purchase')} ${money(i.purchasePrice)}',
                    if (db.biz.gstEnabled && i.gstRate > 0) 'GST ${rateText(i.gstRate)}',
                  ].join(' · '),
                  trailing: i.isService
                      ? null
                      : Column(crossAxisAlignment: CrossAxisAlignment.end, mainAxisSize: MainAxisSize.min, children: [
                          Text(qtyText(db.stockOf(i.id)), style: text.titleMedium?.copyWith(color: low.contains(i.id) ? t.danger : t.ink)),
                          Text(i.unit, style: text.labelSmall),
                        ]),
                  onTap: () => go(context, ItemPage(id: i.id)),
                ),
          ]),
        ),
      ],
    );
  }
}

class ItemPage extends StatelessWidget {
  const ItemPage({super.key, required this.id});
  final String id;

  Future<void> _adjust(BuildContext context, Item it) async {
    final qty = TextEditingController();
    final note = TextEditingController();
    var add = true;
    final ok = await showUdSheet<bool>(context, (c) {
      return StatefulBuilder(builder: (c, set) {
        return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(c.tr('adjust_stock'), style: Theme.of(c).textTheme.headlineSmall),
          const SizedBox(height: 14),
          Chips<bool>(values: const [true, false], selected: add, label: (v) => c.tr(v ? 'stock_add' : 'stock_reduce'), onSelect: (v) => set(() => add = v)),
          const SizedBox(height: 14),
          Field(qty, '${c.tr('qty')} (${it.unit})', type: Field.number, autofocus: true),
          Field(note, c.tr('reason'), hint: c.tr('reason_hint')),
          SizedBox(width: double.infinity, child: FilledButton(onPressed: () => Navigator.pop(c, true), child: Text(c.tr('save')))),
        ]);
      });
    });
    final q = udParseNum(qty.text) ?? 0;
    if (ok == true && q > 0) {
      await db.addAdjustment(StockAdj(itemId: it.id, qty: add ? q : -q, note: note.text.trim()));
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: db,
      builder: (context, _) {
        final it = db.item(id);
        if (it == null) return UdPage(title: context.tr('not_found'));
        final text = Theme.of(context).textTheme;
        final moves = <(DateTime, String, double, Txn?)>[
          for (final t in db.txns)
            if (t.type.stockSign != 0)
              for (final l in t.lines)
                if (l.itemId == it.id) (t.date, '${typeLabel(context, t.type)} ${t.number}${t.partyName.isEmpty ? '' : ' · ${t.partyName}'}', t.type.stockSign * l.qty, t),
          for (final a in db.adjustments)
            if (a.itemId == it.id) (a.date, '${context.tr('adjustment')}${a.note.isEmpty ? '' : ' · ${a.note}'}', a.qty, null),
        ]..sort((a, b) => b.$1.compareTo(a.$1));
        final sold = db.txns.where((t) => t.type == TxnType.sale).expand((t) => t.lines).where((l) => l.itemId == it.id).fold<double>(0, (s, l) => s + l.qty);
        return UdPage(
          eyebrow: context.tr(it.isService ? 'service' : 'product'),
          title: it.name,
          subtitle: [if (it.code.isNotEmpty) it.code, if (it.hsn.isNotEmpty) 'HSN ${it.hsn}', if (it.category.isNotEmpty) it.category].join(' · '),
          actions: [UdIconButton(icon: Icons.edit_outlined, tooltip: context.tr('edit'), onTap: () => go(context, ItemForm(existing: it)))],
          dock: it.isService ? null : UdDock(label: context.tr('adjust_stock'), icon: Icons.tune_rounded, onPressed: () => _adjust(context, it)),
          slivers: [
            UdSliverPad(
              sliver: SliverList.list(children: [
                Summary(cells: [
                  if (!it.isService) (context.tr('in_stock'), '${qtyText(db.stockOf(it.id))} ${it.unit}', null),
                  (context.tr('sold'), '${qtyText(sold)} ${it.unit}', null),
                ]),
                Card2(
                  child: Column(children: [
                    KV(context.tr('sale_price'), money(it.salePrice) + (it.taxInclusive ? ' (${context.tr('incl_tax')})' : '')),
                    KV(context.tr('purchase_price'), money(it.purchasePrice)),
                    if (it.mrp > 0) KV('MRP', money(it.mrp)),
                    if (db.biz.gstEnabled) KV('GST', rateText(it.gstRate)),
                    if (!it.isService) ...[
                      KV(context.tr('stock_value'), money(db.stockOf(it.id) * it.purchasePrice)),
                      if (it.lowStock > 0) KV(context.tr('low_stock_at'), '${qtyText(it.lowStock)} ${it.unit}'),
                    ],
                    if (it.purchasePrice > 0 && it.salePrice > 0)
                      KV(context.tr('margin'), '${money(it.salePrice - it.purchasePrice)} (${((it.salePrice - it.purchasePrice) / it.purchasePrice * 100).toStringAsFixed(1)}%)'),
                  ]),
                ),
                if (!it.isService) ...[
                  UdLabel(context.tr('stock_moves')),
                  if (it.openingStock != 0)
                    UdRow(title: context.tr('opening_stock'), subtitle: dmy(it.createdAt), trailing: Text('+${qtyText(it.openingStock)}', style: text.titleSmall)),
                  for (final m in moves)
                    UdRow(
                      title: m.$2,
                      subtitle: dmy(m.$1),
                      trailing: Text('${m.$3 > 0 ? '+' : ''}${qtyText(m.$3)}', style: text.titleSmall?.copyWith(color: m.$3 > 0 ? green : UdTokens.of(context).danger)),
                      onTap: m.$4 == null ? null : () => go(context, TxnView(id: m.$4!.id)),
                    ),
                ],
              ]),
            ),
          ],
        );
      },
    );
  }
}

class ItemForm extends StatefulWidget {
  const ItemForm({super.key, this.existing, this.returnOnSave = false});
  final Item? existing;
  final bool returnOnSave;

  @override
  State<ItemForm> createState() => _ItemFormState();
}

class _ItemFormState extends State<ItemForm> {
  late final Item _i = widget.existing == null ? (Item()..taxInclusive = db.biz.taxInclusive) : Item.fromJson(widget.existing!.toJson());
  late final _name = TextEditingController(text: _i.name);
  late final _code = TextEditingController(text: _i.code);
  late final _hsn = TextEditingController(text: _i.hsn);
  late final _cat = TextEditingController(text: _i.category);
  late final _sale = TextEditingController(text: numText(_i.salePrice));
  late final _buy = TextEditingController(text: numText(_i.purchasePrice));
  late final _mrp = TextEditingController(text: numText(_i.mrp));
  late final _open = TextEditingController(text: numText(_i.openingStock));
  late final _low = TextEditingController(text: numText(_i.lowStock));

  Future<void> _save() async {
    if (_name.text.trim().isEmpty) {
      udToast(context, context.tr('need_name'));
      return;
    }
    _i
      ..name = _name.text.trim()
      ..code = _code.text.trim()
      ..hsn = _hsn.text.trim()
      ..category = _cat.text.trim()
      ..salePrice = numOf(_sale)
      ..purchasePrice = numOf(_buy)
      ..mrp = numOf(_mrp)
      ..openingStock = numOf(_open)
      ..lowStock = numOf(_low);
    await db.putItem(_i);
    if (!mounted) return;
    if (widget.returnOnSave) {
      Navigator.of(context).pop(_i);
    } else {
      Navigator.of(context).pop();
    }
  }

  Future<void> _delete() async {
    if (!await udConfirm(context)) return;
    await db.deleteItem(_i.id);
    if (mounted) Navigator.of(context).popUntil((r) => r.isFirst);
  }

  @override
  Widget build(BuildContext context) {
    final cats = {for (final i in db.items) if (i.category.isNotEmpty) i.category}.toList()..sort();
    return UdPage(
      title: widget.existing == null ? context.tr('add_item_catalog') : context.tr('edit_item'),
      actions: [if (widget.existing != null) UdIconButton(icon: Icons.delete_outline_rounded, tooltip: context.tr('delete'), onTap: _delete)],
      dock: UdDock(label: context.tr('save'), icon: Icons.check_rounded, onPressed: _save),
      slivers: [
        UdSliverPad(
          sliver: SliverList.list(children: [
            Chips<bool>(
              values: const [false, true],
              selected: _i.isService,
              label: (v) => context.tr(v ? 'service' : 'product'),
              onSelect: (v) => setState(() => _i.isService = v),
            ),
            const SizedBox(height: 16),
            Field(_name, context.tr('item_name'), caps: TextCapitalization.words, autofocus: widget.existing == null),
            Row(children: [
              Expanded(child: Field(_sale, context.tr('sale_price'), type: Field.number, prefix: '₹ ')),
              const SizedBox(width: 10),
              Expanded(child: Field(_buy, context.tr('purchase_price'), type: Field.number, prefix: '₹ ')),
            ]),
            PickField(
              label: context.tr('unit'),
              value: _i.unit,
              onTap: () async {
                final u = await pickFrom<String>(context, title: context.tr('unit'), items: units, label: (u) => u);
                if (u != null) setState(() => _i.unit = u);
              },
            ),
            if (db.biz.gstEnabled) ...[
              UdLabel(context.tr('gst_rate')),
              Chips<double>(values: gstRates, selected: _i.gstRate, label: rateText, onSelect: (r) => setState(() => _i.gstRate = r)),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(context.tr('price_incl_tax')),
                value: _i.taxInclusive,
                onChanged: (v) => setState(() => _i.taxInclusive = v),
              ),
              Field(_hsn, context.tr(_i.isService ? 'sac' : 'hsn'), type: TextInputType.number, hint: context.tr('optional')),
            ],
            if (!_i.isService) ...[
              Row(children: [
                Expanded(child: Field(_open, context.tr('opening_stock'), type: Field.number, hint: '0')),
                const SizedBox(width: 10),
                Expanded(child: Field(_low, context.tr('low_stock_at'), type: Field.number, hint: '0')),
              ]),
              Field(_mrp, 'MRP', type: Field.number, prefix: '₹ ', hint: context.tr('optional')),
            ],
            Field(_code, context.tr('item_code'), hint: context.tr('optional'), caps: TextCapitalization.characters),
            Field(_cat, context.tr('item_category'), hint: context.tr('optional'), caps: TextCapitalization.words),
            if (cats.isNotEmpty)
              Wrap(spacing: 8, children: [
                for (final c in cats) ActionChip(label: Text(c), onPressed: () => setState(() => _cat.text = c)),
              ]),
          ]),
        ),
      ],
    );
  }
}
