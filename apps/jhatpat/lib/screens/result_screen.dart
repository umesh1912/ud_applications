import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../data.dart';
import '../store.dart';
import '../theme.dart';
import '../widgets.dart';
import 'pay_screen.dart';

/// Receipt after paying (also used from History).
class ResultScreen extends StatelessWidget {
  const ResultScreen({super.key, required this.paymentId});

  final String paymentId;

  @override
  Widget build(BuildContext context) {
    final store = context.store;
    final jc = context.jc;
    final p = store.payments.firstWhere((x) => x.id == paymentId);
    final ok = p.status == PayStatus.success;
    final card = ok &&
            store.scratchCards.isNotEmpty &&
            store.scratchCards.first.from == '${p.kind.label} · ${p.biller}' &&
            DateTime.now().difference(p.date).inMinutes < 5
        ? store.scratchCards.first
        : null;
    final prize = card == null
        ? null
        : Container(
            width: 220,
            height: 220,
            decoration: BoxDecoration(color: jc.mintSoft, borderRadius: BorderRadius.circular(18)),
            alignment: Alignment.center,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('You won', style: context.tt.titleMedium),
                Text('₹${card.amount}', style: price(context, 44, color: jc.mint)),
                Text(card.scratched ? 'added to your wallet' : 'in wallet cashback', style: context.tt.bodySmall),
              ],
            ),
          );

    return Scaffold(
      appBar: AppBar(title: Text(ok ? 'Paid' : (p.status == PayStatus.refunded ? 'Refunded' : 'Payment failed'))),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 4, 20, 32),
        children: [
          Receipt(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Center(
                  child: Container(
                    width: 64,
                    height: 64,
                    decoration: BoxDecoration(color: ok ? jc.mintSoft : jc.danger.withValues(alpha: 0.12), shape: BoxShape.circle),
                    child: Icon(ok ? Icons.check_rounded : Icons.close_rounded, size: 36, color: ok ? jc.mint : jc.danger),
                  ),
                ),
                const SizedBox(height: 12),
                Text(inr(p.amount), textAlign: TextAlign.center, style: price(context, 36)),
                const SizedBox(height: 4),
                Text(
                  ok
                      ? '${p.kind.label} for ${p.nickname ?? p.accountId} is done'
                      : p.status == PayStatus.refunded
                          ? 'The money is on its way back to you'
                          : 'Your bank declined or timed out. If money was taken, it comes back automatically.',
                  textAlign: TextAlign.center,
                  style: context.tt.bodyMedium,
                ),
                const SizedBox(height: 16),
                const Divider(),
                const SizedBox(height: 8),
                KV('To', p.biller),
                KV(p.kind.idLabel, p.accountId),
                if (p.planText != null) KV('Plan', p.planText!),
                KV('Paid with', p.method),
                KV('When', dMonTime(p.date)),
                KV('Reference', p.reference),
                if (p.cashback > 0) KV('Cashback to wallet', '+${inr(p.cashback)}', color: jc.mint, strong: true),
                if (p.complaintId != null) KV('Complaint', p.complaintId!),
              ],
            ),
          ),
          if (!ok) ...[
            const Section('Refund'),
            Paper(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _RefundStep('Payment failed', dMonTime(p.date), true),
                  _RefundStep('Refund started', 'Automatically', true),
                  _RefundStep('Back in your account', p.status == PayStatus.refunded ? 'Done' : 'Within 3–5 working days', p.status == PayStatus.refunded),
                  if (p.status == PayStatus.failed) ...[
                    const SizedBox(height: 8),
                    Text('Demo: tap below to see a completed refund.', style: context.tt.bodySmall),
                    TextButton(onPressed: () => store.markRefunded(p), child: const Text('Mark refund as received')),
                  ],
                ],
              ),
            ),
          ],
          if (card != null) ...[
            Section(card.scratched ? 'Scratch card' : 'You won a scratch card'),
            Center(
              child: card.scratched
                  ? prize!
                  : ScratchArea(
                      onRevealed: () {
                        store.scratch(card);
                        toast(context, '₹${card.amount} added to your Jhatpat wallet');
                      },
                      child: prize!,
                    ),
            ),
          ],
          const SizedBox(height: 20),
          if (!ok)
            FilledButton(
              onPressed: () => Navigator.of(context).pushReplacement(MaterialPageRoute(
                builder: (_) => PayScreen(kind: p.kind, saved: store.findSaved(p.kind, p.accountId), prefillNumber: p.accountId),
              )),
              child: const Text('Try again'),
            )
          else
            FilledButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Done')),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () {
                    Clipboard.setData(ClipboardData(
                      text: 'Jhatpat receipt\n${p.kind.label}: ${p.biller}\n${p.kind.idLabel}: ${p.accountId}\n'
                          'Amount: ${inr(p.amount)}\nStatus: ${p.status.name}\nRef: ${p.reference}\n${dMonTime(p.date)}',
                    ));
                    toast(context, 'Receipt copied');
                  },
                  icon: const Icon(Icons.copy, size: 18),
                  label: const Text('Copy receipt'),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => _complain(context, p),
                  icon: const Icon(Icons.support_agent, size: 18),
                  label: const Text('Get help'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _complain(BuildContext context, Payment p) {
    final store = StoreScope.read(context);
    showModalBottomSheet<void>(
      context: context,
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text('Something wrong?', style: ctx.tt.headlineSmall),
              const SizedBox(height: 8),
              Text(
                'Bill payments go through BBPS (Bharat Bill Payment System). A complaint there is tracked by the biller and your bank, '
                'with a fixed time to resolve it.',
                style: ctx.tt.bodyMedium,
              ),
              const SizedBox(height: 14),
              if (p.complaintId != null)
                Text('Complaint ${p.complaintId} is open. We\'ll update you here.', style: ctx.tt.titleSmall)
              else
                FilledButton(
                  onPressed: () {
                    final id = store.raiseComplaint(p);
                    Navigator.pop(ctx);
                    toast(context, 'Complaint $id raised. Keep this number for follow-up.');
                  },
                  child: const Text('Raise a BBPS complaint'),
                ),
              const SizedBox(height: 8),
              OutlinedButton(
                onPressed: () {
                  Navigator.pop(ctx);
                  toast(context, 'Chat support opens here in the full app.');
                },
                child: const Text('Chat with support'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _RefundStep extends StatelessWidget {
  const _RefundStep(this.title, this.sub, this.done);

  final String title;
  final String sub;
  final bool done;

  @override
  Widget build(BuildContext context) {
    final jc = context.jc;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Icon(done ? Icons.check_circle : Icons.radio_button_unchecked, color: done ? jc.mint : jc.muted),
          const SizedBox(width: 10),
          Expanded(child: Text(title, style: context.tt.titleSmall)),
          Text(sub, style: context.tt.bodySmall),
        ],
      ),
    );
  }
}
