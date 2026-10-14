import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:open_filex/open_filex.dart';
import 'package:ud_core/ud_core.dart';

import 'store.dart';
import 'strings.dart';

const appName = 'Daftar';

void main() => runUdApp(UdAppSpec(
      name: appName,
      taglineKey: 'tagline',
      accent: const Color(0xFF1E5A8C),
      icon: Icons.folder_copy_outlined,
      strings: daftarStrings,
      home: (_) => const DaftarGate(),
    ));

class DaftarGate extends StatefulWidget {
  const DaftarGate({super.key});

  @override
  State<DaftarGate> createState() => _DaftarGateState();
}

class _DaftarGateState extends State<DaftarGate> {
  DaftarStore? _store;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_store == null) _init();
  }

  Future<void> _init() async {
    final names = [for (final k in starterFolders) context.tr(k)];
    final store = await DaftarStore.open();
    await store.seed(names);
    if (mounted) setState(() => _store = store);
  }

  @override
  Widget build(BuildContext context) {
    final store = _store;
    if (store == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    return HomePage(store: store);
  }
}

const starterFolders = ['f_identity', 'f_bank', 'f_education', 'f_health', 'f_bills', 'f_work'];

// ------------------------------------------------------------------ home

class HomePage extends StatefulWidget {
  const HomePage({super.key, required this.store});
  final DaftarStore store;

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  String _query = '';

  DaftarStore get store => widget.store;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: store,
      builder: (context, _) {
        final totals = store.totals();
        final results = _query.isEmpty ? null : store.search(_query);
        return UdPage(
          eyebrow: appName,
          title: context.tr('home_title'),
          subtitle: context.tr('home_sub',
              {'n': '${totals.files}', 'size': udFormatBytes(totals.bytes)}),
          actions: [
            UdIconButton(
              icon: Icons.sort_rounded,
              tooltip: context.tr('sort'),
              onTap: () => pickSort(context, store),
            ),
            const UdSettingsButton(appName: appName),
          ],
          dock: _dock(context, store, store.root),
          slivers: [
            UdSliverPad(
              bottom: 18,
              sliver: SliverToBoxAdapter(
                child: TextField(
                  onChanged: (v) => setState(() => _query = v.trim()),
                  decoration: udInputDecoration(context,
                      hint: context.tr('search_hint'), icon: Icons.search_rounded),
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
                        for (final e in results) FileRow(store: store, entry: e, showFolder: true),
                      ]),
                    )
            else ...[
              UdSliverPad(
                bottom: 18,
                sliver: SliverGrid(
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    mainAxisSpacing: 12,
                    crossAxisSpacing: 12,
                    childAspectRatio: 1.5,
                  ),
                  delegate: SliverChildListDelegate([
                    for (final q in _quick(context))
                      UdToolTile(
                        icon: q.icon,
                        title: q.title,
                        subtitle: '${q.load().length}',
                        onTap: () => Navigator.of(context).push(MaterialPageRoute(
                          builder: (_) => ListPage(store: store, title: q.title, icon: q.icon, load: q.load),
                        )),
                      ),
                  ]),
                ),
              ),
              ..._folderContents(context, store, store.root),
            ],
          ],
        );
      },
    );
  }

  List<_Quick> _quick(BuildContext context) => [
        _Quick(Icons.star_outline_rounded, context.tr('starred'), store.starred),
        _Quick(Icons.history_rounded, context.tr('recent'), store.recent),
        _Quick(kindIcon(FileKind.pdf), context.tr('pdfs'), () => store.ofKind(FileKind.pdf)),
        _Quick(kindIcon(FileKind.image), context.tr('photos'), () => store.ofKind(FileKind.image)),
      ];
}

class _Quick {
  _Quick(this.icon, this.title, this.load);
  final IconData icon;
  final String title;
  final List<Entry> Function() load;
}

