import 'package:flutter/material.dart';

import '../format.dart';
import '../models.dart';
import '../store.dart';
import '../theme.dart';
import '../widgets.dart';

/// Add or edit a transaction. The category is suggested from the note
/// ("Swiggy dinner" → Food) until the user picks one themselves.
class TxnSheet extends StatefulWidget {
  const TxnSheet({super.key, this.existing});

  final Txn? existing;

  @override
  State<TxnSheet> createState() => _TxnSheetState();
}

class _TxnSheetState extends State<TxnSheet> {
  late TxnType _type = widget.existing?.type ?? TxnType.expense;
  late final _amount = TextEditingController(
      text: widget.existing == null ? '' : widget.existing!.amount.toStringAsFixed(widget.existing!.amount % 1 == 0 ? 0 : 2));
  late final _note = TextEditingController(text: widget.existing?.note ?? '');
  late String _category = widget.existing?.category ?? 'food';
  late String? _accountId = widget.existing?.accountId;
  late String? _toAccountId = widget.existing?.toAccountId;
  late DateTime _date = widget.existing?.date ?? DateTime.now();
  bool _pickedCategory = false;
  String? _amountError;
  String? _accountError;

  @override
  void initState() {
    super.initState();
    _pickedCategory = widget.existing != null;
    _note.addListener(_suggest);
    final accounts = StoreScope.read(context).accounts;
    _accountId ??= accounts.isEmpty ? null : accounts.first.id;
  }

  @override
  void dispose() {
    _amount.dispose();
    _note.dispose();
    super.dispose();
  }

  void _suggest() {
    if (_pickedCategory || _type == TxnType.transfer) return;
    final s = suggestCategory(_note.text, income: _type == TxnType.income);
    if (s != null && s.id != _category) setState(() => _category = s.id);
  }

  void _setType(TxnType t) {
    setState(() {
      _type = t;
      final cats = categories.where((c) => c.income == (t == TxnType.income));
      if (!cats.any((c) => c.id == _category)) _category = cats.first.id;
      _pickedCategory = false;
    });
    _suggest();
  }

  void _save() {
    final store = StoreScope.read(context);
    final amt = parseAmount(_amount.text);
    setState(() {
      _amountError = (amt == null || amt <= 0) ? 'Enter an amount above zero.' : null;
      _accountError = _accountId == null
          ? 'Add an account first (Passbook → Accounts).'
          : (_type == TxnType.transfer && (_toAccountId == null || _toAccountId == _accountId))
              ? 'Pick a different account to move money to.'
              : null;
    });
    if (_amountError != null || _accountError != null) return;

    if (widget.existing != null) {
      final t = widget.existing!
        ..type = _type
        ..amount = amt!
        ..category = _type == TxnType.transfer ? 'other' : _category
        ..accountId = _accountId!
        ..toAccountId = _type == TxnType.transfer ? _toAccountId : null
        ..date = _date
        ..note = _note.text.trim();
      store.updateTxn();
      Navigator.pop(context, t);
    } else {
      final t = Txn(
        id: store.newId(),
        type: _type,
        amount: amt!,
        category: _type == TxnType.transfer ? 'other' : _category,
        accountId: _accountId!,
        toAccountId: _type == TxnType.transfer ? _toAccountId : null,
        date: _date,
        note: _note.text.trim(),
      );
      store.addTxn(t);
      final nudge = _budgetNudge(store, t);
      final messenger = ScaffoldMessenger.of(context);
      Navigator.pop(context, t);
      if (nudge != null) messenger.showSnackBar(SnackBar(content: Text(nudge)));
    }
  }

