import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../data.dart';
import '../store.dart';
import '../theme.dart';
import '../widgets.dart';
import 'checkout_screen.dart';

/// Step 1 for every category: who/what you're paying, then either pick a
/// plan (recharges) or fetch the bill (BBPS billers).
class PayScreen extends StatefulWidget {
  const PayScreen({super.key, required this.kind, this.saved, this.prefillNumber});

  final Kind kind;
  final SavedBiller? saved;
  final String? prefillNumber;

  @override
  State<PayScreen> createState() => _PayScreenState();
}

class _PayScreenState extends State<PayScreen> {
  late final _id = TextEditingController(text: widget.saved?.accountId ?? widget.prefillNumber ?? '');
  late String _biller = widget.saved?.biller ?? billers[widget.kind]!.first;
  late String? _circle = widget.saved?.circle;
  bool _detected = false;
  bool _fetching = false;
  FetchedBill? _bill;
  String? _error;
  final _amount = TextEditingController();

  Kind get kind => widget.kind;

  @override
  void initState() {
    super.initState();
    _id.addListener(_onId);
    if (widget.saved != null || (widget.prefillNumber?.length ?? 0) >= 10) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _onId());
    }
  }

  @override
  void dispose() {
    _id.dispose();
    _amount.dispose();
    super.dispose();
  }

  void _onId() {
    if (kind == Kind.mobile || kind == Kind.postpaid) {
      final digits = _id.text.replaceAll(RegExp(r'\D'), '');
      if (digits.length == 10 && !_detected && widget.saved == null) {
        final (op, circle) = detectOperator(digits);
        setState(() {
          _biller = kind == Kind.postpaid ? '$op Postpaid' : op;
          if (!billers[kind]!.contains(_biller)) _biller = billers[kind]!.first;
          _circle = circle;
          _detected = true;
        });
      } else if (digits.length < 10 && _detected) {
        setState(() => _detected = false);
      }
    }
    if (_bill != null) setState(() => _bill = null);
  }

  String? _validateId() {
    final v = _id.text.trim();
    if (kind == Kind.mobile || kind == Kind.postpaid) {
      if (!RegExp(r'^[6-9]\d{9}$').hasMatch(v.replaceAll(' ', ''))) return 'Enter a valid 10-digit mobile number.';
      return null;
    }
    if (v.length < kind.minLen) return 'Enter your ${kind.idLabel.toLowerCase()} (at least ${kind.minLen} characters).';
    return null;
  }

  Future<void> _fetch() async {
    final e = _validateId();
    if (e != null) {
      setState(() => _error = e);
      return;
    }
    setState(() {
      _error = null;
      _fetching = true;
    });
    final b = await StoreScope.read(context).fetchBill(kind, _biller, _id.text.trim());
    if (!mounted) return;
    setState(() {
      _fetching = false;
      _bill = b;
      if (b == null) {
        _error = 'No bill is due for this ${kind.idLabel.toLowerCase()} right now. Check the number, or try again after your bill date.';
      } else {
        _amount.text = b.amount.toStringAsFixed(0);
      }
    });
  }

  void _toCheckout({required double amount, String? planText, DateTime? nextDue}) {
    Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => CheckoutScreen(
        kind: kind,
        biller: _biller,
        accountId: _id.text.trim(),
        amount: amount,
        planText: planText,
        circle: _circle,
        nextDue: nextDue,
        existing: widget.saved,
      ),
    ));
  }

  @override
  Widget build(BuildContext context) {
    final jc = context.jc;
    final isPhone = kind == Kind.mobile || kind == Kind.postpaid;
    final plans = plansFor(kind);

    return Scaffold(
      appBar: AppBar(title: Text(kind.label)),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 4, 20, 32),
        children: [
          TextField(
            controller: _id,
            autofocus: widget.saved == null && widget.prefillNumber == null,
            keyboardType: isPhone || kind == Kind.lpg ? TextInputType.phone : TextInputType.text,
            textCapitalization: TextCapitalization.characters,
            inputFormatters: isPhone ? [FilteringTextInputFormatter.digitsOnly, LengthLimitingTextInputFormatter(10)] : null,
            style: context.tt.titleLarge,
            decoration: InputDecoration(
              labelText: kind.idLabel,
              prefixText: isPhone ? '+91  ' : null,
              errorText: _error,
            ),
          ),
          const SizedBox(height: 12),
          InputDecorator(
            decoration: InputDecoration(
              labelText: switch (kind) {
                Kind.mobile || Kind.postpaid => _detected ? 'Operator (detected, tap to change)' : 'Operator',
                Kind.electricity || Kind.water || Kind.gas => 'Board / company',
                Kind.creditCard || Kind.loan => 'Bank or lender',
                Kind.insurance => 'Insurer',
                _ => 'Provider',
              },
              contentPadding: const EdgeInsets.fromLTRB(16, 6, 8, 6),
            ),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                value: _biller,
                isExpanded: true,
                items: [for (final b in billers[kind]!) DropdownMenuItem(value: b, child: Text(b, overflow: TextOverflow.ellipsis))],
                onChanged: (v) => setState(() {
                  _biller = v ?? _biller;
                  _bill = null;
                }),
              ),
            ),
          ),
          if (isPhone && _circle != null) ...[
            const SizedBox(height: 12),
            InputDecorator(
              decoration: const InputDecoration(labelText: 'Circle', contentPadding: EdgeInsets.fromLTRB(16, 6, 8, 6)),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<String>(
                  value: _circle,
                  isExpanded: true,
                  items: [for (final c in circles) DropdownMenuItem(value: c, child: Text(c))],
                  onChanged: (v) => setState(() => _circle = v),
                ),
              ),
            ),
          ],
          if (kind.plans) ...[
            const SizedBox(height: 8),
            if (kind == Kind.mobile && _validateId() != null)
              Padding(
                padding: const EdgeInsets.only(top: 16),
                child: Text('Enter the number to see plans for its operator and circle.', style: context.tt.bodyMedium!.copyWith(color: jc.muted)),
              )
            else
              PlanBrowser(
                plans: plans,
                operator: _biller,
                onPick: (p) {
                  final e = _validateId();
                  if (e != null) {
                    setState(() => _error = e);
                    return;
                  }
                  final days = p.validityDays;
                  _toCheckout(
                    amount: p.price.toDouble(),
                    planText: '${p.data} · ${p.calls} · ${p.validity == '0 days' ? 'no validity change' : p.validity}',
                    nextDue: days > 0 ? DateTime.now().add(Duration(days: days)) : null,
                  );
                },
              ),
          ] else ...[
            const SizedBox(height: 16),
            if (_bill == null)
              FilledButton(
                onPressed: _fetching ? null : _fetch,
                child: _fetching
                    ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2.4))
                    : const Text('Fetch bill'),
              )
            else ...[
              Ticket(
                top: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      children: [
                        KindIcon(kind, size: 36),
                        const SizedBox(width: 10),
                        Expanded(child: Text(_biller, style: context.tt.titleSmall)),
                        Icon(Icons.verified_outlined, color: jc.mint, size: 20),
                        const SizedBox(width: 4),
                        Text('BBPS', style: context.tt.labelSmall!.copyWith(color: jc.mint)),
                      ],
                    ),
                    const SizedBox(height: 12),
                    KV('Name on bill', _bill!.customer),
                    KV('Bill period', _bill!.period),
                    KV('Bill date', dMon(_bill!.billDate)),
                    KV('Due date', '${dMon(_bill!.due)} · ${dueText(_bill!.due)}'),
                  ],
                ),
                bottom: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Amount due', style: context.tt.labelMedium),
                    const SizedBox(height: 4),
                    Text(inr(_bill!.amount), style: price(context, 30)),
                  ],
                ),
              ),
              if (kind == Kind.creditCard || kind == Kind.loan || kind == Kind.education) ...[
                const SizedBox(height: 12),
                TextField(
                  controller: _amount,
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  decoration: const InputDecoration(labelText: 'Amount to pay', prefixText: '₹ ', helperText: 'You can pay part of it or the full amount'),
                ),
              ],
              const SizedBox(height: 14),
              FilledButton(
                onPressed: () {
                  final a = double.tryParse(_amount.text) ?? _bill!.amount;
                  if (a < 1) {
                    setState(() => _error = 'Enter an amount of at least ₹1.');
                    return;
                  }
                  final now = DateTime.now();
                  _toCheckout(amount: a, nextDue: DateTime(now.year, now.month + 1, _bill!.due.day));
                },
                child: Text('Continue to pay ${inr(double.tryParse(_amount.text) ?? _bill!.amount)}'),
              ),
            ],
          ],
          const SizedBox(height: 18),
          const DemoNote(),
        ],
      ),
    );
  }
}

