import 'package:flutter/material.dart';

import '../format.dart';
import '../models.dart';
import '../store.dart';
import '../theme.dart';
import '../widgets.dart';
import 'txn_sheet.dart';

/// Every entry, month by month, like a passbook. Pick one account to see its
/// running balance down the right-hand column.
class PassbookScreen extends StatefulWidget {
  const PassbookScreen({super.key});

  @override
  State<PassbookScreen> createState() => _PassbookScreenState();
}

class _PassbookScreenState extends State<PassbookScreen> {
  DateTime _month = DateTime(DateTime.now().year, DateTime.now().month);
  String? _accountId;
  TxnType? _type;
  String _query = '';
  bool _searching = false;

  @override
  Widget build(BuildContext context) {
    final store = context.store;
    final hc = context.hc;
    final isThisMonth = _month.year == DateTime.now().year && _month.month == DateTime.now().month;

    var list = store.sortedTxns.where((t) => t.date.year == _month.year && t.date.month == _month.month);
    if (_accountId != null) list = list.where((t) => t.accountId == _accountId || t.toAccountId == _accountId);
    if (_type != null) list = list.where((t) => t.type == _type);
    if (_query.isNotEmpty) {
      final q = _query.toLowerCase();
      list = list.where((t) => t.note.toLowerCase().contains(q) || categoryById(t.category).name.toLowerCase().contains(q));
    }
    final entries = list.toList();

    // Running balance for the selected account: walk back from today's balance.
    final balances = <String, double>{};
    if (_accountId != null) {
      final acc = store.accountById(_accountId!);
      if (acc != null) {
        var bal = store.balanceOf(acc);
        for (final t in store.sortedTxns) {
          if (t.accountId != acc.id && t.toAccountId != acc.id) continue;
          balances[t.id] = bal;
          final delta = switch (t.type) {
            TxnType.expense => -t.amount,
            TxnType.income => t.amount,
            TxnType.transfer => t.toAccountId == acc.id ? t.amount : -t.amount,
          };
          bal -= delta;
        }
      }
    }

    final out = entries.where((t) => t.type == TxnType.expense).fold(0.0, (s, t) => s + t.amount);
    final inn = entries.where((t) => t.type == TxnType.income).fold(0.0, (s, t) => s + t.amount);

    return SafeArea(
      child: CustomScrollView(
        slivers: [
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(20, 16, 12, 0),
            sliver: SliverToBoxAdapter(
              child: Row(
                children: [
                  Expanded(child: Text('Passbook', style: context.tt.displaySmall)),
                  IconButton(
                    tooltip: 'Search entries',
                    onPressed: () => setState(() {
                      _searching = !_searching;
                      if (!_searching) _query = '';
                    }),
                    icon: Icon(_searching ? Icons.close : Icons.search),
                  ),
                ],
              ),
            ),
          ),
          if (_searching)
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
              sliver: SliverToBoxAdapter(
                child: TextField(
                  autofocus: true,
                  onChanged: (v) => setState(() => _query = v.trim()),
                  decoration: const InputDecoration(prefixIcon: Icon(Icons.search), hintText: 'Search notes or categories'),
                ),
              ),
            ),
          // Accounts strip
          SliverToBoxAdapter(
            child: SizedBox(
              height: 104,
              child: ListView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.fromLTRB(20, 14, 20, 6),
                children: [
                  for (final a in store.accounts) ...[
                    _AccountCard(
                      account: a,
                      selected: _accountId == a.id,
                      onTap: () => setState(() => _accountId = _accountId == a.id ? null : a.id),
                      onLongPress: () => showForm(context, AccountSheet(existing: a)),
                    ),
                    const SizedBox(width: 10),
                  ],
                  SizedBox(
                    width: 120,
                    child: OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(minimumSize: const Size(120, 84)),
                      onPressed: () => showForm(context, const AccountSheet()),
                      icon: const Icon(Icons.add),
                      label: const Text('Account'),
                    ),
                  ),
                ],
              ),
            ),
          ),
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(20, 6, 20, 0),
            sliver: SliverToBoxAdapter(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (store.accounts.isNotEmpty)
                    Text('Tap an account to filter and see its running balance. Long-press to edit.', style: context.tt.bodySmall),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      IconButton(
                        tooltip: 'Previous month',
                        onPressed: () => setState(() => _month = DateTime(_month.year, _month.month - 1)),
                        icon: const Icon(Icons.chevron_left),
                      ),
                      Expanded(child: Text(monthYear(_month), textAlign: TextAlign.center, style: context.tt.titleMedium)),
                      IconButton(
                        tooltip: 'Next month',
                        onPressed: isThisMonth ? null : () => setState(() => _month = DateTime(_month.year, _month.month + 1)),
                        icon: const Icon(Icons.chevron_right),
                      ),
                    ],
                  ),
                  Wrap(
                    spacing: 6,
                    children: [
                      for (final (t, label) in const [(null, 'All'), (TxnType.expense, 'Spent'), (TxnType.income, 'Received'), (TxnType.transfer, 'Transfers')])
                        ChoiceChip(label: Text(label), selected: _type == t, onSelected: (_) => setState(() => _type = t)),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Text('Out ', style: context.tt.bodySmall),
                      Text(store.money(out), style: context.tt.labelMedium!.copyWith(color: hc.spend)),
                      const SizedBox(width: 16),
                      Text('In ', style: context.tt.bodySmall),
                      Text(store.money(inn), style: context.tt.labelMedium!.copyWith(color: hc.earn)),
                      const Spacer(),
                      Text('${entries.length} entr${entries.length == 1 ? 'y' : 'ies'}', style: context.tt.bodySmall),
                    ],
                  ),
                  const SizedBox(height: 6),
                  const Divider(),
                ],
              ),
            ),
          ),
          if (entries.isEmpty)
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Column(
                  children: [
                    Icon(Icons.menu_book_outlined, size: 40, color: hc.muted),
                    const SizedBox(height: 8),
                    Text(
                      _query.isNotEmpty ? 'No entries match "$_query".' : 'No entries in ${monthName(_month)}.',
                      style: context.tt.titleSmall,
                    ),
                    const SizedBox(height: 4),
                    Text('Tap + to add what you spent or received.', style: context.tt.bodySmall),
                  ],
                ),
              ),
            )
          else
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 100),
              sliver: SliverList.separated(
                itemCount: entries.length,
                separatorBuilder: (_, __) => const Divider(),
                itemBuilder: (context, i) => LedgerRow(
                  txn: entries[i],
                  balanceAfter: balances[entries[i].id],
                  onTap: () => showForm(context, TxnSheet(existing: entries[i])),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _AccountCard extends StatelessWidget {
  const _AccountCard({required this.account, required this.selected, required this.onTap, required this.onLongPress});

  final Account account;
  final bool selected;
  final VoidCallback onTap;
  final VoidCallback onLongPress;

  @override
  Widget build(BuildContext context) {
    final store = context.store;
    final hc = context.hc;
    final bal = store.balanceOf(account);
    final liability = account.type.isLiability;
    return Semantics(
      selected: selected,
      button: true,
      child: Material(
        color: selected ? hc.band : hc.card,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10), side: BorderSide(color: selected ? hc.band : hc.rule)),
        child: InkWell(
          borderRadius: BorderRadius.circular(10),
          onTap: onTap,
          onLongPress: onLongPress,
          child: Container(
            width: 160,
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(account.type.icon, size: 16, color: selected ? hc.onBand : hc.muted),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(account.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: context.tt.labelMedium!.copyWith(color: selected ? hc.onBand : null)),
                    ),
                  ],
                ),
                const Spacer(),
                Text(
                  liability ? '${store.money(-bal)} owed' : store.money(bal),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: money(context, 22, color: selected ? hc.onBand : (liability ? hc.spend : hc.ink)),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
