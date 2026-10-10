import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:open_filex/open_filex.dart';
import 'package:ud_core/ud_core.dart';

import 'pin.dart';
import 'store.dart';
import 'strings.dart';

const appName = 'Vault';

void main() => runUdApp(UdAppSpec(
      name: appName,
      taglineKey: 'tagline',
      accent: const Color(0xFF1F5F5B),
      icon: Icons.shield_outlined,
      strings: vaultStrings,
      home: (_) => const VaultGate(),
    ));

/// Loads storage, shows the PIN lock when needed and re-locks after the app
/// has been in the background for more than 30 seconds.
class VaultGate extends StatefulWidget {
  const VaultGate({super.key});

  @override
  State<VaultGate> createState() => _VaultGateState();
}

class _VaultGateState extends State<VaultGate> with WidgetsBindingObserver {
  VaultStore? _store;
  PinStore? _pins;
  bool _locked = true;
  bool _wrong = false;
  DateTime? _hiddenAt;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _init();
  }

  Future<void> _init() async {
    final store = await VaultStore.open();
    final pins = await PinStore.open();
    if (!mounted) return;
    setState(() {
      _store = store;
      _pins = pins;
      _locked = pins.isSet;
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused || state == AppLifecycleState.hidden) {
      _hiddenAt ??= DateTime.now();
    } else if (state == AppLifecycleState.resumed) {
      final hidden = _hiddenAt;
      _hiddenAt = null;
      if (hidden != null &&
          (_pins?.isSet ?? false) &&
          DateTime.now().difference(hidden).inSeconds > 30) {
        Navigator.of(context).popUntil((r) => r.isFirst);
        setState(() => _locked = true);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final store = _store;
    final pins = _pins;
    if (store == null || pins == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    if (_locked) {
      return Scaffold(
        body: SafeArea(
          child: PinPad(
            title: context.tr('lock_title'),
            error: _wrong ? context.tr('lock_wrong') : null,
            onComplete: (pin) async {
              final ok = pins.check(pin);
              setState(() {
                _wrong = !ok;
                if (ok) _locked = false;
              });
              return ok;
            },
          ),
        ),
      );
    }
    return HomePage(store: store, pins: pins);
  }
}

class HomePage extends StatefulWidget {
  const HomePage({super.key, required this.store, required this.pins});
  final VaultStore store;
  final PinStore pins;

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  String _query = '';

  VaultStore get store => widget.store;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: store,
      builder: (context, _) {
        final expiring = store.expiringSoon();
        final results = _query.isEmpty ? null : store.search(_query);
        return UdPage(
          eyebrow: appName,
          title: context.tr('home_title'),
          subtitle: context.tr('home_sub', {'n': '${store.docs.length}'}),
          actions: [
            UdIconButton(
              icon: widget.pins.isSet
                  ? Icons.lock_rounded
                  : Icons.lock_open_rounded,
              tooltip: widget.pins.isSet
                  ? context.tr('pin_remove')
                  : context.tr('pin_set'),
              onTap: _togglePin,
            ),
            const UdSettingsButton(appName: appName),
          ],
          dock: UdDock(
            label: context.tr('add'),
            icon: Icons.add_rounded,
            onPressed: () => addDocumentFlow(context, store),
          ),
          slivers: [
            UdSliverPad(
              bottom: 18,
              sliver: SliverToBoxAdapter(
                child: TextField(
                  onChanged: (v) => setState(() => _query = v.trim()),
                  decoration: udInputDecoration(context,
                      hint: context.tr('search_hint'),
                      icon: Icons.search_rounded),
                ),
              ),
            ),
            if (results != null)
              results.isEmpty
                  ? SliverToBoxAdapter(
                      child: UdEmpty(
                          icon: Icons.search_off_rounded,
                          title: context.tr('no_results')))
                  : UdSliverPad(
                      sliver: SliverList.list(children: [
                        for (final d in results) DocRow(store: store, doc: d),
                      ]),
                    )
            else ...[
              if (!widget.pins.isSet)
                UdSliverPad(
                  bottom: 18,
                  sliver: SliverToBoxAdapter(child: _PinCard(onTap: _togglePin)),
                ),
              if (expiring.isNotEmpty)
                UdSliverPad(
                  bottom: 8,
                  sliver: SliverList.list(children: [
                    UdLabel(context.tr('expiring_soon')),
                    for (final d in expiring.take(4)) DocRow(store: store, doc: d),
                  ]),
                ),
              UdSliverPad(
                sliver: SliverGrid(
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    mainAxisSpacing: 12,
                    crossAxisSpacing: 12,
                    childAspectRatio: 1.02,
                  ),
                  delegate: SliverChildListDelegate([
                    for (final c in vaultCategories)
                      UdToolTile(
                        icon: c.icon,
                        title: c.title(context),
                        subtitle:
                            '${store.inCategory(c.id).length} · ${c.sub(context)}',
                        onTap: () => Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) =>
                                CategoryPage(store: store, category: c),
                          ),
                        ),
                      ),
                  ]),
                ),
              ),
            ],
          ],
        );
      },
    );
  }

  Future<void> _togglePin() async {
    if (widget.pins.isSet) {
      final ok = await udConfirm(context,
          title: context.tr('pin_remove'),
          body: context.tr('pin_on'),
          confirmLabel: context.tr('pin_remove'));
      if (ok) {
        await widget.pins.clear();
        setState(() {});
      }
      return;
    }
    await Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => SetPinPage(onSave: widget.pins.set),
    ));
    if (mounted) setState(() {});
  }
}

