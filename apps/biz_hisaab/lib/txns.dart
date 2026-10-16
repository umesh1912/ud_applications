import 'package:flutter/material.dart';
import 'package:ud_core/ud_core.dart';

import 'db.dart';
import 'gst.dart';
import 'home.dart';
import 'txn_view.dart';
import 'ui.dart';

/// A date range chosen from presets or the calendar.
class Period {
  const Period(this.key, this.from, this.to);
  final String key;
  final DateTime from;
  final DateTime to; // exclusive

  static Period of(String key) {
    final now = DateTime.now();
    final today = dayOnly(now);
    final end = today.add(const Duration(days: 1));
    return switch (key) {
      'today' => Period(key, today, end),
      'week' => Period(key, today.subtract(Duration(days: today.weekday - 1)), end),
      'month' => Period(key, DateTime(now.year, now.month), end),
      'last_month' => Period(key, DateTime(now.year, now.month - 1), DateTime(now.year, now.month)),
      'quarter' => Period(key, DateTime(now.year, ((now.month - 1) ~/ 3) * 3 + 1), end),
      'fy' => Period(key, fyStart(now), end),
      'last_fy' => Period(key, DateTime(fyStart(now).year - 1, 4), fyStart(now)),
      _ => Period('all', DateTime(2000), DateTime(2200)),
    };
  }

  String label(BuildContext context) => key == 'custom'
      ? '${dmy(from)} – ${dmy(to.subtract(const Duration(days: 1)))}'
      : context.tr('p_$key');
}

const periodKeys = ['today', 'week', 'month', 'last_month', 'quarter', 'fy', 'last_fy', 'all', 'custom'];

Future<Period?> pickPeriod(BuildContext context, Period current) async {
  final key = await showUdActions<String>(context, title: context.tr('period'), actions: [
    for (final k in periodKeys) UdAction(k, k == current.key ? Icons.radio_button_checked_rounded : Icons.radio_button_off_rounded, context.tr('p_$k')),
  ]);
  if (key == null || !context.mounted) return null;
  if (key != 'custom') return Period.of(key);
  final r = await showDateRangePicker(
    context: context,
    firstDate: DateTime(2015),
    lastDate: DateTime(2100),
    initialDateRange: DateTimeRange(start: current.from.year < 2015 ? DateTime.now() : current.from, end: DateTime.now()),
  );
  if (r == null) return null;
  return Period('custom', dayOnly(r.start), dayOnly(r.end).add(const Duration(days: 1)));
}

class PeriodButton extends StatelessWidget {
  const PeriodButton({super.key, required this.period, required this.onChanged});
  final Period period;
  final ValueChanged<Period> onChanged;

  @override
  Widget build(BuildContext context) => PickField(
        label: context.tr('period'),
        value: period.label(context),
        icon: Icons.date_range_rounded,
        onTap: () async {
          final p = await pickPeriod(context, period);
          if (p != null) onChanged(p);
        },
      );
}

class TxnsTab extends StatefulWidget {
  const TxnsTab({super.key});

  @override
  State<TxnsTab> createState() => _TxnsTabState();
}

class _TxnsTabState extends State<TxnsTab> {
  Period _period = Period.of('month');
  TxnType? _type;
  String _q = '';

  @override
  Widget build(BuildContext context) {
    final q = _q.toLowerCase();
    final list = db.inRange(_period.from, _period.to, _type == null ? null : {_type!})
        .where((t) => q.isEmpty || t.partyName.toLowerCase().contains(q) || t.number.toLowerCase().contains(q) ||
            t.notes.toLowerCase().contains(q) || t.lines.any((l) => l.name.toLowerCase().contains(q)))
        .toList()
      ..sort((a, b) => b.date.compareTo(a.date) != 0 ? b.date.compareTo(a.date) : b.createdAt.compareTo(a.createdAt));
    double sum(TxnType ty) => list.where((t) => t.type == ty).fold(0.0, (s, t) => s + db.totalOf(t));
    final moneyIn = list.where((t) => t.type.cashSign > 0).fold(0.0, (s, t) => s + db.cashOf(t));
    final moneyOut = list.where((t) => t.type.cashSign < 0).fold(0.0, (s, t) => s + db.cashOf(t));

    // Group rows by day.
    final rows = <Widget>[];
    DateTime? day;
    final text = Theme.of(context).textTheme;
    for (final t in list) {
      final d = dayOnly(t.date);
      if (day != d) {
        day = d;
        rows.add(Padding(
          padding: const EdgeInsets.only(top: 6, bottom: 8, left: 4),
          child: Text(dmy(d), style: text.labelMedium?.copyWith(color: UdTokens.of(context).inkSoft)),
        ));
      }
      rows.add(TxnRow(t, onTap: () => go(context, TxnView(id: t.id))));
    }

    return UdPage(
      title: context.tr('nav_txns'),
      subtitle: context.tr('txns_sub', {'n': '${list.length}'}),
      showBack: false,
      dock: UdDock(label: context.tr('create_new'), icon: Icons.add_rounded, onPressed: () => chooseNewTxn(context)),
      slivers: [
        UdSliverPad(
          sliver: SliverList.list(children: [
            Summary(cells: [
              if (_type == null || _type == TxnType.sale) (context.tr('t_sale'), money(sum(TxnType.sale), decimals: 0), null),
              if (_type != null && _type != TxnType.sale) (typeLabel(context, _type!), money(sum(_type!), decimals: 0), null),
              (context.tr('money_in'), money(moneyIn, decimals: 0), const Color(0xFF8FD1A8)),
              (context.tr('money_out'), money(moneyOut, decimals: 0), const Color(0xFFFF9B8F)),
            ]),
            PeriodButton(period: _period, onChanged: (p) => setState(() => _period = p)),
            TextField(
              onChanged: (v) => setState(() => _q = v),
              decoration: udInputDecoration(context, hint: context.tr('search_txns'), icon: Icons.search_rounded),
            ),
            const SizedBox(height: 12),
            SizedBox(
              height: 40,
              child: ListView(scrollDirection: Axis.horizontal, children: [
                for (final ty in [null, ...TxnType.values])
                  Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: ChoiceChip(
                      label: Text(ty == null ? context.tr('all') : typeLabel(context, ty)),
                      selected: _type == ty,
                      showCheckmark: false,
                      onSelected: (_) => setState(() => _type = ty),
                    ),
                  ),
              ]),
            ),
            const SizedBox(height: 12),
            if (list.isEmpty)
              UdEmpty(icon: Icons.receipt_long_outlined, title: context.tr('no_txns'), body: context.tr('no_txns_sub'))
            else
              ...rows,
          ]),
        ),
      ],
    );
  }
}
