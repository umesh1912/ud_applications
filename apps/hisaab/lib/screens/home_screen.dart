import 'package:flutter/material.dart';

import '../format.dart';
import '../models.dart';
import '../store.dart';
import '../theme.dart';
import '../widgets.dart';
import 'plan_screen.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key, required this.openTab});

  final ValueChanged<int> openTab;

  @override
  Widget build(BuildContext context) {
    final store = context.store;
    final hc = context.hc;
    final now = DateTime.now();
    final spent = store.spentIn(now);
    final earned = store.earnedIn(now);
    final insights = store.insights();
    final bills = store.upcomingBills.take(3).toList();
    final budgetCats = store.budgets.keys.toList()
      ..sort((a, b) => (store.spentIn(now, category: b) / store.budgets[b]!).compareTo(store.spentIn(now, category: a) / store.budgets[a]!));

    return ListView(
      padding: EdgeInsets.zero,
      children: [
        // Net worth band — the one big number.
        Container(
          color: hc.band,
          padding: EdgeInsets.fromLTRB(20, MediaQuery.of(context).padding.top + 16, 12, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      store.name.isEmpty ? 'Your net worth' : '${store.name}\'s net worth',
                      style: context.tt.titleSmall!.copyWith(color: hc.onBand.withValues(alpha: 0.85)),
                    ),
                  ),
                  IconButton(
                    tooltip: store.hideBalances ? 'Show amounts' : 'Hide amounts',
                    onPressed: () {
                      store.hideBalances = !store.hideBalances;
                      store.changed();
                    },
                    icon: Icon(store.hideBalances ? Icons.visibility_off_outlined : Icons.visibility_outlined, color: hc.onBand),
                  ),
                ],
              ),
              FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerLeft,
                child: Text(store.money(store.netWorth), style: money(context, 56, color: hc.onBand)),
              ),
              const SizedBox(height: 14),
              Wrap(
                spacing: 20,
                runSpacing: 8,
                children: [
                  _BandFigure(label: 'Cash & bank', value: store.money(store.cashTotal)),
                  _BandFigure(label: 'Investments', value: store.money(store.investedValue)),
                  _BandFigure(label: 'You owe', value: store.money(-store.owedTotal)),
                ],
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 100),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Section(monthYear(now), action: 'Passbook', onAction: () => openTab(1)),
              Row(
                children: [
                  Expanded(child: _MonthFigure(label: 'Spent', value: store.money(spent), color: hc.spend)),
                  const SizedBox(width: 12),
                  Expanded(child: _MonthFigure(label: 'Received', value: store.money(earned), color: hc.earn)),
                ],
              ),
              if (insights.isNotEmpty) ...[
                const Section('Worth knowing'),
                Paper(
                  padding: EdgeInsets.zero,
                  child: Column(
                    children: [
                      for (var i = 0; i < insights.length; i++) ...[
                        if (i > 0) const Divider(indent: 52),
                        ListTile(
                          leading: Icon(insights[i].icon, color: insights[i].warn ? hc.brass : hc.green),
                          title: Text(insights[i].text, style: context.tt.bodyMedium),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
              Section('Coming up', action: 'All bills', onAction: () => openTab(2)),
              if (bills.isEmpty)
                Text('No bills added. Add rent, EMIs and subscriptions in Plan to get reminders.',
                    style: context.tt.bodyMedium!.copyWith(color: hc.muted))
              else
                Paper(
                  padding: EdgeInsets.zero,
                  child: Column(
                    children: [
                      for (var i = 0; i < bills.length; i++) ...[
                        if (i > 0) const Divider(indent: 16),
                        BillTile(bill: bills[i]),
                      ],
                    ],
                  ),
                ),
              if (budgetCats.isNotEmpty) ...[
                Section('Budgets this month', action: 'Edit', onAction: () => openTab(2)),
                Paper(
                  child: Column(
                    children: [
                      for (final c in budgetCats.take(4))
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 6),
                          child: BudgetLine(category: categoryById(c)),
                        ),
                    ],
                  ),
                ),
              ],
              if (store.goals.isNotEmpty) ...[
                Section('Goals', action: 'Open', onAction: () => openTab(2)),
                for (final g in store.goals.take(2))
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Paper(
                      child: Row(
                        children: [
                          Icon(goalIcons[g.icon % goalIcons.length], color: hc.brass),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(g.name, style: context.tt.titleSmall),
                                const SizedBox(height: 6),
                                Meter(value: g.progress, color: hc.brass),
                                const SizedBox(height: 4),
                                Text('${store.moneyShort(g.saved)} of ${store.moneyShort(g.target)} · ${(g.progress * 100).round()}%',
                                    style: context.tt.bodySmall),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

class _BandFigure extends StatelessWidget {
  const _BandFigure({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final hc = context.hc;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: context.tt.labelSmall!.copyWith(color: hc.onBand.withValues(alpha: 0.7))),
        Text(value, style: context.tt.titleMedium!.copyWith(color: hc.onBand)),
      ],
    );
  }
}

class _MonthFigure extends StatelessWidget {
  const _MonthFigure({required this.label, required this.value, required this.color});

  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Paper(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: context.tt.labelMedium!.copyWith(color: color)),
          const SizedBox(height: 4),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(value, style: money(context, 30)),
          ),
        ],
      ),
    );
  }
}
