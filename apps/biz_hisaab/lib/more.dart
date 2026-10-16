import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:ud_core/ud_core.dart';

import 'business.dart';
import 'db.dart';
import 'gst.dart';
import 'main.dart' show appName;
import 'reports.dart';
import 'txn_view.dart';
import 'ui.dart';

class MoreTab extends StatelessWidget {
  const MoreTab({super.key});

  @override
  Widget build(BuildContext context) {
    final rows = <(IconData, String, String, VoidCallback)>[
      (Icons.storefront_outlined, 'business_profile', 'business_profile_sub', () => go(context, const BusinessPage())),
      (Icons.receipt_outlined, 'invoice_settings', 'invoice_settings_sub', () => go(context, const InvoiceSettingsPage())),
      (Icons.account_balance_outlined, 'cash_bank', 'cash_bank_sub', () => go(context, const CashBankPage())),
      (Icons.bar_chart_rounded, 'reports', 'reports_sub', () => go(context, const ReportsPage())),
      (Icons.cloud_upload_outlined, 'backup', 'backup_sub', () => go(context, const BackupPage())),
      (Icons.lock_outline_rounded, 'app_lock', db.biz.pin.isEmpty ? 'app_lock_off' : 'app_lock_on', () => setPin(context)),
    ];
    return UdPage(
      title: context.tr('nav_more'),
      subtitle: db.biz.name,
      showBack: false,
      actions: const [UdSettingsButton(appName: appName)],
      slivers: [
        UdSliverPad(
          sliver: SliverList.list(children: [
            for (final r in rows)
              UdRow(
                leading: UdBadgeIcon(r.$1, size: 44),
                title: context.tr(r.$2),
                subtitle: context.tr(r.$3),
                trailing: const Icon(Icons.chevron_right_rounded),
                onTap: r.$4,
              ),
          ]),
        ),
      ],
    );
  }
}

Future<void> setPin(BuildContext context) async {
  if (db.biz.pin.isNotEmpty) {
    final off = await udConfirm(context, title: context.tr('app_lock'), body: context.tr('pin_remove_q'), confirmLabel: context.tr('pin_remove'));
    if (off) {
      db.biz.pin = '';
      await db.save();
    }
    return;
  }
  final pin = await udPrompt(context, title: context.tr('pin_set'), hint: '4 digits');
  if (pin == null) return;
  if (!RegExp(r'^\d{4}$').hasMatch(pin)) {
    if (context.mounted) udToast(context, context.tr('pin_4'));
    return;
  }
  db.biz.pin = pin;
  await db.save();
  if (context.mounted) udToast(context, context.tr('pin_on'));
}

// ---------------------------------------------------------------- cash & bank

class CashBankPage extends StatelessWidget {
  const CashBankPage({super.key});

  Future<void> _edit(BuildContext context, [Account? a]) async {
    final acc = a == null ? Account() : Account.fromJson(a.toJson());
    final name = TextEditingController(text: acc.name);
    final open = TextEditingController(text: numText(acc.opening));
    final no = TextEditingController(text: acc.accountNo);
    final ifsc = TextEditingController(text: acc.ifsc);
    final res = await showUdSheet<String>(context, (c) => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(c.tr(a == null ? 'add_bank' : 'edit_account'), style: Theme.of(c).textTheme.headlineSmall),
          const SizedBox(height: 16),
          if (acc.id != 'cash') Field(name, c.tr('account_name'), hint: 'SBI Current', caps: TextCapitalization.words, autofocus: a == null),
          Field(open, c.tr('opening_balance'), type: Field.number, prefix: '₹ '),
          if (acc.id != 'cash') ...[
            Field(no, c.tr('account_no'), type: TextInputType.number, hint: c.tr('optional')),
            Field(ifsc, 'IFSC', caps: TextCapitalization.characters, hint: c.tr('optional')),
          ],
          Row(children: [
            if (a != null && a.id != 'cash') ...[
              Expanded(child: OutlinedButton(onPressed: () => Navigator.pop(c, 'delete'), child: Text(c.tr('delete')))),
              const SizedBox(width: 12),
            ],
            Expanded(flex: 2, child: FilledButton(onPressed: () => Navigator.pop(c, 'save'), child: Text(c.tr('save')))),
          ]),
        ]));
    if (res == 'delete' && a != null) {
      if (context.mounted && await udConfirm(context, body: context.tr('account_delete_sub'))) await db.deleteAccount(a.id);
    } else if (res == 'save') {
      if (acc.id != 'cash') acc.name = name.text.trim().isEmpty ? 'Bank' : name.text.trim();
      acc
        ..opening = numOf(open)
        ..accountNo = no.text.trim()
        ..ifsc = ifsc.text.trim().toUpperCase();
      await db.putAccount(acc);
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: db,
      builder: (context, _) {
        final text = Theme.of(context).textTheme;
        return UdPage(
          title: context.tr('cash_bank'),
          dock: UdDock(label: context.tr('add_bank'), icon: Icons.add_rounded, onPressed: () => _edit(context)),
          slivers: [
            UdSliverPad(
              sliver: SliverList.list(children: [
                Summary(cells: [(context.tr('total_balance'), money(db.cashAndBank), null)]),
                for (final a in db.accounts)
                  UdRow(
                    leading: UdBadgeIcon(a.kind == 'cash' ? Icons.payments_outlined : Icons.account_balance_outlined, size: 44),
                    title: a.id == 'cash' ? context.tr('cash_in_hand') : a.name,
                    subtitle: a.accountNo.isEmpty ? null : 'A/c ${a.accountNo}',
                    trailing: Text(money(db.accountBalance(a.id)), style: text.titleMedium),
                    onTap: () => go(context, AccountPage(id: a.id, onEdit: () => _edit(context, db.account(a.id)))),
                  ),
                Padding(
                  padding: const EdgeInsets.all(8),
                  child: Text(context.tr('cash_bank_hint'), style: text.bodySmall),
                ),
              ]),
            ),
          ],
        );
      },
    );
  }
}

