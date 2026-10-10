import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:ud_core/ud_core.dart';

import 'strings.dart';

const appName = 'BillBook';

final bills = UdListStore('bills.items');

void main() => runUdApp(UdAppSpec(
      name: appName,
      taglineKey: 'tagline',
      accent: const Color(0xFF3D5A80),
      icon: Icons.receipt_long_rounded,
      strings: billStrings,
      home: (_) => const HomePage(),
    ));

const categories = <String, IconData>{
  'electricity': Icons.bolt_rounded,
  'gas': Icons.local_fire_department_outlined,
  'water': Icons.water_drop_outlined,
  'mobile': Icons.smartphone_rounded,
  'dth': Icons.tv_rounded,
  'broadband': Icons.wifi_rounded,
  'card': Icons.credit_card_rounded,
  'insurance': Icons.health_and_safety_outlined,
  'rent': Icons.home_outlined,
  'other': Icons.receipt_outlined,
};

/// Common billers with their official websites.
const providers = <String, Map<String, String>>{
  'electricity': {
    'DGVCL (South Gujarat)': 'https://www.dgvcl.com',
    'MGVCL (Central Gujarat)': 'https://www.mgvcl.com',
    'PGVCL (Saurashtra)': 'https://www.pgvcl.com',
    'UGVCL (North Gujarat)': 'https://www.ugvcl.com',
    'Torrent Power': 'https://www.torrentpower.com',
  },
  'gas': {
    'Gujarat Gas': 'https://www.gujaratgas.com',
    'Adani Total Gas': 'https://www.adanigas.com',
  },
  'mobile': {
    'Jio': 'https://www.jio.com',
    'Airtel': 'https://www.airtel.in',
    'Vi': 'https://www.myvi.in',
    'BSNL': 'https://www.bsnl.co.in',
  },
  'dth': {
    'Tata Play': 'https://www.tataplay.com',
    'Airtel Digital TV': 'https://www.airtel.in/dth',
    'Dish TV': 'https://www.dishtv.in',
  },
  'broadband': {
    'JioFiber': 'https://www.jio.com',
    'Airtel Xstream Fiber': 'https://www.airtel.in',
  },
  'insurance': {
    'LIC': 'https://licindia.in',
  },
};

String thisMonth() {
  final n = DateTime.now();
  return '${n.year}-${udTwo(n.month)}';
}

bool paidThisMonth(Map<String, dynamic> b) => b['lastPaid'] == thisMonth();

/// Days until this month's due date (negative = overdue).
int daysToDue(Map<String, dynamic> b) {
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  final lastDay = DateTime(now.year, now.month + 1, 0).day;
  final day = min((b['dueDay'] as num).toInt(), lastDay);
  return DateTime(now.year, now.month, day).difference(today).inDays;
}

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  @override
  void initState() {
    super.initState();
    bills.load();
  }

  void _go(Widget page) => Navigator.of(context).push(MaterialPageRoute(builder: (_) => page));

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: bills,
      builder: (context, _) {
        final t = UdTokens.of(context);
        final text = Theme.of(context).textTheme;
        final items = [...bills.items]
          ..sort((a, b) {
            final pa = paidThisMonth(a) ? 1 : 0, pb = paidThisMonth(b) ? 1 : 0;
            if (pa != pb) return pa - pb;
            return daysToDue(a).compareTo(daysToDue(b));
          });
        final paid = items.where(paidThisMonth).length;
        final dueAmount = items
            .where((b) => !paidThisMonth(b))
            .fold<double>(0, (s, b) => s + ((b['amount'] as num?)?.toDouble() ?? 0));
        return UdPage(
          eyebrow: appName,
          title: context.tr('home_title'),
          subtitle: context.tr('home_sub', {'a': '${items.length - paid}', 'b': '$paid'}),
          actions: const [UdSettingsButton(appName: appName)],
          dock: UdDock(label: context.tr('add'), icon: Icons.add_rounded, onPressed: () => _go(const BillForm())),
          slivers: [
            if (items.isNotEmpty && dueAmount > 0)
              UdSliverPad(
                bottom: 16,
                sliver: SliverToBoxAdapter(
                  child: Container(
                    padding: const EdgeInsets.all(18),
                    decoration: BoxDecoration(color: t.ink, borderRadius: BorderRadius.circular(24)),
                    child: Row(children: [
                      Expanded(
                        child: Text(context.tr('due_total'),
                            style: text.titleMedium?.copyWith(color: t.paper.withValues(alpha: 0.8))),
                      ),
                      Text(udRupees(dueAmount), style: text.headlineMedium?.copyWith(color: t.paper)),
                    ]),
                  ),
                ),
              ),
            if (bills.loaded && items.isEmpty)
              SliverToBoxAdapter(
                child: UdEmpty(icon: Icons.receipt_long_outlined, title: context.tr('empty_title'), body: context.tr('empty_body')),
              )
            else
              UdSliverPad(
                sliver: SliverList.list(children: [
                  for (final b in items)
                    UdRow(
                      leading: UdBadgeIcon(categories[b['category']] ?? Icons.receipt_outlined),
                      title: b['provider'] as String,
                      subtitle: [
                        context.tr('c_${b['category']}'),
                        if (b['amount'] != null) udRupees(b['amount'] as num),
                      ].join(' · '),
                      trailing: _DueBadge(bill: b),
                      onTap: () => _go(BillPage(id: b['id'] as String)),
                    ),
                ]),
              ),
          ],
        );
      },
    );
  }
}