  /// Tell the user right away if this pushed a budget past 80% or 100%.
  String? _budgetNudge(Store store, Txn t) {
    if (t.type != TxnType.expense) return null;
    final limit = store.budgets[t.category];
    if (limit == null) return null;
    final spent = store.spentIn(DateTime.now(), category: t.category);
    final before = spent - t.amount;
    final name = categoryById(t.category).name;
    if (before < limit && spent >= limit) return '$name is now over its ${inr(limit)} budget.';
    if (before < limit * 0.8 && spent >= limit * 0.8) {
      return '$name has used ${(spent / limit * 100).round()}% of its budget this month.';
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final store = context.store;
    final hc = context.hc;
    final cats = categories.where((c) => c.income == (_type == TxnType.income)).toList();

    return FormSheet(
      title: widget.existing == null ? 'New entry' : 'Edit entry',
      actions: [
        FilledButton(onPressed: _save, child: Text(widget.existing == null ? 'Save entry' : 'Save changes')),
        if (widget.existing != null)
          TextButton(
            onPressed: () async {
              if (await confirm(context, 'Delete this entry?', 'Balances will update.', 'Delete')) {
                store.deleteTxn(widget.existing!);
                if (context.mounted) Navigator.pop(context);
              }
            },
            style: TextButton.styleFrom(foregroundColor: hc.spend),
            child: const Text('Delete entry'),
          ),
      ],
      children: [
        SegmentedButton<TxnType>(
          segments: const [
            ButtonSegment(value: TxnType.expense, label: Text('Spent'), icon: Icon(Icons.north_east, size: 16)),
            ButtonSegment(value: TxnType.income, label: Text('Received'), icon: Icon(Icons.south_west, size: 16)),
            ButtonSegment(value: TxnType.transfer, label: Text('Transfer'), icon: Icon(Icons.swap_horiz, size: 16)),
          ],
          selected: {_type},
          showSelectedIcon: false,
          onSelectionChanged: (s) => _setType(s.first),
        ),
        const SizedBox(height: 14),
        AmountField(controller: _amount, big: true, autofocus: widget.existing == null, error: _amountError),
        const SizedBox(height: 12),
        TextField(
          controller: _note,
          textCapitalization: TextCapitalization.sentences,
          decoration: InputDecoration(
            labelText: _type == TxnType.transfer ? 'Note (optional)' : 'What was it for?',
            hintText: _type == TxnType.income ? 'e.g. October salary' : 'e.g. Swiggy dinner',
          ),
        ),
        if (_type != TxnType.transfer) ...[
          const SizedBox(height: 14),
          Row(
            children: [
              Text('Category', style: context.tt.titleSmall),
              const SizedBox(width: 8),
              if (!_pickedCategory && _note.text.trim().length >= 3)
                Text('suggested from your note', style: context.tt.labelSmall),
            ],
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              for (final c in cats)
                ChoiceChip(
                  avatar: Icon(c.icon, size: 16, color: c.color),
                  label: Text(c.name),
                  selected: _category == c.id,
                  onSelected: (_) => setState(() {
                    _category = c.id;
                    _pickedCategory = true;
                  }),
                ),
            ],
          ),
        ],
        const SizedBox(height: 14),
        _AccountPicker(
          label: _type == TxnType.transfer ? 'From' : (_type == TxnType.income ? 'Into' : 'Paid from'),
          value: _accountId,
          onChanged: (v) => setState(() => _accountId = v),
        ),
        if (_type == TxnType.transfer) ...[
          const SizedBox(height: 10),
          _AccountPicker(label: 'To', value: _toAccountId, onChanged: (v) => setState(() => _toAccountId = v)),
        ],
        if (_accountError != null) ...[
          const SizedBox(height: 6),
          Text(_accountError!, style: context.tt.bodySmall!.copyWith(color: hc.spend)),
        ],
        const SizedBox(height: 10),
        OutlinedButton.icon(
          onPressed: () async {
            final d = await showDatePicker(
              context: context,
              initialDate: _date,
              firstDate: DateTime(2000),
              lastDate: DateTime.now().add(const Duration(days: 365)),
            );
            if (d != null) setState(() => _date = DateTime(d.year, d.month, d.day, _date.hour, _date.minute));
          },
          icon: const Icon(Icons.event_outlined),
          label: Text(daysBetween(_date, DateTime.now()) == 0 ? 'Today' : dayMonthYear(_date)),
        ),
      ],
    );
  }
}

class _AccountPicker extends StatelessWidget {
  const _AccountPicker({required this.label, required this.value, required this.onChanged});

  final String label;
  final String? value;
  final ValueChanged<String?> onChanged;

