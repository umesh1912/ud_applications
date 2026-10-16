import 'package:flutter/material.dart';
import 'package:ud_core/ud_core.dart';

import 'db.dart';
import 'gst.dart';
import 'main.dart' show appName;
import 'more.dart';
import 'reports.dart';
import 'share.dart';
import 'txn_form.dart';
import 'txn_view.dart';
import 'ui.dart';

/// Opens the form for a new document of [type].
void newTxn(BuildContext context, TxnType type, {Party? party}) =>
    go(context, TxnForm(type: type, party: party));

/// Sheet listing every kind of document.
Future<void> chooseNewTxn(BuildContext context) async {
  final type = await showUdActions<TxnType>(context, title: context.tr('create_new'), actions: [
    for (final t in TxnType.values) UdAction(t, typeIcon(t), typeLabel(context, t)),
  ]);
  if (type != null && context.mounted) newTxn(context, type);
}

class HomeTab extends StatelessWidget {
  const HomeTab({super.key, required this.onTab});
  final ValueChanged<int> onTab;

  @override
  Widget build(BuildContext context) {
    final t = UdTokens.of(context);
    final text = Theme.of(context).textTheme;
    final now = DateTime.now();
    final today = dayOnly(now);
    final tomorrow = today.add(const Duration(days: 1));
    final monthStart = DateTime(now.year, now.month);
    final todaySale = db.sumTotal(today, tomorrow, TxnType.sale);
    final monthSale = db.sumTotal(monthStart, tomorrow, TxnType.sale);
    final monthExp = db.sumTotal(monthStart, tomorrow, TxnType.expense);
    final recent = [...db.txns]..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    final due = db.dueInvoices;
    final low = db.lowStockItems;

    return UdPage(
      eyebrow: appName,
      title: db.biz.name,
      subtitle: '${context.tr('fy')} ${financialYear(now)} · ${dmy(now)}',
      actions: [
        UdIconButton(icon: Icons.bar_chart_rounded, tooltip: context.tr('reports'), onTap: () => go(context, const ReportsPage())),
        const UdSettingsButton(appName: appName),
      ],
      dock: UdDock(
        label: context.tr('new_sale'),
        icon: Icons.add_rounded,
        onPressed: () => newTxn(context, TxnType.sale),
        extras: [
          UdDockAction(icon: Icons.south_west_rounded, label: context.tr('t_paymentIn'), onTap: () => newTxn(context, TxnType.paymentIn)),
          UdDockAction(icon: Icons.apps_rounded, label: context.tr('create_new'), onTap: () => chooseNewTxn(context)),
        ],
      ),
      slivers: [
        UdSliverPad(
          sliver: SliverList.list(children: [
            Row(children: [
              Expanded(
                child: _BigFigure(
                  label: context.tr('to_receive'),
                  value: money(db.toReceive, decimals: 0),
                  color: green,
                  icon: Icons.south_west_rounded,
                  onTap: () => go(context, const PartyBalancesPage(receivable: true)),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _BigFigure(
                  label: context.tr('to_pay'),
                  value: money(db.toPay, decimals: 0),
                  color: t.danger,
                  icon: Icons.north_east_rounded,
                  onTap: () => go(context, const PartyBalancesPage(receivable: false)),
                ),
              ),
            ]),
            const SizedBox(height: 12),
            Summary(cells: [
              (context.tr('today_sale'), money(todaySale, decimals: 0), null),
              (context.tr('month_sale'), money(monthSale, decimals: 0), null),
              (context.tr('month_exp'), money(monthExp, decimals: 0), null),
            ]),
            UdPressable(
              onTap: () => go(context, const CashBankPage()),
              borderRadius: 20,
              padding: const EdgeInsets.all(14),
              child: Row(children: [
                const UdBadgeIcon(Icons.account_balance_rounded, size: 44),
                const SizedBox(width: 12),
                Expanded(child: Text(context.tr('cash_bank'), style: text.titleMedium)),
                Text(money(db.cashAndBank, decimals: 0), style: text.titleLarge),
                Icon(Icons.chevron_right_rounded, color: t.inkFaint),
              ]),
            ),
            const SizedBox(height: 18),
            UdLabel(context.tr('quick_actions')),
          ]),
        ),
        UdSliverPad(
          sliver: SliverGrid.count(
            crossAxisCount: 3,
            mainAxisSpacing: 10,
            crossAxisSpacing: 10,
            childAspectRatio: 0.92,
            children: [
              for (final ty in [TxnType.sale, TxnType.purchase, TxnType.paymentIn, TxnType.paymentOut, TxnType.expense, TxnType.estimate])
                _Quick(icon: typeIcon(ty), label: typeLabel(context, ty), onTap: () => newTxn(context, ty)),
            ],
          ),
        ),
        UdSliverPad(
          top: 18,
          sliver: SliverList.list(children: [
            if (low.isNotEmpty)
              UdPressable(
                onTap: () => go(context, const StockReportPage(lowOnly: true)),
                color: Color.alphaBlend(amber.withValues(alpha: 0.10), t.card),
                borderRadius: 20,
                padding: const EdgeInsets.all(14),
                child: Row(children: [
                  const UdBadgeIcon(Icons.warning_amber_rounded, size: 44, color: amber),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(context.tr('low_stock_n', {'n': '${low.length}'}), style: text.titleMedium),
                      Text(low.take(3).map((e) => e.name).join(', '), maxLines: 1, overflow: TextOverflow.ellipsis, style: text.bodySmall),
                    ]),
                  ),
                  Icon(Icons.chevron_right_rounded, color: t.inkFaint),
                ]),
              ),
            if (due.isNotEmpty) ...[
              const SizedBox(height: 18),
              UdLabel(context.tr('payments_due'),
                  trailing: TextButton(onPressed: () => go(context, const PartyBalancesPage(receivable: true)), child: Text(context.tr('see_all')))),
              for (final inv in due.take(5)) _DueRow(inv: inv),
            ],
            const SizedBox(height: 18),
            UdLabel(context.tr('recent'),
                trailing: recent.isEmpty ? null : TextButton(onPressed: () => onTab(1), child: Text(context.tr('see_all')))),
            if (recent.isEmpty)
              UdEmpty(icon: Icons.receipt_long_outlined, title: context.tr('empty_home'), body: context.tr('empty_home_sub'))
            else
              for (final x in recent.take(8)) TxnRow(x, onTap: () => go(context, TxnView(id: x.id))),
          ]),
        ),
      ],
    );
  }
}

