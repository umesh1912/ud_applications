import 'dart:async';

import 'package:flutter/material.dart';
import 'package:timezone/data/latest.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;
import 'package:ud_core/ud_core.dart';

import 'countries.dart';
import 'strings.dart';

const appName = 'Dial Abroad';

final contacts = UdListStore('dial.contacts');

void main() {
  tzdata.initializeTimeZones();
  runUdApp(UdAppSpec(
    name: appName,
    taglineKey: 'tagline',
    accent: const Color(0xFF127A7A),
    icon: Icons.public_rounded,
    strings: dialStrings,
    home: (_) => const HomePage(),
  ));
}

Country countryOf(String tzName, String code) => countries.firstWhere(
      (c) => c.tz == tzName && c.code == code,
      orElse: () => countries.firstWhere((c) => c.code == code, orElse: () => countries.first),
    );

DateTime localTime(Country c) => tz.TZDateTime.now(tz.getLocation(c.tz));

String hhmm(DateTime d) => '${udTwo(d.hour)}:${udTwo(d.minute)}';

String digits(String s) => s.replaceAll(RegExp(r'\D'), '').replaceFirst(RegExp(r'^0+'), '');

/// Difference from Indian time, e.g. "1 h 30 m".
String offsetLabel(BuildContext context, Country c) {
  final there = tz.getLocation(c.tz).currentTimeZone.offset;
  final india = tz.getLocation('Asia/Kolkata').currentTimeZone.offset;
  final diffMin = (there - india) ~/ 60000;
  if (diffMin == 0) return context.tr('same');
  final m = diffMin.abs();
  final h = '${m ~/ 60} h${m % 60 == 0 ? '' : ' ${m % 60} m'}';
  return context.tr(diffMin > 0 ? 'ahead' : 'behind', {'h': h});
}

(String, Color) callAdvice(BuildContext context, DateTime there) {
  final h = there.hour;
  if (h >= 9 && h < 21) return (context.tr('good_time'), const Color(0xFF2F7D4F));
  if (h >= 7 && h < 9) return (context.tr('early'), const Color(0xFFB7791F));
  if (h >= 21 && h < 23) return (context.tr('late'), const Color(0xFFB7791F));
  return (context.tr('sleeping'), const Color(0xFFB3261E));
}

void callNumber(String code, String number) => udOpenUrl('tel:+$code${digits(number)}');
void whatsapp(String code, String number) => udOpenUrl('https://wa.me/$code${digits(number)}', external: true);

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  Timer? _clock;

  @override
  void initState() {
    super.initState();
    contacts.load();
    _clock = Timer.periodic(const Duration(seconds: 30), (_) => setState(() {}));
  }

  @override
  void dispose() {
    _clock?.cancel();
    super.dispose();
  }

  void _go(Widget page) => Navigator.of(context).push(MaterialPageRoute(builder: (_) => page));

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: contacts,
      builder: (context, _) {
        final t = UdTokens.of(context);
        final text = Theme.of(context).textTheme;
        return UdPage(
          eyebrow: appName,
          title: context.tr('home_title'),
          subtitle: context.tr('home_sub'),
          actions: const [UdSettingsButton(appName: appName)],
          dock: UdDock(
            label: context.tr('add'),
            icon: Icons.person_add_alt_1_rounded,
            onPressed: () => _go(const ContactForm()),
            extras: [UdDockAction(icon: Icons.dialpad_rounded, label: context.tr('quick'), onTap: () => _go(const ContactForm(quick: true)))],
          ),
          slivers: [
            if (contacts.loaded && contacts.items.isEmpty)
              SliverToBoxAdapter(
                child: UdEmpty(icon: Icons.public_rounded, title: context.tr('empty_title'), body: context.tr('empty_body')),
              )
            else
              UdSliverPad(
                sliver: SliverList.list(children: [
                  for (final p in contacts.items) _ContactCard(contact: p),
                ]),
              ),
            UdSliverPad(
              top: 8,
              sliver: SliverList.list(children: [
                UdRow(
                  leading: const UdBadgeIcon(Icons.dialpad_rounded),
                  title: context.tr('quick'),
                  subtitle: context.tr('quick_sub'),
                  trailing: const Icon(Icons.chevron_right_rounded),
                  onTap: () => _go(const ContactForm(quick: true)),
                ),
                const SizedBox(height: 8),
                Text(context.tr('cost_note'), style: text.bodySmall?.copyWith(color: t.inkSoft)),
              ]),
            ),
          ],
        );
      },
    );
  }
}

class _ContactCard extends StatelessWidget {
  const _ContactCard({required this.contact});
  final Map<String, dynamic> contact;

