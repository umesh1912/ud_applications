import 'package:flutter/material.dart';
import 'package:ud_core/ud_core.dart';

import 'db.dart';
import 'gst.dart';
import 'home.dart';
import 'pdf.dart';
import 'share.dart';
import 'txn_view.dart';
import 'ui.dart';

class PartiesTab extends StatefulWidget {
  const PartiesTab({super.key});

  @override
  State<PartiesTab> createState() => _PartiesTabState();
}

class _PartiesTabState extends State<PartiesTab> {
  String _filter = 'all';
  String _q = '';

  @override
  Widget build(BuildContext context) {
    final t = UdTokens.of(context);
    final text = Theme.of(context).textTheme;
    final q = _q.toLowerCase();
    final list = db.parties
        .where((p) => _filter == 'all' || p.kind == _filter)
        .where((p) => q.isEmpty || p.name.toLowerCase().contains(q) || p.phone.contains(q) || p.gstin.toLowerCase().contains(q))
        .toList()
      ..sort((a, b) {
        final ba = db.partyBalance(a.id).abs(), bb = db.partyBalance(b.id).abs();
        if ((ba > 0.01) != (bb > 0.01)) return ba > 0.01 ? -1 : 1;
        return a.name.toLowerCase().compareTo(b.name.toLowerCase());
      });
    return UdPage(
      title: context.tr('nav_parties'),
      subtitle: context.tr('parties_sub', {'n': '${db.parties.length}'}),
      showBack: false,
      dock: UdDock(
        label: context.tr('add_party'),
        icon: Icons.person_add_alt_1_rounded,
        onPressed: () => go(context, PartyForm(kind: _filter == 'supplier' ? 'supplier' : 'customer')),
      ),
      slivers: [
        UdSliverPad(
          sliver: SliverList.list(children: [
            Summary(cells: [
              (context.tr('to_receive'), money(db.toReceive, decimals: 0), const Color(0xFF8FD1A8)),
              (context.tr('to_pay'), money(db.toPay, decimals: 0), const Color(0xFFFF9B8F)),
            ]),
            TextField(
              onChanged: (v) => setState(() => _q = v),
              decoration: udInputDecoration(context, hint: context.tr('search_parties'), icon: Icons.search_rounded),
            ),
            const SizedBox(height: 12),
            Chips<String>(
              values: const ['all', 'customer', 'supplier'],
              selected: _filter,
              label: (f) => context.tr('pk_$f'),
              onSelect: (f) => setState(() => _filter = f),
            ),
            const SizedBox(height: 14),
            if (db.parties.isEmpty)
              UdEmpty(icon: Icons.people_outline_rounded, title: context.tr('empty_parties'), body: context.tr('empty_parties_sub'))
            else
              for (final p in list)
                UdRow(
                  leading: _Avatar(p.name),
                  title: p.name,
                  subtitle: [context.tr('pk_${p.kind}'), if (p.phone.isNotEmpty) p.phone].join(' · '),
                  trailing: _BalanceText(db.partyBalance(p.id)),
                  onTap: () => go(context, PartyPage(id: p.id)),
                ),
            if (db.parties.isNotEmpty && list.isEmpty)
              Padding(padding: const EdgeInsets.all(24), child: Text(context.tr('no_match'), textAlign: TextAlign.center, style: text.bodyMedium?.copyWith(color: t.inkSoft))),
          ]),
        ),
      ],
    );
  }
}

class _Avatar extends StatelessWidget {
  const _Avatar(this.name);
  final String name;

  @override
  Widget build(BuildContext context) {
    final t = UdTokens.of(context);
    final initials = name.trim().split(RegExp(r'\s+')).where((w) => w.isNotEmpty).take(2).map((w) => w.characters.first.toUpperCase()).join();
    return Container(
      width: 44,
      height: 44,
      alignment: Alignment.center,
      decoration: BoxDecoration(color: t.accentSoft, borderRadius: BorderRadius.circular(14)),
      child: Text(initials.isEmpty ? '?' : initials, style: Theme.of(context).textTheme.titleMedium?.copyWith(color: t.accent)),
    );
  }
}

class _BalanceText extends StatelessWidget {
  const _BalanceText(this.bal);
  final double bal;

