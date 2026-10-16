import 'package:flutter/material.dart';
import 'package:ud_core/ud_core.dart';

import 'db.dart';
import 'gst.dart';
import 'parties.dart';
import 'share.dart';
import 'txn_form.dart';
import 'ui.dart';

/// One document: totals, status and everything you can do with it.
class TxnView extends StatelessWidget {
  const TxnView({super.key, required this.id, this.justSaved = false});
  final String id;
  final bool justSaved;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: db,
      builder: (context, _) {
        final t = db.txn(id);
        if (t == null) return UdPage(title: context.tr('not_found'));
        return _Body(t: t, justSaved: justSaved);
      },
    );
  }
}

class _Body extends StatelessWidget {
  const _Body({required this.t, required this.justSaved});
  final Txn t;
  final bool justSaved;

  Future<void> _delete(BuildContext context) async {
    if (!await udConfirm(context)) return;
    await db.deleteTxn(t.id);
    if (context.mounted) Navigator.of(context).pop();
  }

  void _convert(BuildContext context, TxnType to) {
    final c = t.copyAs(to)
      ..number = db.nextNumber(to)
      ..date = DateTime.now()
      ..dueDate = null
      ..linkedId = t.id;
    final party = db.party(t.partyId);
    if (party != null && party.creditDays > 0 && to == TxnType.sale) {
      c.dueDate = dayOnly(c.date).add(Duration(days: party.creditDays));
    }
    Navigator.of(context).push(MaterialPageRoute(
        builder: (_) => TxnForm(type: to, draft: c, convertFromId: t.type.isDraftDoc ? t.id : null)));
  }