class _PinCard extends StatelessWidget {
  const _PinCard({required this.onTap});
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final t = UdTokens.of(context);
    final text = Theme.of(context).textTheme;
    return UdPressable(
      onTap: onTap,
      color: t.accentSoft,
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          Icon(Icons.lock_person_outlined, color: t.accent, size: 30),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(context.tr('pin_card_title'), style: text.titleMedium),
                Text(context.tr('pin_card_body'),
                    style: text.bodySmall?.copyWith(color: t.inkSoft)),
              ],
            ),
          ),
          Icon(Icons.chevron_right_rounded, color: t.accent),
        ],
      ),
    );
  }
}

class CategoryPage extends StatelessWidget {
  const CategoryPage({super.key, required this.store, required this.category});
  final VaultStore store;
  final VaultCategory category;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: store,
      builder: (context, _) {
        final docs = store.inCategory(category.id);
        return UdPage(
          title: category.title(context),
          subtitle: category.sub(context),
          dock: UdDock(
            label: context.tr('add'),
            icon: Icons.add_rounded,
            onPressed: () =>
                addDocumentFlow(context, store, category: category.id),
          ),
          slivers: [
            if (docs.isEmpty)
              SliverToBoxAdapter(
                child: UdEmpty(
                  icon: category.icon,
                  title: context.tr('empty_cat'),
                  body: context.tr('empty_cat_body'),
                ),
              )
            else
              UdSliverPad(
                sliver: SliverList.list(children: [
                  for (final d in docs) DocRow(store: store, doc: d),
                ]),
              ),
          ],
        );
      },
    );
  }
}

class DocRow extends StatelessWidget {
  const DocRow({super.key, required this.store, required this.doc});
  final VaultStore store;
  final VaultDoc doc;

  @override
  Widget build(BuildContext context) {
    final t = UdTokens.of(context);
    final text = Theme.of(context).textTheme;
    final days = doc.daysLeft;
    Widget? badge;
    if (days != null && days <= 45) {
      final expired = days < 0;
      badge = Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: (expired ? t.danger : const Color(0xFFB7791F))
              .withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(
          expired
              ? context.tr('expired')
              : context.tr('expires_in', {'n': '$days'}),
          style: text.labelSmall?.copyWith(
              color: expired ? t.danger : const Color(0xFF8A5A0B)),
        ),
      );
    }
    return UdRow(
      leading: UdBadgeIcon(doc.icon),
      title: doc.name,
      subtitle:
          '${categoryById(doc.cat).title(context)} · ${udFormatBytes(doc.size)}',
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (badge != null) badge,
          IconButton(
            icon: Icon(Icons.more_horiz_rounded, color: t.inkSoft),
            onPressed: () => docActions(context, store, doc),
          ),
        ],
      ),
      onTap: () => OpenFilex.open(store.pathOf(doc)),
      onLongPress: () => docActions(context, store, doc),
    );
  }
}

Future<void> docActions(BuildContext context, VaultStore store, VaultDoc doc) async {
  final a = await showUdActions<String>(context, title: doc.name, actions: [
    UdAction('open', Icons.open_in_new_rounded, context.tr('open')),
    UdAction('share', Icons.ios_share_rounded, context.tr('share')),
    UdAction('rename', Icons.edit_outlined, context.tr('rename')),
    UdAction('move', Icons.drive_file_move_outline, context.tr('move')),
    UdAction('expiry', Icons.event_outlined, context.tr('set_expiry')),
    UdAction('delete', Icons.delete_outline_rounded, context.tr('delete'), danger: true),
  ]);
  if (!context.mounted || a == null) return;
  switch (a) {
    case 'open':
      await OpenFilex.open(store.pathOf(doc));
    case 'share':
      await udShareFiles([await store.exportCopy(doc)]);
    case 'rename':
      final n = await udPrompt(context, title: context.tr('rename'), initial: doc.name);
      if (n != null) {
        doc.name = n;
        await store.update(doc);
      }
    case 'move':
      final c = await _pickCategory(context, doc.cat);
      if (c != null) {
        doc.cat = c;
        await store.update(doc);
      }
    case 'expiry':
      final d = await _pickDate(context, doc.expiry);
      if (d != null) {
        doc.expiry = d;
        await store.update(doc);
      }
    case 'delete':
      if (await udConfirm(context)) await store.remove(doc);
  }
}

