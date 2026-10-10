import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' show Offset, Rect;

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:open_filex/open_filex.dart';
import 'package:printing/printing.dart';
import 'package:syncfusion_flutter_pdf/pdf.dart';
import 'package:ud_core/ud_core.dart';

import 'strings.dart';

const appName = 'FillIt';
const double kDpi = 110;

void main() => runUdApp(UdAppSpec(
      name: appName,
      taglineKey: 'tagline',
      accent: const Color(0xFF0F6E8C),
      icon: Icons.edit_document,
      strings: fillStrings,
      home: (_) => const HomePage(),
    ));

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  List<File> _done = [];

  @override
  void initState() {
    super.initState();
    _reload();
  }

  Future<void> _reload() async {
    final dir = await udDir('filled');
    final files = dir.listSync().whereType<File>().where((f) => f.path.endsWith('.pdf')).toList()
      ..sort((a, b) => b.statSync().modified.compareTo(a.statSync().modified));
    if (mounted) setState(() => _done = files);
  }

  Future<void> _open() async {
    final paths = await udPickFiles(extensions: const ['pdf']);
    if (paths.isEmpty || !mounted) return;
    await Navigator.of(context).push(MaterialPageRoute(builder: (_) => FillPage(path: paths.first)));
    _reload();
  }

  @override
  Widget build(BuildContext context) {
    final t = UdTokens.of(context);
    return UdPage(
      eyebrow: appName,
      title: context.tr('home_title'),
      subtitle: context.tr('home_sub'),
      actions: const [UdSettingsButton(appName: appName)],
      dock: UdDock(label: context.tr('open_pdf'), icon: Icons.file_open_rounded, onPressed: _open),
      slivers: [
        if (_done.isEmpty)
          SliverToBoxAdapter(
            child: UdEmpty(
              icon: Icons.edit_document,
              title: context.tr('empty_title'),
              body: context.tr('empty_body'),
            ),
          )
        else
          UdSliverPad(
            sliver: SliverList.list(children: [
              UdLabel(context.tr('recent')),
              for (final f in _done)
                UdRow(
                  leading: UdBadgeIcon(Icons.picture_as_pdf_outlined, color: t.accent),
                  title: f.path.split('/').last,
                  subtitle: udFormatDate(context, f.statSync().modified),
                  onTap: () => OpenFilex.open(f.path),
                  trailing: IconButton(
                    icon: const Icon(Icons.ios_share_rounded),
                    onPressed: () => udShareFiles([f.path]),
                  ),
                ),
            ]),
          ),
      ],
    );
  }
}

enum Tool { text, tick, cross, date, sign }

/// Something placed on a page. Position is a fraction of page width/height;
/// [size] is in PDF points (font size, mark size or signature width).
class Mark {
  Mark({required this.page, required this.fx, required this.fy, required this.tool, required this.size, this.text, this.image});
  final int page;
  double fx;
  double fy;
  final Tool tool;
  double size;
  String? text;
  Uint8List? image;
}

class PageImage {
  PageImage(this.png, this.widthPx, this.heightPx);
  final Uint8List png;
  final int widthPx;
  final int heightPx;
  double get widthPt => widthPx * 72 / kDpi;
}

class FillPage extends StatefulWidget {
  const FillPage({super.key, required this.path});
  final String path;

  @override
  State<FillPage> createState() => _FillPageState();
}

