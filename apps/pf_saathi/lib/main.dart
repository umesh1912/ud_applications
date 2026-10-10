import 'dart:math';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:ud_core/ud_core.dart';

import 'strings.dart';

const appName = 'PF Saathi';

/// EPFO's published numbers (see passbook.epfindia.gov.in).
const kMissedCall = '9966044425';
const kSmsNumber = '7738299899';
const kPassbook = 'https://passbook.epfindia.gov.in/MemberPassBook/Login';
const kPortal = 'https://unifiedportal-mem.epfindia.gov.in/memberinterface/';
const kUmang = 'https://web.umang.gov.in';
const kInterest = 8.25; // FY 2025-26

const smsLanguages = {
  'ENG': 'English',
  'HIN': 'हिन्दी',
  'GUJ': 'ગુજરાતી',
  'MAR': 'मराठी',
  'PUN': 'ਪੰਜਾਬੀ',
  'BEN': 'বাংলা',
  'KAN': 'ಕನ್ನಡ',
  'TEL': 'తెలుగు',
  'TAM': 'தமிழ்',
  'MAL': 'മലയാളം',
};

void main() => runUdApp(UdAppSpec(
      name: appName,
      taglineKey: 'tagline',
      accent: const Color(0xFF4C6A1F),
      icon: Icons.savings_outlined,
      strings: pfStrings,
      home: (_) => const HomePage(),
    ));

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  SharedPreferences? _p;
  final _uan = TextEditingController();
  String _lang = 'ENG';

  @override
  void initState() {
    super.initState();
    SharedPreferences.getInstance().then((p) {
      if (!mounted) return;
      final app = context.udSettings.lang;
      setState(() {
        _p = p;
        _uan.text = p.getString('pf.uan') ?? '';
        _lang = p.getString('pf.lang') ?? (app == 'hi' ? 'HIN' : app == 'gu' ? 'GUJ' : 'ENG');
      });
    });
  }

  String get _cleanUan => _uan.text.replaceAll(RegExp(r'\D'), '');

  Future<void> _saveUan() async {
    if (_cleanUan.length != 12) {
      udToast(context, context.tr('uan_invalid'));
      return;
    }
    await _p?.setString('pf.uan', _cleanUan);
    if (mounted) udToast(context, context.tr('saved'));
  }

  Future<void> _sms() async {
    if (_cleanUan.length != 12) {
      udToast(context, context.tr('uan_invalid'));
      return;
    }
    await _p?.setString('pf.uan', _cleanUan);
    final body = Uri.encodeComponent('EPFOHO $_cleanUan $_lang');
    await udOpenUrl('sms:$kSmsNumber?body=$body');
  }

  @override
  Widget build(BuildContext context) {
    final t = UdTokens.of(context);
    final text = Theme.of(context).textTheme;
    return UdPage(
      eyebrow: appName,
      title: context.tr('home_title'),
      subtitle: context.tr('home_sub'),
      actions: const [UdSettingsButton(appName: appName)],
      dock: UdDock(
        label: context.tr('check_balance'),
        icon: Icons.call_rounded,
        onPressed: () => udOpenUrl('tel:$kMissedCall'),
      ),
      slivers: [
        UdSliverPad(
          sliver: SliverList.list(children: [
            Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Padding(
                      padding: const EdgeInsets.only(left: 4, bottom: 6),
                      child: Text(context.tr('uan'), style: text.labelMedium)),
                  TextField(
                    controller: _uan,
                    keyboardType: TextInputType.number,
                    maxLength: 12,
                    style: text.titleLarge?.copyWith(letterSpacing: 2),
                    decoration: udInputDecoration(context, hint: context.tr('uan_hint')).copyWith(counterText: ''),
                  ),
                ]),
              ),
              const SizedBox(width: 10),
              SizedBox(
                height: 56,
                child: OutlinedButton(onPressed: _saveUan, child: Text(context.tr('save_uan'))),
              ),
            ]),
            const SizedBox(height: 18),
            UdRow(
              leading: const UdBadgeIcon(Icons.phone_callback_outlined),
              title: '${context.tr('missed_call')} · $kMissedCall',
              subtitle: context.tr('missed_call_sub'),
              onTap: () => udOpenUrl('tel:$kMissedCall'),
            ),
            UdPressable(
              onTap: _sms,
              padding: const EdgeInsets.all(14),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: [
                  const UdBadgeIcon(Icons.sms_outlined),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(context.tr('sms'), style: text.titleMedium),
                      Text(context.tr('sms_sub', {'lang': _lang}),
                          style: text.bodySmall?.copyWith(color: t.inkSoft)),
                    ]),
                  ),
                ]),
                const SizedBox(height: 12),
                Text(context.tr('sms_lang'), style: text.labelSmall),
                const SizedBox(height: 6),
                Wrap(spacing: 6, runSpacing: 6, children: [
                  for (final e in smsLanguages.entries)
                    ChoiceChip(
                      label: Text(e.value),
                      selected: e.key == _lang,
                      showCheckmark: false,
                      visualDensity: VisualDensity.compact,
                      onSelected: (_) {
                        setState(() => _lang = e.key);
                        _p?.setString('pf.lang', e.key);
                      },
                    ),
                ]),
              ]),
            ),
            const SizedBox(height: 18),
            UdLabel(context.tr('official')),
            UdRow(
              leading: const UdBadgeIcon(Icons.menu_book_outlined),
              title: context.tr('passbook'),
              subtitle: context.tr('passbook_sub'),
              trailing: const Icon(Icons.open_in_new_rounded, size: 18),
              onTap: () => udOpenUrl(kPassbook),
            ),
            UdRow(
              leading: const UdBadgeIcon(Icons.account_circle_outlined),
              title: context.tr('portal'),
              subtitle: context.tr('portal_sub'),
              trailing: const Icon(Icons.open_in_new_rounded, size: 18),
              onTap: () => udOpenUrl(kPortal),
            ),
            UdRow(
              leading: const UdBadgeIcon(Icons.apps_rounded),
              title: context.tr('umang'),
              subtitle: context.tr('umang_sub'),
              trailing: const Icon(Icons.open_in_new_rounded, size: 18),
              onTap: () => udOpenUrl(kUmang),
            ),
            UdRow(
              leading: const UdBadgeIcon(Icons.trending_up_rounded),
              title: context.tr('calc'),
              subtitle: context.tr('calc_sub'),
              trailing: const Icon(Icons.chevron_right_rounded),
              onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const CalcPage())),
            ),
            const SizedBox(height: 14),
            UdLabel(context.tr('tips')),
            for (final k in const ['tip1', 'tip2', 'tip3'])
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Icon(Icons.info_outline_rounded, size: 18, color: t.accent),
                  const SizedBox(width: 10),
                  Expanded(child: Text(context.tr(k), style: text.bodyMedium)),
                ]),
              ),
          ]),
        ),
      ],
    );
  }
}

