import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:ud_core/ud_core.dart';

import 'rto.dart';
import 'strings.dart';

const appName = 'Gaadi';

const kVahan = 'https://vahan.parivahan.gov.in/vahanservice/';
const kChallan = 'https://echallan.parivahan.gov.in/';
const kSarathi = 'https://sarathi.parivahan.gov.in/';

final vehicles = UdListStore('gaadi.vehicles');

void main() => runUdApp(UdAppSpec(
      name: appName,
      taglineKey: 'tagline',
      accent: const Color(0xFF3F4752),
      icon: Icons.directions_car_rounded,
      strings: gaadiStrings,
      home: (_) => const HomePage(),
    ));

int? daysUntil(String? iso) {
  if (iso == null) return null;
  final d = DateTime.parse(iso);
  final n = DateTime.now();
  return DateTime(d.year, d.month, d.day).difference(DateTime(n.year, n.month, n.day)).inDays;
}

/// Indian-style number plate.
class Plate extends StatelessWidget {
  const Plate(this.text, {super.key, this.big = false});
  final String text;
  final bool big;

  @override
  Widget build(BuildContext context) {
    final h = big ? 64.0 : 40.0;
    return Container(
      height: h,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.black, width: big ? 3 : 2),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Container(
          width: h * 0.5,
          color: const Color(0xFF1F4BA5),
          alignment: Alignment.bottomCenter,
          padding: const EdgeInsets.only(bottom: 3),
          child: Text('IND', style: TextStyle(color: Colors.white, fontSize: h * 0.17, fontWeight: FontWeight.w700)),
        ),
        Padding(
          padding: EdgeInsets.symmetric(horizontal: h * 0.25),
          child: Text(text,
              style: TextStyle(
                  fontFamily: 'monospace',
                  fontSize: h * 0.46,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1.5,
                  color: Colors.black)),
        ),
      ]),
    );
  }
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
    vehicles.load();
  }

  void _go(Widget page) => Navigator.of(context).push(MaterialPageRoute(builder: (_) => page));

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: vehicles,
      builder: (context, _) {
        final t = UdTokens.of(context);
        final text = Theme.of(context).textTheme;
        return UdPage(
          eyebrow: appName,
          title: context.tr('home_title'),
          subtitle: context.tr('home_sub'),
          actions: const [UdSettingsButton(appName: appName)],
          dock: UdDock(label: context.tr('add'), icon: Icons.add_rounded, onPressed: () => _go(const VehicleForm())),
          slivers: [
            if (vehicles.loaded && vehicles.items.isEmpty)
              SliverToBoxAdapter(
                child: UdEmpty(
                    icon: Icons.directions_car_outlined, title: context.tr('empty_title'), body: context.tr('empty_body')),
              )
            else
              UdSliverPad(
                sliver: SliverList.list(children: [
                  for (final v in vehicles.items)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: UdPressable(
                        onTap: () => _go(VehiclePage(id: v['id'] as String)),
                        padding: const EdgeInsets.all(16),
                        child: Row(children: [
                          Expanded(
                            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                              FittedBox(child: Plate(v['plate'] as String)),
                              const SizedBox(height: 8),
                              Text(v['name'] as String? ?? '', style: text.titleMedium),
                              if (_attention(v))
                                Text(context.tr('needs_attention'),
                                    style: text.labelMedium?.copyWith(color: t.danger)),
                            ]),
                          ),
                          Icon(v['kind'] == 'bike' ? Icons.two_wheeler_rounded : Icons.directions_car_rounded,
                              size: 40, color: t.accent),
                        ]),
                      ),
                    ),
                ]),
              ),
            UdSliverPad(
              top: 10,
              sliver: SliverList.list(children: [
                UdRow(
                  leading: const UdBadgeIcon(Icons.manage_search_rounded),
                  title: context.tr('lookup'),
                  subtitle: context.tr('lookup_sub'),
                  trailing: const Icon(Icons.chevron_right_rounded),
                  onTap: () => _go(const LookupPage()),
                ),
                UdLabel(context.tr('official')),
                for (final (k, url, icon) in [
                  ('vahan', kVahan, Icons.description_outlined),
                  ('challan', kChallan, Icons.receipt_long_outlined),
                  ('sarathi', kSarathi, Icons.badge_outlined),
                ])
                  UdRow(
                    leading: UdBadgeIcon(icon),
                    title: context.tr(k),
                    subtitle: context.tr('${k}_sub'),
                    trailing: const Icon(Icons.open_in_new_rounded, size: 18),
                    onTap: () => udOpenUrl(url),
                  ),
              ]),
            ),
          ],
        );
      },
    );
  }

  bool _attention(Map<String, dynamic> v) => ['insurance', 'puc', 'service'].any((k) {
        final d = daysUntil(v[k] as String?);
        return d != null && d <= 15;
      });
}