class _FillPageState extends State<FillPage> {
  Uint8List? _bytes;
  final _pages = <PageImage>[];
  final _marks = <Mark>[];
  Tool? _tool = Tool.text;
  Uint8List? _signature;
  bool _loading = true;
  bool _failed = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final bytes = await File(widget.path).readAsBytes();
      _bytes = bytes;
      await for (final r in Printing.raster(bytes, dpi: kDpi)) {
        final png = await r.toPng();
        if (!mounted) return;
        setState(() => _pages.add(PageImage(png, r.width, r.height)));
      }
    } catch (_) {
      _failed = true;
    }
    if (mounted) setState(() => _loading = false);
  }

  Future<void> _place(int page, Offset local, Size box) async {
    final tool = _tool;
    if (tool == null) return;
    final fx = local.dx / box.width;
    final fy = local.dy / box.height;
    Mark? m;
    switch (tool) {
      case Tool.text:
        final s = await udPrompt(context, title: context.tr('enter_text'));
        if (s == null) return;
        m = Mark(page: page, fx: fx, fy: fy - 0.01, tool: tool, size: 11, text: s);
      case Tool.date:
        final d = DateTime.now();
        m = Mark(page: page, fx: fx, fy: fy - 0.01, tool: tool, size: 11,
            text: '${udTwo(d.day)}/${udTwo(d.month)}/${d.year}');
      case Tool.tick:
      case Tool.cross:
        m = Mark(page: page, fx: fx, fy: fy, tool: tool, size: 12);
      case Tool.sign:
        var img = _signature;
        if (img == null) {
          udToast(context, context.tr('pick_sign'));
          final x = await ImagePicker().pickImage(source: ImageSource.gallery);
          if (x == null) return;
          img = await x.readAsBytes();
          _signature = img;
        }
        m = Mark(page: page, fx: fx - 0.1, fy: fy - 0.03, tool: tool, size: 110, image: img);
    }
    setState(() => _marks.add(m!));
  }

  Future<void> _editMark(Mark m) async {
    final a = await showUdActions<String>(context, actions: [
      if (m.text != null) UdAction('edit', Icons.edit_outlined, context.tr('edit')),
      UdAction('bigger', Icons.zoom_in_rounded, context.tr('bigger')),
      UdAction('smaller', Icons.zoom_out_rounded, context.tr('smaller')),
      UdAction('remove', Icons.delete_outline_rounded, context.tr('remove'), danger: true),
    ]);
    if (a == null || !mounted) return;
    switch (a) {
      case 'edit':
        final s = await udPrompt(context, title: context.tr('enter_text'), initial: m.text ?? '');
        if (s != null) setState(() => m.text = s);
      case 'bigger':
        setState(() => m.size *= 1.2);
      case 'smaller':
        setState(() => m.size /= 1.2);
      case 'remove':
        setState(() => _marks.remove(m));
    }
  }

  Future<void> _save() async {
    final bytes = _bytes;
    if (bytes == null) return;
    try {
      final out = await udBusy(context, () async {
        final doc = PdfDocument(inputBytes: bytes);
        final ink = PdfColor(20, 24, 40);
        for (final m in _marks) {
          if (m.page >= doc.pages.count) continue;
          final page = doc.pages[m.page];
          final size = page.getClientSize();
          final g = page.graphics;
          final x = m.fx * size.width;
          final y = m.fy * size.height;
          switch (m.tool) {
            case Tool.text:
            case Tool.date:
              final font = PdfStandardFont(PdfFontFamily.helvetica, m.size);
              g.drawString(m.text ?? '', font,
                  brush: PdfSolidBrush(ink),
                  bounds: Rect.fromLTWH(x, y, size.width - x, m.size * 1.6));
            case Tool.tick:
              final pen = PdfPen(ink, width: m.size * 0.14);
              final w = m.size;
              g.drawLine(pen, Offset(x - w * 0.5, y), Offset(x - w * 0.12, y + w * 0.38));
              g.drawLine(pen, Offset(x - w * 0.12, y + w * 0.38), Offset(x + w * 0.55, y - w * 0.45));
            case Tool.cross:
              final pen = PdfPen(ink, width: m.size * 0.14);
              final w = m.size * 0.45;
              g.drawLine(pen, Offset(x - w, y - w), Offset(x + w, y + w));
              g.drawLine(pen, Offset(x - w, y + w), Offset(x + w, y - w));
            case Tool.sign:
              final bmp = PdfBitmap(m.image!);
              final w = m.size;
              final h = w * bmp.height / bmp.width;
              g.drawImage(bmp, Rect.fromLTWH(x, y, w, h));
          }
        }
        final saved = await doc.save();
        doc.dispose();
        final dir = await udDir('filled');
        final name = widget.path.split('/').last.replaceAll(RegExp(r'\.pdf$', caseSensitive: false), '');
        final f = File(udUniquePath(dir, '$name - filled', 'pdf'));
        await f.writeAsBytes(saved, flush: true);
        return f;
      });
      if (!mounted) return;
      udToast(context, context.tr('saved'));
      Navigator.of(context).pop();
      await udShareFiles([out.path]);
    } catch (_) {
      if (mounted) udToast(context, context.tr('error_generic'));
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = UdTokens.of(context);
    final text = Theme.of(context).textTheme;

    Widget toolButton(Tool tool, IconData icon) {
      final sel = _tool == tool;
      return Expanded(
        child: InkResponse(
          onTap: () => setState(() => _tool = sel ? null : tool),
          radius: 30,
          child: Container(
            height: 54,
            margin: const EdgeInsets.symmetric(horizontal: 2),
            decoration: BoxDecoration(
              color: sel ? t.accent : Colors.transparent,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(icon, size: 20, color: sel ? t.onAccent : t.paper),
                Text(context.tr('tool_${tool.name}'),
                    style: text.labelSmall?.copyWith(color: sel ? t.onAccent : t.paper)),
              ],
            ),
          ),
        ),
      );
    }

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 6),
              child: Row(
                children: [
                  UdIconButton(icon: Icons.arrow_back_rounded, onTap: () => Navigator.of(context).pop()),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      _tool == null ? context.tr('drag_hint') : context.tr('tap_place'),
                      maxLines: 2,
                      style: text.bodySmall?.copyWith(color: t.inkSoft),
                    ),
                  ),
                  FilledButton.icon(
                    onPressed: _marks.isEmpty ? null : _save,
                    icon: const Icon(Icons.check_rounded),
                    label: Text(context.tr('save')),
                  ),
                ],
              ),
            ),
            Expanded(
              child: _failed
                  ? Center(child: Padding(padding: const EdgeInsets.all(24), child: Text(context.tr('locked'), textAlign: TextAlign.center)))
                  : ListView.builder(
                      padding: const EdgeInsets.fromLTRB(12, 4, 12, 20),
                      itemCount: _pages.length + (_loading ? 1 : 0),
                      itemBuilder: (context, i) {
                        if (i >= _pages.length) {
                          return Padding(
                            padding: const EdgeInsets.all(30),
                            child: Column(children: [
                              const CircularProgressIndicator(),
                              const SizedBox(height: 10),
                              Text(context.tr('loading')),
                            ]),
                          );
                        }
                        return _pageView(i);
                      },
                    ),
            ),
            Container(
              margin: const EdgeInsets.fromLTRB(12, 0, 12, 10),
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(color: t.ink, borderRadius: BorderRadius.circular(22)),
              child: Row(children: [
                toolButton(Tool.text, Icons.text_fields_rounded),
                toolButton(Tool.tick, Icons.check_rounded),
                toolButton(Tool.cross, Icons.close_rounded),
                toolButton(Tool.date, Icons.today_rounded),
                toolButton(Tool.sign, Icons.draw_rounded),
              ]),
            ),
          ],
        ),
      ),
    );
  }

  Widget _pageView(int i) {
    final t = UdTokens.of(context);
    final p = _pages[i];
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Column(
        children: [
          LayoutBuilder(builder: (context, box) {
            final w = box.maxWidth;
            final h = w * p.heightPx / p.widthPx;
            final scale = w / p.widthPt; // screen pixels per PDF point
            return Container(
              width: w,
              height: h,
              decoration: BoxDecoration(
                color: Colors.white,
                border: Border.all(color: t.line),
                boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 10, offset: Offset(0, 4))],
              ),
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTapUp: (d) => _place(i, d.localPosition, Size(w, h)),
                child: Stack(
                  children: [
                    Positioned.fill(child: Image.memory(p.png, fit: BoxFit.fill, gaplessPlayback: true)),
                    for (final m in _marks.where((m) => m.page == i)) _markView(m, w, h, scale),
                  ],
                ),
              ),
            );
          }),
          Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Text(context.tr('page_n', {'n': '${i + 1}'}), style: Theme.of(context).textTheme.labelSmall),
          ),
        ],
      ),
    );
  }

  Widget _markView(Mark m, double w, double h, double scale) {
    const ink = Color(0xFF141828);
    Widget child;
    var left = m.fx * w;
    var top = m.fy * h;
    switch (m.tool) {
      case Tool.text:
      case Tool.date:
        child = Text(m.text ?? '',
            style: TextStyle(fontFamily: 'sans-serif', fontSize: m.size * scale, color: ink, height: 1.15));
      case Tool.tick:
      case Tool.cross:
        final s = m.size * scale * 1.3;
        left -= s / 2;
        top -= s / 2;
        child = Icon(m.tool == Tool.tick ? Icons.check_rounded : Icons.close_rounded, size: s, color: ink);
      case Tool.sign:
        child = Image.memory(m.image!, width: m.size * scale);
    }
    return Positioned(
      left: left,
      top: top,
      child: GestureDetector(
        onTap: () => _editMark(m),
        onPanUpdate: (d) => setState(() {
          m.fx = (m.fx + d.delta.dx / w).clamp(0.0, 1.0);
          m.fy = (m.fy + d.delta.dy / h).clamp(0.0, 1.0);
        }),
        child: Container(
          padding: const EdgeInsets.all(2),
          decoration: BoxDecoration(
            border: Border.all(color: UdTokens.of(context).accent.withValues(alpha: 0.5), width: 1),
            borderRadius: BorderRadius.circular(4),
          ),
          child: child,
        ),
      ),
    );
  }
}