/// Folders, then files, of one directory as slivers.
List<Widget> _folderContents(BuildContext context, DaftarStore store, Directory dir) {
  final folders = store.foldersIn(dir);
  final files = store.filesIn(dir);
  return [
    if (folders.isNotEmpty)
      UdSliverPad(
        bottom: 8,
        sliver: SliverList.list(children: [
          UdLabel(context.tr('folders')),
          for (final d in folders) FolderRow(store: store, dir: d),
        ]),
      ),
    if (files.isNotEmpty)
      UdSliverPad(
        sliver: SliverList.list(children: [
          UdLabel(context.tr('files')),
          for (final e in files) FileRow(store: store, entry: e),
        ]),
      ),
    if (folders.isEmpty && files.isEmpty)
      SliverToBoxAdapter(
        child: UdEmpty(
          icon: Icons.folder_open_outlined,
          title: context.tr('empty_folder'),
          body: context.tr('empty_folder_body'),
        ),
      ),
  ];
}

UdDock _dock(BuildContext context, DaftarStore store, Directory dir) => UdDock(
      label: context.tr('add'),
      icon: Icons.add_rounded,
      onPressed: () => addFlow(context, store, dir),
      extras: [
        UdDockAction(
          icon: Icons.create_new_folder_outlined,
          label: context.tr('new_folder'),
          onTap: () => newFolder(context, store, dir),
        ),
      ],
    );

// ------------------------------------------------------------------ pages

class FolderPage extends StatelessWidget {
  const FolderPage({super.key, required this.store, required this.dir});
  final DaftarStore store;
  final Directory dir;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: store,
      builder: (context, _) {
        if (!dir.existsSync()) return const SizedBox.shrink();
        return UdPage(
          eyebrow: store.crumbs(dir.parent, appName),
          title: dir.path.split('/').last,
          subtitle: context.tr('n_files', {'n': '${store.countIn(dir)}'}),
          actions: [
            UdIconButton(
              icon: Icons.sort_rounded,
              tooltip: context.tr('sort'),
              onTap: () => pickSort(context, store),
            ),
          ],
          dock: _dock(context, store, dir),
          slivers: _folderContents(context, store, dir),
        );
      },
    );
  }
}

/// A flat list of files from anywhere (starred, recent, PDFs…).
class ListPage extends StatelessWidget {
  const ListPage({
    super.key,
    required this.store,
    required this.title,
    required this.icon,
    required this.load,
  });
  final DaftarStore store;
  final String title;
  final IconData icon;
  final List<Entry> Function() load;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: store,
      builder: (context, _) {
        final items = load();
        return UdPage(
          title: title,
          subtitle: context.tr('n_files', {'n': '${items.length}'}),
          slivers: [
            if (items.isEmpty)
              SliverToBoxAdapter(
                child: UdEmpty(icon: icon, title: context.tr('nothing_here')),
              )
            else
              UdSliverPad(
                sliver: SliverList.list(children: [
                  for (final e in items) FileRow(store: store, entry: e, showFolder: true),
                ]),
              ),
          ],
        );
      },
    );
  }
}

// ------------------------------------------------------------------ rows

class FolderRow extends StatelessWidget {
  const FolderRow({super.key, required this.store, required this.dir});
  final DaftarStore store;
  final Directory dir;

  @override
  Widget build(BuildContext context) {
    final t = UdTokens.of(context);
    return UdRow(
      leading: const UdBadgeIcon(Icons.folder_rounded),
      title: dir.path.split('/').last,
      subtitle: context.tr('n_files', {'n': '${store.countIn(dir)}'}),
      trailing: IconButton(
        icon: Icon(Icons.more_horiz_rounded, color: t.inkSoft),
        onPressed: () => folderActions(context, store, dir),
      ),
      onTap: () => Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => FolderPage(store: store, dir: dir)),
      ),
      onLongPress: () => folderActions(context, store, dir),
    );
  }
}

class FileRow extends StatelessWidget {
  const FileRow({super.key, required this.store, required this.entry, this.showFolder = false});
  final DaftarStore store;
  final Entry entry;
  final bool showFolder;

