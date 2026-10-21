import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../format.dart';
import '../models.dart';
import '../store.dart';
import '../theme.dart';
import '../widgets.dart';

class MoreScreen extends StatelessWidget {
  const MoreScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final store = context.store;
    final hc = context.hc;
    final latest = store.scores.isEmpty ? null : store.scores.last;

    return SafeArea(
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 100),
        children: [
          Text('More', style: context.tt.displaySmall),
          const Section('Credit score'),
          Paper(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (latest == null)
                  Text('Add your CIBIL or Experian score to track it over time.', style: context.tt.bodyMedium)
                else ...[
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text('${latest.score}', style: money(context, 52, color: _scoreColor(hc, latest.score))),
                      const SizedBox(width: 10),
                      Padding(
                        padding: const EdgeInsets.only(bottom: 6),
                        child: Text('${_scoreBand(latest.score)} · ${dayMonthYear(latest.date)}', style: context.tt.bodySmall),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  _ScoreScale(score: latest.score),
                  if (store.scores.length > 1) ...[
                    const SizedBox(height: 10),
                    Text(
                      () {
                        final d = latest.score - store.scores[store.scores.length - 2].score;
                        return d == 0 ? 'No change since last check.' : '${d > 0 ? 'Up' : 'Down'} ${d.abs()} points since last check.';
                      }(),
                      style: context.tt.bodyMedium,
                    ),
                  ],
                ],
                const SizedBox(height: 12),
                OutlinedButton.icon(
                  onPressed: () => _addScore(context),
                  icon: const Icon(Icons.add),
                  label: const Text('Add latest score'),
                ),
                const SizedBox(height: 12),
                Text('Ways to improve it', style: context.tt.titleSmall),
                const SizedBox(height: 4),
                for (final tip in const [
                  'Pay every EMI and card bill in full, on time. Late payments hurt the most.',
                  'Keep card spending under 30% of your limit.',
                  'Avoid applying for many loans or cards in a short time.',
                  'Keep old cards open; a longer history helps.',
                ])
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Padding(padding: const EdgeInsets.only(top: 7, right: 8), child: Icon(Icons.circle, size: 5, color: hc.muted)),
                        Expanded(child: Text(tip, style: context.tt.bodyMedium)),
                      ],
                    ),
                  ),
              ],
            ),
          ),
          const Section('Reports'),
          Paper(
            padding: EdgeInsets.zero,
            child: Column(
              children: [
                ListTile(
                  leading: const Icon(Icons.summarize_outlined),
                  title: const Text('Monthly summary'),
                  subtitle: const Text('Spending by category for the last 6 months'),
                  onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const SummaryScreen())),
                ),
                const Divider(indent: 56),
                ListTile(
                  leading: const Icon(Icons.table_view_outlined),
                  title: const Text('Copy all entries as CSV'),
                  subtitle: const Text('Paste into Excel or Google Sheets'),
                  onTap: () {
                    Clipboard.setData(ClipboardData(text: store.exportCsv()));
                    toast(context, 'Copied ${store.txns.length} entries. Paste them into a spreadsheet.');
                  },
                ),
              ],
            ),
          ),
          const Section('Expert help'),
          Paper(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Talk to a SEBI-registered investment adviser', style: context.tt.titleSmall),
                const SizedBox(height: 4),
                Text(
                  'For a full financial plan, use an adviser registered with SEBI. Check their registration number on '
                  'the SEBI website before paying any fee.',
                  style: context.tt.bodyMedium,
                ),
                const SizedBox(height: 8),
                SelectableText('sebi.gov.in → Intermediaries → Investment Advisers', style: context.tt.labelMedium!.copyWith(color: hc.green)),
                const SizedBox(height: 8),
                Text('Hisaab gives general information, not personal investment advice.', style: context.tt.bodySmall),
              ],
            ),
          ),
          const Section('Security & data'),
          Paper(
            padding: EdgeInsets.zero,
            child: Column(
              children: [
                SwitchListTile(
                  value: store.hideBalances,
                  onChanged: (v) {
                    store.hideBalances = v;
                    store.changed();
                  },
                  secondary: const Icon(Icons.visibility_off_outlined),
                  title: const Text('Hide amounts'),
                  subtitle: const Text('Useful when others can see your screen'),
                ),
                const Divider(indent: 56),
                ListTile(
                  leading: const Icon(Icons.lock_outline),
                  title: const Text('Lock now'),
                  subtitle: const Text('Hisaab also locks after 1 minute in the background'),
                  onTap: store.lockNow,
                ),
                const Divider(indent: 56),
                ListTile(
                  leading: const Icon(Icons.pin_outlined),
                  title: const Text('Change PIN'),
                  onTap: () => _changePin(context),
                ),
                const Divider(indent: 56),
                ListTile(
                  leading: Icon(Icons.delete_forever_outlined, color: hc.spend),
                  title: Text('Reset Hisaab', style: TextStyle(color: hc.spend)),
                  subtitle: const Text('Deletes all accounts, entries and your PIN from this phone'),
                  onTap: () async {
                    if (await confirm(context, 'Delete everything?', 'This can\'t be undone. Copy your CSV first if you need it.', 'Delete everything')) {
                      store.resetAll();
                    }
                  },
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Text('Everything is stored only on this phone. Nothing is uploaded.', style: context.tt.bodySmall, textAlign: TextAlign.center),
        ],
      ),
    );
  }

  static String _scoreBand(int s) => s >= 750 ? 'Excellent' : s >= 700 ? 'Good' : s >= 650 ? 'Fair' : 'Needs work';
  static Color _scoreColor(HC hc, int s) => s >= 700 ? hc.earn : s >= 650 ? hc.brass : hc.spend;

  Future<void> _addScore(BuildContext context) async {
    final store = StoreScope.read(context);
    final ctrl = TextEditingController();
    String? error;
    final v = await showDialog<int>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setS) => AlertDialog(
          title: const Text('Your latest score'),
          content: TextField(
            controller: ctrl,
            autofocus: true,
            keyboardType: TextInputType.number,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly, LengthLimitingTextInputFormatter(3)],
            decoration: InputDecoration(hintText: '300 – 900', errorText: error),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
            TextButton(
              onPressed: () {
                final n = int.tryParse(ctrl.text);
                if (n == null || n < 300 || n > 900) {
                  setS(() => error = 'Scores range from 300 to 900.');
                  return;
                }
                Navigator.pop(ctx, n);
              },
              child: const Text('Save'),
            ),
          ],
        ),
      ),
    );
    if (v != null) store.addScore(v);
  }

  Future<void> _changePin(BuildContext context) async {
    final store = StoreScope.read(context);
    final oldC = TextEditingController();
    final newC = TextEditingController();
    String? error;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setS) => AlertDialog(
          title: const Text('Change PIN'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: oldC,
                obscureText: true,
                keyboardType: TextInputType.number,
                maxLength: 4,
                decoration: const InputDecoration(labelText: 'Current PIN', counterText: ''),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: newC,
                obscureText: true,
                keyboardType: TextInputType.number,
                maxLength: 4,
                decoration: InputDecoration(labelText: 'New PIN', counterText: '', errorText: error),
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
            TextButton(
              onPressed: () {
                if (oldC.text != store.pin) {
                  setS(() => error = 'The current PIN is wrong.');
                } else if (!RegExp(r'^\d{4}$').hasMatch(newC.text)) {
                  setS(() => error = 'Use exactly 4 digits.');
                } else {
                  store.pin = newC.text;
                  store.changed();
                  Navigator.pop(ctx, true);
                }
              },
              child: const Text('Save'),
            ),
          ],
        ),
      ),
    );
    if (ok == true && context.mounted) toast(context, 'PIN changed');
  }
}

