import 'package:flutter/material.dart';

import '../data.dart';
import '../store.dart';
import '../theme.dart';
import '../widgets.dart';
import 'result_screen.dart';

class CheckoutScreen extends StatefulWidget {
  const CheckoutScreen({
    super.key,
    required this.kind,
    required this.biller,
    required this.accountId,
    required this.amount,
    this.planText,
    this.circle,
    this.nextDue,
    this.existing,
  });

  final Kind kind;
  final String biller;
  final String accountId;
  final double amount;
  final String? planText;
  final String? circle;
  final DateTime? nextDue;
  final SavedBiller? existing;

  @override
  State<CheckoutScreen> createState() => _CheckoutScreenState();
}

class _CheckoutScreenState extends State<CheckoutScreen> {
  final _code = TextEditingController();
  Offer? _offer;
  String? _codeMsg;
  String? _methodId;
  bool _save = true;
  late final _nickname = TextEditingController(text: _defaultNickname());
  bool _autopay = false;
  bool _paying = false;
  String? _error;

  String _defaultNickname() => switch (widget.kind) {
        Kind.mobile || Kind.postpaid => 'Phone ${widget.accountId.length >= 4 ? widget.accountId.substring(widget.accountId.length - 4) : ''}',
        _ => widget.kind.label,
      };

  @override
  void initState() {
    super.initState();
    final store = StoreScope.read(context);
    _methodId = store.defaultMethodId;
    final existing = widget.existing ?? store.findSaved(widget.kind, widget.accountId);
    _save = existing == null;
    _autopay = existing?.autopay ?? false;
  }

  @override
  void dispose() {
    _code.dispose();
    _nickname.dispose();
    super.dispose();
  }

  void _apply(String raw, Store store) {
    final o = offerByCode(raw);
    setState(() {
      if (o == null) {
        _offer = null;
        _codeMsg = 'That code isn\'t valid. Check the spelling or pick an offer below.';
        return;
      }
      if (store.usedCodes.contains(o.code) && o.code == 'FIRST50') {
        _offer = null;
        _codeMsg = 'FIRST50 works on your first payment only.';
        return;
      }
      final why = o.whyNot(widget.kind, widget.amount);
      if (why != null) {
        _offer = null;
        _codeMsg = why;
        return;
      }
      _offer = o;
      _code.text = o.code;
      _codeMsg = 'Applied: ${inr(o.cashbackFor(widget.kind, widget.amount).round())} cashback after payment.';
    });
  }

