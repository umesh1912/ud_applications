import 'dart:math';

import 'package:flutter/material.dart';
import 'package:ud_core/ud_core.dart';

Widget numberField(BuildContext context, TextEditingController c, String label,
    {ValueChanged<String>? onChanged, bool decimal = true}) {
  final text = Theme.of(context).textTheme;
  return Padding(
    padding: const EdgeInsets.only(bottom: 14),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(padding: const EdgeInsets.only(bottom: 6, left: 4), child: Text(label, style: text.labelMedium)),
        TextField(
          controller: c,
          keyboardType: TextInputType.numberWithOptions(decimal: decimal),
          style: text.titleMedium,
          onChanged: onChanged,
          decoration: udInputDecoration(context),
        ),
      ],
    ),
  );
}

class ResultCard extends StatelessWidget {
  const ResultCard({super.key, required this.title, required this.value, this.rows = const []});
  final String title;
  final String value;
  final List<(String, String)> rows;

  @override
  Widget build(BuildContext context) {
    final t = UdTokens.of(context);
    final text = Theme.of(context).textTheme;
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(color: t.ink, borderRadius: BorderRadius.circular(24)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: text.labelLarge?.copyWith(color: t.paper.withValues(alpha: 0.7))),
          const SizedBox(height: 4),
          FittedBox(child: Text(value, style: text.displaySmall?.copyWith(color: t.paper))),
          for (final (k, v) in rows)
            Padding(
              padding: const EdgeInsets.only(top: 10),
              child: Row(children: [
                Expanded(child: Text(k, style: text.bodyMedium?.copyWith(color: t.paper.withValues(alpha: 0.75)))),
                Text(v, style: text.titleMedium?.copyWith(color: t.paper)),
              ]),
            ),
        ],
      ),
    );
  }
}

class EmiPage extends StatefulWidget {
  const EmiPage({super.key});

  @override
  State<EmiPage> createState() => _EmiPageState();
}

class _EmiPageState extends State<EmiPage> {
  final _loan = TextEditingController(text: '3000000');
  final _rate = TextEditingController(text: '8.5');
  final _years = TextEditingController(text: '20');

  @override
  Widget build(BuildContext context) {
    final p = udParseNum(_loan.text) ?? 0;
    final r = (udParseNum(_rate.text) ?? 0) / 12 / 100;
    final n = ((udParseNum(_years.text) ?? 0) * 12).round();
    double emi = 0;
    if (p > 0 && n > 0) {
      emi = r == 0 ? p / n : p * r * pow(1 + r, n) / (pow(1 + r, n) - 1);
    }
    final total = emi * n;
    void upd(String _) => setState(() {});
    return UdPage(
      title: context.tr('emi'),
      slivers: [
        UdSliverPad(
          sliver: SliverList.list(children: [
            ResultCard(
              title: context.tr('monthly_emi'),
              value: udRupees(emi),
              rows: [
                (context.tr('total_interest'), udRupeesShort(max(0, total - p))),
                (context.tr('total_pay'), udRupeesShort(total)),
              ],
            ),
            const SizedBox(height: 20),
            numberField(context, _loan, context.tr('loan'), onChanged: upd, decimal: false),
            numberField(context, _rate, context.tr('rate'), onChanged: upd),
            numberField(context, _years, context.tr('years'), onChanged: upd),
          ]),
        ),
      ],
    );
  }
}

/// Approximate rates (stamp %, registration %, stamp % for women buyers).
const statePresets = <String, (double, double, double)>{
  'Gujarat': (4.9, 1.0, 4.9),
  'Maharashtra': (6.0, 1.0, 5.0),
  'Rajasthan': (6.0, 1.0, 5.0),
  'Delhi': (6.0, 1.0, 4.0),
  'Karnataka': (5.0, 1.0, 5.0),
  'Tamil Nadu': (7.0, 2.0, 7.0),
  'Madhya Pradesh': (7.5, 3.0, 7.5),
  'Uttar Pradesh': (7.0, 1.0, 6.0),
  'Other': (6.0, 1.0, 6.0),
};

class StampPage extends StatefulWidget {
  const StampPage({super.key});

  @override
  State<StampPage> createState() => _StampPageState();
}

