import 'dart:ui' show FontFeature;

import 'package:flutter/material.dart';

import '../format.dart';
import '../models.dart';
import '../store.dart';
import '../theme.dart';
import '../widgets.dart';

/// Budgets, bills & EMIs, and savings goals.
class PlanScreen extends StatefulWidget {
  const PlanScreen({super.key});

  @override
  State<PlanScreen> createState() => _PlanScreenState();
}

class _PlanScreenState extends State<PlanScreen> {
  int _tab = 0;

  @override
  Widget build(BuildContext context) {
    final store = context.store;
    return SafeArea(
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 100),
        children: [
          Text('Plan', style: context.tt.displaySmall),
          const SizedBox(height: 14),
          SegmentedButton<int>(
            segments: const [
              ButtonSegment(value: 0, label: Text('Budgets')),
              ButtonSegment(value: 1, label: Text('Bills & EMIs')),
              ButtonSegment(value: 2, label: Text('Goals')),
            ],
            selected: {_tab},
            showSelectedIcon: false,
            onSelectionChanged: (s) => setState(() => _tab = s.first),
          ),
          const SizedBox(height: 8),
          if (_tab == 0) const _Budgets(),
          if (_tab == 1) const _Bills(),
          if (_tab == 2) const _Goals(),
          if (_tab == 1 || _tab == 2) ...[
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: () => showForm(context, _tab == 1 ? const BillSheet() : const GoalSheet()),
              icon: const Icon(Icons.add),
              label: Text(_tab == 1 ? 'Add a bill, EMI or subscription' : 'Add a goal'),
            ),
          ],
          if (_tab == 0 && store.budgets.isEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text('Tap a category to give it a monthly limit. You\'ll be told at 80% and 100%.',
                  style: context.tt.bodySmall),
            ),
        ],
      ),
    );
  }
}

// ── Budgets ──────────────────────────────────────────────────────────

class _Budgets extends StatelessWidget {
  const _Budgets();

  @override
  Widget build(BuildContext context) {
    final store = context.store;
    final now = DateTime.now();
    final expenseCats = categories.where((c) => !c.income).toList()
      ..sort((a, b) {
        final ab = store.budgets.containsKey(a.id) ? 0 : 1;
        final bb = store.budgets.containsKey(b.id) ? 0 : 1;
        if (ab != bb) return ab.compareTo(bb);
        return store.spentIn(now, category: b.id).compareTo(store.spentIn(now, category: a.id));
      });
    final totalBudget = store.budgets.values.fold(0.0, (s, v) => s + v);
    final totalSpent = store.budgets.keys.fold(0.0, (s, c) => s + store.spentIn(now, category: c));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (totalBudget > 0) ...[
          const SizedBox(height: 12),
          Paper(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('${monthName(now)} so far', style: context.tt.labelMedium),
                const SizedBox(height: 4),
                Text('${store.money(totalSpent)} of ${store.money(totalBudget)}', style: money(context, 30)),
                const SizedBox(height: 10),
                Meter(value: totalSpent / totalBudget, tick80: true, height: 10),
                const SizedBox(height: 6),
                Text('${store.money((totalBudget - totalSpent).clamp(0, double.infinity))} left across budgeted categories',
                    style: context.tt.bodySmall),
              ],
            ),
          ),
        ],
        const SizedBox(height: 12),
        Paper(
          padding: EdgeInsets.zero,
          child: Column(
            children: [
              for (var i = 0; i < expenseCats.length; i++) ...[
                if (i > 0) const Divider(indent: 16),
                InkWell(
                  onTap: () => showForm(context, BudgetSheet(category: expenseCats[i])),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    child: BudgetLine(category: expenseCats[i]),
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

class BudgetLine extends StatelessWidget {
  const BudgetLine({super.key, required this.category});

  final Category category;

  @override
  Widget build(BuildContext context) {
    final store = context.store;
    final hc = context.hc;
    final spent = store.spentIn(DateTime.now(), category: category.id);
    final limit = store.budgets[category.id];
    return Row(
      children: [
        CategoryDot(category, size: 32),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(child: Text(category.name, style: context.tt.titleSmall)),
                  Text(
                    limit == null ? store.money(spent) : '${store.money(spent)} / ${store.moneyShort(limit)}',
                    style: context.tt.labelMedium!.copyWith(
                      color: limit != null && spent > limit ? hc.spend : null,
                      fontFeatures: const [FontFeature.tabularFigures()],
                    ),
                  ),
                ],
              ),
              if (limit != null) ...[
                const SizedBox(height: 6),
                Meter(value: spent / limit, tick80: true),
              ] else
                Text('No budget · tap to set one', style: context.tt.bodySmall),
            ],
          ),
        ),
      ],
    );
  }
}

