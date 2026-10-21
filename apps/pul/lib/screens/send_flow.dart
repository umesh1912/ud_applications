import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../data.dart';
import '../store.dart';
import '../theme.dart';
import '../widgets.dart';
import 'transfer_screen.dart';

/// Send money abroad in three steps: who → how much → review and approve.
class SendFlow extends StatefulWidget {
  const SendFlow({super.key, this.recipientId, this.amountInr, this.purpose});

  final String? recipientId;
  final double? amountInr;
  final Purpose? purpose;

  @override
  State<SendFlow> createState() => _SendFlowState();
}

class _SendFlowState extends State<SendFlow> {
  int _step = 0;
  Recipient? _to;
  late Purpose _purpose = widget.purpose ?? Purpose.family;
  final _amount = TextEditingController();
  bool _inInr = true; // amount typed in ₹ (true) or in their currency
  Quote? _locked;
  DateTime? _lockedUntil;
  Timer? _clock;
  bool _declared = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    final store = StoreScope.read(context);
    if (widget.recipientId != null) {
      _to = store.recipientById(widget.recipientId!);
      if (_to != null) _step = 1;
    }
    if (widget.amountInr != null) _amount.text = widget.amountInr!.toStringAsFixed(0);
    _clock = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      if (_lockedUntil != null && DateTime.now().isAfter(_lockedUntil!)) {
        _locked = null;
        _lockedUntil = null;
      }
      setState(() {});
    });
  }

  @override
  void dispose() {
    _clock?.cancel();
    _amount.dispose();
    super.dispose();
  }

  double? _sendInr(Store s) {
    final v = parseNum(_amount.text);
    if (v == null || v <= 0 || _to == null) return null;
    return _inInr ? v : s.inrFor(_to!.currency, v);
  }

  Quote? _quote(Store s) {
    if (_locked != null) return _locked;
    final inr = _sendInr(s);
    if (inr == null) return null;
    return s.quote(currency: _to!.currency, sendInr: inr, purpose: _purpose);
  }

  String? _validate(Store s, Quote? q) {
    if (s.kyc != KycState.verified) return 'Finish KYC before sending money.';
    if (q == null) return 'Enter how much to send.';
    if (q.sendInr < 1000) return 'The smallest transfer is ₹1,000.';
    if (q.sendInr > s.perTransferLimit) return 'That\'s above your per-transfer limit of ${inr(s.perTransferLimit)}. Change it in Account → Security.';
    final usdAfter = s.fySentUsd + q.sendInr / s.rate('USD');
    if (usdAfter > Store.lrsUsd) return 'This would cross the yearly LRS limit of USD 2,50,000.';
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final store = context.store;
    final titles = ['Who are you sending to?', 'How much?', 'Check and send'];
    return PopScope(
      canPop: _step == 0 || (widget.recipientId != null && _step == 1),
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) setState(() => _step--);
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text(titles[_step]),
          bottom: PreferredSize(
            preferredSize: const Size.fromHeight(3),
            child: LinearProgressIndicator(value: (_step + 1) / 3, minHeight: 3),
          ),
        ),
        body: SafeArea(
          child: switch (_step) {
            0 => _recipientStep(store),
            1 => _amountStep(store),
            _ => _reviewStep(store),
          },
        ),
      ),
    );
  }

  // ── Step 1: recipient ──────────────────────────────────────────
  Widget _recipientStep(Store store) {
    final pc = context.pc;
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
      children: [
        OutlinedButton.icon(
          onPressed: () async {
            final r = await showForm<Recipient>(context, const RecipientSheet());
            if (r != null) {
              setState(() {
                _to = r;
                _step = 1;
              });
            }
          },
          icon: const Icon(Icons.person_add_alt_1_outlined),
          label: const Text('Someone new'),
        ),
        if (store.recipients.isNotEmpty) ...[
          const Section('Saved'),
          Paper(
            padding: EdgeInsets.zero,
            child: Column(
              children: [
                for (var i = 0; i < store.recipients.length; i++) ...[
                  if (i > 0) const Divider(indent: 64),
                  ListTile(
                    leading: Flag(store.recipients[i].currency),
                    title: Text(store.recipients[i].name, style: context.tt.titleSmall),
                    subtitle: Text('${store.recipients[i].bank} ${store.recipients[i].masked} · ${store.recipients[i].relation}',
                        style: context.tt.bodySmall),
                    trailing: Icon(Icons.chevron_right, color: pc.muted),
                    onTap: () => setState(() {
                      _to = store.recipients[i];
                      _step = 1;
                    }),
                  ),
                ],
              ],
            ),
          ),
        ],
      ],
    );
  }

  // ── Step 2: amount & purpose ───────────────────────────────────
  Widget _amountStep(Store store) {
    final pc = context.pc;
    final to = _to!;
    final cur = currencyByCode(to.currency);
    final q = _quote(store);
    final remaining = _lockedUntil?.difference(DateTime.now());

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
      children: [
        Row(
          children: [
            Flag(to.currency, size: 30),
            const SizedBox(width: 10),
            Expanded(child: Text('${to.name} · ${cur.name}', style: context.tt.titleMedium)),
            TextButton(onPressed: () => setState(() => _step = 0), child: const Text('Change')),
          ],
        ),
        const SizedBox(height: 10),
        SegmentedButton<bool>(
          segments: [
            const ButtonSegment(value: true, label: Text('I send ₹')),
            ButtonSegment(value: false, label: Text('They get ${to.currency}')),
          ],
          selected: {_inInr},
          showSelectedIcon: false,
          onSelectionChanged: _locked != null
              ? null
              : (s) => setState(() {
                    _inInr = s.first;
                    _amount.clear();
                  }),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _amount,
          enabled: _locked == null,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]'))],
          style: context.tt.displaySmall!.copyWith(fontFeatures: tabular),
          onChanged: (_) => setState(() => _error = null),
          decoration: InputDecoration(
            prefixText: _inInr ? '₹ ' : null,
            suffixText: _inInr ? null : to.currency,
            hintText: '0',
          ),
        ),
        const SizedBox(height: 14),
        Text('Purpose', style: context.tt.titleSmall),
        const SizedBox(height: 6),
        Wrap(
          spacing: 6,
          runSpacing: 6,
          children: [
            for (final p in Purpose.values)
              ChoiceChip(
                avatar: Icon(p.icon, size: 16),
                label: Text(p.label),
                selected: _purpose == p,
                onSelected: _locked != null ? null : (_) => setState(() => _purpose = p),
              ),
          ],
        ),
        const SizedBox(height: 18),
        if (q != null)
          Airmail(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text('${to.name.split(' ').first} gets', style: context.tt.labelMedium),
                FittedBox(
                  alignment: Alignment.centerLeft,
                  fit: BoxFit.scaleDown,
                  child: Text(fx(q.receive, to.currency), style: context.tt.displayMedium!.copyWith(color: pc.blue, fontFeatures: tabular)),
                ),
                const SizedBox(height: 10),
                Line('Amount converted', inr(q.sendInr)),
                Line('Our rate', rateText(q.ourRate, to.currency),
                    hint: 'Mid-market ${rateText(q.midRate, to.currency)} · our margin ${(Store.markup * 100).toStringAsFixed(2)}% (${inr(q.markupCost.round())})'),
                Line('Transfer fee', inr(q.fee)),
                Line('GST on currency conversion', inr(q.gst), hint: 'Set by law, based on the amount'),
                if (q.tcs > 0)
                  Line('TCS (tax collected at source)', inr(q.tcs),
                      hint: '${(_purpose.tcsRate * 100).round()}% on the part above ₹10 lakh this year. You can claim it back in your tax return.',
                      color: pc.warn)
                else
                  Line('TCS', '₹0',
                      hint: store.fySentInr + q.sendInr <= Store.tcsThreshold
                          ? 'No TCS until your transfers this year cross ₹10 lakh'
                          : 'No TCS for this purpose'),
                const Divider(height: 18),
                Line('Total you pay', inr(q.totalInr), strong: true),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Icon(_locked != null ? Icons.lock_clock : Icons.show_chart, size: 18, color: _locked != null ? pc.ok : pc.muted),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        _locked != null && remaining != null
                            ? 'Rate locked for ${remaining.inMinutes}:${(remaining.inSeconds % 60).toString().padLeft(2, '0')}'
                            : 'Live rate. Lock it for 30 minutes while you check details.',
                        style: context.tt.bodySmall,
                      ),
                    ),
                    if (_locked == null)
                      TextButton(
                        onPressed: () => setState(() {
                          _locked = q;
                          _lockedUntil = DateTime.now().add(const Duration(minutes: 30));
                        }),
                        child: const Text('Lock rate'),
                      )
                    else
                      TextButton(
                        onPressed: () => setState(() {
                          _locked = null;
                          _lockedUntil = null;
                        }),
                        child: const Text('Unlock'),
                      ),
                  ],
                ),
              ],
            ),
          ),
        if (_error != null) ...[
          const SizedBox(height: 10),
          Text(_error!, style: context.tt.bodyMedium!.copyWith(color: pc.red)),
        ],
        const SizedBox(height: 16),
        FilledButton(
          onPressed: () {
            final e = _validate(store, q);
            if (e != null) {
              setState(() => _error = e);
              return;
            }
            _locked ??= q;
            _lockedUntil ??= DateTime.now().add(const Duration(minutes: 30));
            setState(() => _step = 2);
          },
          child: const Text('Continue'),
        ),
        const SizedBox(height: 10),
        const DemoNote(),
      ],
    );
  }

  // ── Step 3: review & approve ───────────────────────────────────
  Widget _reviewStep(Store store) {
    final pc = context.pc;
    final to = _to!;
    final q = _locked!;
    final risky = _purpose == Purpose.gift || _purpose == Purpose.investment || to.relation == 'Someone I met online';

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
      children: [
        Airmail(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('To', style: context.tt.labelSmall),
                        Text(to.name, style: context.tt.headlineSmall),
                        Text('${to.bank} · ${to.masked}', style: context.tt.bodySmall),
                        Text('SWIFT ${to.swift}', style: context.tt.bodySmall),
                      ],
                    ),
                  ),
                  Flag(to.currency, size: 36),
                ],
              ),
              const Divider(height: 22),
              Line('They get', fx(q.receive, to.currency), strong: true, color: pc.blue),
              Line('Purpose', _purpose.label),
              Line('Total you pay', inr(q.totalInr), strong: true),
              Line('Paid from', 'Linked bank account ••4821 (demo)'),
              Line('Usually arrives', '1–2 working days'),
            ],
          ),
        ),
        if (risky) ...[
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: pc.red.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: pc.red.withValues(alpha: 0.4)),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.shield_outlined, color: pc.red),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Never send money to someone you haven\'t met in person, or for "guaranteed" investment returns. '
                    'International transfers can\'t be reversed once delivered.',
                    style: context.tt.bodyMedium,
                  ),
                ),
              ],
            ),
          ),
        ],
        const SizedBox(height: 12),
        CheckboxListTile(
          contentPadding: EdgeInsets.zero,
          controlAffinity: ListTileControlAffinity.leading,
          value: _declared,
          onChanged: (v) => setState(() => _declared = v ?? false),
          title: Text('I sign Form A2 and declare this transfer is within the LRS limit and not for a prohibited purpose.',
              style: context.tt.bodyMedium),
        ),
        if (_error != null) Text(_error!, style: context.tt.bodyMedium!.copyWith(color: pc.red)),
        const SizedBox(height: 12),
        FilledButton.icon(
          onPressed: () async {
            if (!_declared) {
              setState(() => _error = 'Tick the Form A2 declaration to continue.');
              return;
            }
            final ok = await askPin(context);
            if (!ok || !context.mounted) return;
            final t = store.send(to: to, q: q, purpose: _purpose);
            store.markRecurringDone(to.id);
            if (!context.mounted) return;
            Navigator.of(context).pushReplacement(
              MaterialPageRoute(builder: (_) => TransferScreen(transferId: t.id, justSent: true)),
            );
          },
          icon: const Icon(Icons.lock_outline),
          label: Text('Send ${inr(q.totalInr)}'),
        ),
        const SizedBox(height: 10),
        const DemoNote(text: 'Demo app: this records a sample transfer. No money leaves your account.'),
      ],
    );
  }
}