/// Plans grouped by tab, with a compare tray.
class PlanBrowser extends StatefulWidget {
  const PlanBrowser({super.key, required this.plans, required this.onPick, required this.operator});

  final List<Plan> plans;
  final ValueChanged<Plan> onPick;
  final String operator;

  @override
  State<PlanBrowser> createState() => _PlanBrowserState();
}

class _PlanBrowserState extends State<PlanBrowser> {
  String _tab = 'Popular';
  final Set<String> _compare = {};
  String _sort = 'Recommended';

  @override
  Widget build(BuildContext context) {
    final jc = context.jc;
    final tabs = <String>['Popular', ...{for (final p in widget.plans) p.tab}.where((t) => t != 'Popular')];
    var list = widget.plans.where((p) => _tab == 'Popular' ? (p.popular || p.tab == 'Popular') : p.tab == _tab).toList();
    if (_sort == 'Price') list.sort((a, b) => a.price.compareTo(b.price));
    if (_sort == 'Per day') list.sort((a, b) => a.perDay.compareTo(b.perDay));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: 14),
        Text('${widget.operator} plans', style: context.tt.headlineSmall),
        const SizedBox(height: 10),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              for (final t in tabs) ...[
                ChoiceChip(label: Text(t), selected: _tab == t, onSelected: (_) => setState(() => _tab = t)),
                const SizedBox(width: 6),
              ],
            ],
          ),
        ),
        Row(
          children: [
            Text('Sort', style: context.tt.labelSmall),
            const SizedBox(width: 6),
            for (final s in const ['Recommended', 'Price', 'Per day'])
              TextButton(
                onPressed: () => setState(() => _sort = s),
                style: TextButton.styleFrom(
                  foregroundColor: _sort == s ? jc.ink : jc.muted,
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  minimumSize: const Size(0, 36),
                ),
                child: Text(s),
              ),
          ],
        ),
        for (final p in list)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Ticket(
              highlight: _compare.contains(p.id),
              onTap: () => widget.onPick(p),
              top: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(inr(p.price), style: price(context, 26)),
                        const SizedBox(height: 6),
                        Text(p.data, style: context.tt.titleSmall),
                        Text(p.calls, style: context.tt.bodyMedium),
                      ],
                    ),
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      if (p.validity != '0 days') Text(p.validity, style: context.tt.titleSmall),
                      if (p.validityDays > 1) Text('${inr(p.perDay.round())}/day', style: context.tt.bodySmall),
                      if (p.popular)
                        Container(
                          margin: const EdgeInsets.only(top: 6),
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(color: jc.mintSoft, borderRadius: BorderRadius.circular(99)),
                          child: Text('Popular', style: context.tt.labelSmall!.copyWith(color: jc.mint)),
                        ),
                    ],
                  ),
                ],
              ),
              bottom: Row(
                children: [
                  Expanded(child: Text(p.extras.isEmpty ? 'Tap to recharge' : p.extras, style: context.tt.bodySmall)),
                  TextButton.icon(
                    onPressed: () => setState(() {
                      if (!_compare.remove(p.id)) {
                        if (_compare.length >= 3) {
                          toast(context, 'Compare up to 3 plans at a time.');
                          return;
                        }
                        _compare.add(p.id);
                      }
                    }),
                    icon: Icon(_compare.contains(p.id) ? Icons.check_box : Icons.check_box_outline_blank, size: 18),
                    label: const Text('Compare'),
                  ),
                ],
              ),
            ),
          ),
        if (_compare.length >= 2)
          FilledButton.icon(
            onPressed: () => _showCompare(context),
            icon: const Icon(Icons.compare_arrows),
            label: Text('Compare ${_compare.length} plans'),
          ),
      ],
    );
  }

  void _showCompare(BuildContext context) {
    final picked = widget.plans.where((p) => _compare.contains(p.id)).toList();
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (ctx) {
        Widget row(String label, String Function(Plan) v, {bool strong = false}) => Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(width: 82, child: Text(label, style: ctx.tt.labelMedium)),
                  for (final p in picked)
                    Expanded(child: Text(v(p), style: strong ? price(ctx, 16) : ctx.tt.bodyMedium)),
                ],
              ),
            );
        final cheapest = picked.reduce((a, b) => a.perDay <= b.perDay ? a : b);
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text('Compare plans', style: ctx.tt.headlineSmall),
                const SizedBox(height: 10),
                row('Price', (p) => inr(p.price), strong: true),
                const Divider(),
                row('Validity', (p) => p.validity),
                row('Data', (p) => p.data),
                row('Calls', (p) => p.calls),
                row('Per day', (p) => p.validityDays > 1 ? inr(p.perDay.round()) : '—'),
                row('Extras', (p) => p.extras.isEmpty ? '—' : p.extras),
                const SizedBox(height: 10),
                if (cheapest.validityDays > 1)
                  Text('Best value per day: ${inr(cheapest.price)} for ${cheapest.validity}.', style: ctx.tt.titleSmall),
                const SizedBox(height: 14),
                Row(
                  children: [
                    for (final p in picked) ...[
                      Expanded(
                        child: FilledButton(
                          onPressed: () {
                            Navigator.pop(ctx);
                            widget.onPick(p);
                          },
                          child: Text(inr(p.price)),
                        ),
                      ),
                      if (p != picked.last) const SizedBox(width: 8),
                    ],
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
