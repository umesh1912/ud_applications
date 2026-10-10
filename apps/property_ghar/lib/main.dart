import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:ud_core/ud_core.dart';

import 'calc.dart';
import 'strings.dart';

const appName = 'Ghar';

final listings = UdListStore('ghar.listings');

void main() => runUdApp(UdAppSpec(
      name: appName,
      taglineKey: 'tagline',
      accent: const Color(0xFF9C5B2E),
      icon: Icons.home_work_rounded,
      strings: gharStrings,
      home: (_) => const HomePage(),
    ));

const propertyTypes = ['flat', 'house', 'plot', 'shop', 'office'];
const amenityKeys = ['parking', 'lift', 'security', 'power', 'water', 'garden', 'gym', 'corner'];
bool hasBhk(String type) => type == 'flat' || type == 'house';

String priceLabel(BuildContext c, Map<String, dynamic> l) {
  final p = (l['price'] as num?) ?? 0;
  return l['purpose'] == 'rent' ? '${udRupees(p)}${c.tr('per_month')}' : udRupeesShort(p);
}

String headline(BuildContext c, Map<String, dynamic> l) {
  final type = l['type'] as String;
  final bhk = hasBhk(type) && l['bhk'] != null ? '${l['bhk']} BHK ' : '';
  return '$bhk${c.tr('pt_$type')} · ${c.tr(l['purpose'] == 'rent' ? 'for_rent' : 'for_sale')}';
}

String areaLabel(Map<String, dynamic> l) {
  final a = (l['area'] as num?) ?? 0;
  if (a == 0) return '';
  return '${a % 1 == 0 ? a.toInt() : a} ${l['unit'] == 'sqyd' ? 'sq yd' : 'sq ft'}';
}

String place(Map<String, dynamic> l) =>
    [l['locality'], l['city']].where((e) => e != null && (e as String).trim().isNotEmpty).join(', ');

String autoDescription(BuildContext c, Map<String, dynamic> l) {
  final type = l['type'] as String;
  final bhk = hasBhk(type) && l['bhk'] != null ? '${l['bhk']} BHK ' : '';
  final parts = <String>[
    c.tr('desc_head', {
      'bhk': bhk,
      'type': c.tr('pt_$type'),
      'purpose': c.tr(l['purpose'] == 'rent' ? 'desc_purpose_rent' : 'desc_purpose_sale'),
      'place': place(l),
    }),
  ];
  final details = [
    if (areaLabel(l).isNotEmpty) areaLabel(l),
    if ((l['floor'] as String? ?? '').isNotEmpty) c.tr('floor_n', {'n': l['floor'] as String}),
    if (l['furnishing'] != null && hasBhk(type)) c.tr('f_${l['furnishing']}'),
  ];
  if (details.isNotEmpty) parts.add(c.tr('desc_area', {'a': details.join(', ')}));
  final amen = [for (final a in (l['amenities'] as List? ?? const [])) c.tr('a_$a')];
  if (amen.isNotEmpty) parts.add(c.tr('desc_amen', {'a': amen.join(', ')}));
  parts.add(c.tr('desc_price', {'p': priceLabel(c, l)}));
  parts.add(c.tr('desc_call', {'n': (l['name'] as String? ?? '').trim(), 'p': l['phone'] as String? ?? ''}));
  return parts.join('\n');
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
    listings.load();
  }

  void _go(Widget page) => Navigator.of(context).push(MaterialPageRoute(builder: (_) => page));

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: listings,
      builder: (context, _) {
        final items = listings.items;
        return UdPage(
          eyebrow: appName,
          title: context.tr('home_title'),
          subtitle: context.tr('home_sub'),
          actions: const [UdSettingsButton(appName: appName)],
          dock: UdDock(
            label: context.tr('post'),
            icon: Icons.add_home_rounded,
            onPressed: () => _go(const ListingForm()),
          ),
          slivers: [
            UdSliverPad(
              sliver: SliverToBoxAdapter(
                child: SizedBox(
                  height: 132,
                  child: Row(children: [
                    Expanded(
                      child: UdToolTile(
                          icon: Icons.calculate_outlined,
                          title: context.tr('emi'),
                          subtitle: context.tr('emi_sub'),
                          onTap: () => _go(const EmiPage())),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: UdToolTile(
                          icon: Icons.account_balance_outlined,
                          title: context.tr('stamp'),
                          subtitle: context.tr('stamp_sub'),
                          onTap: () => _go(const StampPage())),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: UdToolTile(
                          icon: Icons.square_foot_rounded,
                          title: context.tr('area'),
                          subtitle: context.tr('area_sub'),
                          onTap: () => _go(const AreaPage())),
                    ),
                  ]),
                ),
              ),
            ),
            const SliverToBoxAdapter(child: SizedBox(height: 18)),
            if (listings.loaded && items.isEmpty)
              SliverToBoxAdapter(
                child: UdEmpty(
                  icon: Icons.home_work_outlined,
                  title: context.tr('empty_title'),
                  body: context.tr('empty_body'),
                ),
              )
            else
              UdSliverPad(
                sliver: SliverList.list(children: [
                  for (final l in items)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: _ListingCard(listing: l, onTap: () => _go(ListingPage(id: l['id'] as String))),
                    ),
                ]),
              ),
          ],
        );
      },
    );
  }
}