class _DueBadge extends StatelessWidget {
  const _DueBadge({required this.bill});
  final Map<String, dynamic> bill;

  @override
  Widget build(BuildContext context) {
    final t = UdTokens.of(context);
    final text = Theme.of(context).textTheme;
    String label;
    Color c;
    if (paidThisMonth(bill)) {
      label = context.tr('paid_month');
      c = const Color(0xFF2F7D4F);
    } else {
      final d = daysToDue(bill);
      if (d < 0) {
        label = context.tr('overdue', {'n': '${-d}'});
        c = t.danger;
      } else if (d == 0) {
        label = context.tr('due_today');
        c = t.danger;
      } else {
        label = context.tr('due_in', {'n': '$d'});
        c = d <= 5 ? const Color(0xFFB7791F) : t.inkSoft;
      }
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(color: c.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(12)),
      child: Text(label, style: text.labelSmall?.copyWith(color: c)),
    );
  }
}

class BillForm extends StatefulWidget {
  const BillForm({super.key, this.initial});
  final Map<String, dynamic>? initial;

  @override
  State<BillForm> createState() => _BillFormState();
}

class _BillFormState extends State<BillForm> {
  late String _cat = widget.initial?['category'] as String? ?? 'electricity';
  late final _provider = TextEditingController(text: widget.initial?['provider'] as String? ?? '');
  late final _consumer = TextEditingController(text: widget.initial?['consumer'] as String? ?? '');
  late final _amount = TextEditingController(
      text: widget.initial?['amount'] == null ? '' : '${(widget.initial!['amount'] as num).round()}');
  late int _day = (widget.initial?['dueDay'] as num?)?.toInt() ?? 10;

  Future<void> _save() async {
    final provider = _provider.text.trim();
    if (provider.isEmpty || (_consumer.text.trim().isEmpty && _cat != 'rent')) {
      udToast(context, context.tr('needs_fields'));
      return;
    }
    final b = {
      ...?widget.initial,
      'category': _cat,
      'provider': provider,
      'consumer': _consumer.text.trim(),
      'dueDay': _day,
      'amount': udParseNum(_amount.text),
      'url': providers[_cat]?[provider],
    };
    if (b['id'] == null) {
      await bills.add(b);
    } else {
      await bills.put(b);
    }
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    Widget field(TextEditingController c, String label, {TextInputType? type}) => Padding(
          padding: const EdgeInsets.only(bottom: 14),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Padding(padding: const EdgeInsets.only(left: 4, bottom: 6), child: Text(label, style: text.labelMedium)),
            TextField(controller: c, keyboardType: type, style: text.bodyLarge, decoration: udInputDecoration(context)),
          ]),
        );
    return UdPage(
      title: context.tr('add'),
      dock: UdDock(label: context.tr('save_bill'), icon: Icons.check_rounded, onPressed: _save),
      slivers: [
        UdSliverPad(
          sliver: SliverList.list(children: [
            UdLabel(context.tr('category')),
            Wrap(spacing: 8, runSpacing: 8, children: [
              for (final e in categories.entries)
                ChoiceChip(
                  avatar: Icon(e.value, size: 18),
                  label: Text(context.tr('c_${e.key}')),
                  selected: e.key == _cat,
                  showCheckmark: false,
                  onSelected: (_) => setState(() => _cat = e.key),
                ),
            ]),
            const SizedBox(height: 18),
            if (providers[_cat] != null) ...[
              Wrap(spacing: 8, runSpacing: 8, children: [
                for (final p in providers[_cat]!.keys)
                  ActionChip(label: Text(p), onPressed: () => setState(() => _provider.text = p)),
              ]),
              const SizedBox(height: 12),
            ],
            field(_provider, context.tr('provider')),
            field(_consumer, context.tr('consumer'), type: TextInputType.text),
            field(_amount, context.tr('amount'), type: TextInputType.number),
            UdLabel(context.tr('due_day')),
            Row(children: [
              Expanded(
                child: Slider(
                  value: _day.toDouble(),
                  min: 1,
                  max: 31,
                  divisions: 30,
                  label: '$_day',
                  onChanged: (v) => setState(() => _day = v.round()),
                ),
              ),
              SizedBox(width: 44, child: Text('$_day', style: text.headlineSmall, textAlign: TextAlign.end)),
            ]),
          ]),
        ),
      ],
    );
  }
}

