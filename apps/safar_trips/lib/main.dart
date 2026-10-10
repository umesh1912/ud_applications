import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:ud_core/ud_core.dart';

import 'strings.dart';

const appName = 'Safar';

const kIrctc = 'https://www.irctc.co.in/nget/train-search';
const kPnr = 'https://www.indianrail.gov.in/enquiry/PNR/PnrEnquiry.html?locale=en';
const kNtes = 'https://enquiry.indianrail.gov.in/mntes/';
const kGsrtc = 'https://gsrtc.in/';

/// Booking rules (Indian Railways): advance booking opens 60 days before the
/// journey date (journey day excluded) at 08:00; Tatkal opens the day before
/// at 10:00 (AC) or 11:00 (non-AC).
DateTime generalOpens(DateTime journey) {
  final d = DateTime(journey.year, journey.month, journey.day).subtract(const Duration(days: 60));
  return DateTime(d.year, d.month, d.day, 8);
}

DateTime tatkalOpens(DateTime journey, bool ac) {
  final d = DateTime(journey.year, journey.month, journey.day).subtract(const Duration(days: 1));
  return DateTime(d.year, d.month, d.day, ac ? 10 : 11);
}

final trips = UdListStore('safar.trips');
final passengers = UdListStore('safar.passengers');

void main() => runUdApp(UdAppSpec(
      name: appName,
      taglineKey: 'tagline',
      accent: const Color(0xFFA26B00),
      icon: Icons.train_rounded,
      strings: safarStrings,
      home: (_) => const HomePage(),
    ));

String fmtDate(DateTime d) => '${udTwo(d.day)}/${udTwo(d.month)}/${d.year}';
String fmtDateTime(DateTime d) => '${fmtDate(d)}, ${udTwo(d.hour)}:${udTwo(d.minute)}';

String countdown(Duration d) {
  if (d.inDays >= 1) return '${d.inDays}d ${d.inHours % 24}h';
  if (d.inHours >= 1) return '${d.inHours}h ${d.inMinutes % 60}m';
  return '${d.inMinutes}m ${d.inSeconds % 60}s';
}

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  Timer? _tick;

  @override
  void initState() {
    super.initState();
    trips.load();
    passengers.load();
    _tick = Timer.periodic(const Duration(seconds: 30), (_) => setState(() {}));
  }

  @override
  void dispose() {
    _tick?.cancel();
    super.dispose();
  }

  void _go(Widget p) => Navigator.of(context).push(MaterialPageRoute(builder: (_) => p));

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: Listenable.merge([trips, passengers]),
      builder: (context, _) {
        final t = UdTokens.of(context);
        final text = Theme.of(context).textTheme;
        final today = DateTime.now();
        final list = trips.items.where((tr) {
          final d = DateTime.parse(tr['date'] as String);
          return !d.isBefore(DateTime(today.year, today.month, today.day));
        }).toList()
          ..sort((a, b) => (a['date'] as String).compareTo(b['date'] as String));
        return UdPage(
          eyebrow: appName,
          title: context.tr('home_title'),
          subtitle: context.tr('home_sub'),
          actions: const [UdSettingsButton(appName: appName)],
          dock: UdDock(label: context.tr('add'), icon: Icons.add_road_rounded, onPressed: () => _go(const TripForm())),
          slivers: [
            if (trips.loaded && list.isEmpty)
              SliverToBoxAdapter(
                child: UdEmpty(icon: Icons.train_outlined, title: context.tr('empty_title'), body: context.tr('empty_body')),
              )
            else
              UdSliverPad(
                sliver: SliverList.list(children: [
                  for (final tr in list) _TripCard(trip: tr, onTap: () => _go(TripPage(id: tr['id'] as String))),
                ]),
              ),
            UdSliverPad(
              top: 10,
              sliver: SliverList.list(children: [
                UdRow(
                  leading: const UdBadgeIcon(Icons.groups_outlined),
                  title: context.tr('passengers'),
                  subtitle: '${passengers.items.length}',
                  trailing: const Icon(Icons.chevron_right_rounded),
                  onTap: () => _go(const PassengersPage()),
                ),
                UdLabel(context.tr('links')),
                for (final (k, url, icon) in [
                  ('book_irctc', kIrctc, Icons.confirmation_number_outlined),
                  ('check_pnr', kPnr, Icons.fact_check_outlined),
                  ('running', kNtes, Icons.share_location_rounded),
                  ('gsrtc', kGsrtc, Icons.directions_bus_outlined),
                ])
                  UdRow(
                    leading: UdBadgeIcon(icon),
                    title: context.tr(k),
                    trailing: const Icon(Icons.open_in_new_rounded, size: 18),
                    onTap: () => udOpenUrl(url),
                  ),
                const SizedBox(height: 8),
                Text(context.tr('rule_note'), style: text.bodySmall?.copyWith(color: t.inkSoft)),
              ]),
            ),
          ],
        );
      },
    );
  }
}

