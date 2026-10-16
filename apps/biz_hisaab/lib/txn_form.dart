import 'dart:math';

import 'package:flutter/material.dart';
import 'package:ud_core/ud_core.dart';

import 'db.dart';
import 'gst.dart';
import 'items.dart';
import 'parties.dart';
import 'txn_view.dart';
import 'ui.dart';

/// Create or edit any document: invoice, bill, estimate, payment, expense…
class TxnForm extends StatefulWidget {
  const TxnForm({super.key, required this.type, this.existing, this.party, this.draft, this.convertFromId, this.amount, this.linkedId});
  final TxnType type;
  final Txn? existing;
  final Party? party;

  /// A prepared new document (e.g. an estimate being turned into an invoice).
  final Txn? draft;
  final String? convertFromId;
  final double? amount;
  final String? linkedId;

  @override
  State<TxnForm> createState() => _TxnFormState();
}

class _TxnFormState extends State<TxnForm> {
  late final Txn _t;
  late final bool _isNew = widget.existing == null;
  late final _number = TextEditingController(text: _t.number);
  late final _amount = TextEditingController(text: numText(_t.amount));
  late final _paid = TextEditingController(text: numText(_t.paid));
  late final _discount = TextEditingController(text: numText(_t.extraDiscount));
  late final _charges = TextEditingController(text: numText(_t.charges));
  late final _notes = TextEditingController(text: _t.notes);
  late final _ref = TextEditingController(text: _t.refNo);
  late final _cashName = TextEditingController(text: _t.partyId.isEmpty ? _t.partyName : '');
  late final _cashPhone = TextEditingController(text: _t.partyId.isEmpty ? _t.partyPhone : '');
  late bool _fullyPaid;

  TxnType get type => _t.type;

  @override
  void initState() {
    super.initState();
    if (widget.existing != null) {
      _t = Txn.fromJson(widget.existing!.toJson());
    } else if (widget.draft != null) {
      _t = widget.draft!;
    } else {
      _t = Txn(type: widget.type)
        ..number = db.nextNumber(widget.type)
        ..taxInclusive = db.biz.taxInclusive
        ..roundOff = db.biz.roundOff
        ..placeOfSupply = db.biz.state
        ..amount = widget.amount ?? 0
        ..linkedId = widget.linkedId ?? '';
      if (widget.type == TxnType.expense) _t.category = 'other_exp';
      if (widget.party != null) _setParty(widget.party!);
    }
    _fullyPaid = !type.isDraftDoc && type.hasLines && _isNew && widget.draft == null && _t.partyId.isEmpty && type == TxnType.sale;
    if (!_isNew && type.hasLines && !type.isDraftDoc) {
      _fullyPaid = _t.paid > 0 && (_t.paid - db.totals(_t).total).abs() < 0.01;
    }
  }

  void _setParty(Party p) {
    if (_isNew) _fullyPaid = false;
    _t
      ..partyId = p.id
      ..partyName = p.name
      ..partyPhone = p.phone;
    if (p.state.isNotEmpty) _t.placeOfSupply = p.state;
    if (p.creditDays > 0 && (type == TxnType.sale || type == TxnType.purchase)) {
      _t.dueDate = dayOnly(_t.date).add(Duration(days: p.creditDays));
    }
    if (type == TxnType.paymentIn && _amount.text.isEmpty) {
      final bal = db.partyBalance(p.id);
      if (bal > 0) _amount.text = numText(round2(bal));
    }
    if (type == TxnType.paymentOut && _amount.text.isEmpty) {
      final bal = -db.partyBalance(p.id);
      if (bal > 0) _amount.text = numText(round2(bal));
    }
  }

  bool get _partyRequired => !(type == TxnType.sale || type == TxnType.estimate || type == TxnType.expense || type == TxnType.saleOrder || type == TxnType.challan);

  Totals get _totals {
    _t
      ..extraDiscount = numOf(_discount)
      ..charges = numOf(_charges);
    return db.totals(_t);
  }