class CalcPage extends StatefulWidget {
  const CalcPage({super.key});

  @override
  State<CalcPage> createState() => _CalcPageState();
}

class _CalcPageState extends State<CalcPage> {
  final _basic = TextEditingController(text: '25000');
  final _age = TextEditingController(text: '28');
  final _retire = TextEditingController(text: '58');
  final _balance = TextEditingController(text: '0');
  final _hike = TextEditingController(text: '6');
  final _rate = TextEditingController(text: '$kInterest');

  @override
  Widget build(BuildContext context) {
    final t = UdTokens.of(context);
    final text = Theme.of(context).textTheme;
    var basic = udParseNum(_basic.text) ?? 0;
    final age = (udParseNum(_age.text) ?? 0).round();
    final retire = (udParseNum(_retire.text) ?? 58).round();
    final hike = (udParseNum(_hike.text) ?? 0) / 100;
    final rate = (udParseNum(_rate.text) ?? kInterest) / 100;
    var bal = udParseNum(_balance.text) ?? 0;

    final eps0 = 0.0833 * min(basic, 15000.0);
    final emp0 = 0.12 * basic;
    final er0 = 0.12 * basic - eps0;
    for (var y = age; y < retire; y++) {
      var interest = 0.0;
      for (var m = 0; m < 12; m++) {
        final eps = 0.0833 * min(basic, 15000.0);
        bal += 0.12 * basic + (0.12 * basic - eps);
        interest += bal * rate / 12;
      }
      bal += interest;
      basic *= 1 + hike;
    }

    Widget field(TextEditingController c, String label) => Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: TextField(
            controller: c,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            onChanged: (_) => setState(() {}),
            style: text.titleMedium,
            decoration: udInputDecoration(context).copyWith(labelText: label),
          ),
        );

    return UdPage(
      title: context.tr('calc'),
      slivers: [
        UdSliverPad(
          sliver: SliverList.list(children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(color: t.ink, borderRadius: BorderRadius.circular(24)),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(context.tr('corpus'), style: text.labelLarge?.copyWith(color: t.paper.withValues(alpha: 0.7))),
                FittedBox(child: Text(udRupeesShort(bal), style: text.displayMedium?.copyWith(color: t.paper))),
                const SizedBox(height: 10),
                for (final (k, v) in [
                  ('you_add', emp0),
                  ('employer_adds', er0),
                  ('eps_goes', eps0),
                ])
                  Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: Row(children: [
                      Expanded(
                          child: Text(context.tr(k),
                              style: text.bodyMedium?.copyWith(color: t.paper.withValues(alpha: 0.75)))),
                      Text(udRupees(v), style: text.titleMedium?.copyWith(color: t.paper)),
                    ]),
                  ),
              ]),
            ),
            const SizedBox(height: 20),
            field(_basic, context.tr('basic')),
            field(_age, context.tr('age')),
            field(_retire, context.tr('retire_age')),
            field(_balance, context.tr('balance')),
            field(_hike, context.tr('hike')),
            field(_rate, context.tr('rate')),
            Text(context.tr('rate_note'), style: text.bodySmall?.copyWith(color: t.inkSoft)),
          ]),
        ),
      ],
    );
  }
}