  @override
  Widget build(BuildContext context) {
    final store = context.store;
    return InputDecorator(
      decoration: InputDecoration(labelText: label, contentPadding: const EdgeInsets.fromLTRB(14, 6, 8, 6)),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: store.accounts.any((a) => a.id == value) ? value : null,
          isExpanded: true,
          hint: const Text('Choose account'),
          items: [
            for (final a in store.accounts)
              DropdownMenuItem(
                value: a.id,
                child: Row(
                  children: [
                    Icon(a.type.icon, size: 18),
                    const SizedBox(width: 8),
                    Expanded(child: Text(a.name, overflow: TextOverflow.ellipsis)),
                  ],
                ),
              ),
          ],
          onChanged: onChanged,
        ),
      ),
    );
  }
}

/// Add or edit an account.
class AccountSheet extends StatefulWidget {
  const AccountSheet({super.key, this.existing});

  final Account? existing;

  @override
  State<AccountSheet> createState() => _AccountSheetState();
}

class _AccountSheetState extends State<AccountSheet> {
  late final _name = TextEditingController(text: widget.existing?.name ?? '');
  late AccountType _type = widget.existing?.type ?? AccountType.bank;
  late final _opening = TextEditingController(
      text: widget.existing == null ? '' : widget.existing!.opening.abs().toStringAsFixed(0));
  late final _limit = TextEditingController(text: widget.existing?.limit?.toStringAsFixed(0) ?? '');
  String? _error;

  @override
  void dispose() {
    _name.dispose();
    _opening.dispose();
    _limit.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final store = context.store;
    return FormSheet(
      title: widget.existing == null ? 'Add account' : 'Edit account',
      actions: [
        FilledButton(
          onPressed: () {
            if (_name.text.trim().isEmpty) {
              setState(() => _error = 'Give the account a name, e.g. "SBI savings".');
              return;
            }
            final opening = parseAmount(_opening.text) ?? 0;
            final signed = _type.isLiability ? -opening.abs() : opening;
            if (widget.existing != null) {
              widget.existing!
                ..name = _name.text.trim()
                ..type = _type
                ..opening = signed
                ..limit = _type == AccountType.card ? parseAmount(_limit.text) : null;
              store.changed();
            } else {
              store.accounts.add(Account(
                id: store.newId(),
                name: _name.text.trim(),
                type: _type,
                opening: signed,
                limit: _type == AccountType.card ? parseAmount(_limit.text) : null,
              ));
              store.changed();
            }
            Navigator.pop(context);
          },
          child: Text(widget.existing == null ? 'Add account' : 'Save changes'),
        ),
        if (widget.existing != null)
          TextButton(
            onPressed: () async {
              final used = store.txns.any((t) => t.accountId == widget.existing!.id || t.toAccountId == widget.existing!.id);
              if (used) {
                toast(context, 'This account has entries. Delete or move them first.');
                return;
              }
              store.accounts.remove(widget.existing);
              store.changed();
              Navigator.pop(context);
            },
            child: const Text('Delete account'),
          ),
      ],
      children: [
        Wrap(
          spacing: 6,
          runSpacing: 6,
          children: [
            for (final t in AccountType.values)
              ChoiceChip(
                avatar: Icon(t.icon, size: 16),
                label: Text(t.label),
                selected: _type == t,
                onSelected: (_) => setState(() => _type = t),
              ),
          ],
        ),
        const SizedBox(height: 14),
        TextField(
          controller: _name,
          textCapitalization: TextCapitalization.words,
          decoration: InputDecoration(labelText: 'Name', errorText: _error),
        ),
        const SizedBox(height: 12),
        AmountField(
          controller: _opening,
          label: _type.isLiability ? 'Amount you owe today' : 'Balance today',
        ),
        if (_type == AccountType.card) ...[
          const SizedBox(height: 12),
          AmountField(controller: _limit, label: 'Credit limit (optional)'),
        ],
        const SizedBox(height: 12),
        Text(
          'Tip: Indian banks can share statements securely through the RBI Account Aggregator system. '
          'Hisaab keeps everything on your phone, so accounts are added by hand for now.',
          style: context.tt.bodySmall,
        ),
      ],
    );
  }
}