  Future<void> _pay(Store store) async {
    final m = store.methodById(_methodId);
    if (m == null) {
      setState(() => _error = 'Add a payment method in Account first.');
      return;
    }
    final e = store.canPay(m, widget.amount);
    if (e != null) {
      setState(() => _error = e);
      return;
    }
    setState(() {
      _error = null;
      _paying = true;
    });
    var saved = widget.existing ?? store.findSaved(widget.kind, widget.accountId);
    if (saved == null && _save) {
      saved = SavedBiller(
        id: store.newId(),
        kind: widget.kind,
        biller: widget.biller,
        accountId: widget.accountId,
        nickname: _nickname.text.trim().isEmpty ? _defaultNickname() : _nickname.text.trim(),
        circle: widget.circle,
      );
      store.saveBiller(saved);
    }
    if (saved != null) {
      saved.autopay = _autopay;
      if (_autopay) saved.autopayMax = (widget.amount * 1.5).roundToDouble();
    }
    final p = await store.pay(
      kind: widget.kind,
      biller: widget.biller,
      accountId: widget.accountId,
      amount: widget.amount,
      method: m,
      offer: _offer,
      planText: widget.planText,
      nickname: saved?.nickname,
      nextDue: widget.nextDue,
    );
    if (!mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => ResultScreen(paymentId: p.id)),
      (r) => r.isFirst,
    );
  }

  @override
  Widget build(BuildContext context) {
    final store = context.store;
    final jc = context.jc;
    final applicable = offers.where((o) => o.whyNot(widget.kind, widget.amount) == null && !(o.code == 'FIRST50' && store.usedCodes.contains('FIRST50'))).toList();
    final isBill = !widget.kind.plans;

    return PopScope(
      canPop: !_paying,
      child: Scaffold(
        appBar: AppBar(title: const Text('Pay')),
        body: AbsorbPointer(
          absorbing: _paying,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 4, 20, 32),
            children: [
              Ticket(
                top: Row(
                  children: [
                    KindIcon(widget.kind),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(widget.biller, style: context.tt.titleMedium),
                          Text('${widget.kind == Kind.mobile ? '+91 ' : ''}${widget.accountId}${widget.circle == null ? '' : ' · ${widget.circle}'}',
                              style: context.tt.bodySmall),
                        ],
                      ),
                    ),
                  ],
                ),
                bottom: Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Expanded(
                      child: Text(widget.planText ?? 'Bill payment', style: context.tt.bodyMedium),
                    ),
                    const SizedBox(width: 10),
                    Text(inr(widget.amount), style: price(context, 26)),
                  ],
                ),
              ),
              const Section('Offers'),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _code,
                      textCapitalization: TextCapitalization.characters,
                      decoration: const InputDecoration(labelText: 'Coupon code'),
                      onSubmitted: (v) => _apply(v, store),
                    ),
                  ),
                  const SizedBox(width: 8),
                  OutlinedButton(onPressed: () => _apply(_code.text, store), child: const Text('Apply')),
                ],
              ),
              if (_codeMsg != null) ...[
                const SizedBox(height: 6),
                Text(_codeMsg!, style: context.tt.bodySmall!.copyWith(color: _offer != null ? jc.mint : jc.danger)),
              ],
              if (applicable.isNotEmpty) ...[
                const SizedBox(height: 10),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    for (final o in applicable)
                      ActionChip(
                        avatar: Icon(Icons.local_offer_outlined, size: 16, color: jc.mint),
                        label: Text('${o.code} · ${o.title}'),
                        onPressed: () => _apply(o.code, store),
                      ),
                  ],
                ),
              ],
              const Section('Pay with'),
              Paper(
                padding: EdgeInsets.zero,
                child: Column(
                  children: [
                    for (var i = 0; i < store.methods.length; i++) ...[
                      if (i > 0) const Divider(indent: 56),
                      RadioListTile<String>(
                        value: store.methods[i].id,
                        groupValue: _methodId,
                        onChanged: (v) => setState(() => _methodId = v),
                        secondary: Icon(store.methods[i].icon),
                        title: Text(store.methods[i].label, style: context.tt.titleSmall),
                        subtitle: Text(
                          store.methods[i].type == PayMethodType.wallet ? 'Balance ${inr(store.walletBalance)}' : store.methods[i].detail,
                          style: context.tt.bodySmall,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const Section('Next time'),
              Paper(
                padding: EdgeInsets.zero,
                child: Column(
                  children: [
                    if (widget.existing == null && store.findSaved(widget.kind, widget.accountId) == null) ...[
                      SwitchListTile(
                        value: _save,
                        onChanged: (v) => setState(() => _save = v),
                        title: const Text('Save for one-tap payment'),
                        subtitle: const Text('We\'ll also remind you before it\'s due'),
                      ),
                      if (_save)
                        Padding(
                          padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                          child: TextField(
                            controller: _nickname,
                            textCapitalization: TextCapitalization.words,
                            decoration: const InputDecoration(labelText: 'Nickname', hintText: 'e.g. Mummy\'s phone'),
                          ),
                        ),
                      const Divider(),
                    ],
                    SwitchListTile(
                      value: _autopay,
                      onChanged: (_save || widget.existing != null || store.findSaved(widget.kind, widget.accountId) != null)
                          ? (v) => setState(() => _autopay = v)
                          : null,
                      title: Text(isBill ? 'AutoPay this bill' : 'AutoPay when the plan ends'),
                      subtitle: Text(
                        'Sets up a UPI mandate up to ${inr((widget.amount * 1.5).round())}. You get an alert 24 hours before each debit and can stop it any time.',
                      ),
                    ),
                  ],
                ),
              ),
              if (_error != null) ...[
                const SizedBox(height: 12),
                Text(_error!, style: context.tt.bodyMedium!.copyWith(color: jc.danger)),
              ],
              const SizedBox(height: 18),
              FilledButton(
                onPressed: _paying ? null : () => _pay(store),
                child: _paying
                    ? Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2.4, color: jc.onSaffron)),
                          const SizedBox(width: 12),
                          const Text('Paying…'),
                        ],
                      )
                    : Text('Pay ${inr(widget.amount)}'),
              ),
              const SizedBox(height: 12),
              const DemoNote(),
            ],
          ),
        ),
      ),
    );
  }
}