class _BigFigure extends StatelessWidget {
  const _BigFigure({required this.label, required this.value, required this.color, required this.icon, required this.onTap});
  final String label;
  final String value;
  final Color color;
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final t = UdTokens.of(context);
    return UdPressable(
      onTap: onTap,
      color: Color.alphaBlend(color.withValues(alpha: 0.08), t.card),
      borderRadius: 22,
      padding: const EdgeInsets.all(16),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Icon(icon, size: 18, color: color),
          const SizedBox(width: 6),
          Expanded(child: Text(label, style: text.labelMedium?.copyWith(color: color))),
        ]),
        const SizedBox(height: 10),
        FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.centerLeft,
          child: Text(value, style: text.headlineSmall?.copyWith(color: color)),
        ),
      ]),
    );
  }
}

class _Quick extends StatelessWidget {
  const _Quick({required this.icon, required this.label, required this.onTap});
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final t = UdTokens.of(context);
    final text = Theme.of(context).textTheme;
    return UdPressable(
      onTap: onTap,
      borderRadius: 20,
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 8),
      child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(color: t.accentSoft, borderRadius: BorderRadius.circular(14)),
          child: Icon(icon, color: t.accent, size: 22),
        ),
        const SizedBox(height: 8),
        Text(label, textAlign: TextAlign.center, maxLines: 2, overflow: TextOverflow.ellipsis, style: text.labelMedium),
      ]),
    );
  }
}

class _DueRow extends StatelessWidget {
  const _DueRow({required this.inv});
  final Txn inv;

  @override
  Widget build(BuildContext context) {
    final t = UdTokens.of(context);
    final text = Theme.of(context).textTheme;
    final st = db.docStatus(inv);
    final status = st.statusOn(inv.dueDate);
    final party = db.party(inv.partyId);
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: UdPressable(
        onTap: () => go(context, TxnView(id: inv.id)),
        borderRadius: 20,
        padding: const EdgeInsets.fromLTRB(14, 10, 8, 10),
        child: Row(children: [
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(inv.partyName.isEmpty ? context.tr('cash_sale') : inv.partyName, maxLines: 1, overflow: TextOverflow.ellipsis, style: text.titleMedium),
              const SizedBox(height: 3),
              Row(children: [
                StatusChip(status),
                const SizedBox(width: 8),
                Flexible(
                  child: Text('${inv.number} · ${inv.dueDate == null ? dmy(inv.date) : '${context.tr('due')} ${dmy(inv.dueDate!)}'}',
                      maxLines: 1, overflow: TextOverflow.ellipsis, style: text.bodySmall),
                ),
              ]),
            ]),
          ),
          Text(money(st.due, decimals: 0), style: text.titleMedium?.copyWith(color: status == PayStatus.overdue ? t.danger : t.ink)),
          if (party != null && party.phone.isNotEmpty)
            IconButton(
              tooltip: context.tr('remind'),
              icon: const Icon(Icons.chat_outlined),
              color: green,
              onPressed: () => sendReminder(context, party, amount: st.due, invoice: inv),
            ),
        ]),
      ),
    );
  }
}