class BudgetSheet extends StatefulWidget {
  const BudgetSheet({super.key, required this.category});

  final Category category;

  @override
  State<BudgetSheet> createState() => _BudgetSheetState();
}

class _BudgetSheetState extends State<BudgetSheet> {
  late final _ctrl = TextEditingController(
    text: StoreScope.read(context).budgets[widget.category.id]?.toStringAsFixed(0) ?? '',
  );

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final store = context.store;
    final avg = () {
      final now = DateTime.now();
      var total = 0.0;
      for (var i = 1; i <= 3; i++) {
        total += store.spentIn(DateTime(now.year, now.month - i), category: widget.category.id);
      }
      return total / 3;
    }();
    return FormSheet(
      title: '${widget.category.name} budget',
      actions: [
        FilledButton(
          onPressed: () {
            store.setBudget(widget.category.id, parseAmount(_ctrl.text));
            Navigator.pop(context);
          },
          child: const Text('Save budget'),
        ),
        if (store.budgets.containsKey(widget.category.id))
          TextButton(
            onPressed: () {
              store.setBudget(widget.category.id, null);
              Navigator.pop(context);
            },
            child: const Text('Remove budget'),
          ),
      ],
      children: [
        AmountField(controller: _ctrl, label: 'Monthly limit', autofocus: true),
        const SizedBox(height: 8),
        Text(
          avg > 0
              ? 'You spent about ${inr(avg.round())} a month here over the last 3 months.'
              : 'No spending recorded here in the last 3 months.',
          style: context.tt.bodySmall,
        ),
      ],
    );
  }
}

// ── Bills ────────────────────────────────────────────────────────────

class _Bills extends StatelessWidget {
  const _Bills();