class _ListingCard extends StatelessWidget {
  const _ListingCard({required this.listing, required this.onTap});
  final Map<String, dynamic> listing;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final t = UdTokens.of(context);
    final text = Theme.of(context).textTheme;
    final photos = (listing['photos'] as List? ?? const []).cast<String>();
    final done = listing['status'] == 'done';
    return UdPressable(
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AspectRatio(
            aspectRatio: 16 / 9,
            child: Stack(fit: StackFit.expand, children: [
              photos.isNotEmpty && File(photos.first).existsSync()
                  ? Image.file(File(photos.first), fit: BoxFit.cover, cacheWidth: 800)
                  : Container(color: t.accentSoft, child: Icon(Icons.home_work_outlined, size: 48, color: t.accent)),
              if (done)
                Container(
                  color: Colors.black45,
                  alignment: Alignment.center,
                  child: Text(context.tr(listing['purpose'] == 'rent' ? 'rented' : 'sold'),
                      style: text.headlineMedium?.copyWith(color: Colors.white)),
                ),
            ]),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(priceLabel(context, listing), style: text.headlineSmall?.copyWith(color: t.accent)),
                Text(headline(context, listing), style: text.titleMedium),
                Text([place(listing), areaLabel(listing)].where((e) => e.isNotEmpty).join(' · '),
                    style: text.bodySmall?.copyWith(color: t.inkSoft)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class ListingForm extends StatefulWidget {
  const ListingForm({super.key, this.initial});
  final Map<String, dynamic>? initial;

  @override
  State<ListingForm> createState() => _ListingFormState();
}

class _ListingFormState extends State<ListingForm> {
  late final Map<String, dynamic> _l = {
    'purpose': 'sale',
    'type': 'flat',
    'bhk': 2,
    'unit': 'sqft',
    'furnishing': 'none',
    'amenities': <String>[],
    'photos': <String>[],
    'status': 'active',
    ...?widget.initial,
  };
  late final _area = TextEditingController(text: _num(_l['area']));
  late final _price = TextEditingController(text: _num(_l['price']));
  late final _city = TextEditingController(text: _l['city'] as String? ?? '');
  late final _locality = TextEditingController(text: _l['locality'] as String? ?? '');
  late final _floor = TextEditingController(text: _l['floor'] as String? ?? '');
  late final _name = TextEditingController(text: _l['name'] as String? ?? '');
  late final _phone = TextEditingController(text: _l['phone'] as String? ?? '');
  late final _desc = TextEditingController(text: _l['desc'] as String? ?? '');

  static String _num(dynamic v) => v == null ? '' : ((v as num) % 1 == 0 ? '${v.toInt()}' : '$v');

  List<String> get _amen => (_l['amenities'] as List).cast<String>();
  List<String> get _photos => (_l['photos'] as List).cast<String>();

  void _collect() {
    _l['area'] = udParseNum(_area.text);
    _l['price'] = udParseNum(_price.text);
    _l['city'] = _city.text.trim();
    _l['locality'] = _locality.text.trim();
    _l['floor'] = _floor.text.trim();
    _l['name'] = _name.text.trim();
    _l['phone'] = _phone.text.trim();
    _l['desc'] = _desc.text.trim();
  }

  Future<void> _addPhotos() async {
    final picked = await ImagePicker().pickMultiImage(imageQuality: 82, maxWidth: 1600);
    if (picked.isEmpty) return;
    final dir = await udDir('ghar_photos');
    final saved = <String>[];
    for (final x in picked) {
      final f = File('${dir.path}/${DateTime.now().microsecondsSinceEpoch}.jpg');
      await File(x.path).copy(f.path);
      saved.add(f.path);
    }
    setState(() => _l['photos'] = [..._photos, ...saved]);
  }

  Future<void> _save() async {
    _collect();
    if (_l['price'] == null || (_l['city'] as String).isEmpty || (_l['phone'] as String).isEmpty) {
      udToast(context, context.tr('required'));
      return;
    }
    if ((_l['desc'] as String).isEmpty) _l['desc'] = autoDescription(context, _l);
    _l['created'] ??= DateTime.now().toIso8601String();
    if (_l['id'] == null) {
      await listings.add(_l);
    } else {
      await listings.put(_l);
    }
    if (mounted) Navigator.of(context).pop();
  }

  Widget _field(TextEditingController c, String label, {TextInputType? type, int lines = 1}) {
    final text = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Padding(padding: const EdgeInsets.only(bottom: 6, left: 4), child: Text(label, style: text.labelMedium)),
        TextField(
          controller: c,
          keyboardType: type,
          maxLines: lines,
          minLines: 1,
          style: text.bodyLarge,
          decoration: udInputDecoration(context),
        ),
      ]),
    );
  }

  Widget _chips<T>(List<T> values, T selected, String Function(T) label, ValueChanged<T> onPick) => Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          for (final v in values)
            ChoiceChip(
              label: Text(label(v)),
              selected: v == selected,
              showCheckmark: false,
              onSelected: (_) => setState(() => onPick(v)),
            ),
        ],
      );

  @override
  Widget build(BuildContext context) {
    final t = UdTokens.of(context);
    final type = _l['type'] as String;
    final rent = _l['purpose'] == 'rent';
    return UdPage(
      title: context.tr(widget.initial == null ? 'post' : 'edit'),
      dock: UdDock(label: context.tr('save_listing'), icon: Icons.check_rounded, onPressed: _save),
      slivers: [
        UdSliverPad(
          sliver: SliverList.list(children: [
            UdLabel(context.tr('purpose')),
            _chips<String>(['sale', 'rent'], _l['purpose'] as String, (v) => context.tr(v), (v) => _l['purpose'] = v),
            const SizedBox(height: 14),
            UdLabel(context.tr('type')),
            _chips<String>(propertyTypes, type, (v) => context.tr('pt_$v'), (v) => _l['type'] = v),
            if (hasBhk(type)) ...[
              const SizedBox(height: 14),
              UdLabel(context.tr('bhk')),
              _chips<int>([1, 2, 3, 4, 5], (_l['bhk'] as num?)?.toInt() ?? 2, (v) => v == 5 ? '5+' : '$v',
                  (v) => _l['bhk'] = v),
            ],
            const SizedBox(height: 18),
            Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
              Expanded(child: _field(_area, context.tr('area_label'), type: TextInputType.number)),
              const SizedBox(width: 10),
              Padding(
                padding: const EdgeInsets.only(bottom: 14),
                child: SegmentedButton<String>(
                  showSelectedIcon: false,
                  segments: const [
                    ButtonSegment(value: 'sqft', label: Text('sq ft')),
                    ButtonSegment(value: 'sqyd', label: Text('gaj')),
                  ],
                  selected: {_l['unit'] as String},
                  onSelectionChanged: (s) => setState(() => _l['unit'] = s.first),
                ),
              ),
            ]),
            _field(_price, context.tr(rent ? 'rent_price' : 'price'), type: TextInputType.number),
            _field(_city, context.tr('city')),
            _field(_locality, context.tr('locality')),
            if (type != 'plot') _field(_floor, context.tr('floor'), type: TextInputType.number),
            if (hasBhk(type) || type == 'office') ...[
              UdLabel(context.tr('furnishing')),
              _chips<String>(['none', 'semi', 'full'], _l['furnishing'] as String, (v) => context.tr('f_$v'),
                  (v) => _l['furnishing'] = v),
              const SizedBox(height: 14),
            ],
            UdLabel(context.tr('amenities')),
            Wrap(spacing: 8, runSpacing: 8, children: [
              for (final a in amenityKeys)
                FilterChip(
                  label: Text(context.tr('a_$a')),
                  selected: _amen.contains(a),
                  onSelected: (on) => setState(() => _l['amenities'] = on ? [..._amen, a] : (_amen..remove(a))),
                ),
            ]),
            const SizedBox(height: 18),
            UdLabel(context.tr('photos')),
            SizedBox(
              height: 96,
              child: ListView(scrollDirection: Axis.horizontal, children: [
                GestureDetector(
                  onTap: _addPhotos,
                  child: Container(
                    width: 96,
                    decoration: BoxDecoration(
                      color: t.accentSoft,
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(color: t.line),
                    ),
                    child: Icon(Icons.add_a_photo_outlined, color: t.accent),
                  ),
                ),
                for (final p in _photos)
                  Padding(
                    padding: const EdgeInsets.only(left: 8),
                    child: Stack(children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(18),
                        child: Image.file(File(p), width: 96, height: 96, fit: BoxFit.cover, cacheWidth: 300),
                      ),
                      Positioned(
                        right: 4,
                        top: 4,
                        child: GestureDetector(
                          onTap: () => setState(() => _l['photos'] = [..._photos]..remove(p)),
                          child: const CircleAvatar(
                              radius: 12, backgroundColor: Colors.black54, child: Icon(Icons.close, size: 14, color: Colors.white)),
                        ),
                      ),
                    ]),
                  ),
              ]),
            ),
            const SizedBox(height: 18),
            _field(_name, context.tr('contact')),
            _field(_phone, context.tr('phone'), type: TextInputType.phone),
            Row(children: [
              Expanded(child: UdLabel(context.tr('description'))),
              TextButton.icon(
                onPressed: () {
                  _collect();
                  setState(() => _desc.text = autoDescription(context, _l));
                },
                icon: const Icon(Icons.auto_awesome_rounded, size: 18),
                label: Text(context.tr('auto_write')),
              ),
            ]),
            _field(_desc, '', lines: 6),
          ]),
        ),
      ],
    );
  }
}

