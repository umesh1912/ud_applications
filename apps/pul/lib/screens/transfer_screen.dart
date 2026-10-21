import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../data.dart';
import '../store.dart';
import '../theme.dart';
import '../widgets.dart';
import 'send_flow.dart';

/// One transfer: postmark status, live tracker, receipt and actions.
class TransferScreen extends StatelessWidget {
  const TransferScreen({super.key, required this.transferId, this.justSent = false});

  final String transferId;
  final bool justSent;

  @override
  Widget build(BuildContext context) {
    final store = context.store;
    final pc = context.pc;
    final t = store.transfers.firstWhere((x) => x.id == transferId);
    final to = store.recipientById(t.recipientId);
    final hasRecurring = store.recurring.any((r) => r.recipientId == t.recipientId);

    return Scaffold(
      appBar: AppBar(title: Text(justSent ? 'Sent' : 'Transfer')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 32),
        children: [
          Airmail(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(justSent ? 'On its way to' : 'To', style: context.tt.labelMedium),
                          Text(t.recipientName, style: context.tt.headlineMedium),
                          const SizedBox(height: 6),
                          Text(fx(t.receive, t.currency), style: context.tt.displaySmall!.copyWith(color: pc.blue, fontFeatures: tabular)),
                        ],
                      ),
                    ),
                    Postmark(label: statusLabel(t), color: statusColor(context, t), date: t.createdAt),
                  ],
                ),
              ],
            ),
          ),
          const Section('Tracking'),
          Paper(child: StepTimeline(transfer: t)),
          if (t.cancelled)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text('Cancelled. ${inr(t.total)} would be refunded to your bank account within 2 working days.',
                  style: context.tt.bodyMedium),
            ),
          const Section('Receipt'),
          Paper(
            child: Column(
              children: [
                Line('Amount converted', inr(t.sendInr)),
                Line('Rate', rateText(t.rate, t.currency)),
                Line('Transfer fee', inr(t.fee)),
                Line('GST', inr(t.gst)),
                Line('TCS', inr(t.tcs), hint: t.tcs > 0 ? 'Shown on Form 27D; claim it in your tax return' : null),
                const Divider(height: 18),
                Line('Total paid', inr(t.total), strong: true),
                Line('Purpose', t.purpose.label),
                Line('Created', dateTime(t.createdAt)),
                Row(
                  children: [
                    Expanded(child: Text('Reference', style: context.tt.bodyMedium)),
                    SelectableText(t.reference, style: context.tt.titleSmall!.copyWith(fontFeatures: tabular)),
                    IconButton(
                      tooltip: 'Copy reference',
                      onPressed: () {
                        Clipboard.setData(ClipboardData(text: t.reference));
                        toast(context, 'Reference copied');
                      },
                      icon: const Icon(Icons.copy, size: 18),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          if (t.canCancel)
            OutlinedButton.icon(
              onPressed: () async {
                final ok = await showDialog<bool>(
                  context: context,
                  builder: (ctx) => AlertDialog(
                    title: const Text('Cancel this transfer?'),
                    content: const Text('It hasn\'t been converted yet, so you\'ll get the full amount back.'),
                    actions: [
                      TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Keep it')),
                      TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Cancel transfer')),
                    ],
                  ),
                );
                if (ok == true) store.cancel(t);
              },
              icon: const Icon(Icons.close),
              label: const Text('Cancel transfer'),
            ),
          if (to != null) ...[
            const SizedBox(height: 8),
            FilledButton.icon(
              onPressed: () => Navigator.of(context).push(MaterialPageRoute(
                builder: (_) => SendFlow(recipientId: to.id, amountInr: t.sendInr, purpose: t.purpose),
              )),
              icon: const Icon(Icons.replay),
              label: Text('Send again to ${to.name.split(' ').first}'),
            ),
            if (!hasRecurring) ...[
              const SizedBox(height: 8),
              OutlinedButton.icon(
                onPressed: () {
                  store.addRecurring(Recurring(
                    id: store.newId(),
                    recipientId: to.id,
                    sendInr: t.sendInr,
                    day: t.createdAt.day.clamp(1, 28),
                    purpose: t.purpose,
                    lastDone: t.createdAt,
                  ));
                  toast(context, 'We\'ll remind you on day ${t.createdAt.day.clamp(1, 28)} of each month.');
                },
                icon: const Icon(Icons.event_repeat),
                label: const Text('Remind me monthly'),
              ),
            ],
          ],
          const SizedBox(height: 12),
          TextButton.icon(
            onPressed: () => showModalBottomSheet<void>(
              context: context,
              builder: (ctx) => const _HelpSheet(),
            ),
            icon: const Icon(Icons.support_agent),
            label: const Text('Problem with this transfer?'),
          ),
        ],
      ),
    );
  }
}

class _HelpSheet extends StatefulWidget {
  const _HelpSheet();

  @override
  State<_HelpSheet> createState() => _HelpSheetState();
}

class _HelpSheetState extends State<_HelpSheet> {
  String? _issue;
  bool _sent = false;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(_sent ? 'We\'ve got it' : 'What went wrong?', style: context.tt.headlineSmall),
            const SizedBox(height: 10),
            if (_sent)
              Text('A support agent will reply in the Help section within 4 working hours. Keep your reference handy.',
                  style: context.tt.bodyMedium)
            else ...[
              for (final i in const [
                'It\'s taking longer than expected',
                'The recipient says they didn\'t get it',
                'Wrong amount or details',
                'I think this is fraud',
              ])
                RadioListTile<String>(
                  contentPadding: EdgeInsets.zero,
                  value: i,
                  groupValue: _issue,
                  onChanged: (v) => setState(() => _issue = v),
                  title: Text(i),
                ),
              const SizedBox(height: 8),
              FilledButton(
                onPressed: _issue == null ? null : () => setState(() => _sent = true),
                child: const Text('Raise a ticket'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