/// Asks for the transaction PIN. Three wrong tries cancel.
Future<bool> askPin(BuildContext context) async {
  final store = StoreScope.read(context);
  final ctrl = TextEditingController();
  var tries = 0;
  String? error;
  final ok = await showDialog<bool>(
    context: context,
    barrierDismissible: false,
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, setS) => AlertDialog(
        title: const Text('Enter transaction PIN'),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          obscureText: true,
          keyboardType: TextInputType.number,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly, LengthLimitingTextInputFormatter(4)],
          decoration: InputDecoration(errorText: error),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          TextButton(
            onPressed: () {
              if (ctrl.text == store.txnPin) {
                Navigator.pop(ctx, true);
                return;
              }
              tries++;
              if (tries >= 3) {
                Navigator.pop(ctx, false);
                return;
              }
              setS(() {
                error = 'Wrong PIN. ${3 - tries} tr${3 - tries == 1 ? 'y' : 'ies'} left.';
                ctrl.clear();
              });
            },
            child: const Text('Approve'),
          ),
        ],
      ),
    ),
  );
  if (ok != true && tries >= 3 && context.mounted) {
    toast(context, 'Too many wrong PINs. Transfer cancelled for your safety.');
  }
  return ok == true;
}

/// Add a new recipient.
class RecipientSheet extends StatefulWidget {
  const RecipientSheet({super.key});