  Future<void> _pickParty() async {
    final sale = type.isSaleSide;
    final list = [...db.parties]..sort((a, b) {
        final ka = (a.kind == 'customer') == sale ? 0 : 1, kb = (b.kind == 'customer') == sale ? 0 : 1;
        return ka != kb ? ka - kb : a.name.toLowerCase().compareTo(b.name.toLowerCase());
      });
    final p = await pickFrom<Party>(
      context,
      title: context.tr(sale ? 'pick_customer' : 'pick_supplier'),
      items: list,
      label: (p) => p.name,
      sub: (p) => [if (p.phone.isNotEmpty) p.phone, _balText(context, db.partyBalance(p.id))].join(' · '),
      addLabel: context.tr(sale ? 'add_customer' : 'add_supplier'),
      onAdd: () => Navigator.of(context).push<Party>(
          MaterialPageRoute(builder: (_) => PartyForm(kind: sale ? 'customer' : 'supplier', returnOnSave: true))),
    );
    if (p != null) setState(() => _setParty(p));
  }

  Future<void> _editLine([int? index]) async {
    Line? line;
    if (index == null) {
      final it = await pickItem(context, sale: type.isSaleSide, inclusive: _t.taxInclusive);
      if (it == null || !mounted) return;
      line = it;
      // Adding the same item again just bumps the quantity.
      final same = _t.lines.indexWhere((l) => l.itemId.isNotEmpty && l.itemId == it.itemId && l.rate == it.rate);
      if (same != -1) {
        setState(() => _t.lines[same].qty += 1);
        return;
      }
    } else {
      line = _t.lines[index].copy();
    }
    final res = await showModalBottomSheet<Object>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (c) => LineSheet(line: line!, inclusive: _t.taxInclusive, canDelete: index != null),
    );
    if (!mounted) return;
    setState(() {
      if (res == 'delete' && index != null) {
        _t.lines.removeAt(index);
      } else if (res is Line) {
        if (index == null) {
          _t.lines.add(res);
        } else {
          _t.lines[index] = res;
        }
      }
    });
  }

  Future<void> _save() async {
    if (_number.text.trim().isEmpty) _number.text = db.nextNumber(type);
    _t
      ..number = _number.text.trim()
      ..notes = _notes.text.trim()
      ..refNo = _ref.text.trim()
      ..extraDiscount = numOf(_discount)
      ..charges = numOf(_charges);
    if (_t.partyId.isEmpty) {
      _t
        ..partyName = _cashName.text.trim()
        ..partyPhone = _cashPhone.text.trim();
    }
    if (_partyRequired && _t.partyId.isEmpty) {
      udToast(context, context.tr('need_party'));
      return;
    }
    if (type.hasLines) {
      if (_t.lines.isEmpty) {
        udToast(context, context.tr('need_items'));
        return;
      }
      final total = db.totals(_t).total;
      if (type.isDraftDoc) {
        _t.paid = 0;
      } else {
        _t.paid = _fullyPaid ? total : min(numOf(_paid), total);
      }
    } else {
      _t.amount = numOf(_amount);
      if (_t.amount <= 0) {
        udToast(context, context.tr('need_amount'));
        return;
      }
    }
    if (_t.dueDate != null && _t.dueDate!.isBefore(dayOnly(_t.date))) _t.dueDate = dayOnly(_t.date);
    if (_t.mode == 'cash') {
      _t.accountId = 'cash';
    } else if (_t.accountId == 'cash' && db.accounts.length > 1) {
      _t.accountId = db.accounts.firstWhere((a) => a.id != 'cash').id;
    }
    await db.putTxn(_t);
    if (widget.convertFromId != null) {
      final src = db.txn(widget.convertFromId!);
      if (src != null) {
        src.convertedTo = _t.id;
        await db.putTxn(src);
      }
    }
    if (!mounted) return;
    udToast(context, context.tr('saved'));
    if (_isNew) {
      Navigator.of(context).pushReplacement(MaterialPageRoute(builder: (_) => TxnView(id: _t.id, justSaved: true)));
    } else {
      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = UdTokens.of(context);
    final text = Theme.of(context).textTheme;
    final totals = type.hasLines ? _totals : null;
    final party = db.party(_t.partyId);
    final sale = type.isSaleSide;

    return UdPage(
      eyebrow: typeLabel(context, type),
      title: _isNew ? context.tr('new_x', {'x': typeLabel(context, type)}) : '${typeLabel(context, type)} ${_t.number}',
      dock: UdDock(
        label: context.tr('save'),
        icon: Icons.check_rounded,
        onPressed: _save,
      ),
      slivers: [
        UdSliverPad(
          sliver: SliverList.list(children: [
            // ---------------- who
            if (type != TxnType.expense) ...[
              PickField(
                label: context.tr(sale ? 'customer' : 'supplier') + (_partyRequired ? '' : ' (${context.tr('optional')})'),
                value: party?.name ?? context.tr(sale ? 'pick_customer' : 'pick_supplier'),
                placeholder: party == null,
                icon: Icons.person_outline_rounded,
                onTap: _pickParty,
              ),
              if (party != null)
                Padding(
                  padding: const EdgeInsets.only(left: 4, bottom: 8),
                  child: Row(children: [
                    Expanded(child: Text(_balText(context, db.partyBalance(party.id)), style: text.bodySmall)),
                    TextButton(
                      onPressed: () => setState(() {
                        if (_isNew) _fullyPaid = type == TxnType.sale;
                        _t
                          ..partyId = ''
                          ..partyName = ''
                          ..partyPhone = '';
                      }),
                      child: Text(context.tr('clear')),
                    ),
                  ]),
                ),
              if (party == null && !_partyRequired && type.hasLines)
                Row(children: [
                  Expanded(child: Field(_cashName, context.tr('cash_name'), hint: context.tr('optional'), caps: TextCapitalization.words)),
                  const SizedBox(width: 10),
                  Expanded(child: Field(_cashPhone, context.tr('phone'), type: TextInputType.phone, hint: context.tr('optional'))),
                ]),
            ],
            if (type == TxnType.expense) ...[
              UdLabel(context.tr('category')),
              Chips<String>(
                values: expenseCategories,
                selected: _t.category,
                label: (c) => context.tr('ec_$c'),
                onSelect: (c) => setState(() => _t.category = c),
              ),
              const SizedBox(height: 16),
            ],
            // ---------------- number & dates
            Row(children: [
              Expanded(child: Field(_number, context.tr(type == TxnType.purchase ? 'bill_no' : 'number'), caps: TextCapitalization.characters)),
              const SizedBox(width: 10),
              Expanded(
                child: PickField(
                  label: context.tr('date'),
                  value: dmy(_t.date),
                  icon: Icons.event_outlined,
                  onTap: () async {
                    final d = await pickDate(context, _t.date);
                    if (d != null) {
                      setState(() => _t.date = DateTime(d.year, d.month, d.day, _t.date.hour, _t.date.minute));
                    }
                  },
                ),
              ),
            ]),
            if (type == TxnType.sale || type == TxnType.purchase || type == TxnType.estimate)
              PickField(
                label: context.tr(type == TxnType.estimate ? 'valid_till' : 'due_date'),
                value: _t.dueDate == null ? context.tr('none') : dmy(_t.dueDate!),
                placeholder: _t.dueDate == null,
                icon: Icons.event_available_outlined,
                onTap: () async {
                  final choice = await showUdActions<int>(context, actions: [
                    UdAction(0, Icons.block_rounded, context.tr('none')),
                    for (final d in [7, 15, 30, 45, 60]) UdAction(d, Icons.timelapse_rounded, context.tr('n_days', {'n': '$d'})),
                    UdAction(-1, Icons.calendar_month_rounded, context.tr('pick_date')),
                  ]);
                  if (choice == null || !context.mounted) return;
                  if (choice == -1) {
                    final d = await pickDate(context, _t.dueDate ?? _t.date.add(const Duration(days: 15)));
                    if (d != null) setState(() => _t.dueDate = d);
                  } else {
                    setState(() => _t.dueDate = choice == 0 ? null : dayOnly(_t.date).add(Duration(days: choice)));
                  }
                },
              ),
            if (type.hasLines && db.biz.gstEnabled)
              PickField(
                label: context.tr('place_of_supply'),
                value: stateName(_t.placeOfSupply).isEmpty ? context.tr('pick') : '${stateName(_t.placeOfSupply)} (${_t.placeOfSupply})',
                icon: Icons.place_outlined,
                onTap: () async {
                  final s = await pickState(context, title: context.tr('place_of_supply'));
                  if (s != null) setState(() => _t.placeOfSupply = s);
                },
              ),

            // ---------------- items
            if (type.hasLines) ...[
              UdLabel(context.tr('items_n', {'n': '${_t.lines.length}'}),
                  trailing: Row(mainAxisSize: MainAxisSize.min, children: [
                    Text(context.tr('price_incl_tax'), style: text.labelSmall),
                    Switch(
                      value: _t.taxInclusive,
                      onChanged: (v) => setState(() => _t.taxInclusive = v),
                    ),
                  ])),
              for (var i = 0; i < _t.lines.length; i++) _lineTile(i),
              UdPressable(
                onTap: () => _editLine(),
                color: t.accentSoft,
                border: false,
                borderRadius: 18,
                padding: const EdgeInsets.symmetric(vertical: 16),
                child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                  Icon(Icons.add_rounded, color: t.accent),
                  const SizedBox(width: 8),
                  Text(context.tr('add_item'), style: text.titleMedium?.copyWith(color: t.accent)),
                ]),
              ),
              const SizedBox(height: 18),
              Card2(
                child: Column(children: [
                  KV(context.tr('subtotal'), money(totals!.gross)),
                  if (totals.discount > 0) KV(context.tr('item_discount'), '- ${money(totals.discount)}'),
                  if (db.biz.gstEnabled && totals.tax > 0) ...[
                    KV(context.tr('taxable'), money(totals.taxable)),
                    if (totals.interState)
                      KV('IGST', money(totals.igst))
                    else ...[
                      KV('CGST', money(totals.cgst)),
                      KV('SGST', money(totals.sgst)),
                    ],
                  ],
                  const SizedBox(height: 8),
                  Row(children: [
                    Expanded(child: Field(_discount, context.tr('extra_discount'), type: Field.number, prefix: '₹ ', onChanged: (_) => setState(() {}))),
                    const SizedBox(width: 10),
                    Expanded(child: Field(_charges, context.tr('charges'), type: Field.number, prefix: '₹ ', onChanged: (_) => setState(() {}))),
                  ]),
                  Row(children: [
                    Expanded(child: Text(context.tr('round_off'), style: text.bodyMedium)),
                    if (totals.roundOff.abs() > 0.001) Text(money(totals.roundOff), style: text.bodySmall),
                    Switch(value: _t.roundOff, onChanged: (v) => setState(() => _t.roundOff = v)),
                  ]),
                  Divider(color: t.line),
                  KV(context.tr('total'), money(totals.total), bold: true),
                ]),
              ),
              if (!type.isDraftDoc) ...[
                Row(children: [
                  Expanded(
                    child: Text(context.tr(type.cashSign > 0 ? 'fully_received' : 'fully_paid'), style: text.titleMedium),
                  ),
                  Switch(value: _fullyPaid, onChanged: (v) => setState(() => _fullyPaid = v)),
                ]),
                if (!_fullyPaid)
                  Field(_paid, context.tr(type.cashSign > 0 ? 'received_now' : 'paid_now'),
                      type: Field.number, prefix: '₹ ', hint: '0', onChanged: (_) => setState(() {})),
                if (!_fullyPaid && totals.total - numOf(_paid) > 0)
                  Padding(
                    padding: const EdgeInsets.only(left: 4, bottom: 12),
                    child: Text('${context.tr('balance_due')}: ${money(max(0, totals.total - numOf(_paid)))}',
                        style: text.titleSmall?.copyWith(color: t.danger)),
                  ),
              ],
            ],
            if (!type.hasLines)
              Field(_amount, context.tr('amount'), type: Field.number, prefix: '₹ ', autofocus: _isNew && widget.amount == null, onChanged: (_) => setState(() {})),

            // ---------------- how paid
            if (!type.isDraftDoc && (!type.hasLines || _fullyPaid || numOf(_paid) > 0)) ...[
              UdLabel(context.tr('pay_mode')),
              Chips<String>(
                values: payModes,
                selected: _t.mode,
                label: (m) => context.tr('pm_$m'),
                onSelect: (m) => setState(() {
                  _t.mode = m;
                  if (m == 'cash') _t.accountId = 'cash';
                }),
              ),
              if (_t.mode != 'cash' && db.accounts.length > 1) ...[
                const SizedBox(height: 14),
                PickField(
                  label: context.tr('account'),
                  value: db.account(_t.accountId == 'cash' ? db.accounts.firstWhere((a) => a.id != 'cash').id : _t.accountId).name,
                  icon: Icons.account_balance_outlined,
                  onTap: () async {
                    final a = await pickFrom<Account>(context,
                        title: context.tr('account'), items: db.accounts.where((a) => a.id != 'cash').toList(), label: (a) => a.name);
                    if (a != null) setState(() => _t.accountId = a.id);
                  },
                ),
              ] else
                const SizedBox(height: 14),
              if (_t.mode == 'cheque' || _t.mode == 'bank' || _t.mode == 'upi')
                Field(_ref, context.tr(_t.mode == 'cheque' ? 'cheque_no' : 'ref_no'), caps: TextCapitalization.characters),
            ],
            Field(_notes, context.tr('notes'), maxLines: 3, hint: context.tr('optional')),
          ]),
        ),
      ],
    );
  }

  Widget _lineTile(int i) {
    final l = _t.lines[i];
    final c = calcLine(l, inclusive: _t.taxInclusive, gst: db.biz.gstEnabled);
    final text = Theme.of(context).textTheme;
    final t = UdTokens.of(context);
    final stock = l.itemId.isEmpty ? null : db.item(l.itemId);
    final avail = stock == null || stock.isService ? null : db.stockOf(stock.id);
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: UdPressable(
        onTap: () => _editLine(i),
        borderRadius: 18,
        padding: const EdgeInsets.fromLTRB(14, 12, 6, 12),
        child: Row(children: [
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(l.name, maxLines: 2, overflow: TextOverflow.ellipsis, style: text.titleMedium),
              const SizedBox(height: 3),
              Text(
                [
                  '${qtyText(l.qty)} ${l.unit} × ${money(l.rate)}',
                  if (l.discountPct > 0) '-${rateText(l.discountPct)}',
                  if (db.biz.gstEnabled && l.gstRate > 0) 'GST ${rateText(l.gstRate)}',
                ].join(' · '),
                style: text.bodySmall,
              ),
              if (avail != null && type.stockSign < 0 && avail < l.qty)
                Text(context.tr('stock_left', {'n': qtyText(avail)}), style: text.labelSmall?.copyWith(color: t.danger)),
            ]),
          ),
          Text(money(c.total), style: text.titleMedium),
          Column(mainAxisSize: MainAxisSize.min, children: [
            InkResponse(
              onTap: () => setState(() => l.qty += 1),
              child: Padding(padding: const EdgeInsets.all(6), child: Icon(Icons.add_circle_outline_rounded, size: 22, color: t.accent)),
            ),
            InkResponse(
              onTap: () => setState(() {
                if (l.qty > 1) {
                  l.qty -= 1;
                } else {
                  _t.lines.removeAt(i);
                }
              }),
              child: Padding(padding: const EdgeInsets.all(6), child: Icon(Icons.remove_circle_outline_rounded, size: 22, color: t.inkSoft)),
            ),
          ]),
        ]),
      ),
    );
  }
}