Future<String?> _pickCategory(BuildContext context, String current) =>
    showUdActions<String>(context, title: context.tr('choose_category'), actions: [
      for (final c in vaultCategories) UdAction(c.id, c.icon, c.title(context)),
    ]);

Future<DateTime?> _pickDate(BuildContext context, DateTime? initial) {
  final now = DateTime.now();
  return showDatePicker(
    context: context,
    initialDate: initial ?? now.add(const Duration(days: 365)),
    firstDate: DateTime(now.year - 20),
    lastDate: DateTime(now.year + 50),
  );
}

/// Source → name, category and optional expiry → saved.
Future<void> addDocumentFlow(BuildContext context, VaultStore store, {String? category}) async {
  final src = await showUdActions<String>(context, title: context.tr('add'), actions: [
    UdAction('files', Icons.folder_open_outlined, context.tr('from_files')),
    UdAction('camera', Icons.photo_camera_outlined, context.tr('from_camera')),
    UdAction('gallery', Icons.photo_library_outlined, context.tr('from_gallery')),
  ]);
  if (src == null || !context.mounted) return;

  final paths = <String>[];
  if (src == 'files') {
    paths.addAll(await udPickFiles());
  } else {
    final x = await ImagePicker().pickImage(
      source: src == 'camera' ? ImageSource.camera : ImageSource.gallery,
      imageQuality: 88,
    );
    if (x != null) paths.add(x.path);
  }
  if (paths.isEmpty || !context.mounted) return;

  for (final p in paths) {
    if (!context.mounted) return;
    final fileName = p.split('/').last;
    final dot = fileName.lastIndexOf('.');
    final suggested = src == 'files' && dot > 0 ? fileName.substring(0, dot) : '';
    final details = await showUdSheet<_Details>(
      context,
      (c) => _DetailsForm(initialName: suggested, initialCat: category ?? 'identity'),
    );
    if (details == null) continue;
    await store.add(
      sourcePath: p,
      name: details.name,
      cat: details.cat,
      expiry: details.expiry,
    );
    if (context.mounted) {
      udToast(context, context.tr('added', {'c': categoryById(details.cat).title(context)}));
    }
  }
}

class _Details {
  _Details(this.name, this.cat, this.expiry);
  final String name;
  final String cat;
  final DateTime? expiry;
}

class _DetailsForm extends StatefulWidget {
  const _DetailsForm({required this.initialName, required this.initialCat});
  final String initialName;
  final String initialCat;

  @override
  State<_DetailsForm> createState() => _DetailsFormState();
}

class _DetailsFormState extends State<_DetailsForm> {
  late final _name = TextEditingController(text: widget.initialName);
  late String _cat = widget.initialCat;
  DateTime? _expiry;

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final t = UdTokens.of(context);
    final text = Theme.of(context).textTheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(context.tr('add'), style: text.headlineSmall),
        const SizedBox(height: 16),
        TextField(
          controller: _name,
          autofocus: widget.initialName.isEmpty,
          style: text.bodyLarge,
          decoration: udInputDecoration(context, hint: context.tr('doc_name')),
        ),
        const SizedBox(height: 18),
        UdLabel(context.tr('choose_category')),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final c in vaultCategories)
              ChoiceChip(
                avatar: Icon(c.icon,
                    size: 18, color: c.id == _cat ? t.onAccent : t.accent),
                label: Text(c.title(context)),
                labelStyle: text.labelMedium
                    ?.copyWith(color: c.id == _cat ? t.onAccent : t.ink),
                selected: c.id == _cat,
                showCheckmark: false,
                selectedColor: t.accent,
                backgroundColor: t.paper,
                side: BorderSide(color: c.id == _cat ? t.accent : t.line),
                shape: const StadiumBorder(),
                onSelected: (_) => setState(() => _cat = c.id),
              ),
          ],
        ),
        const SizedBox(height: 18),
        UdLabel(context.tr('expiry')),
        OutlinedButton.icon(
          onPressed: () async {
            final d = await _pickDate(context, _expiry);
            if (d != null) setState(() => _expiry = d);
          },
          icon: const Icon(Icons.event_outlined),
          label: Text(_expiry == null
              ? context.tr('expiry_none')
              : '${udTwo(_expiry!.day)}/${udTwo(_expiry!.month)}/${_expiry!.year}'),
        ),
        const SizedBox(height: 22),
        SizedBox(
          width: double.infinity,
          child: FilledButton(
            onPressed: () {
              final n = _name.text.trim();
              Navigator.pop(
                context,
                _Details(
                  n.isEmpty ? udStampName(categoryById(_cat).title(context)) : n,
                  _cat,
                  _expiry,
                ),
              );
            },
            child: Text(context.tr('save')),
          ),
        ),
      ],
    );
  }
}