class _TripCard extends StatelessWidget {
  const _TripCard({required this.trip, required this.onTap});
  final Map<String, dynamic> trip;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final t = UdTokens.of(context);
    final text = Theme.of(context).textTheme;
    final date = DateTime.parse(trip['date'] as String);
    final ac = trip['ac'] as bool? ?? true;
    final now = DateTime.now();
    final g = generalOpens(date);
    final tk = tatkalOpens(date, ac);
    String status(DateTime opens, DateTime closes) {
      if (now.isBefore(opens)) return context.tr('in', {'t': countdown(opens.difference(now))});
      if (now.isBefore(closes)) return context.tr('open_now');
      return context.tr('closed');
    }

    final days = DateTime(date.year, date.month, date.day).difference(DateTime(now.year, now.month, now.day)).inDays;
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: UdPressable(
        onTap: onTap,
        padding: const EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Expanded(
              child: Text('${trip['from']}  →  ${trip['to']}',
                  maxLines: 1, overflow: TextOverflow.ellipsis, style: text.titleLarge),
            ),
            Text(context.tr('days_left', {'n': '$days'}), style: text.labelMedium?.copyWith(color: t.accent)),
          ]),
          Text(
            [fmtDate(date), if ((trip['train'] as String? ?? '').isNotEmpty) trip['train'] as String, ac ? 'AC' : 'Non-AC']
                .join(' · '),
            style: text.bodySmall?.copyWith(color: t.inkSoft),
          ),
          const SizedBox(height: 12),
          Row(children: [
            Expanded(child: _Mini(label: context.tr('general_opens'), value: status(g, date))),
            const SizedBox(width: 8),
            Expanded(child: _Mini(label: context.tr('tatkal_opens'), value: status(tk, date))),
          ]),
        ]),
      ),
    );
  }
}

class _Mini extends StatelessWidget {
  const _Mini({required this.label, required this.value});
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final t = UdTokens.of(context);
    final text = Theme.of(context).textTheme;
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(color: t.accentSoft, borderRadius: BorderRadius.circular(14)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(label, style: text.labelSmall),
        Text(value, style: text.titleSmall),
      ]),
    );
  }
}

class TripForm extends StatefulWidget {
  const TripForm({super.key});

  @override
  State<TripForm> createState() => _TripFormState();
}

class _TripFormState extends State<TripForm> {
  final _from = TextEditingController();
  final _to = TextEditingController();
  final _train = TextEditingController();
  DateTime? _date;
  bool _ac = true;