  @override
  State<RecipientSheet> createState() => _RecipientSheetState();
}

class _RecipientSheetState extends State<RecipientSheet> {
  final _name = TextEditingController();
  final _bank = TextEditingController();
  final _acc = TextEditingController();
  final _swift = TextEditingController();
  final _email = TextEditingController();
  String _currency = 'USD';
  String _relation = 'Family';
  String? _error;

  @override
  void dispose() {
    for (final c in [_name, _bank, _acc, _swift, _email]) {
      c.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final store = context.store;
    return FormSheet(
      title: 'New recipient',
      actions: [
        FilledButton(
          onPressed: () {
            final swift = _swift.text.trim().toUpperCase();
            String? e;
            if (_name.text.trim().length < 2) {
              e = 'Enter their full name as the bank has it.';
            } else if (_bank.text.trim().isEmpty) {
              e = 'Enter the name of their bank.';
            } else if (_acc.text.trim().length < 6) {
              e = 'Enter their account number or IBAN.';
            } else if (!RegExp(r'^[A-Z]{6}[A-Z0-9]{2}([A-Z0-9]{3})?$').hasMatch(swift)) {
              e = 'A SWIFT/BIC code has 8 or 11 characters, like CHASUS33.';
            }
            if (e != null) {
              setState(() => _error = e);
              return;
            }
            final r = Recipient(
              id: store.newId(),
              name: _name.text.trim(),
              currency: _currency,
              bank: _bank.text.trim(),
              account: _acc.text.trim().replaceAll(' ', ''),
              swift: swift,
              relation: _relation,
              email: _email.text.trim(),
            );
            store.addRecipient(r);
            Navigator.pop(context, r);
          },
          child: const Text('Save recipient'),
        ),
      ],
      children: [
        DropdownButtonFormField<String>(
          value: _currency,
          decoration: const InputDecoration(labelText: 'Country and currency'),
          items: [
            for (final c in currencies)
              DropdownMenuItem(value: c.code, child: Text('${c.flag}  ${c.country} · ${c.code}', overflow: TextOverflow.ellipsis)),
          ],
          onChanged: (v) => setState(() => _currency = v ?? 'USD'),
        ),
        const SizedBox(height: 12),
        TextField(controller: _name, textCapitalization: TextCapitalization.words, decoration: const InputDecoration(labelText: 'Full name')),
        const SizedBox(height: 12),
        TextField(controller: _bank, textCapitalization: TextCapitalization.words, decoration: const InputDecoration(labelText: 'Bank name')),
        const SizedBox(height: 12),
        TextField(controller: _acc, textCapitalization: TextCapitalization.characters, decoration: const InputDecoration(labelText: 'Account number or IBAN')),
        const SizedBox(height: 12),
        TextField(
          controller: _swift,
          textCapitalization: TextCapitalization.characters,
          inputFormatters: [LengthLimitingTextInputFormatter(11)],
          decoration: const InputDecoration(labelText: 'SWIFT / BIC code'),
        ),
        const SizedBox(height: 12),
        TextField(controller: _email, keyboardType: TextInputType.emailAddress, decoration: const InputDecoration(labelText: 'Email for updates (optional)')),
        const SizedBox(height: 12),
        Text('How do you know them?', style: context.tt.titleSmall),
        const SizedBox(height: 6),
        Wrap(
          spacing: 6,
          runSpacing: 6,
          children: [
            for (final r in const ['Family', 'Myself (own account abroad)', 'University or school', 'Hospital', 'Business', 'Friend', 'Someone I met online'])
              ChoiceChip(label: Text(r), selected: _relation == r, onSelected: (_) => setState(() => _relation = r)),
          ],
        ),
        if (_error != null) ...[
          const SizedBox(height: 10),
          Text(_error!, style: context.tt.bodyMedium!.copyWith(color: context.pc.red)),
        ],
      ],
    );
  }
}