  @override
  Widget build(BuildContext context) {
    final t = UdTokens.of(context);
    final where = showFolder ? store.crumbs(entry.file.parent, appName) : null;
    final starred = store.isStarred(entry.path);
    return UdRow(
      leading: entry.kind == FileKind.image
          ? ClipRRect(
              borderRadius: BorderRadius.circular(15),
              child: Image.file(
                entry.file,
                width: 48,
                height: 48,
                fit: BoxFit.cover,
                cacheWidth: 144,
                errorBuilder: (_, __, ___) => UdBadgeIcon(kindIcon(entry.kind)),
              ),
            )
          : UdBadgeIcon(kindIcon(entry.kind)),
      title: entry.name,
      subtitle: [
        if (where != null) where,
        if (entry.ext.isNotEmpty) entry.ext.toUpperCase(),
        udFormatBytes(entry.size),
        udFormatDate(context, entry.modified),
      ].join(' · '),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (starred) Icon(Icons.star_rounded, size: 20, color: t.accent),
          IconButton(
            icon: Icon(Icons.more_horiz_rounded, color: t.inkSoft),
            onPressed: () => fileActions(context, store, entry),
          ),
        ],
      ),
      onTap: () => openEntry(context, entry),
      onLongPress: () => fileActions(context, store, entry),
    );
  }
}

// ------------------------------------------------------------------ actions

Future<void> openEntry(BuildContext context, Entry e) async {
  final r = await OpenFilex.open(e.path);
  if (r.type != ResultType.done && context.mounted) {
    udToast(context, context.tr('no_app'));
  }
}

Future<void> fileActions(BuildContext context, DaftarStore store, Entry e) async {
  final starred = store.isStarred(e.path);
  final a = await showUdActions<String>(context, title: e.fileName, actions: [
    UdAction('open', Icons.open_in_new_rounded, context.tr('open')),
    UdAction('share', Icons.ios_share_rounded, context.tr('share')),
    UdAction('star', starred ? Icons.star_rounded : Icons.star_outline_rounded,
        context.tr(starred ? 'unstar' : 'star')),
    UdAction('rename', Icons.edit_outlined, context.tr('rename')),
    UdAction('move', Icons.drive_file_move_outline, context.tr('move')),
    UdAction('copy', Icons.copy_rounded, context.tr('duplicate')),
    UdAction('info', Icons.info_outline_rounded, context.tr('details')),
    UdAction('delete', Icons.delete_outline_rounded, context.tr('delete'), danger: true),
  ]);
  if (!context.mounted || a == null) return;
  try {
    switch (a) {
      case 'open':
        await openEntry(context, e);
      case 'share':
        await udShareFiles([await store.exportCopy(e)]);
      case 'star':
        await store.toggleStar(e.path);
      case 'rename':
        final n = await udPrompt(context, title: context.tr('rename'), initial: e.name);
        if (n != null && n != e.name) await store.renameFile(e, n);
      case 'move':
        final to = await pickFolder(context, store, exclude: e.file.parent);
        if (to != null) {
          await store.moveFile(e, to);
          if (context.mounted) {
            udToast(context, context.tr('moved_to', {'f': store.crumbs(to, appName)}));
          }
        }
      case 'copy':
        await store.duplicate(e);
      case 'info':
        await _details(context, store, e);
      case 'delete':
        if (await udConfirm(context)) await store.deleteFile(e);
    }
  } on FileSystemException {
    if (context.mounted) udToast(context, context.tr('error_generic'));
  }
}

Future<void> folderActions(BuildContext context, DaftarStore store, Directory d) async {
  final name = d.path.split('/').last;
  final a = await showUdActions<String>(context, title: name, actions: [
    UdAction('rename', Icons.edit_outlined, context.tr('rename')),
    UdAction('delete', Icons.delete_outline_rounded, context.tr('delete'), danger: true),
  ]);
  if (!context.mounted || a == null) return;
  try {
    switch (a) {
      case 'rename':
        final n = await udPrompt(context, title: context.tr('rename'), initial: name);
        if (n != null && n != name) await store.renameFolder(d, n);
      case 'delete':
        final n = store.countIn(d);
        final ok = await udConfirm(context,
            title: context.tr('delete_folder'),
            body: n == 0
                ? context.tr('confirm_delete_sub')
                : context.tr('delete_folder_body', {'n': '$n'}));
        if (ok) await store.deleteFolder(d);
    }
  } on FileSystemException {
    if (context.mounted) udToast(context, context.tr('error_generic'));
  }
}