class ListingPage extends StatefulWidget {
  const ListingPage({super.key, required this.id});
  final String id;

  @override
  State<ListingPage> createState() => _ListingPageState();
}

class _ListingPageState extends State<ListingPage> {
  final _flyerKey = GlobalKey();

  Map<String, dynamic>? get _l {
    for (final e in listings.items) {
      if (e['id'] == widget.id) return e;
    }
    return null;
  }

  Future<String?> _flyerPng() async {
    final boundary = _flyerKey.currentContext?.findRenderObject() as RenderRepaintBoundary?;
    if (boundary == null) return null;
    final img = await boundary.toImage(pixelRatio: 3);
    final data = await img.toByteData(format: ui.ImageByteFormat.png);
    if (data == null) return null;
    final dir = await getTemporaryDirectory();
    final f = File('${dir.path}/ghar_flyer_${DateTime.now().millisecondsSinceEpoch}.png');
    await f.writeAsBytes(data.buffer.asUint8List());
    return f.path;
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: listings,
      builder: (context, _) {
        final l = _l;
        if (l == null) return const Scaffold();
        final t = UdTokens.of(context);
        final text = Theme.of(context).textTheme;
        final photos = (l['photos'] as List? ?? const []).cast<String>().where((p) => File(p).existsSync()).toList();
        final done = l['status'] == 'done';
        return UdPage(
          title: headline(context, l),
          subtitle: place(l),
          actions: [
            UdIconButton(
              icon: Icons.edit_outlined,
              tooltip: context.tr('edit'),
              onTap: () => Navigator.of(context)
                  .push(MaterialPageRoute(builder: (_) => ListingForm(initial: Map<String, dynamic>.from(l)))),
            ),
            UdIconButton(
              icon: Icons.delete_outline_rounded,
              tooltip: context.tr('delete'),
              onTap: () async {
                if (!await udConfirm(context)) return;
                await listings.remove(l['id'] as String);
                if (context.mounted) Navigator.of(context).pop();
              },
            ),
          ],
          dock: UdDock(
            label: context.tr('share_whatsapp'),
            icon: Icons.share_rounded,
            onPressed: () async {
              final flyer = await _flyerPng();
              await udShareFiles([if (flyer != null) flyer, ...photos.take(5)], text: l['desc'] as String?);
            },
            extras: [
              UdDockAction(
                icon: Icons.image_outlined,
                label: context.tr('share_flyer'),
                onTap: () async {
                  final flyer = await _flyerPng();
                  if (flyer != null) await udShareFiles([flyer]);
                },
              ),
            ],
          ),
          slivers: [
            UdSliverPad(
              sliver: SliverList.list(children: [
                Center(
                  child: RepaintBoundary(
                    key: _flyerKey,
                    child: _Flyer(listing: l, photo: photos.isEmpty ? null : photos.first),
                  ),
                ),
                const SizedBox(height: 16),
                if (photos.length > 1)
                  SizedBox(
                    height: 90,
                    child: ListView(scrollDirection: Axis.horizontal, children: [
                      for (final p in photos.skip(1))
                        Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(14),
                            child: Image.file(File(p), width: 120, height: 90, fit: BoxFit.cover, cacheWidth: 360),
                          ),
                        ),
                    ]),
                  ),
                const SizedBox(height: 16),
                Text(l['desc'] as String? ?? '', style: text.bodyLarge),
                const SizedBox(height: 16),
                OutlinedButton.icon(
                  onPressed: () async {
                    l['status'] = done ? 'active' : 'done';
                    await listings.put(l);
                  },
                  icon: Icon(done ? Icons.refresh_rounded : Icons.handshake_outlined, color: t.accent),
                  label: Text(context.tr(done ? 'mark_active' : 'mark_sold')),
                ),
              ]),
            ),
          ],
        );
      },
    );
  }
}