class LookupPage extends StatefulWidget {
  const LookupPage({super.key});

  @override
  State<LookupPage> createState() => _LookupPageState();
}

class _LookupPageState extends State<LookupPage> {
  final _c = TextEditingController();

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final info = decodePlate(_c.text);
    return UdPage(
      title: context.tr('lookup'),
      slivers: [
        UdSliverPad(
          sliver: SliverList.list(children: [
            TextField(
              controller: _c,
              autofocus: true,
              textCapitalization: TextCapitalization.characters,
              style: text.headlineSmall,
              onChanged: (_) => setState(() {}),
              decoration: udInputDecoration(context, hint: context.tr('plate_hint'), icon: Icons.pin_outlined),
            ),
            const SizedBox(height: 24),
            if (info != null) ...[
              Center(child: FittedBox(child: Plate(info.formatted, big: true))),
              const SizedBox(height: 20),
              if (info.state != null)
                Text(context.tr('rto_from', {'s': info.state!}), style: text.headlineSmall, textAlign: TextAlign.center),
              if (info.rto != null)
                Text(context.tr('rto_office', {'r': info.rto!}), style: text.titleMedium, textAlign: TextAlign.center),
              const SizedBox(height: 20),
              FilledButton.icon(
                onPressed: () {
                  Clipboard.setData(ClipboardData(text: info.formatted.replaceAll(' ', '')));
                  udToast(context, context.tr('copied'));
                  udOpenUrl(kChallan);
                },
                icon: const Icon(Icons.receipt_long_outlined),
                label: Text(context.tr('challan')),
              ),
            ] else if (_c.text.length > 4)
              Text(context.tr('bad_plate'), style: text.bodyMedium, textAlign: TextAlign.center),
          ]),
        ),
      ],
    );
  }
}

class VehicleForm extends StatefulWidget {
  const VehicleForm({super.key});

  @override
  State<VehicleForm> createState() => _VehicleFormState();
}

class _VehicleFormState extends State<VehicleForm> {
  final _plate = TextEditingController();
  final _name = TextEditingController();
  String _kind = 'bike';

  Future<void> _save() async {
    final info = decodePlate(_plate.text);
    if (info == null) {
      udToast(context, context.tr('bad_plate'));
      return;
    }
    await vehicles.add({'plate': info.formatted, 'name': _name.text.trim(), 'kind': _kind, 'fuel': []});
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final info = decodePlate(_plate.text);
    return UdPage(
      title: context.tr('add'),
      dock: UdDock(label: context.tr('save_vehicle'), icon: Icons.check_rounded, onPressed: _save),
      slivers: [
        UdSliverPad(
          sliver: SliverList.list(children: [
            SegmentedButton<String>(
              showSelectedIcon: false,
              segments: [
                ButtonSegment(value: 'bike', icon: const Icon(Icons.two_wheeler_rounded), label: Text(context.tr('kind_bike'))),
                ButtonSegment(value: 'car', icon: const Icon(Icons.directions_car_rounded), label: Text(context.tr('kind_car'))),
                ButtonSegment(value: 'other', icon: const Icon(Icons.local_shipping_outlined), label: Text(context.tr('kind_other'))),
              ],
              selected: {_kind},
              onSelectionChanged: (s) => setState(() => _kind = s.first),
            ),
            const SizedBox(height: 18),
            TextField(
              controller: _plate,
              textCapitalization: TextCapitalization.characters,
              style: text.headlineSmall,
              onChanged: (_) => setState(() {}),
              decoration: udInputDecoration(context, hint: context.tr('plate_hint')),
            ),
            if (info != null)
              Padding(
                padding: const EdgeInsets.only(top: 8, left: 4),
                child: Text(
                  [if (info.state != null) info.state!, if (info.rto != null) info.rto!].join(' · '),
                  style: text.bodySmall,
                ),
              ),
            const SizedBox(height: 14),
            TextField(
              controller: _name,
              style: text.bodyLarge,
              decoration: udInputDecoration(context, hint: context.tr('nickname')),
            ),
          ]),
        ),
      ],
    );
  }
}