class _ScoreScale extends StatelessWidget {
  const _ScoreScale({required this.score});

  final int score;

  @override
  Widget build(BuildContext context) {
    final hc = context.hc;
    final pos = ((score - 300) / 600).clamp(0.0, 1.0);
    return Column(
      children: [
        LayoutBuilder(
          builder: (context, box) => SizedBox(
            height: 22,
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                Positioned(
                  top: 8,
                  left: 0,
                  right: 0,
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: Row(
                      children: [
                        Expanded(flex: 350, child: Container(height: 8, color: hc.spend)),
                        Expanded(flex: 50, child: Container(height: 8, color: hc.brass)),
                        Expanded(flex: 50, child: Container(height: 8, color: hc.earn.withValues(alpha: 0.6))),
                        Expanded(flex: 150, child: Container(height: 8, color: hc.earn)),
                      ],
                    ),
                  ),
                ),
                Positioned(
                  left: (box.maxWidth * pos - 6).clamp(0.0, box.maxWidth - 12),
                  top: 2,
                  child: Container(
                    width: 12,
                    height: 20,
                    decoration: BoxDecoration(color: hc.ink, borderRadius: BorderRadius.circular(3), border: Border.all(color: hc.card, width: 2)),
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 4),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('300', style: context.tt.labelSmall),
            Text('650', style: context.tt.labelSmall),
            Text('750', style: context.tt.labelSmall),
            Text('900', style: context.tt.labelSmall),
          ],
        ),
      ],
    );
  }
}