/// The shareable card: photo, price, headline, key facts and phone number.
class _Flyer extends StatelessWidget {
  const _Flyer({required this.listing, this.photo});
  final Map<String, dynamic> listing;
  final String? photo;

  @override
  Widget build(BuildContext context) {
    final t = UdTokens.of(context);
    final text = Theme.of(context).textTheme;
    const paper = Color(0xFFFFFCF5);
    const ink = Color(0xFF1D1B16);
    final amen = [for (final a in (listing['amenities'] as List? ?? const []).take(4)) context.tr('a_$a')];
    return Container(
      width: 340,
      decoration: BoxDecoration(
        color: paper,
        borderRadius: BorderRadius.circular(26),
        border: Border.all(color: const Color(0xFFE4DCCC)),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AspectRatio(
            aspectRatio: 4 / 3,
            child: Stack(fit: StackFit.expand, children: [
              photo != null
                  ? Image.file(File(photo!), fit: BoxFit.cover, cacheWidth: 1000)
                  : Container(color: t.accent, child: const Icon(Icons.home_work_rounded, size: 80, color: Colors.white54)),
              Positioned(
                left: 14,
                top: 14,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(color: t.accent, borderRadius: BorderRadius.circular(14)),
                  child: Text(
                    context.tr(listing['purpose'] == 'rent' ? 'for_rent' : 'for_sale').toUpperCase(),
                    style: text.labelMedium?.copyWith(color: Colors.white, letterSpacing: 1.4),
                  ),
                ),
              ),
            ]),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(priceLabel(context, listing), style: text.displaySmall?.copyWith(color: t.accent)),
                const SizedBox(height: 2),
                Text(headline(context, listing), style: text.titleLarge?.copyWith(color: ink)),
                const SizedBox(height: 4),
                Row(children: [
                  Icon(Icons.place_outlined, size: 16, color: ink.withValues(alpha: 0.6)),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(place(listing),
                        style: text.bodyMedium?.copyWith(color: ink.withValues(alpha: 0.7))),
                  ),
                ]),
                if (areaLabel(listing).isNotEmpty || amen.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  Wrap(spacing: 6, runSpacing: 6, children: [
                    for (final s in [if (areaLabel(listing).isNotEmpty) areaLabel(listing), ...amen])
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                        decoration: BoxDecoration(
                          color: t.accent.withValues(alpha: 0.10),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(s, style: text.labelMedium?.copyWith(color: ink)),
                      ),
                  ]),
                ],
                const SizedBox(height: 14),
                Container(height: 1, color: const Color(0xFFE4DCCC)),
                const SizedBox(height: 12),
                Row(children: [
                  CircleAvatar(
                    radius: 18,
                    backgroundColor: ink,
                    child: const Icon(Icons.call_rounded, size: 18, color: paper),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      if ((listing['name'] as String? ?? '').isNotEmpty)
                        Text(listing['name'] as String, style: text.labelMedium?.copyWith(color: ink)),
                      Text(listing['phone'] as String? ?? '', style: text.titleLarge?.copyWith(color: ink)),
                    ]),
                  ),
                ]),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
