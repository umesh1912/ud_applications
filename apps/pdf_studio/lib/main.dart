import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:open_filex/open_filex.dart';
import 'package:syncfusion_flutter_pdfviewer/pdfviewer.dart';
import 'package:ud_core/ud_core.dart';

import 'pdf_ops.dart';
import 'strings.dart';

const appName = 'PDF Studio';

void main() => runUdApp(UdAppSpec(
      name: appName,
      taglineKey: 'tagline',
      accent: const Color(0xFFA3273B),
      icon: Icons.picture_as_pdf_rounded,
      strings: pdfStrings,
      home: (_) => const HomePage(),
    ));

/// A PDF the user picked, with the password if it needed one.
class PickedPdf {
  PickedPdf(this.path, this.bytes, this.password);
  final String path;
  final Uint8List bytes;
  final String? password;

  String get baseName {
    final n = path.split('/').last;
    return n.toLowerCase().endsWith('.pdf') ? n.substring(0, n.length - 4) : n;
  }
}

Future<PickedPdf?> pickPdf(BuildContext context, {bool askPassword = true}) async {
  final paths = await udPickFiles(extensions: const ['pdf']);
  if (paths.isEmpty || !context.mounted) return null;
  final path = paths.first;
  final bytes = await File(path).readAsBytes();
  if (!askPassword) return PickedPdf(path, bytes, null);
  String? password;
  for (var attempt = 0; attempt < 4; attempt++) {
    try {
      pageCountOf(bytes, password: password);
      return PickedPdf(path, bytes, password);
    } on PdfPasswordException {
      if (!context.mounted) return null;
      password = await udPrompt(
        context,
        title: context.tr(attempt == 0 ? 'password_needed' : 'password_wrong'),
        hint: context.tr('password'),
      );
      if (password == null) return null;
    } catch (_) {
      if (context.mounted) udToast(context, context.tr('error_generic'));
      return null;
    }
  }
  return null;
}

Future<Directory> outputDir() => udDir('pdf_studio');

Future<File> saveOutput(BuildContext context, String base, String suffixKey, Uint8List bytes) async {
  final dir = await outputDir();
  final suffix = context.mounted ? context.tr(suffixKey) : suffixKey;
  final path = udUniquePath(dir, '$base - $suffix', 'pdf');
  final f = File(path);
  await f.writeAsBytes(bytes, flush: true);
  return f;
}

class Tool {
  const Tool(this.id, this.icon);
  final String id;
  final IconData icon;
}