  Future<void> _save() async {
    if (_from.text.trim().isEmpty || _to.text.trim().isEmpty || _date == null) {
      udToast(context, context.tr('needs_fields'));
      return;
    }
    final tr = await trips.add({
      'from': _from.text.trim(),
      'to': _to.text.trim(),
      'train': _train.text.trim(),
      'date': _date!.toIso8601String(),
      'ac': _ac,
    });
    if (!mounted) return;
    Navigator.of(context).pushReplacement(MaterialPageRoute(builder: (_) => TripPage(id: tr['id'] as String)));
  }

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final now = DateTime.now();
    Widget field(TextEditingController c, String hint, IconData icon) => Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: TextField(
            controller: c,
            textCapitalization: TextCapitalization.words,
            style: text.bodyLarge,
            decoration: udInputDecoration(context, hint: hint, icon: icon),
          ),
        );
    return UdPage(
      title: context.tr('add'),
      dock: UdDock(label: context.tr('save_trip'), icon: Icons.check_rounded, onPressed: _save),
      slivers: [
        UdSliverPad(
          sliver: SliverList.list(children: [
            field(_from, context.tr('from'), Icons.trip_origin_rounded),
            field(_to, context.tr('to'), Icons.place_outlined),
            OutlinedButton.icon(
              onPressed: () async {
                final d = await showDatePicker(
                  context: context,
                  initialDate: _date ?? now.add(const Duration(days: 30)),
                  firstDate: now,
                  lastDate: now.add(const Duration(days: 365)),
                );
                if (d != null) setState(() => _date = d);
              },
              icon: const Icon(Icons.event_rounded),
              label: Text(_date == null ? context.tr('date') : fmtDate(_date!)),
            ),
            const SizedBox(height: 12),
            field(_train, context.tr('train'), Icons.train_outlined),
            UdLabel(context.tr('cls')),
            SegmentedButton<bool>(
              showSelectedIcon: false,
              segments: [
                ButtonSegment(value: true, label: Text(context.tr('ac'))),
                ButtonSegment(value: false, label: Text(context.tr('nonac'))),
              ],
              selected: {_ac},
              onSelectionChanged: (s) => setState(() => _ac = s.first),
            ),
          ]),
        ),
      ],
    );
  }
}

class TripPage extends StatefulWidget {
  const TripPage({super.key, required this.id});
  final String id;

  @override
  State<TripPage> createState() => _TripPageState();
}

class _TripPageState extends State<TripPage> {
  Timer? _tick;
  final _pnr = TextEditingController();

  @override
  void initState() {
    super.initState();
    _tick = Timer.periodic(const Duration(seconds: 1), (_) => setState(() {}));
  }

  @override
  void dispose() {
    _tick?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    Map<String, dynamic>? found;
    for (final e in trips.items) {
      if (e['id'] == widget.id) found = e;
    }
    final trip = found;
    if (trip == null) return const Scaffold();
    if (_pnr.text.isEmpty && trip['pnr'] != null) _pnr.text = trip['pnr'] as String;
    final t = UdTokens.of(context);
    final text = Theme.of(context).textTheme;
    final date = DateTime.parse(trip['date'] as String);
    final ac = trip['ac'] as bool? ?? true;
    final now = DateTime.now();

    Widget big(String label, DateTime opens) {
      final open = !now.isBefore(opens) && now.isBefore(date);
      final over = !now.isBefore(date);
      return Container(
        width: double.infinity,
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: open ? t.accent : t.ink,
          borderRadius: BorderRadius.circular(24),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(label, style: text.labelLarge?.copyWith(color: t.paper.withValues(alpha: 0.75))),
          const SizedBox(height: 4),
          Text(
            over
                ? context.tr('closed')
                : open
                    ? context.tr('open_now')
                    : countdown(opens.difference(now)),
            style: text.displaySmall?.copyWith(color: t.paper),
          ),
          Text(fmtDateTime(opens), style: text.bodyMedium?.copyWith(color: t.paper.withValues(alpha: 0.8))),
        ]),
      );
    }

    return UdPage(
      title: '${trip['from']} → ${trip['to']}',
      subtitle: [fmtDate(date), if ((trip['train'] as String? ?? '').isNotEmpty) trip['train'] as String].join(' · '),
      actions: [
        UdIconButton(
          icon: Icons.delete_outline_rounded,
          onTap: () async {
            if (!await udConfirm(context)) return;
            await trips.remove(widget.id);
            if (context.mounted) Navigator.of(context).pop();
          },
        ),
      ],
      dock: UdDock(
        label: context.tr('book_irctc'),
        icon: Icons.confirmation_number_outlined,
        onPressed: () => udOpenUrl(kIrctc),
        extras: [
          UdDockAction(
            icon: Icons.groups_outlined,
            label: context.tr('passengers'),
            onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const PassengersPage())),
          ),
        ],
      ),
      slivers: [
        UdSliverPad(
          sliver: SliverList.list(children: [
            big(context.tr('general_opens'), generalOpens(date)),
            big(context.tr('tatkal_opens'), tatkalOpens(date, ac)),
            Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Icon(Icons.verified_user_outlined, size: 18, color: t.accent),
              const SizedBox(width: 8),
              Expanded(child: Text(context.tr('aadhaar_note'), style: text.bodySmall)),
            ]),
            const SizedBox(height: 20),
            UdLabel(context.tr('pnr')),
            Row(children: [
              Expanded(
                child: TextField(
                  controller: _pnr,
                  keyboardType: TextInputType.number,
                  maxLength: 10,
                  onChanged: (v) {
                    trip['pnr'] = v.trim();
                    trips.put(trip);
                  },
                  decoration: udInputDecoration(context, hint: '10 digits').copyWith(counterText: ''),
                ),
              ),
              const SizedBox(width: 10),
              SizedBox(
                height: 56,
                child: FilledButton(
                  onPressed: () {
                    if (_pnr.text.trim().isNotEmpty) {
                      Clipboard.setData(ClipboardData(text: _pnr.text.trim()));
                      udToast(context, context.tr('copied'));
                    }
                    udOpenUrl(kPnr);
                  },
                  child: Text(context.tr('check_pnr')),
                ),
              ),
            ]),
          ]),
        ),
      ],
    );
  }
}

