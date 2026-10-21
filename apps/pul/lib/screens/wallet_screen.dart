import 'package:flutter/material.dart';

import '../data.dart';
import '../store.dart';
import '../theme.dart';
import '../widgets.dart';

/// Multi-currency wallet and the travel card linked to it.
class WalletScreen extends StatefulWidget {
  const WalletScreen({super.key});

  @override
  State<WalletScreen> createState() => _WalletScreenState();
}

class _WalletScreenState extends State<WalletScreen> {
  String _from = 'INR';
  String _to = 'USD';
  final _amount = TextEditingController();
  String? _error;

  @override
  void dispose() {
    _amount.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final store = context.store;
    final pc = context.pc;
    final codes = ['INR', ...currencies.map((c) => c.code)];
    final amt = parseNum(_amount.text) ?? 0;
    final preview = () {
      if (amt <= 0 || _from == _to) return null;
      final inrV = _from == 'INR' ? amt : amt * store.rate(_from) * (1 - Store.markup);
      return _to == 'INR' ? inrV : inrV / (store.rate(_to) * (1 + Store.markup));
    }();

    String fmt(double v, String code) => code == 'INR' ? inr(v, paise: true) : fx(v, code);

    return Scaffold(
      appBar: AppBar(title: const Text('Wallet')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 32),
        children: [
          // Travel card
          AspectRatio(
            aspectRatio: 1.6,
            child: Container(
              decoration: BoxDecoration(
                color: store.cardFrozen ? pc.muted : pc.blue,
                borderRadius: BorderRadius.circular(16),
              ),
              padding: const EdgeInsets.all(18),
              child: DefaultTextStyle(
                style: context.tt.titleMedium!.copyWith(color: Colors.white),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text('Pul travel card', style: context.tt.headlineSmall!.copyWith(color: Colors.white)),
                        const Spacer(),
                        if (store.cardFrozen) const Icon(Icons.ac_unit, color: Colors.white),
                      ],
                    ),
                    const Spacer(),
                    Text('••••  ••••  ••••  4821', style: context.tt.headlineSmall!.copyWith(color: Colors.white, letterSpacing: 2, fontFeatures: tabular)),
                    const SizedBox(height: 8),
                    Text(store.name.isEmpty ? 'YOUR NAME' : store.name.toUpperCase(), style: context.tt.labelMedium!.copyWith(color: Colors.white)),
                    Text('Spends from your wallet balance in the local currency', style: context.tt.bodySmall!.copyWith(color: Colors.white70)),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 8),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            value: store.cardFrozen,
            onChanged: store.setCardFrozen,
            title: const Text('Freeze card'),
            subtitle: const Text('Blocks all card payments until you unfreeze it'),
          ),
          const Section('Balances'),
          Paper(
            child: Column(
              children: [
                for (final e in store.wallet.entries)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 5),
                    child: Row(
                      children: [
                        Flag(e.key, size: 22),
                        const SizedBox(width: 10),
                        Expanded(child: Text(e.key, style: context.tt.titleSmall)),
                        Text(fmt(e.value, e.key), style: context.tt.titleSmall!.copyWith(fontFeatures: tabular)),
                      ],
                    ),
                  ),
              ],
            ),
          ),
          const Section('Convert'),
          Paper(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        value: _from,
                        decoration: const InputDecoration(labelText: 'From'),
                        items: [for (final c in codes) DropdownMenuItem(value: c, child: Text(c))],
                        onChanged: (v) => setState(() => _from = v ?? 'INR'),
                      ),
                    ),
                    IconButton(
                      tooltip: 'Swap',
                      onPressed: () => setState(() {
                        final t = _from;
                        _from = _to;
                        _to = t;
                      }),
                      icon: const Icon(Icons.swap_horiz),
                    ),
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        value: _to,
                        decoration: const InputDecoration(labelText: 'To'),
                        items: [for (final c in codes) DropdownMenuItem(value: c, child: Text(c))],
                        onChanged: (v) => setState(() => _to = v ?? 'USD'),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _amount,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  onChanged: (_) => setState(() => _error = null),
                  decoration: InputDecoration(
                    labelText: 'Amount in $_from',
                    helperText: 'Available ${fmt(store.balance(_from), _from)}',
                    errorText: _error,
                  ),
                ),
                if (preview != null) ...[
                  const SizedBox(height: 10),
                  Text('You get ${fmt(preview, _to)}', style: context.tt.titleMedium!.copyWith(color: pc.blue)),
                ],
                const SizedBox(height: 12),
                FilledButton(
                  onPressed: () {
                    if (_from == _to) {
                      setState(() => _error = 'Pick two different currencies.');
                      return;
                    }
                    final e = store.convert(_from, _to, amt);
                    if (e != null) {
                      setState(() => _error = e);
                      return;
                    }
                    _amount.clear();
                    toast(context, 'Converted');
                  },
                  child: const Text('Convert'),
                ),
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