class BillPage extends StatelessWidget {
  const BillPage({super.key, required this.id});
  final String id;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: bills,
      builder: (context, _) {
        Map<String, dynamic>? found;
        for (final b in bills.items) {
          if (b['id'] == id) found = b;
        }
        final b = found;
        if (b == null) return const Scaffold();
        final t = UdTokens.of(context);
        final text = Theme.of(context).textTheme;
        final history = (b['history'] as List? ?? const []).cast<Map>();
        final url = b['url'] as String?;
        final paid = paidThisMonth(b);

        Future<void> markPaid() async {
          if (paid) {
            b['lastPaid'] = null;
            await bills.put(b);
            return;
          }
          final amt = await udPrompt(context,
              title: context.tr('paid_amount'),
              initial: b['amount'] == null ? '' : '${(b['amount'] as num).round()}');
          if (amt == null) return;
          b['lastPaid'] = thisMonth();
          b['history'] = [
            {'date': DateTime.now().toIso8601String(), 'amount': udParseNum(amt)},
            ...history,
          ];
          await bills.put(b);
        }

        return UdPage(
          title: b['provider'] as String,
          subtitle: context.tr('c_${b['category']}'),
          actions: [
            UdIconButton(
              icon: Icons.edit_outlined,
              onTap: () => Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => BillForm(initial: Map<String, dynamic>.from(b)))),
            ),
            UdIconButton(
              icon: Icons.delete_outline_rounded,
              onTap: () async {
                if (!await udConfirm(context)) return;
                await bills.remove(id);
                if (context.mounted) Navigator.of(context).pop();
              },
            ),
          ],
          dock: UdDock(
            label: url != null && !paid ? context.tr('pay_now') : context.tr(paid ? 'undo_paid' : 'mark_paid'),
            icon: url != null && !paid ? Icons.open_in_new_rounded : Icons.check_circle_outline_rounded,
            onPressed: () => url != null && !paid ? udOpenUrl(url) : markPaid(),
            extras: [
              if (url != null && !paid)
                UdDockAction(icon: Icons.check_circle_outline_rounded, label: context.tr('mark_paid'), onTap: markPaid),
            ],
          ),
          slivers: [
            UdSliverPad(
              sliver: SliverList.list(children: [
                Container(
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    color: t.card,
                    borderRadius: BorderRadius.circular(22),
                    border: Border.all(color: t.line),
                  ),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(context.tr('consumer'), style: text.labelMedium?.copyWith(color: t.inkSoft)),
                    const SizedBox(height: 4),
                    Row(children: [
                      Expanded(child: SelectableText(b['consumer'] as String? ?? '', style: text.headlineSmall)),
                      TextButton.icon(
                        onPressed: () {
                          Clipboard.setData(ClipboardData(text: b['consumer'] as String? ?? ''));
                          udToast(context, context.tr('copied'));
                        },
                        icon: const Icon(Icons.copy_rounded, size: 18),
                        label: Text(context.tr('copy_consumer')),
                      ),
                    ]),
                    const SizedBox(height: 12),
                    _DueBadge(bill: b),
                  ]),
                ),
                const SizedBox(height: 10),
                Text(context.tr('pay_hint'), style: text.bodySmall?.copyWith(color: t.inkSoft)),
                const SizedBox(height: 20),
                UdLabel(context.tr('history')),
                if (history.isEmpty)
                  Text(context.tr('no_history'), style: text.bodyMedium?.copyWith(color: t.inkSoft))
                else
                  for (final h in history)
                    UdRow(
                      leading: const UdBadgeIcon(Icons.check_rounded, size: 40, color: Color(0xFF2F7D4F)),
                      title: h['amount'] == null ? '—' : udRupees(h['amount'] as num),
                      subtitle: udFormatDate(context, DateTime.parse(h['date'] as String)),
                    ),
              ]),
            ),
          ],
        );
      },
    );
  }
}
