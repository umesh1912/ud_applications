import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../data.dart';
import '../store.dart';
import '../theme.dart';
import '../widgets.dart';
import 'pay_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key, required this.openTab});

  final ValueChanged<int> openTab;

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final _number = TextEditingController();
  String _search = '';

  @override
  void dispose() {
    _number.dispose();
    super.dispose();
  }

  void _open(Widget w) => Navigator.of(context).push(MaterialPageRoute(builder: (_) => w));

  @override
  Widget build(BuildContext context) {
    final store = context.store;
    final jc = context.jc;
    final due = store.dueSoon;
    final matches = _search.isEmpty
        ? <Kind>[]
        : Kind.values.where((k) =>
            k.label.toLowerCase().contains(_search) || (billers[k] ?? []).any((b) => b.toLowerCase().contains(_search))).toList();

    return SafeArea(
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 14, 20, 32),
        children: [
          Row(
            children: [
              Expanded(
                child: Text('Jhatpat', style: context.tt.displaySmall),
              ),
              InkWell(
                borderRadius: BorderRadius.circular(99),
                onTap: () => widget.openTab(2),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(color: jc.mintSoft, borderRadius: BorderRadius.circular(99)),
                  child: Row(
                    children: [
                      Icon(Icons.account_balance_wallet_outlined, size: 18, color: jc.mint),
                      const SizedBox(width: 6),
                      Text(inr(store.walletBalance), style: context.tt.labelLarge!.copyWith(color: jc.mint, fontFeatures: tabular)),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),

          // Hero ticket: recharge any number.
          Ticket(
            color: jc.saffron,
            top: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text('Recharge a mobile', style: context.tt.headlineMedium!.copyWith(color: jc.onSaffron)),
                const SizedBox(height: 4),
                Text('We find the operator and circle for you.', style: context.tt.bodyMedium!.copyWith(color: jc.onSaffron)),
              ],
            ),
            bottom: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _number,
                    keyboardType: TextInputType.phone,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly, LengthLimitingTextInputFormatter(10)],
                    style: context.tt.titleLarge,
                    decoration: const InputDecoration(hintText: '10-digit number', prefixText: '+91 '),
                    onSubmitted: (v) => _open(PayScreen(kind: Kind.mobile, prefillNumber: v)),
                  ),
                ),
                const SizedBox(width: 10),
                IconButton.filled(
                  tooltip: 'See plans',
                  style: IconButton.styleFrom(backgroundColor: jc.ink, foregroundColor: jc.bg, minimumSize: const Size(54, 54)),
                  onPressed: () => _open(PayScreen(kind: Kind.mobile, prefillNumber: _number.text)),
                  icon: const Icon(Icons.arrow_forward),
                ),
              ],
            ),
          ),

          if (due.isNotEmpty) ...[
            const Section('Coming up'),
            for (final s in due)
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Ticket(
                  onTap: () => _open(PayScreen(kind: s.kind, saved: s)),
                  top: Row(
                    children: [
                      KindIcon(s.kind, size: 40),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(s.nickname, style: context.tt.titleMedium),
                            Text('${s.biller} · ${s.accountId}', style: context.tt.bodySmall, maxLines: 1, overflow: TextOverflow.ellipsis),
                          ],
                        ),
                      ),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(dueText(s.nextDue!, expiry: s.kind.plans),
                              style: context.tt.labelMedium!.copyWith(
                                color: s.nextDue!.isBefore(DateTime.now().add(const Duration(days: 2))) ? jc.danger : jc.ink,
                              )),
                          if (s.autopay) Text('AutoPay on', style: context.tt.labelSmall!.copyWith(color: jc.mint)),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
          ],

          if (store.saved.isNotEmpty) ...[
            Section('Saved', action: 'Manage', onAction: () => widget.openTab(3)),
            SizedBox(
              height: 98,
              child: ListView(
                scrollDirection: Axis.horizontal,
                children: [
                  for (final s in store.saved) ...[
                    SizedBox(
                      width: 128,
                      child: Paper(
                        padding: const EdgeInsets.all(12),
                        onTap: () => _open(PayScreen(kind: s.kind, saved: s)),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Icon(s.kind.icon, size: 22),
                            const Spacer(),
                            Text(s.nickname, maxLines: 1, overflow: TextOverflow.ellipsis, style: context.tt.titleSmall),
                            Text(s.lastAmount == null ? s.biller : 'Last ${inr(s.lastAmount!)}',
                                maxLines: 1, overflow: TextOverflow.ellipsis, style: context.tt.bodySmall),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                  ],
                ],
              ),
            ),
          ],

          const SizedBox(height: 18),
          TextField(
            onChanged: (v) => setState(() => _search = v.trim().toLowerCase()),
            decoration: const InputDecoration(prefixIcon: Icon(Icons.search), hintText: 'Search: electricity, Tata Play, FASTag…'),
          ),
          if (_search.isNotEmpty) ...[
            const SizedBox(height: 10),
            if (matches.isEmpty)
              Text('Nothing matches "$_search". Try the category, like "water" or "loan".', style: context.tt.bodyMedium)
            else
              for (final k in matches)
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: KindIcon(k, size: 38),
                  title: Text(k.label, style: context.tt.titleSmall),
                  subtitle: Text((billers[k] ?? []).take(3).join(', '), style: context.tt.bodySmall, maxLines: 1, overflow: TextOverflow.ellipsis),
                  onTap: () => _open(PayScreen(kind: k)),
                ),
          ] else
            for (final (title, kinds) in kindGroups) ...[
              Section(title),
              _KindGrid(kinds: kinds, onTap: (k) => _open(PayScreen(kind: k))),
            ],

          Section('Offers', action: 'Rewards', onAction: () => widget.openTab(2)),
          SizedBox(
            height: 132,
            child: ListView(
              scrollDirection: Axis.horizontal,
              children: [
                for (final o in offers) ...[
                  SizedBox(
                    width: 240,
                    child: Ticket(
                      color: jc.mintSoft,
                      top: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(o.title, style: context.tt.titleSmall, maxLines: 2),
                          const SizedBox(height: 2),
                          Text(o.detail, style: context.tt.bodySmall, maxLines: 1, overflow: TextOverflow.ellipsis),
                        ],
                      ),
                      bottom: Text('Code ${o.code}', style: context.tt.labelLarge!.copyWith(color: jc.mint)),
                    ),
                  ),
                  const SizedBox(width: 10),
                ],
              ],
            ),
          ),
          const SizedBox(height: 18),
          const DemoNote(),
        ],
      ),
    );
  }
}

class _KindGrid extends StatelessWidget {
  const _KindGrid({required this.kinds, required this.onTap});

  final List<Kind> kinds;
  final ValueChanged<Kind> onTap;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, box) {
        const cols = 4;
        final w = (box.maxWidth - (cols - 1) * 8) / cols;
        return Wrap(
          spacing: 8,
          runSpacing: 12,
          children: [
            for (final k in kinds)
              SizedBox(
                width: w,
                child: Semantics(
                  button: true,
                  label: k.label,
                  child: InkWell(
                    borderRadius: BorderRadius.circular(14),
                    onTap: () => onTap(k),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 6),
                      child: Column(
                        children: [
                          KindIcon(k, size: 50),
                          const SizedBox(height: 6),
                          Text(k.label, textAlign: TextAlign.center, maxLines: 2, style: context.tt.labelMedium),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}
