import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../data.dart';
import '../store.dart';
import '../theme.dart';
import '../widgets.dart';
import 'onboarding.dart';
import 'send_flow.dart';
import 'wallet_screen.dart';

class AccountScreen extends StatelessWidget {
  const AccountScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final store = context.store;
    final pc = context.pc;
    void open(Widget w) => Navigator.of(context).push(MaterialPageRoute(builder: (_) => w));

    return SafeArea(
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
        children: [
          Text('Account', style: context.tt.displaySmall),
          const SizedBox(height: 12),
          Paper(
            onTap: store.kyc == KycState.verified ? null : () => open(const KycScreen()),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(store.name.isEmpty ? 'Not verified yet' : store.name, style: context.tt.titleLarge),
                      Text('+91 ${store.phone}${store.pan.isEmpty ? '' : ' · PAN ${store.pan.substring(0, 2)}•••••${store.pan.substring(7)}'}',
                          style: context.tt.bodySmall),
                    ],
                  ),
                ),
                Postmark(
                  label: switch (store.kyc) {
                    KycState.verified => 'KYC done',
                    KycState.inReview => 'In review',
                    KycState.notStarted => 'No KYC',
                  },
                  color: store.kyc == KycState.verified ? pc.ok : pc.warn,
                  size: 64,
                ),
              ],
            ),
          ),
          const Section('Money'),
          Paper(
            padding: EdgeInsets.zero,
            child: Column(
              children: [
                _Link(Icons.call_received, 'Receive money from abroad', 'Your account details for USD, GBP and EUR', () => open(const ReceiveScreen())),
                const Divider(indent: 56),
                _Link(Icons.account_balance_wallet_outlined, 'Wallet and travel card', 'Hold and convert 12 currencies', () => open(const WalletScreen())),
                const Divider(indent: 56),
                _Link(Icons.people_outline, 'Recipients', '${store.recipients.length} saved', () => open(const RecipientsScreen())),
                const Divider(indent: 56),
                _Link(Icons.event_repeat, 'Monthly reminders', '${store.recurring.length} set up', () => open(const RecipientsScreen())),
              ],
            ),
          ),
          const Section('Limits and tax'),
          Paper(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text('LRS limit this financial year', style: context.tt.titleSmall),
                const SizedBox(height: 6),
                LinearProgressIndicator(value: (store.fySentUsd / Store.lrsUsd).clamp(0.0, 1.0), minHeight: 8, borderRadius: BorderRadius.circular(4)),
                const SizedBox(height: 4),
                Text('About USD ${store.fySentUsd.round()} of USD 2,50,000 used', style: context.tt.bodySmall),
                const SizedBox(height: 14),
                Line('Sent since 1 April', inr(store.fySentInr)),
                Line('TCS-free amount left', inr((Store.tcsThreshold - store.fySentInr).clamp(0, Store.tcsThreshold)),
                    hint: 'TCS applies above ₹10 lakh a year (rate depends on purpose)'),
                Line('TCS collected so far', inr(store.fyTcsPaid), hint: 'Shows in your Form 26AS; claim it when you file'),
                const SizedBox(height: 8),
                OutlinedButton.icon(
                  onPressed: () => showDialog<void>(
                    context: context,
                    builder: (ctx) => AlertDialog(
                      title: const Text('Tax documents'),
                      content: const Text(
                        'For each quarter with TCS you get a Form 27D certificate. Every transfer also has a receipt with its '
                        'Form A2 declaration and reference number. In this demo, documents are not generated.',
                      ),
                      actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('OK'))],
                    ),
                  ),
                  icon: const Icon(Icons.description_outlined),
                  label: const Text('Tax documents'),
                ),
              ],
            ),
          ),
          const Section('Security'),
          Paper(
            padding: EdgeInsets.zero,
            child: Column(
              children: [
                _Link(Icons.pin_outlined, 'Change transaction PIN', 'Asked before every transfer', () => _changePin(context)),
                const Divider(indent: 56),
                _Link(Icons.speed, 'Per-transfer limit', inr(store.perTransferLimit), () => _setLimit(context)),
                const Divider(indent: 56),
                _Link(Icons.phonelink_lock, 'This phone is your trusted device', 'Signing in elsewhere needs an SMS code', null),
              ],
            ),
          ),
          const Section('Help and safety'),
          Paper(
            padding: EdgeInsets.zero,
            child: Column(
              children: [
                for (final (q, a) in const [
                  ('How long does a transfer take?', 'Usually 1–2 working days, depending on the receiving bank and country.'),
                  ('Why is there GST?', 'The law charges GST on the value of currency conversion. It\'s small and shown before you pay.'),
                  ('What is TCS?', 'Tax collected at source on transfers above ₹10 lakh a year. It isn\'t an extra cost: you can claim it back or adjust it against your income tax.'),
                  ('What if I sent it to the wrong account?', 'Cancel it from the transfer page before it\'s converted. After that, raise a ticket and we\'ll try to recall it.'),
                  ('How do I spot a scam?', 'Be wary of anyone you\'ve only met online asking for money, "customs fees", or investments with guaranteed returns. Pul will never ask for your PIN.'),
                ]) ...[
                  ExpansionTile(
                    title: Text(q, style: context.tt.titleSmall),
                    childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
                    expandedAlignment: Alignment.centerLeft,
                    children: [Text(a, style: context.tt.bodyMedium)],
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 16),
          OutlinedButton(
            onPressed: () => store.signOut(),
            child: const Text('Sign out'),
          ),
          const SizedBox(height: 16),
          const DemoNote(),
        ],
      ),
    );
  }

  Future<void> _changePin(BuildContext context) async {
    final store = StoreScope.read(context);
    if (store.txnPin != null && !await askPin(context)) return;
    if (!context.mounted) return;
    final ctrl = TextEditingController();
    final pin = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('New transaction PIN'),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          obscureText: true,
          keyboardType: TextInputType.number,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly, LengthLimitingTextInputFormatter(4)],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          TextButton(onPressed: () => Navigator.pop(ctx, ctrl.text), child: const Text('Save')),
        ],
      ),
    );
    if (pin != null && pin.length == 4) {
      store.setTxnPin(pin);
      if (context.mounted) toast(context, 'PIN changed');
    } else if (pin != null && context.mounted) {
      toast(context, 'PIN not changed: use exactly 4 digits.');
    }
  }

  Future<void> _setLimit(BuildContext context) async {
    final store = StoreScope.read(context);
    final v = await showDialog<double>(
      context: context,
      builder: (ctx) => SimpleDialog(
        title: const Text('Largest single transfer'),
        children: [
          for (final l in const [100000.0, 250000.0, 500000.0, 1000000.0, 2500000.0])
            SimpleDialogOption(onPressed: () => Navigator.pop(ctx, l), child: Text(inr(l))),
        ],
      ),
    );
    if (v != null) {
      store.perTransferLimit = v;
      store.changed();
    }
  }
}

