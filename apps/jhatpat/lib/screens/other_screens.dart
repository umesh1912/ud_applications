import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../data.dart';
import '../store.dart';
import '../theme.dart';
import '../widgets.dart';
import 'result_screen.dart';

// ── History ──────────────────────────────────────────────────────────

class HistoryScreen extends StatefulWidget {
  const HistoryScreen({super.key});

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  String _filter = 'All';

  @override
  Widget build(BuildContext context) {
    final store = context.store;
    final jc = context.jc;
    final list = store.payments.where((p) => switch (_filter) {
          'Recharges' => p.kind.plans || p.kind == Kind.fastag,
          'Bills' => !p.kind.plans && p.kind != Kind.fastag,
          'Failed' => p.status != PayStatus.success,
          _ => true,
        }).toList();
    final now = DateTime.now();
    final monthTotal = store.payments
        .where((p) => p.status == PayStatus.success && p.date.year == now.year && p.date.month == now.month)
        .fold(0.0, (s, p) => s + p.amount);

    return SafeArea(
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 14, 20, 32),
        children: [
          Text('History', style: context.tt.displaySmall),
          const SizedBox(height: 4),
          Text('${inr(monthTotal)} paid this month · ${inr(store.totalCashback)} cashback so far', style: context.tt.bodySmall),
          const SizedBox(height: 12),
          Wrap(
            spacing: 6,
            children: [
              for (final f in const ['All', 'Recharges', 'Bills', 'Failed'])
                ChoiceChip(label: Text(f), selected: _filter == f, onSelected: (_) => setState(() => _filter = f)),
            ],
          ),
          const SizedBox(height: 12),
          if (list.isEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 40),
              child: Column(
                children: [
                  Icon(Icons.receipt_long_outlined, size: 44, color: jc.muted),
                  const SizedBox(height: 8),
                  Text(_filter == 'Failed' ? 'No failed payments' : 'No payments yet', style: context.tt.titleMedium),
                  Text('Receipts for every recharge and bill appear here.', style: context.tt.bodySmall),
                ],
              ),
            )
          else
            Paper(
              padding: EdgeInsets.zero,
              child: Column(
                children: [
                  for (var i = 0; i < list.length; i++) ...[
                    if (i > 0) const Divider(indent: 72),
                    ListTile(
                      onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => ResultScreen(paymentId: list[i].id))),
                      leading: KindIcon(list[i].kind, size: 40),
                      title: Text(list[i].nickname ?? list[i].biller, style: context.tt.titleSmall),
                      subtitle: Text('${list[i].biller} · ${dMonTime(list[i].date)}', style: context.tt.bodySmall, maxLines: 1, overflow: TextOverflow.ellipsis),
                      trailing: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(inr(list[i].amount), style: context.tt.titleSmall!.copyWith(fontFeatures: tabular)),
                          Text(
                            switch (list[i].status) {
                              PayStatus.success => list[i].cashback > 0 ? '+${inr(list[i].cashback)} back' : 'Paid',
                              PayStatus.failed => 'Failed · refund on the way',
                              PayStatus.refunded => 'Refunded',
                            },
                            style: context.tt.labelSmall!.copyWith(
                              color: list[i].status == PayStatus.success ? jc.mint : jc.danger,
                            ),
                          ),
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

// ── Rewards ──────────────────────────────────────────────────────────

class RewardsScreen extends StatelessWidget {
  const RewardsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final store = context.store;
    final jc = context.jc;
    final unscratched = store.scratchCards.where((c) => !c.scratched).toList();
    final scratched = store.scratchCards.where((c) => c.scratched).toList();

    return SafeArea(
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 14, 20, 32),
        children: [
          Text('Rewards', style: context.tt.displaySmall),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: Ticket(
                  color: jc.mintSoft,
                  top: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Wallet', style: context.tt.labelMedium),
                      FittedBox(alignment: Alignment.centerLeft, fit: BoxFit.scaleDown, child: Text(inr(store.walletBalance), style: price(context, 24))),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Ticket(
                  color: jc.saffronSoft,
                  top: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Points', style: context.tt.labelMedium),
                      Text('${store.points}', style: price(context, 24)),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              Expanded(child: Text('1 point for every ₹100 paid. 10 points = ₹1 in your wallet.', style: context.tt.bodySmall)),
              TextButton(
                onPressed: store.points >= 10
                    ? () {
                        final r = store.points ~/ 10;
                        store.redeemPoints();
                        toast(context, '₹$r added to your wallet');
                      }
                    : null,
                child: const Text('Redeem'),
              ),
            ],
          ),
          Section(unscratched.isEmpty ? 'Scratch cards' : '${unscratched.length} to scratch'),
          if (store.scratchCards.isEmpty)
            Text('Pay a bill or recharge of ₹99 or more to win a scratch card.', style: context.tt.bodyMedium)
          else
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                for (final c in [...unscratched, ...scratched])
                  SizedBox(
                    width: 150,
                    height: 150,
                    child: c.scratched
                        ? Container(
                            decoration: BoxDecoration(color: jc.card, borderRadius: BorderRadius.circular(18), border: Border.all(color: jc.rule)),
                            alignment: Alignment.center,
                            padding: const EdgeInsets.all(10),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text('₹${c.amount}', style: price(context, 28, color: jc.mint)),
                                const SizedBox(height: 4),
                                Text(c.from, textAlign: TextAlign.center, maxLines: 2, style: context.tt.bodySmall),
                              ],
                            ),
                          )
                        : ScratchArea(
                            size: 150,
                            onRevealed: () {
                              store.scratch(c);
                              toast(context, '₹${c.amount} added to your wallet');
                            },
                            child: Container(
                              color: jc.mintSoft,
                              alignment: Alignment.center,
                              child: Text('₹${c.amount}', style: price(context, 30, color: jc.mint)),
                            ),
                          ),
                  ),
              ],
            ),
          const Section('Coupon codes'),
          for (final o in offers)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Ticket(
                top: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(o.title, style: context.tt.titleSmall),
                    Text(o.detail, style: context.tt.bodySmall),
                  ],
                ),
                bottom: Row(
                  children: [
                    Expanded(child: Text(o.code, style: context.tt.labelLarge!.copyWith(letterSpacing: 1.5))),
                    if (o.code == 'FIRST50' && store.usedCodes.contains('FIRST50'))
                      Text('Used', style: context.tt.labelSmall)
                    else
                      TextButton.icon(
                        onPressed: () {
                          Clipboard.setData(ClipboardData(text: o.code));
                          toast(context, '${o.code} copied. Paste it at checkout.');
                        },
                        icon: const Icon(Icons.copy, size: 16),
                        label: const Text('Copy'),
                      ),
                  ],
                ),
              ),
            ),
          const Section('Invite friends'),
          Ticket(
            color: jc.saffronSoft,
            top: Text('You both get ₹25 when a friend pays their first bill with your code.', style: context.tt.bodyMedium),
            bottom: Row(
              children: [
                Expanded(child: Text(store.referralCode, style: price(context, 20))),
                TextButton.icon(
                  onPressed: () {
                    Clipboard.setData(ClipboardData(
                      text: 'Pay bills and recharge with Jhatpat. Use my code ${store.referralCode} and we both get ₹25.',
                    ));
                    toast(context, 'Invite message copied. Paste it in WhatsApp.');
                  },
                  icon: const Icon(Icons.copy, size: 16),
                  label: const Text('Copy invite'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ── Account ──────────────────────────────────────────────────────────

class AccountScreen extends StatelessWidget {
  const AccountScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final store = context.store;
    final jc = context.jc;
    return SafeArea(
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 14, 20, 32),
        children: [
          Text('Account', style: context.tt.displaySmall),
          const SizedBox(height: 6),
          Text('${store.name} · +91 ${store.phone}', style: context.tt.bodyMedium),
          Section('Saved billers & family', action: null),
          if (store.saved.isEmpty)
            Text('Save numbers and accounts at checkout to pay them in one tap.', style: context.tt.bodyMedium)
          else
            for (final s in store.saved)
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Paper(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Row(
                        children: [
                          KindIcon(s.kind, size: 38),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(s.nickname, style: context.tt.titleSmall),
                                Text('${s.biller} · ${s.accountId}', style: context.tt.bodySmall, maxLines: 1, overflow: TextOverflow.ellipsis),
                              ],
                            ),
                          ),
                          PopupMenuButton<String>(
                            tooltip: 'More',
                            onSelected: (v) async {
                              if (v == 'rename') {
                                final ctrl = TextEditingController(text: s.nickname);
                                final name = await showDialog<String>(
                                  context: context,
                                  builder: (ctx) => AlertDialog(
                                    title: const Text('Nickname'),
                                    content: TextField(controller: ctrl, autofocus: true, textCapitalization: TextCapitalization.words),
                                    actions: [
                                      TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
                                      TextButton(onPressed: () => Navigator.pop(ctx, ctrl.text.trim()), child: const Text('Save')),
                                    ],
                                  ),
                                );
                                if (name != null && name.isNotEmpty) {
                                  s.nickname = name;
                                  store.changed();
                                }
                              }
                              if (v == 'delete') store.removeBiller(s);
                            },
                            itemBuilder: (_) => const [
                              PopupMenuItem(value: 'rename', child: Text('Rename')),
                              PopupMenuItem(value: 'delete', child: Text('Remove')),
                            ],
                          ),
                        ],
                      ),
                      SwitchListTile(
                        contentPadding: EdgeInsets.zero,
                        dense: true,
                        value: s.autopay,
                        onChanged: (v) {
                          s.autopay = v;
                          if (v && s.autopayMax == 0) s.autopayMax = ((s.lastAmount ?? 500) * 1.5).roundToDouble();
                          store.changed();
                        },
                        title: const Text('AutoPay'),
                        subtitle: Text(s.autopay ? 'UPI mandate up to ${inr(s.autopayMax)}' : 'Off'),
                      ),
                      SwitchListTile(
                        contentPadding: EdgeInsets.zero,
                        dense: true,
                        value: s.remind,
                        onChanged: (v) {
                          s.remind = v;
                          store.changed();
                        },
                        title: Text(s.kind.plans ? 'Remind me before the plan ends' : 'Remind me before the due date'),
                      ),
                    ],
                  ),
                ),
              ),
          Section('Payment methods', action: 'Add', onAction: () => _addMethod(context)),
          Paper(
            padding: EdgeInsets.zero,
            child: Column(
              children: [
                for (var i = 0; i < store.methods.length; i++) ...[
                  if (i > 0) const Divider(indent: 56),
                  ListTile(
                    leading: Icon(store.methods[i].icon),
                    title: Text(store.methods[i].label, style: context.tt.titleSmall),
                    subtitle: Text(
                      store.methods[i].type == PayMethodType.wallet ? 'Balance ${inr(store.walletBalance)}' : store.methods[i].detail,
                      style: context.tt.bodySmall,
                    ),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (store.defaultMethodId == store.methods[i].id)
                          Text('Default', style: context.tt.labelSmall!.copyWith(color: jc.mint))
                        else
                          TextButton(
                            onPressed: () {
                              store.defaultMethodId = store.methods[i].id;
                              store.changed();
                            },
                            child: const Text('Make default'),
                          ),
                        if (store.methods[i].type != PayMethodType.wallet)
                          IconButton(
                            tooltip: 'Remove',
                            onPressed: () => store.removeMethod(store.methods[i]),
                            icon: const Icon(Icons.delete_outline, size: 20),
                          ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
          const Section('Help'),
          Paper(
            padding: EdgeInsets.zero,
            child: Column(
              children: [
                for (final (q, a) in const [
                  ('My recharge failed but money was taken', 'It comes back automatically within 3–5 working days. Open the payment in History to track the refund or raise a complaint.'),
                  ('What is BBPS?', 'The Bharat Bill Payment System, run under NPCI. Bills paid through it get a reference number and a formal complaint process.'),
                  ('How does AutoPay work?', 'A UPI mandate lets us debit up to the limit you set when a bill is due. You get an alert 24 hours before, and can cancel any time.'),
                  ('Is my card saved safely?', 'Cards are tokenised as RBI requires; we never store the full card number.'),
                ])
                  ExpansionTile(
                    title: Text(q, style: context.tt.titleSmall),
                    childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
                    expandedAlignment: Alignment.centerLeft,
                    children: [Text(a, style: context.tt.bodyMedium)],
                  ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          OutlinedButton(onPressed: store.signOut, child: const Text('Sign out')),
          const SizedBox(height: 12),
          const DemoNote(),
        ],
      ),
    );
  }

  Future<void> _addMethod(BuildContext context) async {
    final store = StoreScope.read(context);
    var type = PayMethodType.upi;
    final ctrl = TextEditingController();
    String? error;
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setS) => Padding(
          padding: EdgeInsets.fromLTRB(20, 0, 20, MediaQuery.of(ctx).viewInsets.bottom + 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text('Add a way to pay', style: ctx.tt.headlineSmall),
              const SizedBox(height: 12),
              SegmentedButton<PayMethodType>(
                segments: const [
                  ButtonSegment(value: PayMethodType.upi, label: Text('UPI ID')),
                  ButtonSegment(value: PayMethodType.card, label: Text('Card')),
                  ButtonSegment(value: PayMethodType.netbanking, label: Text('Net banking')),
                ],
                selected: {type},
                showSelectedIcon: false,
                onSelectionChanged: (s) => setS(() {
                  type = s.first;
                  ctrl.clear();
                  error = null;
                }),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: ctrl,
                autofocus: true,
                keyboardType: type == PayMethodType.card ? TextInputType.number : TextInputType.text,
                decoration: InputDecoration(
                  labelText: switch (type) {
                    PayMethodType.upi => 'UPI ID, e.g. name@okbank',
                    PayMethodType.card => 'Card number',
                    _ => 'Bank name',
                  },
                  errorText: error,
                ),
              ),
              const SizedBox(height: 14),
              FilledButton(
                onPressed: () {
                  final v = ctrl.text.trim().replaceAll(' ', '');
                  String? e;
                  if (type == PayMethodType.upi && !RegExp(r'^[\w.\-]{2,}@[a-zA-Z]{2,}$').hasMatch(v)) {
                    e = 'A UPI ID looks like name@bank.';
                  } else if (type == PayMethodType.card && !RegExp(r'^\d{15,16}$').hasMatch(v)) {
                    e = 'Enter the 15 or 16 digits on the card.';
                  } else if (type == PayMethodType.netbanking && v.length < 3) {
                    e = 'Enter your bank\'s name.';
                  }
                  if (e != null) {
                    setS(() => error = e);
                    return;
                  }
                  store.addMethod(PayMethod(
                    store.newId(),
                    type,
                    switch (type) {
                      PayMethodType.upi => 'UPI',
                      PayMethodType.card => 'Card',
                      _ => 'Net banking',
                    },
                    switch (type) {
                      PayMethodType.card => '•••• ${v.substring(v.length - 4)} (tokenised)',
                      PayMethodType.netbanking => ctrl.text.trim(),
                      _ => v,
                    },
                  ));
                  Navigator.pop(ctx);
                },
                child: const Text('Save'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Sign in ──────────────────────────────────────────────────────────

class SignInScreen extends StatefulWidget {
  const SignInScreen({super.key});

  @override
  State<SignInScreen> createState() => _SignInScreenState();
}

class _SignInScreenState extends State<SignInScreen> {
  final _name = TextEditingController();
  final _phone = TextEditingController();
  final _otp = TextEditingController();
  bool _sent = false;
  String? _error;

  @override
  void dispose() {
    _name.dispose();
    _phone.dispose();
    _otp.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final jc = context.jc;
    return Scaffold(
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 40, 20, 24),
          children: [
            Ticket(
              color: jc.saffron,
              top: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Jhatpat', style: context.tt.displayMedium!.copyWith(color: jc.onSaffron)),
                  const SizedBox(height: 6),
                  Text('Every recharge and bill, paid in seconds.', style: context.tt.bodyLarge!.copyWith(color: jc.onSaffron)),
                ],
              ),
              bottom: Text('Mobile · DTH · Electricity · FASTag · Gas · EMIs and more',
                  style: context.tt.labelMedium!.copyWith(color: jc.onSaffron)),
            ),
            const SizedBox(height: 28),
            if (!_sent) ...[
              TextField(
                controller: _name,
                textCapitalization: TextCapitalization.words,
                decoration: const InputDecoration(labelText: 'Your name'),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _phone,
                keyboardType: TextInputType.phone,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly, LengthLimitingTextInputFormatter(10)],
                decoration: InputDecoration(labelText: 'Mobile number', prefixText: '+91  ', errorText: _error),
              ),
            ] else ...[
              Text('Enter the code sent to +91 ${_phone.text}', style: context.tt.titleMedium),
              const SizedBox(height: 4),
              Text('Demo: any 6 digits work.', style: context.tt.bodySmall),
              const SizedBox(height: 12),
              TextField(
                controller: _otp,
                autofocus: true,
                keyboardType: TextInputType.number,
                textAlign: TextAlign.center,
                style: price(context, 26),
                inputFormatters: [FilteringTextInputFormatter.digitsOnly, LengthLimitingTextInputFormatter(6)],
                decoration: InputDecoration(errorText: _error),
              ),
            ],
            const SizedBox(height: 16),
            FilledButton(
              onPressed: () {
                if (!_sent) {
                  if (_name.text.trim().isEmpty || !RegExp(r'^[6-9]\d{9}$').hasMatch(_phone.text)) {
                    setState(() => _error = 'Add your name and a valid 10-digit mobile number.');
                    return;
                  }
                  setState(() {
                    _sent = true;
                    _error = null;
                  });
                } else {
                  if (_otp.text.length != 6) {
                    setState(() => _error = 'Enter all 6 digits.');
                    return;
                  }
                  StoreScope.read(context).signIn(_name.text.trim(), _phone.text);
                }
              },
              child: Text(_sent ? 'Verify and continue' : 'Get code'),
            ),
            const SizedBox(height: 18),
            const DemoNote(),
          ],
        ),
      ),
    );
  }
}