String _balText(BuildContext context, double bal) {
  if (bal.abs() < 0.01) return context.tr('settled');
  return bal > 0 ? context.tr('they_owe', {'a': money(bal)}) : context.tr('you_owe', {'a': money(-bal)});
}

String balanceText(BuildContext context, double bal) => _balText(context, bal);

/// Picks an item from the catalogue (or a one-off line) and returns a filled line.
Future<Line?> pickItem(BuildContext context, {required bool sale, required bool inclusive}) async {
  final list = [...db.items]..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
  const oneOff = '__one_off__';
  final picked = await pickFrom<Object>(
    context,
    title: context.tr('pick_item'),
    items: [oneOff, ...list],
    label: (e) => e is Item ? e.name : context.tr('one_off_item'),
    sub: (e) => e is Item
        ? [
            money(sale ? e.salePrice : e.purchasePrice),
            if (!e.isService) '${context.tr('stock')}: ${qtyText(db.stockOf(e.id))} ${e.unit}',
            if (e.code.isNotEmpty) e.code,
          ].join(' · ')
        : context.tr('one_off_item_sub'),
    addLabel: context.tr('add_item_catalog'),
    onAdd: () => Navigator.of(context).push<Object>(MaterialPageRoute(builder: (_) => const ItemForm(returnOnSave: true))),
  );
  if (picked == null) return null;
  if (picked is! Item) return Line()..gstRate = 0;
  final price = sale ? picked.salePrice : picked.purchasePrice;
  return Line()
    ..itemId = picked.id
    ..name = picked.name
    ..hsn = picked.hsn
    ..unit = picked.unit
    ..qty = 1
    ..gstRate = picked.gstRate
    // Convert the item's price when the document counts tax the other way.
    ..rate = !db.biz.gstEnabled || picked.taxInclusive == inclusive
        ? price
        : picked.taxInclusive
            ? round2(price / (1 + picked.gstRate / 100))
            : round2(price * (1 + picked.gstRate / 100));
}

