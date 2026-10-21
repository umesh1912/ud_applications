import 'dart:ui' show FontFeature;

import 'dart:math';

import 'package:flutter/material.dart';

import '../format.dart';
import '../models.dart';
import '../store.dart';
import '../theme.dart';
import '../widgets.dart';

/// Investments, net worth and an income-tax estimate.
class WealthScreen extends StatelessWidget {
  const WealthScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final store = context.store;
    final hc = context.hc;
    final alloc = store.allocation;
    final total = store.investedValue;
    final gain = total - store.investedCost;

    return SafeArea(
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 100),
        children: [
          Text('Wealth', style: context.tt.displaySmall),
          const SizedBox(height: 14),
          Paper(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Investments today', style: context.tt.labelMedium),
                const SizedBox(height: 4),
                Text(store.money(total), style: money(context, 40)),
                const SizedBox(height: 4),
                Text(
                  store.hideBalances
                      ? 'Returns hidden'
                      : '${gain >= 0 ? 'Up' : 'Down'} ${inr(gain.abs())} on ${inr(store.investedCost)} invested'
                          '${store.investedCost > 0 ? ' (${(gain / store.investedCost * 100).toStringAsFixed(1)}%)' : ''}',
                  style: context.tt.bodyMedium!.copyWith(color: gain >= 0 ? hc.earn : hc.spend),
                ),
                if (total > 0) ...[
                  const SizedBox(height: 14),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(6),
                    child: SizedBox(
                      height: 14,
                      child: Row(
                        children: [
                          for (final e in alloc.entries)
                            Expanded(
                              flex: max(1, (e.value / total * 1000).round()),
                              child: Container(color: e.key.color),
                            ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 14,
                    runSpacing: 6,
                    children: [
                      for (final e in alloc.entries)
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(width: 10, height: 10, decoration: BoxDecoration(color: e.key.color, borderRadius: BorderRadius.circular(2))),
                            const SizedBox(width: 6),
                            Text('${e.key.label} ${(e.value / total * 100).round()}%', style: context.tt.bodySmall),
                          ],
                        ),
                    ],
                  ),
                ],
              ],
            ),
          ),
          Section('Holdings', action: 'Add', onAction: () => showForm(context, const HoldingSheet())),
          if (store.holdings.isEmpty)
            Text('Add mutual funds, stocks, FDs, PPF, NPS, gold or property to track them together.',
                style: context.tt.bodyMedium!.copyWith(color: hc.muted))
          else
            Paper(
              padding: EdgeInsets.zero,
              child: Column(
                children: [
                  for (var i = 0; i < store.holdings.length; i++) ...[
                    if (i > 0) const Divider(indent: 16),
                    _HoldingTile(h: store.holdings[i]),
                  ],
                ],
              ),
            ),
          const Section('Net worth'),
          Paper(
            child: Column(
              children: [
                _Line('Cash and bank accounts', store.money(store.cashTotal)),
                _Line('Investments', store.money(store.investedValue)),
                _Line('Credit cards and loans', store.money(store.owedTotal), color: hc.spend),
                const Divider(height: 20),
                _Line('Net worth', store.money(store.netWorth), bold: true),
              ],
            ),
          ),
          const Section('Income tax estimate'),
          const _TaxCard(),
        ],
      ),
    );
  }
}

class _Line extends StatelessWidget {
  const _Line(this.label, this.value, {this.color, this.bold = false});

  final String label;
  final String value;
  final Color? color;
  final bool bold;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Expanded(child: Text(label, style: bold ? context.tt.titleSmall : context.tt.bodyMedium)),
          Text(value,
              style: (bold ? context.tt.titleMedium : context.tt.bodyMedium)!
                  .copyWith(color: color, fontFeatures: const [FontFeature.tabularFigures()])),
        ],
      ),
    );
  }
}

class _HoldingTile extends StatelessWidget {
  const _HoldingTile({required this.h});

  final Holding h;