class AccountPage extends StatelessWidget {
  const AccountPage({super.key, required this.id, required this.onEdit});
  final String id;
  final VoidCallback onEdit;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: db,
      builder: (context, _) {
        final a = db.account(id);
        final text = Theme.of(context).textTheme;
        final t = UdTokens.of(context);
        final list = [for (final x in db.txns) if (x.type.cashSign != 0 && db.cashOf(x) > 0 && (x.accountId == id || (id == 'cash' && !db.accounts.any((e) => e.id == x.accountId)))) x]
          ..sort((x, y) => y.date.compareTo(x.date));
        return UdPage(
          title: a.id == 'cash' ? context.tr('cash_in_hand') : a.name,
          actions: [UdIconButton(icon: Icons.edit_outlined, tooltip: context.tr('edit'), onTap: onEdit)],
          slivers: [
            UdSliverPad(
              sliver: SliverList.list(children: [
                Summary(cells: [
                  (context.tr('balance'), money(db.accountBalance(id)), null),
                  (context.tr('opening_balance'), money(a.opening), null),
                ]),
                if (list.isEmpty) UdEmpty(icon: Icons.account_balance_wallet_outlined, title: context.tr('no_entries')),
                for (final x in list)
                  UdRow(
                    title: x.partyName.isNotEmpty ? x.partyName : typeLabel(context, x.type),
                    subtitle: '${typeLabel(context, x.type)} ${x.number} · ${dmy(x.date)} · ${context.tr('pm_${x.mode}')}',
                    trailing: Text('${x.type.cashSign > 0 ? '+' : '−'} ${money(db.cashOf(x))}',
                        style: text.titleSmall?.copyWith(color: x.type.cashSign > 0 ? green : t.danger)),
                    onTap: () => go(context, TxnView(id: x.id)),
                  ),
              ]),
            ),
          ],
        );
      },
    );
  }
}

// ---------------------------------------------------------------- backup

class BackupPage extends StatelessWidget {
  const BackupPage({super.key});

  Future<void> _export(BuildContext context) async {
    final dir = await udDir('hisaab/backup');
    final d = DateTime.now();
    final path = '${dir.path}/hisaab-backup-${d.year}-${two(d.month)}-${two(d.day)}.json';
    await File(path).writeAsString(jsonEncode(db.toJson()));
    await udShareFiles([path], text: context.mounted ? context.tr('backup_share_text', {'b': db.biz.name}) : null);
  }

  Future<void> _import(BuildContext context) async {
    final files = await udPickFiles(extensions: ['json']);
    if (files.isEmpty || !context.mounted) return;
    final ok = await udConfirm(context, title: context.tr('restore_q'), body: context.tr('restore_sub'), confirmLabel: context.tr('restore'));
    if (!ok) return;
    try {
      final done = await db.restore(await File(files.first).readAsString());
      if (context.mounted) udToast(context, context.tr(done ? 'restore_done' : 'restore_bad'));
    } catch (_) {
      if (context.mounted) udToast(context, context.tr('restore_bad'));
    }
  }

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return UdPage(
      title: context.tr('backup'),
      subtitle: context.tr('backup_long'),
      slivers: [
        UdSliverPad(
          sliver: SliverList.list(children: [
            Summary(cells: [
              (context.tr('nav_parties'), '${db.parties.length}', null),
              (context.tr('nav_items'), '${db.items.length}', null),
              (context.tr('nav_txns'), '${db.txns.length}', null),
            ]),
            UdRow(
              leading: const UdBadgeIcon(Icons.ios_share_rounded, size: 44),
              title: context.tr('backup_now'),
              subtitle: context.tr('backup_now_sub'),
              onTap: () => _export(context),
            ),
            UdRow(
              leading: const UdBadgeIcon(Icons.settings_backup_restore_rounded, size: 44),
              title: context.tr('restore'),
              subtitle: context.tr('restore_pick'),
              onTap: () => _import(context),
            ),
            Padding(padding: const EdgeInsets.all(8), child: Text(context.tr('backup_tip'), style: text.bodySmall)),
          ]),
        ),
      ],
    );
  }
}