class PassengersPage extends StatelessWidget {
  const PassengersPage({super.key});

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: passengers,
      builder: (context, _) {
        final text = Theme.of(context).textTheme;
        String all() => [
              for (final p in passengers.items) '${p['name']}, ${p['age']}, ${context.tr(p['gender'] as String)}',
            ].join('\n');
        return UdPage(
          title: context.tr('passengers'),
          dock: UdDock(
            label: context.tr('add_passenger'),
            icon: Icons.person_add_alt_1_rounded,
            onPressed: () async {
              final p = await showUdSheet<Map<String, dynamic>>(context, (c) => const _PassengerForm());
              if (p != null) await passengers.add(p);
            },
            extras: [
              UdDockAction(
                icon: Icons.copy_all_rounded,
                label: context.tr('copy_all'),
                onTap: () {
                  Clipboard.setData(ClipboardData(text: all()));
                  udToast(context, context.tr('copied'));
                },
              ),
            ],
          ),
          slivers: [
            UdSliverPad(
              sliver: SliverList.list(children: [
                for (final p in passengers.items)
                  UdRow(
                    leading: const UdBadgeIcon(Icons.person_outline_rounded),
                    title: p['name'] as String,
                    subtitle: '${p['age']} · ${context.tr(p['gender'] as String)}',
                    trailing: IconButton(
                      icon: const Icon(Icons.delete_outline_rounded),
                      onPressed: () => passengers.remove(p['id'] as String),
                    ),
                  ),
                if (passengers.items.isEmpty) Text(context.tr('add_passenger'), style: text.bodyMedium),
              ]),
            ),
          ],
        );
      },
    );
  }
}

class _PassengerForm extends StatefulWidget {
  const _PassengerForm();

  @override
  State<_PassengerForm> createState() => _PassengerFormState();
}

class _PassengerFormState extends State<_PassengerForm> {
  final _name = TextEditingController();
  final _age = TextEditingController();
  String _gender = 'male';

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(context.tr('add_passenger'), style: text.headlineSmall),
      const SizedBox(height: 16),
      TextField(
        controller: _name,
        autofocus: true,
        textCapitalization: TextCapitalization.words,
        decoration: udInputDecoration(context, hint: context.tr('p_name')),
      ),
      const SizedBox(height: 12),
      TextField(
        controller: _age,
        keyboardType: TextInputType.number,
        decoration: udInputDecoration(context, hint: context.tr('p_age')),
      ),
      const SizedBox(height: 12),
      SegmentedButton<String>(
        showSelectedIcon: false,
        segments: [
          ButtonSegment(value: 'male', label: Text(context.tr('male'))),
          ButtonSegment(value: 'female', label: Text(context.tr('female'))),
          ButtonSegment(value: 'other', label: Text(context.tr('other'))),
        ],
        selected: {_gender},
        onSelectionChanged: (s) => setState(() => _gender = s.first),
      ),
      const SizedBox(height: 16),
      SizedBox(
        width: double.infinity,
        child: FilledButton(
          onPressed: () {
            final age = int.tryParse(_age.text.trim());
            if (_name.text.trim().isEmpty || age == null) return;
            Navigator.pop(context, {'name': _name.text.trim(), 'age': age, 'gender': _gender});
          },
          child: Text(context.tr('save')),
        ),
      ),
    ]);
  }
}