const tools = [
  Tool('merge', Icons.call_merge_rounded),
  Tool('images', Icons.add_photo_alternate_outlined),
  Tool('sign', Icons.draw_outlined),
  Tool('extract', Icons.content_copy_rounded),
  Tool('delete', Icons.layers_clear_outlined),
  Tool('rotate', Icons.rotate_right_rounded),
  Tool('numbers', Icons.format_list_numbered_rounded),
  Tool('watermark', Icons.branding_watermark_outlined),
  Tool('protect', Icons.lock_outline_rounded),
  Tool('unlock', Icons.lock_open_rounded),
];

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  List<File> _recent = [];

  @override
  void initState() {
    super.initState();
    _reload();
  }

  Future<void> _reload() async {
    final dir = await outputDir();
    final files = dir.listSync().whereType<File>().where((f) => f.path.endsWith('.pdf')).toList()
      ..sort((a, b) => b.statSync().modified.compareTo(a.statSync().modified));
    if (mounted) setState(() => _recent = files.take(8).toList());
  }

  Future<void> _go(Widget page) async {
    await Navigator.of(context).push(MaterialPageRoute(builder: (_) => page));
    _reload();
  }

  Future<void> _showResult(File f) => _go(ResultPage(file: f));

  Future<void> _view() async {
    final pdf = await pickPdf(context, askPassword: false);
    if (pdf != null) _go(ViewerPage(path: pdf.path));
  }

  Future<void> _run(String id) async {
    switch (id) {
      case 'merge':
        return _go(MergePage(onDone: _showResult));
      case 'images':
        return _images();
    }
    final pdf = await pickPdf(context, askPassword: id != 'unlock');
    if (pdf == null || !mounted) return;
    try {
      final f = await _apply(id, pdf);
      if (f != null && mounted) {
        await _showResult(f);
      }
    } on PdfPasswordException {
      if (mounted) udToast(context, context.tr('password_wrong'));
    } catch (_) {
      if (mounted) udToast(context, context.tr('error_generic'));
    }
  }

  Future<File?> _apply(String id, PickedPdf pdf) async {
    final pw = pdf.password;
    final count = id == 'unlock' ? 0 : pageCountOf(pdf.bytes, password: pw);
    Uint8List? out;
    String sfx = 'sfx_deleted';

    switch (id) {
      case 'extract':
      case 'delete':
        final input = await udPrompt(context,
            title: context.tr('pages_prompt'),
            hint: context.tr('pages_hint', {'n': '$count'}));
        if (input == null || !mounted) return null;
        final pages = parsePages(input, count);
        if (pages == null || (id == 'delete' && pages.length >= count)) {
          udToast(context, context.tr('pages_invalid'));
          return null;
        }
        out = await udBusy(
            context,
            () => id == 'extract'
                ? extractPages(pdf.bytes, pages, password: pw)
                : deletePages(pdf.bytes, pages, password: pw));
        sfx = id == 'extract' ? 'sfx_extract' : 'sfx_deleted';
      case 'rotate':
        final turns = await showUdActions<int>(context, title: context.tr('rotate_by'), actions: [
          const UdAction(1, Icons.rotate_right_rounded, '90°'),
          const UdAction(2, Icons.sync_rounded, '180°'),
          const UdAction(3, Icons.rotate_left_rounded, '270°'),
        ]);
        if (turns == null || !mounted) return null;
        out = await udBusy(context, () => rotatePages(pdf.bytes, turns, password: pw));
        sfx = 'sfx_rotated';
      case 'numbers':
        out = await udBusy(context, () => addPageNumbers(pdf.bytes, password: pw));
        sfx = 'sfx_numbered';
      case 'watermark':
        final text = await _askWatermark(context);
        if (text == null || !mounted) return null;
        out = await udBusy(context, () => addWatermark(pdf.bytes, text, password: pw));
        sfx = 'sfx_watermark';
      case 'protect':
        final p = await udPrompt(context, title: context.tr('password_new'), hint: context.tr('password'));
        if (p == null || !mounted) return null;
        out = await udBusy(context, () => protectPdf(pdf.bytes, p, password: pw));
        sfx = 'sfx_protected';
      case 'unlock':
        final p = await udPrompt(context, title: context.tr('password'), hint: context.tr('password'));
        if (p == null || !mounted) return null;
        out = await udBusy(context, () => unlockPdf(pdf.bytes, p));
        sfx = 'sfx_unlocked';
      case 'sign':
        out = await _sign(pdf);
        sfx = 'sfx_signed';
    }
    if (out == null || !mounted) return null;
    return saveOutput(context, pdf.baseName, sfx, out);
  }

  Future<Uint8List?> _sign(PickedPdf pdf) async {
    udToast(context, context.tr('sign_pick'));
    final x = await ImagePicker().pickImage(source: ImageSource.gallery);
    if (x == null || !mounted) return null;
    final png = await x.readAsBytes();
    if (!mounted) return null;
    final pos = await showUdActions<SignPos>(context, title: context.tr('sign_where'), actions: [
      UdAction(SignPos.bottomRight, Icons.south_east_rounded, context.tr('pos_br')),
      UdAction(SignPos.bottomCenter, Icons.south_rounded, context.tr('pos_bc')),
      UdAction(SignPos.bottomLeft, Icons.south_west_rounded, context.tr('pos_bl')),
    ]);
    if (pos == null || !mounted) return null;
    final all = await showUdActions<bool>(context, actions: [
      UdAction(false, Icons.last_page_rounded, context.tr('last_page')),
      UdAction(true, Icons.auto_stories_outlined, context.tr('all_pages')),
    ]);
    if (all == null || !mounted) return null;
    return udBusy(context,
        () => addSignature(pdf.bytes, png, pos: pos, allPages: all, password: pdf.password));
  }

  Future<void> _images() async {
    final src = await showUdActions<String>(context, title: context.tr('t_images'), actions: [
      UdAction('gallery', Icons.photo_library_outlined, context.tr('from_gallery')),
      UdAction('camera', Icons.photo_camera_outlined, context.tr('from_camera')),
    ]);
    if (src == null || !mounted) return;
    final picker = ImagePicker();
    final List<XFile> picked = src == 'gallery'
        ? await picker.pickMultiImage(imageQuality: 90)
        : [if (await picker.pickImage(source: ImageSource.camera, imageQuality: 90) case final x?) x];
    if (picked.isEmpty || !mounted) return;
    try {
      final bytes = await udBusy(context, () async {
        final imgs = [for (final x in picked) await x.readAsBytes()];
        return imagesToPdf(imgs);
      });
      if (!mounted) return;
      final f = await saveOutput(context, udStampName(context.tr('photos_name')), 'sfx_merged', bytes);
      if (mounted) await _showResult(f);
    } catch (_) {
      if (mounted) udToast(context, context.tr('error_generic'));
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = UdTokens.of(context);
    return UdPage(
      eyebrow: appName,
      title: context.tr('home_title'),
      subtitle: context.tr('home_sub'),
      actions: const [UdSettingsButton(appName: appName)],
      dock: UdDock(
        label: context.tr('open_pdf'),
        icon: Icons.menu_book_rounded,
        onPressed: _view,
      ),
      slivers: [
        UdSliverPad(
          sliver: SliverGrid(
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              mainAxisSpacing: 12,
              crossAxisSpacing: 12,
              childAspectRatio: 1.08,
            ),
            delegate: SliverChildListDelegate([
              for (var i = 0; i < tools.length; i++)
                UdToolTile(
                  icon: tools[i].icon,
                  title: context.tr('t_${tools[i].id}'),
                  subtitle: context.tr('t_${tools[i].id}_sub'),
                  highlight: i == 0,
                  onTap: () => _run(tools[i].id),
                ),
            ]),
          ),
        ),
        if (_recent.isNotEmpty)
          UdSliverPad(
            top: 24,
            sliver: SliverList.list(children: [
              UdLabel(context.tr('recent')),
              for (final f in _recent)
                UdRow(
                  leading: UdBadgeIcon(Icons.picture_as_pdf_outlined, color: t.accent),
                  title: f.path.split('/').last,
                  subtitle:
                      '${udFormatBytes(f.lengthSync())} · ${udFormatDate(context, f.statSync().modified)}',
                  trailing: Icon(Icons.chevron_right_rounded, color: t.inkFaint),
                  onTap: () => _showResult(f),
                ),
            ]),
          ),
      ],
    );
  }
}