/// Six months of spending, category by category.
class SummaryScreen extends StatelessWidget {
  const SummaryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final store = context.store;
    final hc = context.hc;
    final now = DateTime.now();
    final months = [for (var i = 5; i >= 0; i--) DateTime(now.year, now.month - i)];
    final totals = months.map(store.spentIn).toList();
    final maxT = totals.fold(0.0, (a, b) => a > b ? a : b);
    final cats = store.spendByCategory(now).entries.toList()..sort((a, b) => b.value.compareTo(a.value));
    final monthTotal = store.spentIn(now);

    return Scaffold(
      appBar: AppBar(title: const Text('Monthly summary')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 32),
        children: [
          Paper(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Spending, last 6 months', style: context.tt.titleSmall),
                const SizedBox(height: 14),
                SizedBox(
                  height: 150,
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      for (var i = 0; i < months.length; i++)
                        Expanded(
                          child: Semantics(
                            label: '${monthName(months[i])}: ${inr(totals[i])}',
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.end,
                              children: [
                                Text(store.moneyShort(totals[i]), style: context.tt.labelSmall),
                                const SizedBox(height: 4),
                                Container(
                                  height: maxT == 0 ? 2 : (totals[i] / maxT * 100).clamp(2, 100).toDouble(),
                                  margin: const EdgeInsets.symmetric(horizontal: 6),
                                  decoration: BoxDecoration(
                                    color: i == months.length - 1 ? hc.green : hc.green.withValues(alpha: 0.35),
                                    borderRadius: const BorderRadius.vertical(top: Radius.circular(4)),
                                  ),
                                ),
                                const SizedBox(height: 6),
                                Text(monthShort(months[i]), style: context.tt.labelSmall),
                              ],
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          Section('${monthName(now)} by category'),
          if (cats.isEmpty)
            Text('Nothing spent yet this month.', style: context.tt.bodyMedium)
          else
            Paper(
              padding: EdgeInsets.zero,
              child: Column(
                children: [
                  for (var i = 0; i < cats.length; i++) ...[
                    if (i > 0) const Divider(indent: 64),
                    ListTile(
                      leading: CategoryDot(categoryById(cats[i].key)),
                      title: Text(categoryById(cats[i].key).name, style: context.tt.titleSmall),
                      subtitle: Text('${(cats[i].value / monthTotal * 100).round()}% of spending'),
                      trailing: Text(store.money(cats[i].value), style: context.tt.titleSmall),
                    ),
                  ],
                ],
              ),
            ),
        ],
      ),
    );
  }
}