  @override
  Widget build(BuildContext context) {
    final store = context.store;
    final bills = store.upcomingBills;
    final monthly = bills.fold(0.0, (s, b) => s + b.amount / (b.repeat.months == 0 ? 1 : b.repeat.months));
    if (bills.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 24),
        child: Text('Add rent, EMIs, insurance and subscriptions. Hisaab shows what\'s due and when.',
            style: context.tt.bodyMedium),
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: 12),
        Text('About ${store.money(monthly)} a month in regular payments', style: context.tt.bodySmall),
        const SizedBox(height: 8),
        Paper(
          padding: EdgeInsets.zero,
          child: Column(
            children: [
              for (var i = 0; i < bills.length; i++) ...[
                if (i > 0) const Divider(indent: 16),
                BillTile(bill: bills[i], showMenu: true),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

class BillTile extends StatelessWidget {
  const BillTile({super.key, required this.bill, this.showMenu = false});

  final Bill bill;
  final bool showMenu;

  @override
  Widget build(BuildContext context) {
    final store = context.store;
    final hc = context.hc;
    final days = daysBetween(DateTime.now(), bill.due);
    final overdue = days < 0;
    final soon = days <= 3;
    return ListTile(
      contentPadding: const EdgeInsets.fromLTRB(16, 4, 8, 4),
      leading: Icon(bill.kind.icon, color: overdue ? hc.spend : hc.green),
      title: Text(bill.name, style: context.tt.titleSmall),
      subtitle: Text(
        '${dueLabel(bill.due)} · ${dayMonth(bill.due)} · ${bill.repeat.label.toLowerCase()}',
        style: context.tt.bodySmall!.copyWith(color: overdue ? hc.spend : (soon ? hc.brass : null)),
      ),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(store.money(bill.amount), style: context.tt.titleSmall),
          const SizedBox(width: 4),
          TextButton(onPressed: () => showForm(context, PayBillSheet(bill: bill)), child: const Text('Pay')),
          if (showMenu)
            IconButton(
              tooltip: 'Delete',
              onPressed: () async {
                if (await confirm(context, 'Delete ${bill.name}?', 'Its reminders will stop.', 'Delete')) {
                  store.removeBill(bill);
                }
              },
              icon: const Icon(Icons.delete_outline, size: 20),
            ),
        ],
      ),
    );
  }
}

class PayBillSheet extends StatefulWidget {
  const PayBillSheet({super.key, required this.bill});

  final Bill bill;

  @override
  State<PayBillSheet> createState() => _PayBillSheetState();
}

class _PayBillSheetState extends State<PayBillSheet> {
  String? _from;
  bool _record = true;

  @override
  void initState() {
    super.initState();
    final accs = StoreScope.read(context).accounts.where((a) => a.type != AccountType.loan).toList();
    _from = accs.isEmpty ? null : accs.first.id;
  }

  @override
  Widget build(BuildContext context) {
    final store = context.store;
    final b = widget.bill;
    return FormSheet(
      title: 'Mark ${b.name} paid',
      actions: [
        FilledButton(
          onPressed: () {
            store.payBill(b, fromAccountId: _record ? _from : null);
            final messenger = ScaffoldMessenger.of(context);
            Navigator.pop(context);
            messenger.showSnackBar(SnackBar(
              content: Text(b.repeat == Repeat.once ? '${b.name} paid' : '${b.name} paid. Next due ${dayMonth(b.due)}.'),
            ));
          },
          child: Text('Mark ${inr(b.amount)} paid'),
        ),
      ],
      children: [
        Text('Pay this in your bank or UPI app first, then record it here.', style: context.tt.bodyMedium),
        const SizedBox(height: 10),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          value: _record,
          onChanged: (v) => setState(() => _record = v),
          title: const Text('Add it to my passbook'),
          subtitle: const Text('Records the payment as spending'),
        ),
        if (_record)
          DropdownButtonFormField<String>(
            value: _from,
            decoration: const InputDecoration(labelText: 'Paid from'),
            items: [
              for (final a in store.accounts.where((a) => a.type != AccountType.loan))
                DropdownMenuItem(value: a.id, child: Text(a.name, overflow: TextOverflow.ellipsis)),
            ],
            onChanged: (v) => setState(() => _from = v),
          ),
      ],
    );
  }
}

class BillSheet extends StatefulWidget {
  const BillSheet({super.key});

  @override
  State<BillSheet> createState() => _BillSheetState();
}

class _BillSheetState extends State<BillSheet> {
  final _name = TextEditingController();
  final _amount = TextEditingController();
  BillKind _kind = BillKind.bill;
  Repeat _repeat = Repeat.monthly;
  DateTime _due = DateTime.now().add(const Duration(days: 7));
  String? _error;

  @override
  void dispose() {
    _name.dispose();
    _amount.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final store = context.store;
    return FormSheet(
      title: 'New bill or EMI',
      actions: [
        FilledButton(
          onPressed: () {
            final amt = parseAmount(_amount.text);
            if (_name.text.trim().isEmpty || amt == null || amt <= 0) {
              setState(() => _error = 'Add a name and an amount above zero.');
              return;
            }
            store.addBill(Bill(id: store.newId(), name: _name.text.trim(), amount: amt, due: _due, kind: _kind, repeat: _repeat));
            Navigator.pop(context);
          },
          child: const Text('Save'),
        ),
      ],
      children: [
        Wrap(
          spacing: 6,
          runSpacing: 6,
          children: [
            for (final k in BillKind.values)
              ChoiceChip(
                avatar: Icon(k.icon, size: 16),
                label: Text(k.label),
                selected: _kind == k,
                onSelected: (_) => setState(() => _kind = k),
              ),
          ],
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _name,
          textCapitalization: TextCapitalization.sentences,
          decoration: const InputDecoration(labelText: 'Name', hintText: 'e.g. Home loan EMI'),
        ),
        const SizedBox(height: 12),
        AmountField(controller: _amount, error: _error),
        const SizedBox(height: 12),
        Wrap(
          spacing: 6,
          runSpacing: 6,
          children: [
            for (final r in Repeat.values)
              ChoiceChip(label: Text(r.label), selected: _repeat == r, onSelected: (_) => setState(() => _repeat = r)),
          ],
        ),
        const SizedBox(height: 12),
        OutlinedButton.icon(
          onPressed: () async {
            final d = await showDatePicker(
              context: context,
              initialDate: _due,
              firstDate: DateTime.now().subtract(const Duration(days: 60)),
              lastDate: DateTime.now().add(const Duration(days: 730)),
              helpText: 'Next due date',
            );
            if (d != null) setState(() => _due = d);
          },
          icon: const Icon(Icons.event_outlined),
          label: Text('Next due ${dayMonthYear(_due)}'),
        ),
      ],
    );
  }
}

// ── Goals ────────────────────────────────────────────────────────────

class _Goals extends StatelessWidget {
  const _Goals();

  @override
  Widget build(BuildContext context) {
    final store = context.store;
    final hc = context.hc;
    if (store.goals.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 24),
        child: Text('Set a goal — an emergency fund, a house, a trip — and see how much to save each month.',
            style: context.tt.bodyMedium),
      );
    }
    return Column(
      children: [
        for (final g in store.goals)
          Padding(
            padding: const EdgeInsets.only(top: 12),
            child: Paper(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(goalIcons[g.icon % goalIcons.length], color: hc.brass),
                      const SizedBox(width: 10),
                      Expanded(child: Text(g.name, style: context.tt.titleMedium)),
                      PopupMenuButton<String>(
                        tooltip: 'More',
                        onSelected: (v) async {
                          if (v == 'delete' && await confirm(context, 'Delete ${g.name}?', 'Saved progress will be lost.', 'Delete')) {
                            store.removeGoal(g);
                          }
                        },
                        itemBuilder: (_) => const [PopupMenuItem(value: 'delete', child: Text('Delete goal'))],
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text('${store.money(g.saved)} saved', style: money(context, 30)),
                  Text('of ${store.money(g.target)} by ${monthYear(g.by)}', style: context.tt.bodySmall),
                  const SizedBox(height: 10),
                  Meter(value: g.progress, color: hc.brass, height: 10),
                  const SizedBox(height: 10),
                  Text(
                    g.progress >= 1
                        ? 'Goal reached. Well done!'
                        : 'Save ${store.money(g.monthlyNeeded.ceil())} a month to get there on time.',
                    style: context.tt.bodyMedium,
                  ),
                  const SizedBox(height: 8),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: OutlinedButton.icon(
                      onPressed: () => showForm(context, ContributeSheet(goal: g)),
                      icon: const Icon(Icons.add),
                      label: const Text('Add money'),
                    ),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }
}

class ContributeSheet extends StatefulWidget {
  const ContributeSheet({super.key, required this.goal});

  final Goal goal;

  @override
  State<ContributeSheet> createState() => _ContributeSheetState();
}

class _ContributeSheetState extends State<ContributeSheet> {
  final _ctrl = TextEditingController();

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final store = context.store;
    return FormSheet(
      title: 'Add to ${widget.goal.name}',
      actions: [
        FilledButton(
          onPressed: () {
            final a = parseAmount(_ctrl.text);
            if (a == null || a <= 0) return;
            store.contribute(widget.goal, a);
            Navigator.pop(context);
          },
          child: const Text('Add'),
        ),
      ],
      children: [
        AmountField(controller: _ctrl, autofocus: true),
        const SizedBox(height: 8),
        Text('Suggested this month: ${inr(widget.goal.monthlyNeeded.ceil())}', style: context.tt.bodySmall),
      ],
    );
  }
}

class GoalSheet extends StatefulWidget {
  const GoalSheet({super.key});

  @override
  State<GoalSheet> createState() => _GoalSheetState();
}

class _GoalSheetState extends State<GoalSheet> {
  final _name = TextEditingController();
  final _target = TextEditingController();
  final _saved = TextEditingController();
  DateTime _by = DateTime(DateTime.now().year + 1, DateTime.now().month);
  int _icon = 0;
  String? _error;

  @override
  void dispose() {
    _name.dispose();
    _target.dispose();
    _saved.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final store = context.store;
    final hc = context.hc;
    final target = parseAmount(_target.text) ?? 0;
    final preview = Goal(id: '', name: '', target: target, saved: parseAmount(_saved.text) ?? 0, by: _by);
    return FormSheet(
      title: 'New goal',
      actions: [
        FilledButton(
          onPressed: () {
            if (_name.text.trim().isEmpty || target <= 0) {
              setState(() => _error = 'Add a name and a target amount.');
              return;
            }
            store.addGoal(Goal(
              id: store.newId(),
              name: _name.text.trim(),
              target: target,
              saved: parseAmount(_saved.text) ?? 0,
              by: _by,
              icon: _icon,
            ));
            Navigator.pop(context);
          },
          child: const Text('Create goal'),
        ),
      ],
      children: [
        Wrap(
          spacing: 6,
          children: [
            for (var i = 0; i < goalIcons.length; i++)
              IconButton(
                tooltip: 'Icon ${i + 1}',
                isSelected: _icon == i,
                style: IconButton.styleFrom(backgroundColor: _icon == i ? hc.greenSoft : null),
                onPressed: () => setState(() => _icon = i),
                icon: Icon(goalIcons[i], color: _icon == i ? hc.brass : hc.muted),
              ),
          ],
        ),
        const SizedBox(height: 8),
        TextField(
          controller: _name,
          textCapitalization: TextCapitalization.sentences,
          decoration: InputDecoration(labelText: 'Goal', hintText: 'e.g. Emergency fund', errorText: _error),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _target,
          keyboardType: TextInputType.number,
          onChanged: (_) => setState(() {}),
          decoration: const InputDecoration(labelText: 'Target amount', prefixText: '₹ '),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _saved,
          keyboardType: TextInputType.number,
          onChanged: (_) => setState(() {}),
          decoration: const InputDecoration(labelText: 'Already saved (optional)', prefixText: '₹ '),
        ),
        const SizedBox(height: 12),
        OutlinedButton.icon(
          onPressed: () async {
            final d = await showDatePicker(
              context: context,
              initialDate: _by,
              firstDate: DateTime.now(),
              lastDate: DateTime(DateTime.now().year + 40),
              helpText: 'Reach it by',
            );
            if (d != null) setState(() => _by = d);
          },
          icon: const Icon(Icons.flag_outlined),
          label: Text('Reach it by ${monthYear(_by)}'),
        ),
        if (target > 0) ...[
          const SizedBox(height: 12),
          Text('You\'ll need to save about ${inr(preview.monthlyNeeded.ceil())} a month.',
              style: context.tt.titleSmall!.copyWith(color: hc.brass)),
        ],
      ],
    );
  }
}