class _Link extends StatelessWidget {
  const _Link(this.icon, this.title, this.sub, this.onTap);

  final IconData icon;
  final String title;
  final String sub;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Icon(icon),
      title: Text(title, style: context.tt.titleSmall),
      subtitle: Text(sub, style: context.tt.bodySmall),
      trailing: onTap == null ? null : const Icon(Icons.chevron_right),
      onTap: onTap,
    );
  }
}

/// Details people abroad can use to pay you.
class ReceiveScreen extends StatelessWidget {
  const ReceiveScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final store = context.store;
    final pc = context.pc;
    final details = [
      ('USD', [('Account holder', store.name.isEmpty ? 'Your name' : store.name), ('Account number', '8401 2275 3390 (demo)'), ('ACH routing', '026 073 150 (demo)'), ('Account type', 'Checking')]),
      ('GBP', [('Account holder', store.name.isEmpty ? 'Your name' : store.name), ('Sort code', '23-14-70 (demo)'), ('Account number', '4418 2209 (demo)')]),
      ('EUR', [('Account holder', store.name.isEmpty ? 'Your name' : store.name), ('IBAN', 'BE12 9670 4418 2209 (demo)'), ('BIC', 'PULXBEB1 (demo)')]),
    ];
    return Scaffold(
      appBar: AppBar(title: const Text('Receive money')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 32),
        children: [
          Text('Share these with clients or family abroad. Money arrives in your wallet and you can move it to your Indian bank.',
              style: context.tt.bodyMedium),
          const SizedBox(height: 12),
          for (final (code, rows) in details) ...[
            Airmail(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      Flag(code),
                      const SizedBox(width: 8),
                      Expanded(child: Text('Your $code details', style: context.tt.titleLarge)),
                      IconButton(
                        tooltip: 'Copy all',
                        onPressed: () {
                          Clipboard.setData(ClipboardData(text: rows.map((r) => '${r.$1}: ${r.$2}').join('\n')));
                          toast(context, '$code details copied');
                        },
                        icon: const Icon(Icons.copy),
                      ),
                    ],
                  ),
                  for (final (k, v) in rows) Line(k, v),
                ],
              ),
            ),
            const SizedBox(height: 12),
          ],
          Text('Freelancer? Ask the payer to mention the service (for example "software development") so the right RBI purpose code is used. '
              'We issue a FIRA (foreign inward remittance advice) for every payment.',
              style: context.tt.bodySmall),
          const Section('Received'),
          Paper(
            padding: EdgeInsets.zero,
            child: Column(
              children: [
                for (var i = 0; i < store.incoming.length; i++) ...[
                  if (i > 0) const Divider(indent: 64),
                  ListTile(
                    leading: Flag(store.incoming[i].currency),
                    title: Text(store.incoming[i].from, style: context.tt.titleSmall),
                    subtitle: Text('${shortDate(store.incoming[i].date)} · ${store.incoming[i].purpose}', style: context.tt.bodySmall),
                    trailing: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text('+${fx(store.incoming[i].amount, store.incoming[i].currency)}',
                            style: context.tt.titleSmall!.copyWith(color: pc.ok, fontFeatures: tabular)),
                        Text(inr(store.incoming[i].inr), style: context.tt.bodySmall),
                      ],
                    ),
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

class RecipientsScreen extends StatelessWidget {
  const RecipientsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final store = context.store;
    final pc = context.pc;
    return Scaffold(
      appBar: AppBar(title: const Text('Recipients')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => showForm(context, const RecipientSheet()),
        icon: const Icon(Icons.person_add_alt_1),
        label: const Text('Add'),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 100),
        children: [
          if (store.recipients.isEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 32),
              child: Text('Save the people and institutions you pay abroad to send faster next time.',
                  style: context.tt.bodyMedium!.copyWith(color: pc.muted)),
            ),
          for (final r in store.recipients)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Paper(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flag(r.currency),
                        const SizedBox(width: 10),
                        Expanded(child: Text(r.name, style: context.tt.titleMedium)),
                        PopupMenuButton<String>(
                          tooltip: 'More',
                          onSelected: (v) async {
                            if (v == 'delete') store.removeRecipient(r);
                            if (v == 'monthly') {
                              final day = DateTime.now().day.clamp(1, 28);
                              store.addRecurring(Recurring(id: store.newId(), recipientId: r.id, sendInr: 25000, day: day, purpose: Purpose.family));
                              toast(context, 'Monthly reminder on day $day for ₹25,000. Send from Home when it\'s due.');
                            }
                          },
                          itemBuilder: (_) => [
                            if (!store.recurring.any((x) => x.recipientId == r.id))
                              const PopupMenuItem(value: 'monthly', child: Text('Remind me monthly')),
                            const PopupMenuItem(value: 'delete', child: Text('Delete recipient')),
                          ],
                        ),
                      ],
                    ),
                    Text('${r.bank} · ${r.masked} · SWIFT ${r.swift}', style: context.tt.bodySmall),
                    Text(r.relation, style: context.tt.bodySmall),
                    for (final rec in store.recurring.where((x) => x.recipientId == r.id))
                      Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: Row(
                          children: [
                            Icon(Icons.event_repeat, size: 18, color: pc.blue),
                            const SizedBox(width: 6),
                            Expanded(
                              child: Text('${inr(rec.sendInr)} monthly · next ${shortDate(rec.nextDue)}', style: context.tt.bodyMedium),
                            ),
                            TextButton(onPressed: () => store.removeRecurring(rec), child: const Text('Stop')),
                          ],
                        ),
                      ),
                    const SizedBox(height: 8),
                    FilledButton.tonal(
                      onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => SendFlow(recipientId: r.id))),
                      child: Text('Send to ${r.name.split(' ').first}'),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}
