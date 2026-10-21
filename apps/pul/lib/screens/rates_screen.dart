import 'package:flutter/material.dart';

import '../data.dart';
import '../store.dart';
import '../theme.dart';
import '../widgets.dart';
import 'home_screen.dart';

class RatesScreen extends StatelessWidget {
  const RatesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final store = context.store;
    final pc = context.pc;
    return SafeArea(
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
        children: [
          Text('Rates', style: context.tt.displaySmall),
          const SizedBox(height: 4),
          Text('Mid-market rate, and what you get with Pul\'s ${(Store.markup * 100).toStringAsFixed(2)}% margin. Updates every few seconds.',
              style: context.tt.bodySmall),
          const SizedBox(height: 12),
          Paper(
            padding: EdgeInsets.zero,
            child: Column(
              children: [
                for (var i = 0; i < currencies.length; i++) ...[
                  if (i > 0) const Divider(indent: 64),
                  _RateRow(c: currencies[i]),
                ],
              ],
            ),
          ),
          const Section('Rate alerts'),
          if (store.alerts.isEmpty)
            Text('Tap any currency above to get told when it drops to your target.', style: context.tt.bodyMedium!.copyWith(color: pc.muted))
          else
            Paper(
              padding: EdgeInsets.zero,
              child: Column(
                children: [
                  for (var i = 0; i < store.alerts.length; i++) ...[
                    if (i > 0) const Divider(indent: 64),
                    ListTile(
                      leading: Flag(store.alerts[i].currency),
                      title: Text('${store.alerts[i].currency} at ₹${store.alerts[i].target.toStringAsFixed(2)} or less'),
                      subtitle: Text(
                        store.alerts[i].triggeredAt == null
                            ? 'Watching · now ₹${store.rate(store.alerts[i].currency).toStringAsFixed(2)}'
                            : 'Reached on ${dateTime(store.alerts[i].triggeredAt!)}',
                        style: context.tt.bodySmall!.copyWith(color: store.alerts[i].triggeredAt == null ? null : pc.ok),
                      ),
                      trailing: IconButton(
                        tooltip: 'Delete alert',
                        onPressed: () => store.removeAlert(store.alerts[i]),
                        icon: const Icon(Icons.delete_outline),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          const SizedBox(height: 16),
          const DemoNote(text: 'Demo rates: they move randomly around realistic values.'),
        ],
      ),
    );
  }
}

class _RateRow extends StatelessWidget {
  const _RateRow({required this.c});

  final Currency c;

  @override
  Widget build(BuildContext context) {
    final store = context.store;
    final pc = context.pc;
    final mid = store.rate(c.code);
    final ours = mid * (1 + Store.markup);
    final ch = store.change(c.code);
    final dp = mid < 5 ? 4 : 2;
    return ListTile(
      onTap: () => _alertSheet(context, c),
      leading: Flag(c.code),
      title: Text('${c.code} · ${c.name}', style: context.tt.titleSmall),
      subtitle: Text('You pay ₹${ours.toStringAsFixed(dp)}', style: context.tt.bodySmall),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text('₹${mid.toStringAsFixed(dp)}', style: context.tt.titleMedium!.copyWith(fontFeatures: tabular)),
          const SizedBox(width: 4),
          Icon(ch > 0 ? Icons.arrow_drop_up : (ch < 0 ? Icons.arrow_drop_down : Icons.remove),
              color: ch > 0 ? pc.red : (ch < 0 ? pc.ok : pc.muted)),
        ],
      ),
    );
  }

  void _alertSheet(BuildContext context, Currency c) {
    final store = StoreScope.read(context);
    final ctrl = TextEditingController(text: (store.rate(c.code) * 0.99).toStringAsFixed(2));
    showForm<void>(
      context,
      FormSheet(
        title: 'Alert me about ${c.code}',
        actions: [
          FilledButton(
            onPressed: () {
              final v = parseNum(ctrl.text);
              if (v == null || v <= 0) return;
              store.addAlert(c.code, v);
              Navigator.pop(context);
              toast(context, 'We\'ll tell you when 1 ${c.code} costs ₹${v.toStringAsFixed(2)} or less.');
            },
            child: const Text('Create alert'),
          ),
        ],
        children: [
          Text('Now ${rateText(store.rate(c.code), c.code)}', style: context.tt.bodyMedium),
          const SizedBox(height: 10),
          TextField(
            controller: ctrl,
            autofocus: true,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: InputDecoration(labelText: 'Tell me when 1 ${c.code} costs', prefixText: '₹ '),
          ),
        ],
      ),
    );
  }
}

/// All transfers.
class ActivityScreen extends StatelessWidget {
  const ActivityScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final store = context.store;
    final pc = context.pc;
    final inFlight = store.transfers.where((t) => !t.delivered && !t.cancelled).toList();
    final done = store.transfers.where((t) => t.delivered || t.cancelled).toList();
    return SafeArea(
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
        children: [
          Text('Activity', style: context.tt.displaySmall),
          if (store.transfers.isEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 40),
              child: Column(
                children: [
                  Icon(Icons.local_post_office_outlined, size: 48, color: pc.muted),
                  const SizedBox(height: 10),
                  Text('No transfers yet', style: context.tt.titleMedium),
                  Text('Send your first one from Home.', style: context.tt.bodySmall),
                ],
              ),
            ),
          if (inFlight.isNotEmpty) ...[
            const Section('On the way'),
            Paper(
              padding: EdgeInsets.zero,
              child: Column(children: [
                for (var i = 0; i < inFlight.length; i++) ...[
                  if (i > 0) const Divider(indent: 64),
                  TransferTile(t: inFlight[i]),
                ],
              ]),
            ),
          ],
          if (done.isNotEmpty) ...[
            const Section('Completed'),
            Paper(
              padding: EdgeInsets.zero,
              child: Column(children: [
                for (var i = 0; i < done.length; i++) ...[
                  if (i > 0) const Divider(indent: 64),
                  TransferTile(t: done[i]),
                ],
              ]),
            ),
          ],
        ],
      ),
    );
  }
}