  @override
  Widget build(BuildContext context) {
    final t = UdTokens.of(context);
    final text = Theme.of(context).textTheme;
    if (bal.abs() < 0.01) return Text(context.tr('settled'), style: text.labelSmall);
    final c = bal > 0 ? green : t.danger;
    return Column(crossAxisAlignment: CrossAxisAlignment.end, mainAxisSize: MainAxisSize.min, children: [
      Text(money(bal.abs(), decimals: 0), style: text.titleMedium?.copyWith(color: c)),
      Text(context.tr(bal > 0 ? 'will_get' : 'will_give'), style: text.labelSmall?.copyWith(color: c)),
    ]);
  }
}

// ---------------------------------------------------------------- party page

class LedgerEntry {
  LedgerEntry(this.date, this.label, this.ref, this.debit, this.credit, this.balance, this.txn);
  final DateTime date;
  final String label;
  final String ref;
  final double debit; // increases what they owe
  final double credit;
  final double balance;
  final Txn? txn;
}

List<LedgerEntry> ledgerOf(BuildContext context, Party p) {
  final list = [for (final t in db.txns) if (t.partyId == p.id && db.partyEffect(t) != 0) t]
    ..sort((a, b) => a.date.compareTo(b.date) != 0 ? a.date.compareTo(b.date) : a.createdAt.compareTo(b.createdAt));
  var bal = p.opening;
  final out = <LedgerEntry>[
    LedgerEntry(p.openingDate, context.tr('opening_balance'), '', p.opening > 0 ? p.opening : 0, p.opening < 0 ? -p.opening : 0, bal, null),
  ];
  for (final t in list) {
    final e = db.partyEffect(t);
    bal += e;
    out.add(LedgerEntry(t.date, typeLabel(context, t.type), t.number, e > 0 ? e : 0, e < 0 ? -e : 0, bal, t));
  }
  return out;
}

class PartyPage extends StatelessWidget {
  const PartyPage({super.key, required this.id});
  final String id;

  Future<void> _statement(BuildContext context, Party p) async {
    final entries = ledgerOf(context, p);
    final bal = db.partyBalance(p.id);
    await shareTablePdf(
      context,
      () => buildTablePdf(
        title: 'Statement of account — ${p.name}',
        subtitle: [if (p.phone.isNotEmpty) p.phone, if (p.gstin.isNotEmpty) 'GSTIN ${p.gstin}', 'As on ${dmy(DateTime.now())}'].join(' · '),
        headers: ['Date', 'Particulars', 'No.', 'Debit', 'Credit', 'Balance'],
        rows: [
          for (final e in entries)
            [dmy(e.date), e.label, e.ref, e.debit > 0 ? money(e.debit, symbol: false) : '', e.credit > 0 ? money(e.credit, symbol: false) : '',
              '${money(e.balance.abs(), symbol: false)} ${e.balance >= 0 ? 'Dr' : 'Cr'}'],
        ],
        summary: [
          ('Closing balance', bal.abs() < 0.01 ? 'Settled' : '${money(bal.abs())} ${bal > 0 ? 'receivable' : 'payable'}'),
        ],
        rightAligned: {3, 4, 5},
      ),
      'Statement ${p.name}',
    );
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: db,
      builder: (context, _) {
        final p = db.party(id);
        if (p == null) return UdPage(title: context.tr('not_found'));
        final t = UdTokens.of(context);
        final text = Theme.of(context).textTheme;
        final bal = db.partyBalance(p.id);
        final entries = ledgerOf(context, p).reversed.toList();
        final docs = [for (final x in db.txns) if (x.partyId == p.id && x.type.isDraftDoc) x];
        final customer = p.kind == 'customer';
        return UdPage(
          eyebrow: context.tr('pk_${p.kind}'),
          title: p.name,
          subtitle: [if (p.phone.isNotEmpty) p.phone, if (p.gstin.isNotEmpty) p.gstin].join(' · '),
          actions: [
            UdIconButton(icon: Icons.edit_outlined, tooltip: context.tr('edit'), onTap: () => go(context, PartyForm(kind: p.kind, existing: p))),
          ],
          dock: UdDock(
            label: context.tr(customer ? 'new_sale' : 't_purchase'),
            icon: Icons.add_rounded,
            onPressed: () => newTxn(context, customer ? TxnType.sale : TxnType.purchase, party: p),
            extras: [
              UdDockAction(
                icon: customer ? Icons.south_west_rounded : Icons.north_east_rounded,
                label: context.tr(customer ? 't_paymentIn' : 't_paymentOut'),
                onTap: () => newTxn(context, customer ? TxnType.paymentIn : TxnType.paymentOut, party: p),
              ),
              UdDockAction(
                icon: Icons.apps_rounded,
                label: context.tr('create_new'),
                onTap: () async {
                  final type = await showUdActions<TxnType>(context, title: context.tr('create_new'), actions: [
                    for (final ty in TxnType.values.where((e) => e != TxnType.expense)) UdAction(ty, typeIcon(ty), typeLabel(context, ty)),
                  ]);
                  if (type != null && context.mounted) newTxn(context, type, party: p);
                },
              ),
            ],
          ),
          slivers: [
            UdSliverPad(
              sliver: SliverList.list(children: [
                Container(
                  padding: const EdgeInsets.all(18),
                  margin: const EdgeInsets.only(bottom: 12),
                  decoration: BoxDecoration(color: t.ink, borderRadius: BorderRadius.circular(24)),
                  child: Row(children: [
                    Expanded(
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text(bal.abs() < 0.01 ? context.tr('settled') : context.tr(bal > 0 ? 'will_get' : 'will_give'),
                            style: text.labelMedium?.copyWith(color: t.paper.withValues(alpha: 0.75))),
                        const SizedBox(height: 6),
                        Text(money(bal.abs()),
                            style: text.headlineMedium?.copyWith(color: bal >= 0 ? const Color(0xFF8FD1A8) : const Color(0xFFFF9B8F))),
                      ]),
                    ),
                  ]),
                ),
                Row(children: [
                  if (p.phone.isNotEmpty) ...[
                    Expanded(child: _Act(Icons.call_outlined, context.tr('call'), () => udOpenUrl('tel:${p.phone}'))),
                    const SizedBox(width: 8),
                  ],
                  if (bal > 0.01) ...[
                    Expanded(child: _Act(Icons.notifications_active_outlined, context.tr('remind'), () => sendReminder(context, p, amount: bal))),
                    const SizedBox(width: 8),
                  ],
                  Expanded(child: _Act(Icons.picture_as_pdf_outlined, context.tr('statement'), () => _statement(context, p))),
                ]),
                const SizedBox(height: 18),
                if (docs.isNotEmpty) ...[
                  UdLabel(context.tr('open_docs')),
                  for (final d in docs) TxnRow(d, onTap: () => go(context, TxnView(id: d.id)), showParty: false),
                  const SizedBox(height: 8),
                ],
                UdLabel(context.tr('ledger')),
                for (final e in entries)
                  if (e.txn == null && e.debit == 0 && e.credit == 0)
                    const SizedBox.shrink()
                  else
                    _LedgerRow(e),
                if (entries.length <= 1 && p.opening == 0)
                  UdEmpty(icon: Icons.menu_book_outlined, title: context.tr('no_entries')),
              ]),
            ),
          ],
        );
      },
    );
  }
}