/// Edits one invoice line.
class LineSheet extends StatefulWidget {
  const LineSheet({super.key, required this.line, required this.inclusive, required this.canDelete});
  final Line line;
  final bool inclusive;
  final bool canDelete;

  @override
  State<LineSheet> createState() => _LineSheetState();
}

class _LineSheetState extends State<LineSheet> {
  late final Line l = widget.line;
  late final _name = TextEditingController(text: l.name);
  late final _qty = TextEditingController(text: qtyText(l.qty));
  late final _rate = TextEditingController(text: numText(l.rate));
  late final _disc = TextEditingController(text: numText(l.discountPct));
  late final _hsn = TextEditingController(text: l.hsn);

  void _sync() {
    l
      ..name = _name.text.trim()
      ..qty = udParseNum(_qty.text) ?? 0
      ..rate = numOf(_rate)
      ..discountPct = numOf(_disc).clamp(0, 100).toDouble()
      ..hsn = _hsn.text.trim();
  }

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final t = UdTokens.of(context);
    _sync();
    final c = calcLine(l, inclusive: widget.inclusive, gst: db.biz.gstEnabled);
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(l.itemId.isEmpty ? context.tr('one_off_item') : l.name, style: text.headlineSmall),
          const SizedBox(height: 16),
          if (l.itemId.isEmpty) Field(_name, context.tr('item_name'), autofocus: true, caps: TextCapitalization.words),
          Row(children: [
            Expanded(child: Field(_qty, context.tr('qty'), type: Field.number, autofocus: l.itemId.isNotEmpty, onChanged: (_) => setState(() {}))),
            const SizedBox(width: 10),
            Expanded(
              child: PickField(
                label: context.tr('unit'),
                value: l.unit,
                onTap: () async {
                  final u = await pickFrom<String>(context, title: context.tr('unit'), items: units, label: (u) => u);
                  if (u != null) setState(() => l.unit = u);
                },
              ),
            ),
          ]),
          Row(children: [
            Expanded(child: Field(_rate, context.tr('rate'), type: Field.number, prefix: '₹ ', onChanged: (_) => setState(() {}))),
            const SizedBox(width: 10),
            Expanded(child: Field(_disc, context.tr('discount_pct'), type: Field.number, hint: '0', onChanged: (_) => setState(() {}))),
          ]),
          if (db.biz.gstEnabled) ...[
            UdLabel(context.tr('gst_rate')),
            Chips<double>(values: gstRates, selected: l.gstRate, label: rateText, onSelect: (r) => setState(() => l.gstRate = r)),
            const SizedBox(height: 14),
            Field(_hsn, context.tr('hsn'), type: TextInputType.number),
          ],
          Card2(
            child: Column(children: [
              KV(context.tr('amount'), money(c.gross)),
              if (c.discount > 0) KV(context.tr('discount'), '- ${money(c.discount)}'),
              if (db.biz.gstEnabled && c.tax > 0) KV('GST', money(c.tax)),
              Divider(color: t.line),
              KV(context.tr('total'), money(c.total), bold: true),
            ]),
          ),
          Row(children: [
            if (widget.canDelete) ...[
              Expanded(
                child: OutlinedButton(
                  style: OutlinedButton.styleFrom(foregroundColor: t.danger),
                  onPressed: () => Navigator.pop(context, 'delete'),
                  child: Text(context.tr('remove')),
                ),
              ),
              const SizedBox(width: 12),
            ],
            Expanded(
              flex: 2,
              child: FilledButton(
                onPressed: () {
                  _sync();
                  if (l.name.isEmpty || l.qty <= 0) {
                    udToast(context, context.tr('need_name_qty'));
                    return;
                  }
                  Navigator.pop(context, l);
                },
                child: Text(context.tr('done')),
              ),
            ),
          ]),
        ]),
      ),
    );
  }
}