class _StampPageState extends State<StampPage> {
  final _value = TextEditingController(text: '5000000');
  final _stamp = TextEditingController();
  final _reg = TextEditingController();
  String _state = 'Gujarat';
  bool _woman = false;

  @override
  void initState() {
    super.initState();
    _apply();
  }

  void _apply() {
    final (s, r, w) = statePresets[_state]!;
    _stamp.text = '${_woman ? w : s}';
    // Gujarat waives the registration fee for women buyers.
    _reg.text = '${_woman && _state == 'Gujarat' ? 0 : r}';
  }

  @override
  Widget build(BuildContext context) {
    final t = UdTokens.of(context);
    final text = Theme.of(context).textTheme;
    final v = udParseNum(_value.text) ?? 0;
    final stamp = v * (udParseNum(_stamp.text) ?? 0) / 100;
    final reg = v * (udParseNum(_reg.text) ?? 0) / 100;
    void upd(String _) => setState(() {});
    return UdPage(
      title: context.tr('stamp'),
      slivers: [
        UdSliverPad(
          sliver: SliverList.list(children: [
            ResultCard(
              title: context.tr('stamp_total'),
              value: udRupees(stamp + reg),
              rows: [
                (context.tr('stamp_rate'), udRupees(stamp)),
                (context.tr('reg_rate'), udRupees(reg)),
              ],
            ),
            const SizedBox(height: 20),
            numberField(context, _value, context.tr('property_value'), onChanged: upd, decimal: false),
            UdLabel(context.tr('state')),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final s in statePresets.keys)
                  ChoiceChip(
                    label: Text(s),
                    selected: s == _state,
                    showCheckmark: false,
                    onSelected: (_) => setState(() {
                      _state = s;
                      _apply();
                    }),
                  ),
              ],
            ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(context.tr('woman_buyer'), style: text.bodyMedium),
              value: _woman,
              onChanged: (b) => setState(() {
                _woman = b;
                _apply();
              }),
            ),
            numberField(context, _stamp, context.tr('stamp_rate'), onChanged: upd),
            numberField(context, _reg, context.tr('reg_rate'), onChanged: upd),
            Text(context.tr('approx_note'), style: text.bodySmall?.copyWith(color: t.inkSoft)),
          ]),
        ),
      ],
    );
  }
}

/// Square feet per unit.
const areaUnits = <String, double>{
  'Sq ft': 1,
  'Sq m': 10.7639,
  'Sq yd / Gaj': 9,
  'Guntha': 1089,
  'Bigha (Gujarat)': 17424,
  'Acre': 43560,
  'Hectare': 107639,
};

class AreaPage extends StatefulWidget {
  const AreaPage({super.key});

  @override
  State<AreaPage> createState() => _AreaPageState();
}

class _AreaPageState extends State<AreaPage> {
  final _value = TextEditingController(text: '1000');
  String _from = 'Sq ft';

  String _fmt(double v) {
    if (v >= 1000) return v.toStringAsFixed(0);
    if (v >= 1) return v.toStringAsFixed(2);
    return v.toStringAsFixed(4);
  }

  @override
  Widget build(BuildContext context) {
    final t = UdTokens.of(context);
    final text = Theme.of(context).textTheme;
    final sqft = (udParseNum(_value.text) ?? 0) * areaUnits[_from]!;
    return UdPage(
      title: context.tr('area'),
      slivers: [
        UdSliverPad(
          sliver: SliverList.list(children: [
            numberField(context, _value, context.tr('value'), onChanged: (_) => setState(() {})),
            UdLabel(context.tr('from')),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final u in areaUnits.keys)
                  ChoiceChip(
                    label: Text(u),
                    selected: u == _from,
                    showCheckmark: false,
                    onSelected: (_) => setState(() => _from = u),
                  ),
              ],
            ),
            const SizedBox(height: 18),
            for (final e in areaUnits.entries)
              if (e.key != _from)
                Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
                  decoration: BoxDecoration(
                    color: t.card,
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(color: t.line),
                  ),
                  child: Row(children: [
                    Expanded(child: Text(e.key, style: text.bodyMedium?.copyWith(color: t.inkSoft))),
                    Text(_fmt(sqft / e.value), style: text.titleLarge),
                  ]),
                ),
          ]),
        ),
      ],
    );
  }
}