Future<void> _details(BuildContext context, DaftarStore store, Entry e) {
  return showUdSheet<void>(context, (c) {
    final t = UdTokens.of(c);
    final text = Theme.of(c).textTheme;
    Widget row(String k, String v) => Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                width: 110,
                child: Text(k, style: text.bodyMedium?.copyWith(color: t.inkSoft)),
              ),
              Expanded(child: Text(v, style: text.bodyMedium)),
            ],
          ),
        );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(e.fileName, style: text.headlineSmall),
        const SizedBox(height: 18),
        row(c.tr('d_folder'), store.crumbs(e.file.parent, appName)),
        row(c.tr('d_type'), e.ext.isEmpty ? '—' : e.ext.toUpperCase()),
        row(c.tr('d_size'), udFormatBytes(e.size)),
        row(c.tr('d_modified'), udFormatDate(c, e.modified)),
      ],
    );
  });
}

Future<void> pickSort(BuildContext context, DaftarStore store) async {
  final s = await showUdActions<SortBy>(context, title: context.tr('sort'), actions: [
    UdAction(SortBy.newest, Icons.schedule_rounded, context.tr('sort_newest')),
    UdAction(SortBy.name, Icons.sort_by_alpha_rounded, context.tr('sort_name')),
    UdAction(SortBy.size, Icons.data_usage_rounded, context.tr('sort_size')),
  ]);
  if (s != null) await store.setSort(s);
}

/// Lists every folder with its path; returns the one picked.
Future<Directory?> pickFolder(BuildContext context, DaftarStore store, {Directory? exclude}) {
  final folders = store.allFolders().where((d) => d.path != exclude?.path).toList();
  return showUdActions<Directory>(context, title: context.tr('move_to'), actions: [
    for (final d in folders)
      UdAction(
        d,
        d.path == store.root.path ? Icons.home_outlined : Icons.folder_outlined,
        store.crumbs(d, appName),
      ),
  ]);
}

Future<void> newFolder(BuildContext context, DaftarStore store, Directory parent) async {
  final n = await udPrompt(context, title: context.tr('new_folder'), hint: context.tr('folder_name'));
  if (n == null) return;
  await store.createFolder(parent, n);
}

Future<void> addFlow(BuildContext context, DaftarStore store, Directory dir) async {
  final src = await showUdActions<String>(context, title: context.tr('add'), actions: [
    UdAction('files', Icons.folder_open_outlined, context.tr('from_files')),
    UdAction('camera', Icons.photo_camera_outlined, context.tr('from_camera')),
    UdAction('gallery', Icons.photo_library_outlined, context.tr('from_gallery')),
    UdAction('folder', Icons.create_new_folder_outlined, context.tr('new_folder')),
  ]);
  if (src == null || !context.mounted) return;
  if (src == 'folder') return newFolder(context, store, dir);

  final paths = <String>[];
  String? prefix;
  try {
    switch (src) {
      case 'files':
        paths.addAll(await udPickFiles());
      case 'camera':
        final x = await ImagePicker().pickImage(source: ImageSource.camera, imageQuality: 88);
        if (x != null) {
          paths.add(x.path);
          prefix = udStampName(context.tr('photo'));
        }
      case 'gallery':
        paths.addAll([for (final x in await ImagePicker().pickMultiImage(imageQuality: 92)) x.path]);
    }
  } catch (_) {
    if (context.mounted) udToast(context, context.tr('error_generic'));
    return;
  }
  if (paths.isEmpty || !context.mounted) return;
  final n = await store.import(dir, paths, namePrefix: prefix);
  if (context.mounted) {
    udToast(context, context.tr('added', {'n': '$n', 'f': store.crumbs(dir, appName)}));
  }
}