Future<String?> _askWatermark(BuildContext context) {
  final ctrl = TextEditingController(text: 'CONFIDENTIAL');
  return showUdSheet<String>(context, (c) {
    final t = UdTokens.of(c);
    final text = Theme.of(c).textTheme;
    void submit() {
      final v = ctrl.text.trim();
      if (v.isNotEmpty) Navigator.pop(c, v);
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(c.tr('watermark_text'), style: text.headlineSmall),
        const SizedBox(height: 16),
        TextField(
          controller: ctrl,
          autofocus: true,
          style: text.bodyLarge,
          decoration: udInputDecoration(c, hint: c.tr('watermark_hint')),
          onSubmitted: (_) => submit(),
        ),
        const SizedBox(height: 10),
        Text(c.tr('latin_note'), style: text.bodySmall?.copyWith(color: t.inkSoft)),
        const SizedBox(height: 18),
        SizedBox(
          width: double.infinity,
          child: FilledButton(onPressed: submit, child: Text(c.tr('apply'))),
        ),
      ],
    );
  });
}

class MergePage extends StatefulWidget {
  const MergePage({super.key, required this.onDone});
  final Future<void> Function(File) onDone;

  @override
  State<MergePage> createState() => _MergePageState();
}

class _MergePageState extends State<MergePage> {
  final _files = <PickedPdf>[];

  Future<void> _add() async {
    final p = await pickPdf(context);
    if (p != null) setState(() => _files.add(p));
  }