  @override
  Widget build(BuildContext context) {
    final store = context.store;
    final hc = context.hc;
    return ListTile(
      onTap: () => showForm(context, HoldingSheet(existing: h)),
      leading: Container(width: 6, height: 36, decoration: BoxDecoration(color: h.kind.color, borderRadius: BorderRadius.circular(3))),
      title: Text(h.name, style: context.tt.titleSmall),
      subtitle: Text('${h.kind.label}${h.taxSaver ? ' · 80C' : ''}', style: context.tt.bodySmall),
      trailing: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Text(store.money(h.current), style: context.tt.titleSmall),
          Text(
            store.hideBalances ? '' : '${h.gain >= 0 ? '+' : ''}${(h.gainPct * 100).toStringAsFixed(1)}%',
            style: context.tt.labelSmall!.copyWith(color: h.gain >= 0 ? hc.earn : hc.spend),
          ),
        ],
      ),
    );
  }
}

class HoldingSheet extends StatefulWidget {
  const HoldingSheet({super.key, this.existing});

  final Holding? existing;

  @override
  State<HoldingSheet> createState() => _HoldingSheetState();
}

class _HoldingSheetState extends State<HoldingSheet> {
  late final _name = TextEditingController(text: widget.existing?.name ?? '');
  late final _invested = TextEditingController(text: widget.existing?.invested.toStringAsFixed(0) ?? '');
  late final _current = TextEditingController(text: widget.existing?.current.toStringAsFixed(0) ?? '');
  late HoldingKind _kind = widget.existing?.kind ?? HoldingKind.mutualFund;
  late bool _tax = widget.existing?.taxSaver ?? false;
  String? _error;

  @override
  void dispose() {
    _name.dispose();
    _invested.dispose();
    _current.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final store = context.store;
    return FormSheet(
      title: widget.existing == null ? 'Add investment' : 'Update investment',
      actions: [
        FilledButton(
          onPressed: () {
            final inv = parseAmount(_invested.text);
            final cur = parseAmount(_current.text) ?? inv;
            if (_name.text.trim().isEmpty || inv == null || inv < 0) {
              setState(() => _error = 'Add a name and the amount you invested.');
              return;
            }
            if (widget.existing != null) {
              widget.existing!
                ..name = _name.text.trim()
                ..kind = _kind
                ..invested = inv
                ..current = cur!
                ..taxSaver = _tax;
              store.changed();
            } else {
              store.addHolding(Holding(id: store.newId(), name: _name.text.trim(), kind: _kind, invested: inv, current: cur!, taxSaver: _tax));
            }
            Navigator.pop(context);
          },
          child: Text(widget.existing == null ? 'Add investment' : 'Save'),
        ),
        if (widget.existing != null)
          TextButton(
            onPressed: () {
              store.removeHolding(widget.existing!);
              Navigator.pop(context);
            },
            child: const Text('Remove'),
          ),
      ],
      children: [
        Wrap(
          spacing: 6,
          runSpacing: 6,
          children: [
            for (final k in HoldingKind.values)
              ChoiceChip(label: Text(k.label), selected: _kind == k, onSelected: (_) => setState(() => _kind = k)),
          ],
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _name,
          textCapitalization: TextCapitalization.words,
          decoration: InputDecoration(labelText: 'Name', hintText: 'e.g. Parag Parikh Flexi Cap', errorText: _error),
        ),
        const SizedBox(height: 12),
        AmountField(controller: _invested, label: 'Total invested'),
        const SizedBox(height: 12),
        AmountField(controller: _current, label: 'Value today'),
        const SizedBox(height: 4),
        Text('Check the value in your fund, broker or bank app and update it here now and then.', style: context.tt.bodySmall),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          value: _tax,
          onChanged: (v) => setState(() => _tax = v),
          title: const Text('Counts for Section 80C'),
          subtitle: const Text('ELSS, PPF, tax-saver FD, NPS (Tier 1) and similar'),
        ),
      ],
    );
  }
}

class _TaxCard extends StatefulWidget {
  const _TaxCard();