class VehiclePage extends StatelessWidget {
  const VehiclePage({super.key, required this.id});
  final String id;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: vehicles,
      builder: (context, _) {
        Map<String, dynamic>? found;
        for (final e in vehicles.items) {
          if (e['id'] == id) found = e;
        }
        final v = found;
        if (v == null) return const Scaffold();
        final t = UdTokens.of(context);
        final text = Theme.of(context).textTheme;
        final info = decodePlate(v['plate'] as String);
        final fuel = [for (final f in (v['fuel'] as List? ?? const [])) Map<String, dynamic>.from(f as Map)]
          ..sort((a, b) => (b['date'] as String).compareTo(a['date'] as String));

        double? mileage;
        if (fuel.length >= 2) {
          final km = (fuel[0]['odo'] as num) - (fuel[1]['odo'] as num);
          final l = (fuel[0]['litres'] as num);
          if (km > 0 && l > 0) mileage = km / l;
        }
        final now = DateTime.now();
        final monthSpend = fuel
            .where((f) {
              final d = DateTime.parse(f['date'] as String);
              return d.year == now.year && d.month == now.month;
            })
            .fold<double>(0, (s, f) => s + (f['amount'] as num).toDouble());

        Future<void> setDate(String key) async {
          final cur = v[key] == null ? null : DateTime.parse(v[key] as String);
          final d = await showDatePicker(
            context: context,
            initialDate: cur ?? now.add(const Duration(days: 180)),
            firstDate: DateTime(now.year - 5),
            lastDate: DateTime(now.year + 10),
          );
          if (d == null) return;
          v[key] = d.toIso8601String();
          await vehicles.put(v);
        }

        Future<void> addFuel() async {
          final res = await showUdSheet<Map<String, dynamic>>(context, (c) => const _FuelForm());
          if (res == null) return;
          v['fuel'] = [...fuel, res];
          await vehicles.put(v);
        }

        Widget dateRow(String key, IconData icon) {
          final d = daysUntil(v[key] as String?);
          final iso = v[key] as String?;
          String sub;
          Color c = t.inkSoft;
          if (iso == null) {
            sub = context.tr('not_set');
          } else {
            final dt = DateTime.parse(iso);
            final when = d! < 0
                ? context.tr('expired')
                : d == 0
                    ? context.tr('today')
                    : context.tr('in_days', {'n': '$d'});
            sub = '${udTwo(dt.day)}/${udTwo(dt.month)}/${dt.year} · $when';
            if (d <= 15) c = d < 0 ? t.danger : const Color(0xFFB7791F);
          }
          return UdPressable(
            onTap: () => setDate(key),
            padding: const EdgeInsets.all(14),
            child: Row(children: [
              UdBadgeIcon(icon, size: 44),
              const SizedBox(width: 14),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(context.tr(key), style: text.titleMedium),
                  Text(sub, style: text.bodySmall?.copyWith(color: c)),
                ]),
              ),
              const Icon(Icons.edit_calendar_outlined),
            ]),
          );
        }

        return UdPage(
          title: v['name'] as String? ?? '',
          actions: [
            UdIconButton(
              icon: Icons.delete_outline_rounded,
              onTap: () async {
                if (!await udConfirm(context)) return;
                await vehicles.remove(id);
                if (context.mounted) Navigator.of(context).pop();
              },
            ),
          ],
          dock: UdDock(
            label: context.tr('add_fuel'),
            icon: Icons.local_gas_station_rounded,
            onPressed: addFuel,
            extras: [
              UdDockAction(
                icon: Icons.receipt_long_outlined,
                label: context.tr('challan'),
                onTap: () {
                  Clipboard.setData(ClipboardData(text: (v['plate'] as String).replaceAll(' ', '')));
                  udToast(context, context.tr('copied'));
                  udOpenUrl(kChallan);
                },
              ),
            ],
          ),
          slivers: [
            UdSliverPad(
              sliver: SliverList.list(children: [
                Center(child: FittedBox(child: Plate(v['plate'] as String, big: true))),
                if (info?.state != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 10),
                    child: Text(
                      [info!.state!, if (info.rto != null) info.rto!].join(' · '),
                      textAlign: TextAlign.center,
                      style: text.bodyMedium?.copyWith(color: t.inkSoft),
                    ),
                  ),
                const SizedBox(height: 20),
                dateRow('insurance', Icons.health_and_safety_outlined),
                const SizedBox(height: 10),
                dateRow('puc', Icons.eco_outlined),
                const SizedBox(height: 10),
                dateRow('service', Icons.build_outlined),
                const SizedBox(height: 22),
                UdLabel(context.tr('fuel')),
                Row(children: [
                  Expanded(
                    child: _Stat(
                        label: context.tr('mileage'),
                        value: mileage == null ? '—' : context.tr('kmpl', {'n': mileage.toStringAsFixed(1)})),
                  ),
                  const SizedBox(width: 10),
                  Expanded(child: _Stat(label: context.tr('month_spend'), value: udRupees(monthSpend))),
                ]),
                const SizedBox(height: 12),
                if (fuel.isEmpty)
                  Text(context.tr('no_fuel'), style: text.bodyMedium?.copyWith(color: t.inkSoft))
                else
                  for (final f in fuel.take(10))
                    UdRow(
                      leading: const UdBadgeIcon(Icons.local_gas_station_outlined, size: 40),
                      title: '${f['litres']} l · ${udRupees(f['amount'] as num)}',
                      subtitle:
                          '${udFormatDate(context, DateTime.parse(f['date'] as String))} · ${f['odo']} km · ${context.tr('per_litre', {'n': ((f['amount'] as num) / (f['litres'] as num)).toStringAsFixed(1)})}',
                    ),
              ]),
            ),
          ],
        );
      },
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat({required this.label, required this.value});
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final t = UdTokens.of(context);
    final text = Theme.of(context).textTheme;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: t.accentSoft, borderRadius: BorderRadius.circular(18)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(label, style: text.labelSmall),
        const SizedBox(height: 4),
        FittedBox(child: Text(value, style: text.headlineSmall)),
      ]),
    );
  }
}

class _FuelForm extends StatefulWidget {
  const _FuelForm();

  @override
  State<_FuelForm> createState() => _FuelFormState();
}

class _FuelFormState extends State<_FuelForm> {
  final _l = TextEditingController();
  final _a = TextEditingController();
  final _o = TextEditingController();

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    Widget f(TextEditingController c, String label) => Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: TextField(
            controller: c,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            style: text.titleMedium,
            decoration: udInputDecoration(context).copyWith(labelText: label),
          ),
        );
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(context.tr('add_fuel'), style: text.headlineSmall),
      const SizedBox(height: 16),
      f(_l, context.tr('litres')),
      f(_a, context.tr('amount')),
      f(_o, context.tr('odometer')),
      SizedBox(
        width: double.infinity,
        child: FilledButton(
          onPressed: () {
            final l = udParseNum(_l.text), a = udParseNum(_a.text), o = udParseNum(_o.text);
            if (l == null || a == null || o == null || l <= 0) return;
            Navigator.pop(context, {'date': DateTime.now().toIso8601String(), 'litres': l, 'amount': a, 'odo': o});
          },
          child: Text(context.tr('save')),
        ),
      ),
    ]);
  }
}