  Future<void> _merge() async {
    if (_files.length < 2) {
      udToast(context, context.tr('pick_two'));
      return;
    }
    try {
      final bytes = await udBusy(context, () => mergePdfs([for (final f in _files) f.bytes]));
      if (!mounted) return;
      final f = await saveOutput(context, _files.first.baseName, 'sfx_merged', bytes);
      if (!mounted) return;
      Navigator.of(context).pop();
      await widget.onDone(f);
    } catch (_) {
      if (mounted) udToast(context, context.tr('error_generic'));
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = UdTokens.of(context);
    return UdPage(
      title: context.tr('t_merge'),
      subtitle: context.tr('order_sub'),
      actions: [UdIconButton(icon: Icons.add_rounded, filled: true, onTap: _add)],
      dock: UdDock(
        label: context.tr('t_merge'),
        icon: Icons.call_merge_rounded,
        onPressed: _merge,
        extras: [UdDockAction(icon: Icons.add_rounded, label: context.tr('open_pdf'), onTap: _add)],
      ),
      slivers: [
        if (_files.isEmpty)
          SliverToBoxAdapter(
            child: UdEmpty(icon: Icons.call_merge_rounded, title: context.tr('pick_two')),
          )
        else
          UdSliverPad(
            sliver: SliverReorderableList(
              itemCount: _files.length,
              onReorder: (a, b) => setState(() {
                if (b > a) b -= 1;
                _files.insert(b, _files.removeAt(a));
              }),
              itemBuilder: (context, i) {
                final f = _files[i];
                return ReorderableDelayedDragStartListener(
                  key: ObjectKey(f),
                  index: i,
                  child: UdRow(
                    leading: CircleAvatar(
                      backgroundColor: t.accentSoft,
                      child: Text('${i + 1}', style: TextStyle(color: t.accent, fontWeight: FontWeight.w700)),
                    ),
                    title: f.baseName,
                    subtitle: udFormatBytes(f.bytes.length),
                    trailing: IconButton(
                      icon: Icon(Icons.close_rounded, color: t.inkSoft),
                      onPressed: () => setState(() => _files.removeAt(i)),
                    ),
                  ),
                );
              },
            ),
          ),
      ],
    );
  }
}

class ResultPage extends StatelessWidget {
  const ResultPage({super.key, required this.file});
  final File file;

  @override
  Widget build(BuildContext context) {
    final t = UdTokens.of(context);
    final text = Theme.of(context).textTheme;
    final name = file.path.split('/').last;
    return UdPage(
      title: context.tr('done_title'),
      actions: [
        UdIconButton(
          icon: Icons.delete_outline_rounded,
          tooltip: context.tr('delete'),
          onTap: () async {
            if (!await udConfirm(context)) return;
            await file.delete();
            if (context.mounted) Navigator.of(context).pop();
          },
        ),
      ],
      dock: UdDock(
        label: context.tr('share'),
        icon: Icons.ios_share_rounded,
        onPressed: () => udShareFiles([file.path]),
        extras: [
          UdDockAction(
            icon: Icons.menu_book_rounded,
            label: context.tr('view'),
            onTap: () => Navigator.of(context)
                .push(MaterialPageRoute(builder: (_) => ViewerPage(path: file.path))),
          ),
          UdDockAction(
            icon: Icons.open_in_new_rounded,
            label: context.tr('open_with'),
            onTap: () => OpenFilex.open(file.path),
          ),
        ],
      ),
      slivers: [
        UdSliverPad(
          sliver: SliverToBoxAdapter(
            child: UdPressable(
              onTap: () => Navigator.of(context)
                  .push(MaterialPageRoute(builder: (_) => ViewerPage(path: file.path))),
              padding: const EdgeInsets.all(24),
              child: Column(
                children: [
                  Container(
                    width: 96,
                    height: 120,
                    decoration: BoxDecoration(
                      color: t.accentSoft,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: t.line),
                    ),
                    child: Icon(Icons.picture_as_pdf_rounded, size: 44, color: t.accent),
                  ),
                  const SizedBox(height: 18),
                  Text(name, textAlign: TextAlign.center, style: text.titleLarge),
                  const SizedBox(height: 6),
                  Text(udFormatBytes(file.lengthSync()), style: text.bodySmall),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class ViewerPage extends StatelessWidget {
  const ViewerPage({super.key, required this.path});
  final String path;

  @override
  Widget build(BuildContext context) {
    final t = UdTokens.of(context);
    final text = Theme.of(context).textTheme;
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
              child: Row(
                children: [
                  UdIconButton(
                      icon: Icons.arrow_back_rounded,
                      onTap: () => Navigator.of(context).maybePop()),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(path.split('/').last,
                        maxLines: 1, overflow: TextOverflow.ellipsis, style: text.titleMedium),
                  ),
                  const SizedBox(width: 12),
                  UdIconButton(
                      icon: Icons.ios_share_rounded,
                      onTap: () => udShareFiles([path])),
                ],
              ),
            ),
            Expanded(
              child: Container(
                color: t.paper,
                child: SfPdfViewer.file(File(path)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
