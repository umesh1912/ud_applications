import 'package:flutter/material.dart';

import '../data.dart';
import '../store.dart';
import '../theme.dart';
import '../widgets.dart';
import 'onboarding.dart';
import 'send_flow.dart';
import 'transfer_screen.dart';
import 'wallet_screen.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key, required this.openTab});

  final ValueChanged<int> openTab;

  @override
  Widget build(BuildContext context) {
    final store = context.store;
    final pc = context.pc;
    final due = store.recurring.where((r) => r.dueNow).toList();
    final recent = store.transfers.take(3).toList();
    final first = store.name.isEmpty ? '' : ', ${store.name.split(' ').first}';

    void open(Widget w) => Navigator.of(context).push(MaterialPageRoute(builder: (_) => w));

    return SafeArea(
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
        children: [
          Text('Namaste$first', style: context.tt.displaySmall),
          const SizedBox(height: 12),
          if (store.kyc != KycState.verified || store.txnPin == null) ...[
            Paper(
              onTap: () => open(const KycScreen()),
              child: Row(
                children: [
                  Icon(Icons.badge_outlined, color: pc.warn),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(store.kyc == KycState.inReview ? 'KYC in review' : 'Finish KYC to send money', style: context.tt.titleSmall),
                        Text('PAN + video KYC, about 3 minutes', style: context.tt.bodySmall),
                      ],
                    ),
                  ),
                  const Icon(Icons.chevron_right),
                ],
              ),
            ),
            const SizedBox(height: 12),
          ],
          for (final a in store.freshAlerts)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Paper(
                onTap: () {
                  store.clearFreshAlerts();
                  openTab(2);
                },
                child: Row(
                  children: [
                    Icon(Icons.notifications_active_outlined, color: pc.ok),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        '${a.currency} hit your target: ${rateText(store.rate(a.currency), a.currency)}',
                        style: context.tt.titleSmall,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          for (final r in due)
            if (store.recipientById(r.recipientId) != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Paper(
                  onTap: () => open(SendFlow(recipientId: r.recipientId, amountInr: r.sendInr, purpose: r.purpose)),
                  child: Row(
                    children: [
                      Icon(Icons.event_repeat, color: pc.blue),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text('Monthly transfer to ${store.recipientById(r.recipientId)!.name} is due (${inr(r.sendInr)})',
                            style: context.tt.titleSmall),
                      ),
                      Text('Send', style: context.tt.labelLarge!.copyWith(color: pc.blue)),
                    ],
                  ),
                ),
              ),

          // The airmail envelope: the main job, one tap away.
          Airmail(
            padding: const EdgeInsets.fromLTRB(18, 18, 18, 14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text('Send money abroad', style: context.tt.headlineMedium),
                const SizedBox(height: 4),
                Text('To 12 currencies. Fee, GST and tax shown before you pay.', style: context.tt.bodyMedium),
                const SizedBox(height: 14),
                FilledButton.icon(
                  onPressed: () => open(const SendFlow()),
                  icon: const Icon(Icons.flight_takeoff),
                  label: const Text('Start a transfer'),
                ),
              ],
            ),
          ),

          Section('Today\'s rates', action: 'All rates', onAction: () => openTab(2)),
          SizedBox(
            height: 86,
            child: ListView(
              scrollDirection: Axis.horizontal,
              children: [
                for (final c in currencies.take(6)) ...[
                  _RateChip(code: c.code),
                  const SizedBox(width: 10),
                ],
              ],
            ),
          ),

          Section('Wallet', action: 'Open', onAction: () => open(const WalletScreen())),
          Paper(
            onTap: () => open(const WalletScreen()),
            child: Column(
              children: [
                for (final e in store.wallet.entries.where((e) => e.value > 0 || e.key == 'INR'))
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: Row(
                      children: [
                        Flag(e.key, size: 22),
                        const SizedBox(width: 10),
                        Expanded(child: Text(e.key == 'INR' ? 'Indian rupee' : currencyByCode(e.key).name, style: context.tt.bodyMedium)),
                        Text(e.key == 'INR' ? inr(e.value) : fx(e.value, e.key), style: context.tt.titleSmall!.copyWith(fontFeatures: tabular)),
                      ],
                    ),
                  ),
              ],
            ),
          ),

          Section('Recent', action: recent.isEmpty ? null : 'All', onAction: () => openTab(1)),
          if (recent.isEmpty)
            Text('Your transfers will show here with live tracking.', style: context.tt.bodyMedium!.copyWith(color: pc.muted))
          else
            Paper(
              padding: EdgeInsets.zero,
              child: Column(
                children: [
                  for (var i = 0; i < recent.length; i++) ...[
                    if (i > 0) const Divider(indent: 64),
                    TransferTile(t: recent[i]),
                  ],
                ],
              ),
            ),
          const SizedBox(height: 16),
          const DemoNote(),
        ],
      ),
    );
  }
}

class _RateChip extends StatelessWidget {
  const _RateChip({required this.code});

  final String code;

  @override
  Widget build(BuildContext context) {
    final store = context.store;
    final pc = context.pc;
    final ch = store.change(code);
    return Container(
      width: 132,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: pc.card, borderRadius: BorderRadius.circular(12), border: Border.all(color: pc.rule)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Flag(code, size: 18),
              const SizedBox(width: 6),
              Text(code, style: context.tt.labelMedium),
              const Spacer(),
              Icon(ch > 0 ? Icons.arrow_upward : (ch < 0 ? Icons.arrow_downward : Icons.remove),
                  size: 14, color: ch > 0 ? pc.red : (ch < 0 ? pc.ok : pc.muted)),
            ],
          ),
          const Spacer(),
          Text('₹${store.rate(code).toStringAsFixed(store.rate(code) < 5 ? 4 : 2)}',
              style: context.tt.titleLarge!.copyWith(fontFeatures: tabular)),
        ],
      ),
    );
  }
}

class TransferTile extends StatelessWidget {
  const TransferTile({super.key, required this.t});

  final Transfer t;

  @override
  Widget build(BuildContext context) {
    final color = statusColor(context, t);
    return ListTile(
      onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => TransferScreen(transferId: t.id))),
      leading: Flag(t.currency),
      title: Text(t.recipientName, style: context.tt.titleSmall),
      subtitle: Text('${shortDate(t.createdAt)} · ${inr(t.total)}', style: context.tt.bodySmall),
      trailing: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Text(fx(t.receive, t.currency), style: context.tt.titleSmall!.copyWith(fontFeatures: tabular)),
          Text(statusLabel(t), style: context.tt.labelSmall!.copyWith(color: color)),
        ],
      ),
    );
  }
}