  @override
  State<_TaxCard> createState() => _TaxCardState();
}

class _TaxCardState extends State<_TaxCard> {
  late final _income = TextEditingController(
    text: StoreScope.read(context).annualIncome > 0 ? StoreScope.read(context).annualIncome.toStringAsFixed(0) : '',
  );
  late final _other80C = TextEditingController(
    text: StoreScope.read(context).other80C > 0 ? StoreScope.read(context).other80C.toStringAsFixed(0) : '',
  );
  late final _80d = TextEditingController(
    text: StoreScope.read(context).deduction80D > 0 ? StoreScope.read(context).deduction80D.toStringAsFixed(0) : '',
  );

  @override
  void dispose() {
    _income.dispose();
    _other80C.dispose();
    _80d.dispose();
    super.dispose();
  }

  void _save() {
    final s = StoreScope.read(context);
    s.annualIncome = parseAmount(_income.text) ?? 0;
    s.other80C = parseAmount(_other80C.text) ?? 0;
    s.deduction80D = parseAmount(_80d.text) ?? 0;
    s.changed();
  }

  @override
  Widget build(BuildContext context) {
    final store = context.store;
    final hc = context.hc;
    final inc = store.annualIncome;
    final n = store.newRegime(inc);
    final o = store.oldRegime(inc);
    final used80C = min(150000.0, store.invested80C);
    final better = n.tax <= o.tax ? 'new' : 'old';

    return Paper(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          AmountField(controller: _income, label: 'Yearly income before tax (salary + other)'),
          const SizedBox(height: 10),
          AmountField(controller: _other80C, label: 'Other 80C: EPF, life insurance, tuition, home-loan principal'),
          const SizedBox(height: 10),
          AmountField(controller: _80d, label: 'Health insurance premium (80D)'),
          const SizedBox(height: 10),
          OutlinedButton(onPressed: _save, child: const Text('Update estimate')),
          const SizedBox(height: 16),
          Text('Section 80C used', style: context.tt.labelMedium),
          const SizedBox(height: 6),
          Meter(value: used80C / 150000, color: hc.brass, height: 10),
          const SizedBox(height: 4),
          Text(
            used80C >= 150000
                ? 'Full ₹1,50,000 used (only counts in the old regime).'
                : '${inr(used80C)} of ₹1,50,000 · ${inr(150000 - used80C)} more would still save tax in the old regime.',
            style: context.tt.bodySmall,
          ),
          if (inc > 0) ...[
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(child: _Regime(label: 'New regime', tax: n.tax, taxable: n.taxable, best: better == 'new')),
                const SizedBox(width: 10),
                Expanded(child: _Regime(label: 'Old regime', tax: o.tax, taxable: o.taxable, best: better == 'old')),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              (n.tax - o.tax).abs() < 1
                  ? 'Both regimes come out about the same for you.'
                  : 'The $better regime saves you about ${inr((n.tax - o.tax).abs().round())} this year.',
              style: context.tt.titleSmall,
            ),
          ],
          const SizedBox(height: 10),
          Text(
            'Estimate for FY 2026-27, individuals under 60, including 4% cess. Surcharge (income above ₹50 lakh) '
            'and other deductions like HRA aren\'t included. Check with a tax professional before filing.',
            style: context.tt.bodySmall,
          ),
        ],
      ),
    );
  }
}

class _Regime extends StatelessWidget {
  const _Regime({required this.label, required this.tax, required this.taxable, required this.best});

  final String label;
  final double tax;
  final double taxable;
  final bool best;

  @override
  Widget build(BuildContext context) {
    final hc = context.hc;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: best ? hc.greenSoft : null,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: best ? hc.green : hc.rule, width: best ? 1.6 : 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(best ? '$label · lower' : label, style: context.tt.labelMedium),
          const SizedBox(height: 4),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(inr(tax.round()), style: money(context, 28)),
          ),
          Text('on ${inrShort(taxable)} taxable', style: context.tt.bodySmall),
        ],
      ),
    );
  }
}