  @override
  Widget build(BuildContext context) {
    final tk = UdTokens.of(context);
    final text = Theme.of(context).textTheme;
    final tot = db.totals(t);
    final st = (t.type == TxnType.sale || t.type == TxnType.purchase) ? db.docStatus(t) : null;
    final party = db.party(t.partyId);
    final converted = db.txn(t.convertedTo);
    final source = db.txn(t.linkedId);
    final payments = [for (final p in db.txns) if (p.linkedId == t.id && !p.type.hasLines) p];
    final phone = party?.phone ?? t.partyPhone;

    final actions = <(IconData, String, VoidCallback)>[
      (Icons.share_rounded, context.tr('share_pdf'), () => shareDocPdf(context, t)),
      (Icons.print_outlined, context.tr('print'), () => printDoc(context, t)),
      if (phone.isNotEmpty) (Icons.chat_outlined, 'WhatsApp', () => openWhatsApp(context, phone, docMessage(context, t))),
      (Icons.visibility_outlined, context.tr('preview'), () => previewDoc(context, t)),
      if (t.type.hasLines && db.biz.printSize != '80' && db.biz.printSize != '58')
        (Icons.receipt_outlined, context.tr('thermal'), () => printDoc(context, t, size: '80')),
      if (st != null && st.due > 0 && party != null)
        (
          Icons.payments_outlined,
          context.tr(t.type == TxnType.sale ? 'receive_payment' : 'make_payment'),
          () => go(context,
              TxnForm(type: t.type == TxnType.sale ? TxnType.paymentIn : TxnType.paymentOut, party: party, amount: st.due, linkedId: t.id)),
        ),
      if (t.type.isDraftDoc && converted == null) (Icons.receipt_long_rounded, context.tr('convert_invoice'), () => _convert(context, TxnType.sale)),
      if (t.type == TxnType.estimate && converted == null)
        (Icons.pending_actions_rounded, context.tr('convert_order'), () => _convert(context, TxnType.saleOrder)),
      if (t.type == TxnType.sale) (Icons.assignment_return_outlined, context.tr('t_saleReturn'), () => _convert(context, TxnType.saleReturn)),
      if (t.type == TxnType.purchase) (Icons.assignment_returned_outlined, context.tr('t_purchaseReturn'), () => _convert(context, TxnType.purchaseReturn)),
      if (t.type.hasLines)
        (Icons.copy_rounded, context.tr('duplicate'), () {
          final c = t.copyAs(t.type)
            ..number = db.nextNumber(t.type)
            ..date = DateTime.now()
            ..dueDate = null
            ..linkedId = '';
          go(context, TxnForm(type: t.type, draft: c));
        }),
      if (phone.isNotEmpty) (Icons.call_outlined, context.tr('call'), () => udOpenUrl('tel:$phone')),
      (Icons.edit_outlined, context.tr('edit'), () => go(context, TxnForm(type: t.type, existing: t))),
      (Icons.delete_outline_rounded, context.tr('delete'), () => _delete(context)),
    ];

    return UdPage(
      eyebrow: typeLabel(context, t.type),
      title: t.number.isEmpty ? typeLabel(context, t.type) : t.number,
      subtitle: [
        if (t.partyName.isNotEmpty) t.partyName else if (t.type == TxnType.sale) context.tr('cash_sale'),
        if (t.type == TxnType.expense) context.tr('ec_${t.category.isEmpty ? 'other_exp' : t.category}'),
        dmy(t.date),
      ].join(' · '),
      dock: UdDock(
        label: context.tr('share_pdf'),
        icon: Icons.share_rounded,
        onPressed: () => shareDocPdf(context, t),
        extras: [
          UdDockAction(icon: Icons.print_outlined, label: context.tr('print'), onTap: () => printDoc(context, t)),
        ],
      ),
      slivers: [
        UdSliverPad(
          sliver: SliverList.list(children: [
            if (justSaved)
              Container(
                margin: const EdgeInsets.only(bottom: 14),
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(color: green.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(18)),
                child: Row(children: [
                  const Icon(Icons.check_circle_rounded, color: green),
                  const SizedBox(width: 10),
                  Expanded(child: Text(context.tr('saved_share'), style: text.bodyMedium)),
                ]),
              ),
            Summary(cells: [
              (context.tr('total'), money(tot.total), null),
              if (st != null) ...[
                (context.tr(t.type == TxnType.sale ? 'received' : 'paid'), money(st.total - st.due), const Color(0xFF8FD1A8)),
                (context.tr('balance_due'), money(st.due), st.due > 0 ? const Color(0xFFFF9B8F) : null),
              ],
            ]),
            if (st != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 14),
                child: Row(children: [
                  StatusChip(st.statusOn(t.dueDate)),
                  const SizedBox(width: 8),
                  if (t.dueDate != null)
                    Flexible(child: Text('${context.tr('due')} ${dmy(t.dueDate!)}', overflow: TextOverflow.ellipsis, style: text.bodySmall)),
                ]),
              ),
            if (converted != null)
              _LinkRow(icon: Icons.link_rounded, label: '${context.tr('converted_to')} ${typeLabel(context, converted.type)} ${converted.number}', id: converted.id),
            if (source != null)
              _LinkRow(icon: Icons.link_rounded, label: '${context.tr('from_doc')} ${typeLabel(context, source.type)} ${source.number}', id: source.id),
            UdLabel(context.tr('actions')),
            Wrap(spacing: 10, runSpacing: 10, children: [
              for (final a in actions)
                SizedBox(
                  width: (MediaQuery.of(context).size.width - 40 - 30) / 4,
                  height: 84,
                  child: UdPressable(
                    onTap: a.$3,
                    borderRadius: 18,
                    padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 4),
                    child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                      Icon(a.$1, color: a.$1 == Icons.delete_outline_rounded ? tk.danger : tk.accent),
                      const SizedBox(height: 6),
                      Text(a.$2, textAlign: TextAlign.center, maxLines: 2, overflow: TextOverflow.ellipsis, style: text.labelSmall?.copyWith(color: tk.ink)),
                    ]),
                  ),
                ),
            ]),
            const SizedBox(height: 18),
            if (t.type.hasLines) ...[
              UdLabel(context.tr('items_n', {'n': '${t.lines.length}'})),
              Card2(
                child: Column(children: [
                  for (final l in t.lines)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 6),
                      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Expanded(
                          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                            Text(l.name, style: text.titleSmall),
                            Text(
                              [
                                '${qtyText(l.qty)} ${l.unit} × ${money(l.rate)}',
                                if (l.discountPct > 0) '-${rateText(l.discountPct)}',
                                if (db.biz.gstEnabled && l.gstRate > 0) 'GST ${rateText(l.gstRate)}',
                              ].join(' · '),
                              style: text.bodySmall,
                            ),
                          ]),
                        ),
                        Text(money(calcLine(l, inclusive: t.taxInclusive, gst: db.biz.gstEnabled).total), style: text.titleSmall),
                      ]),
                    ),
                  Divider(color: tk.line),
                  KV(context.tr('subtotal'), money(tot.gross)),
                  if (tot.discount > 0) KV(context.tr('item_discount'), '- ${money(tot.discount)}'),
                  if (db.biz.gstEnabled && tot.tax > 0) ...[
                    KV(context.tr('taxable'), money(tot.taxable)),
                    if (tot.interState) KV('IGST', money(tot.igst)) else ...[KV('CGST', money(tot.cgst)), KV('SGST', money(tot.sgst))],
                  ],
                  if (tot.extraDiscount > 0) KV(context.tr('extra_discount'), '- ${money(tot.extraDiscount)}'),
                  if (tot.charges > 0) KV(context.tr('charges'), money(tot.charges)),
                  if (tot.roundOff.abs() > 0.001) KV(context.tr('round_off'), money(tot.roundOff)),
                  KV(context.tr('total'), money(tot.total), bold: true),
                ]),
              ),
            ] else
              Card2(
                child: Column(children: [
                  KV(context.tr('amount'), money(t.amount), bold: true),
                  KV(context.tr('pay_mode'), context.tr('pm_${t.mode}')),
                  if (t.mode != 'cash') KV(context.tr('account'), db.account(t.accountId).name),
                  if (t.refNo.isNotEmpty) KV(context.tr('ref_no'), t.refNo),
                ]),
              ),
            if (t.type.hasLines && !t.type.isDraftDoc && t.paid > 0)
              Card2(child: KV(context.tr('pay_mode'), '${context.tr('pm_${t.mode}')} · ${money(t.paid)}${t.refNo.isEmpty ? '' : ' · ${t.refNo}'}')),
            if (payments.isNotEmpty) ...[
              UdLabel(context.tr('payments')),
              for (final p in payments) TxnRow(p, onTap: () => go(context, TxnView(id: p.id)), showParty: false),
            ],
            if (t.notes.isNotEmpty) ...[
              UdLabel(context.tr('notes')),
              Card2(child: Text(t.notes, style: text.bodyMedium)),
            ],
            if (party != null)
              UdRow(
                leading: const UdBadgeIcon(Icons.person_outline_rounded, size: 40),
                title: party.name,
                subtitle: balanceText(context, db.partyBalance(party.id)),
                trailing: const Icon(Icons.chevron_right_rounded),
                onTap: () => go(context, PartyPage(id: party.id)),
              ),
          ]),
        ),
      ],
    );
  }
}

class _LinkRow extends StatelessWidget {
  const _LinkRow({required this.icon, required this.label, required this.id});
  final IconData icon;
  final String label;
  final String id;

  @override
  Widget build(BuildContext context) => UdRow(
        leading: UdBadgeIcon(icon, size: 36),
        title: label,
        trailing: const Icon(Icons.chevron_right_rounded),
        onTap: () => Navigator.of(context).pushReplacement(MaterialPageRoute(builder: (_) => TxnView(id: id))),
      );
}