class _Act extends StatelessWidget {
  const _Act(this.icon, this.label, this.onTap);
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final t = UdTokens.of(context);
    return UdPressable(
      onTap: onTap,
      borderRadius: 18,
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Column(children: [
        Icon(icon, color: t.accent),
        const SizedBox(height: 4),
        Text(label, maxLines: 1, overflow: TextOverflow.ellipsis, style: Theme.of(context).textTheme.labelSmall?.copyWith(color: t.ink)),
      ]),
    );
  }
}

class _LedgerRow extends StatelessWidget {
  const _LedgerRow(this.e);
  final LedgerEntry e;

  @override
  Widget build(BuildContext context) {
    final t = UdTokens.of(context);
    final text = Theme.of(context).textTheme;
    final up = e.debit > 0;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: UdPressable(
        onTap: e.txn == null ? null : () => go(context, TxnView(id: e.txn!.id)),
        borderRadius: 18,
        padding: const EdgeInsets.all(12),
        child: Row(children: [
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('${e.label} ${e.ref}', style: text.titleSmall),
              Text(dmy(e.date), style: text.bodySmall),
            ]),
          ),
          Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
            Text('${up ? '+' : '−'} ${money(up ? e.debit : e.credit)}', style: text.titleSmall?.copyWith(color: up ? green : t.danger)),
            Text('${context.tr('bal')} ${money(e.balance)}', style: text.bodySmall),
          ]),
        ]),
      ),
    );
  }
}

// ---------------------------------------------------------------- form

class PartyForm extends StatefulWidget {
  const PartyForm({super.key, this.kind = 'customer', this.existing, this.returnOnSave = false});
  final String kind;
  final Party? existing;

  /// Pop with the saved party (used when adding a party while making an invoice).
  final bool returnOnSave;

