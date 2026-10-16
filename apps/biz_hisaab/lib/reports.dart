import 'dart:math';

import 'package:flutter/material.dart';
import 'package:ud_core/ud_core.dart';

import 'db.dart';
import 'gst.dart';
import 'parties.dart';
import 'pdf.dart';
import 'share.dart';
import 'txn_view.dart';
import 'txns.dart';
import 'ui.dart';

class ReportsPage extends StatelessWidget {
  const ReportsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final list = <(IconData, String, String, Widget)>[
      (Icons.trending_up_rounded, 'r_pl', 'r_pl_sub', const ProfitLossPage()),
      (Icons.receipt_long_rounded, 'r_sales', 'r_sales_sub', const ReportView(kind: 'sales')),
      (Icons.shopping_bag_outlined, 'r_purchases', 'r_purchases_sub', const ReportView(kind: 'purchases')),
      if (db.biz.gstEnabled) (Icons.account_balance_outlined, 'r_gst', 'r_gst_sub', const GstReportPage()),
      (Icons.today_rounded, 'r_daybook', 'r_daybook_sub', const ReportView(kind: 'daybook')),
      (Icons.star_outline_rounded, 'r_items', 'r_items_sub', const ReportView(kind: 'items')),
      (Icons.inventory_2_outlined, 'r_stock', 'r_stock_sub', const StockReportPage()),
      (Icons.account_balance_wallet_outlined, 'r_expenses', 'r_expenses_sub', const ReportView(kind: 'expenses')),
      (Icons.south_west_rounded, 'r_receivable', 'r_receivable_sub', const PartyBalancesPage(receivable: true)),
      (Icons.north_east_rounded, 'r_payable', 'r_payable_sub', const PartyBalancesPage(receivable: false)),
    ];
    return UdPage(
      title: context.tr('reports'),
      subtitle: context.tr('reports_sub'),
      slivers: [
        UdSliverPad(
          sliver: SliverList.list(children: [
            for (final r in list)
              UdRow(
                leading: UdBadgeIcon(r.$1, size: 44),
                title: context.tr(r.$2),
                subtitle: context.tr(r.$3),
                trailing: const Icon(Icons.chevron_right_rounded),
                onTap: () => go(context, r.$4),
              ),
          ]),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------- generic table report

class ReportData {
  ReportData({required this.title, required this.headers, required this.rows, this.ids = const [], this.summary = const [], this.right = const {}});
  final String title;
  final List<String> headers;
  final List<List<String>> rows;
  final List<String?> ids; // transaction id per row, to open it
  final List<(String, String)> summary;
  final Set<int> right;
}

ReportData buildReport(BuildContext context, String kind, Period p) {
  String m(num v) => money(v, symbol: false);
  switch (kind) {
    case 'sales':
    case 'purchases':
      final type = kind == 'sales' ? TxnType.sale : TxnType.purchase;
      final list = db.inRange(p.from, p.to, {type}).toList()..sort((a, b) => a.date.compareTo(b.date));
      var total = 0.0, tax = 0.0, due = 0.0;
      final rows = <List<String>>[];
      for (final t in list) {
        final tt = db.totals(t);
        final st = db.docStatus(t);
        total += tt.total;
        tax += tt.tax;
        due += st.due;
        rows.add([dmy(t.date), t.number, t.partyName.isEmpty ? context.tr('cash_sale') : t.partyName, m(tt.taxable), m(tt.tax), m(tt.total), m(st.due)]);
      }
      return ReportData(
        title: context.tr(kind == 'sales' ? 'r_sales' : 'r_purchases'),
        headers: [context.tr('date'), context.tr('number'), context.tr('party'), context.tr('taxable'), 'GST', context.tr('total'), context.tr('balance_due')],
        rows: rows,
        ids: [for (final t in list) t.id],
        right: {3, 4, 5, 6},
        summary: [
          (context.tr('count'), '${list.length}'),
          (context.tr('total'), money(total)),
          if (db.biz.gstEnabled) ('GST', money(tax)),
          (context.tr(kind == 'sales' ? 'received' : 'paid'), money(total - due)),
          (context.tr('balance_due'), money(due)),
        ],
      );
    case 'daybook':
      final list = db.inRange(p.from, p.to).toList()..sort((a, b) => a.date.compareTo(b.date));
      var inn = 0.0, out = 0.0;
      final rows = <List<String>>[];
      for (final t in list) {
        final c = db.cashOf(t);
        if (t.type.cashSign > 0) inn += c;
        if (t.type.cashSign < 0) out += c;
        rows.add([
          dmy(t.date),
          typeLabel(context, t.type),
          t.number,
          t.partyName.isNotEmpty ? t.partyName : (t.type == TxnType.expense ? context.tr('ec_${t.category.isEmpty ? 'other_exp' : t.category}') : ''),
          m(db.totalOf(t)),
          t.type.cashSign > 0 && c > 0 ? m(c) : '',
          t.type.cashSign < 0 && c > 0 ? m(c) : '',
        ]);
      }
      return ReportData(
        title: context.tr('r_daybook'),
        headers: [context.tr('date'), context.tr('type'), context.tr('number'), context.tr('party'), context.tr('total'), context.tr('money_in'), context.tr('money_out')],
        rows: rows,
        ids: [for (final t in list) t.id],
        right: {4, 5, 6},
        summary: [(context.tr('money_in'), money(inn)), (context.tr('money_out'), money(out)), (context.tr('net'), money(inn - out))],
      );
    case 'expenses':
      final list = db.inRange(p.from, p.to, {TxnType.expense}).toList()..sort((a, b) => a.date.compareTo(b.date));
      final byCat = <String, double>{};
      for (final t in list) {
        final c = t.category.isEmpty ? 'other_exp' : t.category;
        byCat[c] = (byCat[c] ?? 0) + t.amount;
      }
      final total = byCat.values.fold(0.0, (s, v) => s + v);
      final cats = byCat.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
      return ReportData(
        title: context.tr('r_expenses'),
        headers: [context.tr('category'), context.tr('amount'), '%'],
        rows: [for (final e in cats) [context.tr('ec_${e.key}'), m(e.value), total == 0 ? '' : (e.value / total * 100).toStringAsFixed(1)]],
        right: {1, 2},
        summary: [(context.tr('total'), money(total)), (context.tr('count'), '${list.length}')],
      );
    case 'items':
      final agg = <String, (String, double, double, double)>{}; // name, qty, amount, cost
      for (final t in db.inRange(p.from, p.to, {TxnType.sale, TxnType.saleReturn})) {
        final sign = t.type == TxnType.sale ? 1 : -1;
        for (final l in t.lines) {
          final key = l.itemId.isEmpty ? 'x:${l.name}' : l.itemId;
          final c = calcLine(l, inclusive: t.taxInclusive, gst: db.biz.gstEnabled);
          final cost = l.qty * (db.item(l.itemId)?.purchasePrice ?? 0);
          final prev = agg[key] ?? (l.name, 0.0, 0.0, 0.0);
          agg[key] = (prev.$1, prev.$2 + sign * l.qty, prev.$3 + sign * c.taxable, prev.$4 + sign * cost);
        }
      }
      final list = agg.values.toList()..sort((a, b) => b.$3.compareTo(a.$3));
      return ReportData(
        title: context.tr('r_items'),
        headers: [context.tr('item_name'), context.tr('qty'), context.tr('sale_value'), context.tr('profit')],
        rows: [for (final e in list) [e.$1, qtyText(e.$2), m(e.$3), m(e.$3 - e.$4)]],
        right: {1, 2, 3},
        summary: [
          (context.tr('sale_value'), money(list.fold(0.0, (s, e) => s + e.$3))),
          (context.tr('profit'), money(list.fold(0.0, (s, e) => s + e.$3 - e.$4))),
        ],
      );
  }
  return ReportData(title: '', headers: const [], rows: const []);
}

class ReportView extends StatefulWidget {
  const ReportView({super.key, required this.kind});
  final String kind;

  @override
  State<ReportView> createState() => _ReportViewState();
}

class _ReportViewState extends State<ReportView> {
  Period _p = Period.of('month');

  @override
  Widget build(BuildContext context) {
    final r = buildReport(context, widget.kind, _p);
    return ReportScaffold(
      data: r,
      period: _p,
      onPeriod: (p) => setState(() => _p = p),
    );
  }
}

/// Period picker, summary, a scrollable table and PDF / Excel export.
class ReportScaffold extends StatelessWidget {
  const ReportScaffold({super.key, required this.data, required this.period, required this.onPeriod, this.header = const []});
  final ReportData data;
  final Period period;
  final ValueChanged<Period> onPeriod;
  final List<Widget> header;

  @override
  Widget build(BuildContext context) {
    final t = UdTokens.of(context);
    final text = Theme.of(context).textTheme;
    final name = '${data.title} ${period.label(context)}';
    return UdPage(
      eyebrow: context.tr('reports'),
      title: data.title,
      dock: UdDock(
        label: context.tr('share_pdf'),
        icon: Icons.picture_as_pdf_outlined,
        onPressed: () => shareTablePdf(
          context,
          () => buildTablePdf(
            title: data.title,
            subtitle: '${dmy(period.from.year < 2001 ? DateTime(2001) : period.from)} – ${dmy(period.to.subtract(const Duration(days: 1)).isAfter(DateTime.now()) ? DateTime.now() : period.to.subtract(const Duration(days: 1)))}',
            headers: data.headers,
            rows: data.rows,
            summary: data.summary,
            rightAligned: data.right,
          ),
          name,
        ),
        extras: [
          UdDockAction(icon: Icons.table_view_outlined, label: context.tr('export_excel'), onTap: () => shareCsv(context, name, data.headers, data.rows)),
        ],
      ),
      slivers: [
        UdSliverPad(
          sliver: SliverList.list(children: [
            PeriodButton(period: period, onChanged: onPeriod),
            ...header,
            if (data.summary.isNotEmpty)
              Card2(
                child: Column(children: [for (final s in data.summary) KV(s.$1, s.$2, bold: s == data.summary.last)]),
              ),
            if (data.rows.isEmpty)
              UdEmpty(icon: Icons.bar_chart_rounded, title: context.tr('no_data'))
            else
              Card2(
                padding: EdgeInsets.zero,
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.all(8),
                  child: DataTable(
                    showCheckboxColumn: false,
                    headingRowHeight: 40,
                    dataRowMinHeight: 40,
                    dataRowMaxHeight: 52,
                    columnSpacing: 18,
                    headingTextStyle: text.labelMedium?.copyWith(color: t.inkSoft),
                    dataTextStyle: text.bodyMedium,
                    columns: [
                      for (var i = 0; i < data.headers.length; i++) DataColumn(label: Text(data.headers[i]), numeric: data.right.contains(i)),
                    ],
                    rows: [
                      for (var r = 0; r < data.rows.length; r++)
                        DataRow(
                          onSelectChanged: r < data.ids.length && data.ids[r] != null ? (_) => go(context, TxnView(id: data.ids[r]!)) : null,
                          cells: [for (final c in data.rows[r]) DataCell(Text(c))],
                        ),
                    ],
                  ),
                ),
              ),
          ]),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------- profit & loss

class ProfitLossPage extends StatefulWidget {
  const ProfitLossPage({super.key});

  @override
  State<ProfitLossPage> createState() => _ProfitLossPageState();
}

class _ProfitLossPageState extends State<ProfitLossPage> {
  Period _p = Period.of('month');

  @override
  Widget build(BuildContext context) {
    double taxable(TxnType ty) => db.inRange(_p.from, _p.to, {ty}).fold(0.0, (s, t) => s + db.totals(t).taxable - t.extraDiscount + t.charges);
    double cost(TxnType ty) => db.inRange(_p.from, _p.to, {ty}).fold(0.0, (s, t) => s + db.costOf(t));
    final sales = taxable(TxnType.sale);
    final returns = taxable(TxnType.saleReturn);
    final cogs = cost(TxnType.sale) - cost(TxnType.saleReturn);
    final gross = sales - returns - cogs;
    final exp = <String, double>{};
    for (final t in db.inRange(_p.from, _p.to, {TxnType.expense})) {
      final c = t.category.isEmpty ? 'other_exp' : t.category;
      exp[c] = (exp[c] ?? 0) + t.amount;
    }
    final expTotal = exp.values.fold(0.0, (s, v) => s + v);
    final net = gross - expTotal;
    final purchases = taxable(TxnType.purchase) - taxable(TxnType.purchaseReturn);
    String m(double v) => money(v, symbol: false);

    final data = ReportData(
      title: context.tr('r_pl'),
      headers: [context.tr('particulars'), context.tr('amount')],
      rows: [
        [context.tr('pl_sales'), m(sales)],
        [context.tr('pl_returns'), '- ${m(returns)}'],
        [context.tr('pl_cogs'), '- ${m(cogs)}'],
        [context.tr('pl_gross'), m(gross)],
        for (final e in exp.entries) [context.tr('ec_${e.key}'), '- ${m(e.value)}'],
        [context.tr('pl_net'), m(net)],
      ],
      right: {1},
      summary: [
        (context.tr('pl_gross'), money(gross)),
        (context.tr('r_expenses'), money(expTotal)),
        (context.tr('pl_net'), money(net)),
      ],
    );
    final t = UdTokens.of(context);
    return ReportScaffold(
      data: data,
      period: _p,
      onPeriod: (p) => setState(() => _p = p),
      header: [
        Summary(cells: [
          (context.tr(net >= 0 ? 'pl_profit' : 'pl_loss'), money(net.abs(), decimals: 0), net >= 0 ? const Color(0xFF8FD1A8) : const Color(0xFFFF9B8F)),
          (context.tr('pl_margin'), sales == 0 ? '—' : '${(net / max(1, sales) * 100).toStringAsFixed(1)}%', null),
        ]),
        Padding(
          padding: const EdgeInsets.only(bottom: 12, left: 4),
          child: Text(context.tr('pl_note', {'p': money(purchases)}), style: Theme.of(context).textTheme.bodySmall?.copyWith(color: t.inkSoft)),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------- GST

class GstReportPage extends StatefulWidget {
  const GstReportPage({super.key});

  @override
  State<GstReportPage> createState() => _GstReportPageState();
}

class _GstReportPageState extends State<GstReportPage> {
  Period _p = Period.of('last_month');

  @override
  Widget build(BuildContext context) {
    final out = <double, List<double>>{}; // rate: taxable, cgst, sgst, igst
    final inp = <double, List<double>>{};
    var b2b = 0, b2c = 0;
    void add(Map<double, List<double>> m, Txn t, int sign) {
      final tt = db.totals(t);
      tt.byRate.forEach((rate, v) {
        final row = m.putIfAbsent(rate, () => [0, 0, 0, 0]);
        row[0] += sign * v.$1;
        if (tt.interState) {
          row[3] += sign * v.$2;
        } else {
          row[1] += sign * v.$2 / 2;
          row[2] += sign * v.$2 / 2;
        }
      });
    }

    final b2bRows = <List<String>>[];
    for (final t in db.inRange(_p.from, _p.to, {TxnType.sale, TxnType.saleReturn})) {
      add(out, t, t.type == TxnType.sale ? 1 : -1);
      final party = db.party(t.partyId);
      if (t.type == TxnType.sale) {
        if (party != null && party.gstin.isNotEmpty) {
          b2b++;
          final tt = db.totals(t);
          b2bRows.add([party.gstin, party.name, t.number, dmy(t.date), money(tt.total, symbol: false), t.placeOfSupply,
            money(tt.taxable, symbol: false), money(tt.igst, symbol: false), money(tt.cgst, symbol: false), money(tt.sgst, symbol: false)]);
        } else {
          b2c++;
        }
      }
    }
    for (final t in db.inRange(_p.from, _p.to, {TxnType.purchase, TxnType.purchaseReturn})) {
      add(inp, t, t.type == TxnType.purchase ? 1 : -1);
    }
    double col(Map<double, List<double>> m, int i) => m.values.fold(0.0, (s, r) => s + r[i]);
    final outTax = col(out, 1) + col(out, 2) + col(out, 3);
    final inTax = col(inp, 1) + col(inp, 2) + col(inp, 3);
    String m(double v) => money(v, symbol: false);
    final rates = {...out.keys, ...inp.keys}.toList()..sort();

    final data = ReportData(
      title: context.tr('r_gst'),
      headers: [context.tr('gst_rate'), context.tr('gst_out_taxable'), 'CGST', 'SGST', 'IGST', context.tr('gst_in_taxable'), context.tr('gst_itc')],
      rows: [
        for (final r in rates)
          [
            rateText(r),
            m(out[r]?[0] ?? 0),
            m(out[r]?[1] ?? 0),
            m(out[r]?[2] ?? 0),
            m(out[r]?[3] ?? 0),
            m(inp[r]?[0] ?? 0),
            m((inp[r]?[1] ?? 0) + (inp[r]?[2] ?? 0) + (inp[r]?[3] ?? 0)),
          ],
      ],
      right: {1, 2, 3, 4, 5, 6},
      summary: [
        (context.tr('gst_output'), money(outTax)),
        (context.tr('gst_itc'), money(inTax)),
        (context.tr('gst_b2b_b2c'), '$b2b / $b2c'),
        (context.tr(outTax - inTax >= 0 ? 'gst_payable' : 'gst_credit'), money((outTax - inTax).abs())),
      ],
    );
    final name = 'GSTR-1 B2B ${_p.label(context)}';
    return ReportScaffold(
      data: data,
      period: _p,
      onPeriod: (p) => setState(() => _p = p),
      header: [
        UdRow(
          leading: const UdBadgeIcon(Icons.table_view_outlined, size: 40),
          title: context.tr('gst_b2b_export'),
          subtitle: context.tr('gst_b2b_export_sub', {'n': '${b2bRows.length}'}),
          trailing: const Icon(Icons.ios_share_rounded),
          onTap: () => shareCsv(context, name,
              ['GSTIN of recipient', 'Receiver name', 'Invoice number', 'Invoice date', 'Invoice value', 'Place of supply', 'Taxable value', 'IGST', 'CGST', 'SGST'], b2bRows),
        ),
        const SizedBox(height: 4),
      ],
    );
  }
}

// ---------------------------------------------------------------- stock

class StockReportPage extends StatelessWidget {
  const StockReportPage({super.key, this.lowOnly = false});
  final bool lowOnly;

  @override
  Widget build(BuildContext context) {
    final low = db.lowStockItems.map((e) => e.id).toSet();
    final list = db.items.where((i) => !i.isService && (!lowOnly || low.contains(i.id))).toList()..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
    String m(double v) => money(v, symbol: false);
    final data = ReportData(
      title: context.tr(lowOnly ? 'low_stock' : 'r_stock'),
      headers: [context.tr('item_name'), context.tr('in_stock'), context.tr('unit'), context.tr('purchase_price'), context.tr('stock_value'), context.tr('low_stock_at')],
      rows: [
        for (final i in list)
          [i.name, qtyText(db.stockOf(i.id)), i.unit, m(i.purchasePrice), m(max(0, db.stockOf(i.id)) * i.purchasePrice), i.lowStock > 0 ? qtyText(i.lowStock) : ''],
      ],
      right: {1, 3, 4, 5},
      summary: [
        (context.tr('count'), '${list.length}'),
        (context.tr('low_stock'), '${low.length}'),
        (context.tr('stock_value'), money(list.fold(0.0, (s, i) => s + max(0, db.stockOf(i.id)) * i.purchasePrice))),
      ],
    );
    return ReportScaffold(data: data, period: Period.of('all'), onPeriod: (_) {});
  }
}

// ---------------------------------------------------------------- receivable / payable

class PartyBalancesPage extends StatelessWidget {
  const PartyBalancesPage({super.key, required this.receivable});
  final bool receivable;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: db,
      builder: (context, _) {
        final text = Theme.of(context).textTheme;
        final list = db.parties.where((p) => receivable ? db.partyBalance(p.id) > 0.01 : db.partyBalance(p.id) < -0.01).toList()
          ..sort((a, b) => db.partyBalance(b.id).abs().compareTo(db.partyBalance(a.id).abs()));
        final total = list.fold(0.0, (s, p) => s + db.partyBalance(p.id).abs());
        final due = receivable ? db.dueInvoices.where((t) => db.docStatus(t).statusOn(t.dueDate) == PayStatus.overdue).toList() : <Txn>[];
        return UdPage(
          eyebrow: context.tr('reports'),
          title: context.tr(receivable ? 'r_receivable' : 'r_payable'),
          dock: list.isEmpty
              ? null
              : UdDock(
                  label: context.tr('share_pdf'),
                  icon: Icons.picture_as_pdf_outlined,
                  onPressed: () => shareTablePdf(
                    context,
                    () => buildTablePdf(
                      title: receivable ? 'Receivables' : 'Payables',
                      subtitle: 'As on ${dmy(DateTime.now())}',
                      headers: ['Party', 'Phone', 'Amount'],
                      rows: [for (final p in list) [p.name, p.phone, money(db.partyBalance(p.id).abs(), symbol: false)]],
                      summary: [('Total', money(total))],
                      rightAligned: {2},
                    ),
                    receivable ? 'Receivables' : 'Payables',
                  ),
                ),
          slivers: [
            UdSliverPad(
              sliver: SliverList.list(children: [
                Summary(cells: [
                  (context.tr(receivable ? 'to_receive' : 'to_pay'), money(total, decimals: 0), receivable ? const Color(0xFF8FD1A8) : const Color(0xFFFF9B8F)),
                  (context.tr('parties'), '${list.length}', null),
                  if (receivable) (context.tr('st_overdue'), '${due.length}', due.isEmpty ? null : const Color(0xFFFF9B8F)),
                ]),
                if (list.isEmpty) UdEmpty(icon: Icons.check_circle_outline_rounded, title: context.tr('all_settled')),
                for (final p in list)
                  UdRow(
                    title: p.name,
                    subtitle: p.phone.isEmpty ? null : p.phone,
                    trailing: Row(mainAxisSize: MainAxisSize.min, children: [
                      Text(money(db.partyBalance(p.id).abs()), style: text.titleMedium?.copyWith(color: receivable ? green : UdTokens.of(context).danger)),
                      if (receivable)
                        IconButton(
                          tooltip: context.tr('remind'),
                          icon: const Icon(Icons.chat_outlined, color: green),
                          onPressed: () => sendReminder(context, p, amount: db.partyBalance(p.id)),
                        ),
                    ]),
                    onTap: () => go(context, PartyPage(id: p.id)),
                  ),
              ]),
            ),
          ],
        );
      },
    );
  }
}