  @override
  Widget build(BuildContext context) {
    final t = UdTokens.of(context);
    final text = Theme.of(context).textTheme;
    final c = countryOf(contact['tz'] as String, contact['code'] as String);
    final now = localTime(c);
    final (advice, color) = callAdvice(context, now);
    final night = now.hour < 6 || now.hour >= 19;
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: UdPressable(
        onLongPress: () async {
          if (await udConfirm(context)) contacts.remove(contact['id'] as String);
        },
        padding: const EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Text(c.flag, style: const TextStyle(fontSize: 30)),
            const SizedBox(width: 12),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(contact['name'] as String, style: text.titleLarge),
                Text('${c.name} · +${c.code} ${contact['number']}',
                    style: text.bodySmall?.copyWith(color: t.inkSoft)),
              ]),
            ),
            Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
              Row(children: [
                Icon(night ? Icons.nightlight_round : Icons.wb_sunny_rounded,
                    size: 18, color: night ? const Color(0xFF5B4FCF) : const Color(0xFFD9A11E)),
                const SizedBox(width: 4),
                Text(hhmm(now), style: text.headlineMedium),
              ]),
              Text(offsetLabel(context, c), style: text.labelSmall),
            ]),
          ]),
          const SizedBox(height: 12),
          Row(children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(color: color.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(12)),
              child: Text(advice, style: text.labelSmall?.copyWith(color: color)),
            ),
            const Spacer(),
            OutlinedButton.icon(
              style: OutlinedButton.styleFrom(minimumSize: const Size(0, 44)),
              onPressed: () => whatsapp(c.code, contact['number'] as String),
              icon: const Icon(Icons.chat_rounded, size: 18),
              label: Text(context.tr('whatsapp')),
            ),
            const SizedBox(width: 8),
            FilledButton.icon(
              style: FilledButton.styleFrom(minimumSize: const Size(0, 44)),
              onPressed: () => callNumber(c.code, contact['number'] as String),
              icon: const Icon(Icons.call_rounded, size: 18),
              label: Text(context.tr('call')),
            ),
          ]),
        ]),
      ),
    );
  }
}

class ContactForm extends StatefulWidget {
  const ContactForm({super.key, this.quick = false});
  final bool quick;

  @override
  State<ContactForm> createState() => _ContactFormState();
}

class _ContactFormState extends State<ContactForm> {
  final _name = TextEditingController();
  final _number = TextEditingController();
  final _search = TextEditingController();
  Country _country = countries.first;

  @override
  Widget build(BuildContext context) {
    final t = UdTokens.of(context);
    final text = Theme.of(context).textTheme;
    final q = _search.text.toLowerCase();
    final list = countries.where((c) => q.isEmpty || c.name.toLowerCase().contains(q) || c.code.startsWith(q)).toList();
    final now = localTime(_country);
    final (advice, color) = callAdvice(context, now);

    return UdPage(
      title: context.tr(widget.quick ? 'quick' : 'add'),
      dock: widget.quick
          ? UdDock(
              label: context.tr('call'),
              icon: Icons.call_rounded,
              onPressed: () => callNumber(_country.code, _number.text),
              extras: [
                UdDockAction(
                    icon: Icons.chat_rounded,
                    label: context.tr('whatsapp'),
                    onTap: () => whatsapp(_country.code, _number.text)),
              ],
            )
          : UdDock(
              label: context.tr('save_contact'),
              icon: Icons.check_rounded,
              onPressed: () async {
                if (_name.text.trim().isEmpty || digits(_number.text).isEmpty) {
                  udToast(context, context.tr('needs_number'));
                  return;
                }
                await contacts.add({
                  'name': _name.text.trim(),
                  'number': digits(_number.text),
                  'code': _country.code,
                  'tz': _country.tz,
                });
                if (context.mounted) Navigator.of(context).pop();
              },
            ),
      slivers: [
        UdSliverPad(
          sliver: SliverList.list(children: [
            if (!widget.quick) ...[
              TextField(
                controller: _name,
                textCapitalization: TextCapitalization.words,
                style: text.bodyLarge,
                decoration: udInputDecoration(context, hint: context.tr('contact_name'), icon: Icons.person_outline),
              ),
              const SizedBox(height: 12),
            ],
            Row(children: [
              Container(
                height: 56,
                padding: const EdgeInsets.symmetric(horizontal: 14),
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: t.accentSoft,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: t.line),
                ),
                child: Text('${_country.flag} +${_country.code}', style: text.titleMedium),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: TextField(
                  controller: _number,
                  keyboardType: TextInputType.phone,
                  style: text.titleMedium,
                  onChanged: (_) => setState(() {}),
                  decoration: udInputDecoration(context, hint: context.tr('number')),
                ),
              ),
            ]),
            const SizedBox(height: 12),
            Row(children: [
              Text('${_country.name}: ${hhmm(now)}', style: text.titleMedium),
              const SizedBox(width: 10),
              Text(advice, style: text.labelMedium?.copyWith(color: color)),
            ]),
            const SizedBox(height: 18),
            UdLabel(context.tr('country')),
            TextField(
              controller: _search,
              onChanged: (_) => setState(() {}),
              decoration: udInputDecoration(context, hint: context.tr('search_country'), icon: Icons.search_rounded),
            ),
            const SizedBox(height: 10),
            for (final c in list)
              ListTile(
                contentPadding: const EdgeInsets.symmetric(horizontal: 4),
                leading: Text(c.flag, style: const TextStyle(fontSize: 26)),
                title: Text(c.name, style: text.titleMedium),
                subtitle: Text('+${c.code} · ${hhmm(localTime(c))}', style: text.bodySmall),
                trailing: c == _country ? Icon(Icons.check_circle_rounded, color: t.accent) : null,
                onTap: () => setState(() => _country = c),
              ),
          ]),
        ),
      ],
    );
  }
}