  @override
  State<PartyForm> createState() => _PartyFormState();
}

class _PartyFormState extends State<PartyForm> {
  late final Party _p = widget.existing == null ? (Party()..kind = widget.kind) : Party.fromJson(widget.existing!.toJson());
  late final _name = TextEditingController(text: _p.name);
  late final _phone = TextEditingController(text: _p.phone);
  late final _email = TextEditingController(text: _p.email);
  late final _gstin = TextEditingController(text: _p.gstin);
  late final _address = TextEditingController(text: _p.address);
  late final _opening = TextEditingController(text: numText(_p.opening.abs()));
  late final _credit = TextEditingController(text: _p.creditDays == 0 ? '' : '${_p.creditDays}');
  late bool _theyOwe = _p.opening >= 0 ? _p.kind == 'customer' || _p.opening > 0 : false;

  Future<void> _save() async {
    if (_name.text.trim().isEmpty) {
      udToast(context, context.tr('need_name'));
      return;
    }
    final g = _gstin.text.trim().toUpperCase();
    if (g.isNotEmpty && !isValidGstin(g)) {
      udToast(context, context.tr('bad_gstin'));
      return;
    }
    final open = numOf(_opening);
    _p
      ..name = _name.text.trim()
      ..phone = _phone.text.trim()
      ..email = _email.text.trim()
      ..gstin = g
      ..address = _address.text.trim()
      ..opening = _theyOwe ? open : -open
      ..creditDays = int.tryParse(_credit.text.trim()) ?? 0;
    if (_p.state.isEmpty && g.isNotEmpty) _p.state = stateFromGstin(g) ?? '';
    await db.putParty(_p);
    if (mounted) Navigator.of(context).pop(widget.returnOnSave ? _p : null);
  }

  Future<void> _delete() async {
    final used = db.txns.any((t) => t.partyId == _p.id);
    if (!await udConfirm(context, body: used ? context.tr('party_delete_used') : null)) return;
    await db.deleteParty(_p.id);
    if (mounted) Navigator.of(context).popUntil((r) => r.isFirst);
  }

  @override
  Widget build(BuildContext context) {
    return UdPage(
      title: widget.existing == null ? context.tr('add_party') : context.tr('edit_party'),
      actions: [
        if (widget.existing != null) UdIconButton(icon: Icons.delete_outline_rounded, tooltip: context.tr('delete'), onTap: _delete),
      ],
      dock: UdDock(label: context.tr('save'), icon: Icons.check_rounded, onPressed: _save),
      slivers: [
        UdSliverPad(
          sliver: SliverList.list(children: [
            Chips<String>(
              values: const ['customer', 'supplier'],
              selected: _p.kind,
              label: (k) => context.tr('pk_$k'),
              onSelect: (k) => setState(() {
                _p.kind = k;
                if (numOf(_opening) == 0) _theyOwe = k == 'customer';
              }),
            ),
            const SizedBox(height: 16),
            Field(_name, context.tr('party_name'), caps: TextCapitalization.words, autofocus: widget.existing == null),
            Field(_phone, context.tr('phone'), type: TextInputType.phone),
            Field(_gstin, context.tr('gstin'), caps: TextCapitalization.characters, hint: context.tr('optional'), onChanged: (v) {
              final s = stateFromGstin(v.trim());
              if (s != null && v.trim().length >= 2) setState(() => _p.state = s);
            }),
            PickField(
              label: context.tr('state'),
              value: _p.state.isEmpty ? context.tr('pick') : '${stateName(_p.state)} (${_p.state})',
              placeholder: _p.state.isEmpty,
              icon: Icons.place_outlined,
              onTap: () async {
                final s = await pickState(context);
                if (s != null) setState(() => _p.state = s);
              },
            ),
            Field(_address, context.tr('address'), maxLines: 3),
            Field(_email, context.tr('email'), type: TextInputType.emailAddress, caps: TextCapitalization.none),
            UdLabel(context.tr('opening_balance')),
            Field(_opening, context.tr('amount'), type: Field.number, prefix: '₹ ', hint: '0'),
            Chips<bool>(
              values: const [true, false],
              selected: _theyOwe,
              label: (v) => context.tr(v ? 'they_owe_me' : 'i_owe_them'),
              onSelect: (v) => setState(() => _theyOwe = v),
            ),
            const SizedBox(height: 16),
            Field(_credit, context.tr('credit_days'), type: TextInputType.number, hint: context.tr('credit_days_hint')),
          ]),
        ),
      ],
    );
  }
}
