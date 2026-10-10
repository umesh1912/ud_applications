import 'package:flutter/material.dart';
import 'package:google_mlkit_document_scanner/google_mlkit_document_scanner.dart';
import 'package:open_filex/open_filex.dart';
import 'package:ud_core/ud_core.dart';

import 'store.dart';
import 'strings.dart';

const appName = 'DocScan';

void main() => runUdApp(UdAppSpec(
      name: appName,
      taglineKey: 'tagline',
      accent: const Color(0xFFC2512E),
      icon: Icons.document_scanner_rounded,
      strings: scanStrings,
      home: (_) => const HomePage(),
    ));

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  List<Scan>? _scans;
  bool _searching = false;
  String _query = '';

  @override
  void initState() {
    super.initState();
    _reload();
  }

  Future<void> _reload() async {
    final s = await Scan.loadAll();
    if (mounted) setState(() => _scans = s);
  }

  Future<void> _scan() async {
    final scanner = DocumentScanner(
      options: DocumentScannerOptions(
        documentFormats: const {DocumentFormat.jpeg, DocumentFormat.pdf},
        mode: ScannerMode.full,
        pageLimit: 40,
        isGalleryImport: true,
      ),
    );
    try {
      final result = await scanner.scanDocument();
      final images = result.images ?? const <String>[];
      if (images.isEmpty) return;
      if (!mounted) return;
      final name = await _askName(context) ??
          udStampName(context.tr('default_name'));
      final scan = await Scan.create(
        name: name,
        pdfPath: result.pdf?.uri,
        imagePaths: images,
      );
      await _reload();
      if (mounted) {
        await Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => ScanPage(scan: scan)));
        _reload();
      }
    } catch (e) {
      // Cancelling the scanner throws too; only report real failures.
      final msg = e.toString().toLowerCase();
      if (mounted && !msg.contains('cancel')) {
        udToast(context, context.tr('scan_failed'));
      }
    } finally {
      scanner.close();
    }
  }

  @override
  Widget build(BuildContext context) {
    final scans = _scans;
    final filtered = scans
        ?.where((s) => s.name.toLowerCase().contains(_query.toLowerCase()))
        .toList();

    return UdPage(
      eyebrow: appName,
      title: context.tr('home_title'),
      subtitle: context.tr('home_sub'),
      actions: [
        UdIconButton(
          icon: _searching ? Icons.close_rounded : Icons.search_rounded,
          tooltip: context.tr('search'),
          onTap: () => setState(() {
            _searching = !_searching;
            _query = '';
          }),
        ),
        const UdSettingsButton(appName: appName),
      ],
      dock: UdDock(
        label: context.tr('scan'),
        icon: Icons.document_scanner_rounded,
        onPressed: _scan,
      ),
      slivers: [
        if (_searching)
          UdSliverPad(
            bottom: 16,
            sliver: SliverToBoxAdapter(
              child: TextField(
                autofocus: true,
                onChanged: (v) => setState(() => _query = v),
                decoration: udInputDecoration(context,
                    hint: context.tr('search_hint'), icon: Icons.search_rounded),
              ),
            ),
          ),
        if (scans == null)
          const SliverToBoxAdapter(
            child: Padding(
              padding: EdgeInsets.all(48),
              child: Center(child: CircularProgressIndicator()),
            ),
          )
        else if (scans.isEmpty)
          SliverToBoxAdapter(
            child: UdEmpty(
              icon: Icons.document_scanner_outlined,
              title: context.tr('empty_title'),
              body: context.tr('empty_body'),
            ),
          )
        else if (filtered!.isEmpty)
          SliverToBoxAdapter(
            child: UdEmpty(
                icon: Icons.search_off_rounded,
                title: context.tr('no_results')),
          )
        else
          UdSliverPad(
            sliver: SliverGrid(
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                mainAxisSpacing: 14,
                crossAxisSpacing: 14,
                childAspectRatio: 0.7,
              ),
              delegate: SliverChildBuilderDelegate(
                (context, i) => _ScanCard(
                  scan: filtered[i],
                  onTap: () async {
                    await Navigator.of(context).push(MaterialPageRoute(
                        builder: (_) => ScanPage(scan: filtered[i])));
                    _reload();
                  },
                ),
                childCount: filtered.length,
              ),
            ),
          ),
      ],
    );
  }
}

/// Bottom sheet asking for a name, with one-tap Indian document suggestions.
Future<String?> _askName(BuildContext context, {String initial = ''}) {
  final ctrl = TextEditingController(text: initial);
  const keys = [
    'suggest_aadhaar',
    'suggest_pan',
    'suggest_marksheet',
    'suggest_bill',
    'suggest_receipt',
    'suggest_certificate',
    'suggest_notes',
  ];
  return showUdSheet<String>(context, (c) {
    final t = UdTokens.of(c);
    final text = Theme.of(c).textTheme;
    void submit() {
      final v = ctrl.text.trim();
      Navigator.pop(c, v.isEmpty ? null : v);
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(c.tr('name_scan'), style: text.headlineSmall),
        const SizedBox(height: 16),
        TextField(
          controller: ctrl,
          autofocus: true,
          style: text.bodyLarge,
          decoration: udInputDecoration(c,
              hint: udStampName(c.tr('default_name'))),
          onSubmitted: (_) => submit(),
        ),
        const SizedBox(height: 14),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final k in keys)
              ActionChip(
                label: Text(c.tr(k)),
                labelStyle: text.labelMedium,
                backgroundColor: t.paper,
                side: BorderSide(color: t.line),
                shape: const StadiumBorder(),
                onPressed: () => ctrl.text = c.tr(k),
              ),
          ],
        ),
        const SizedBox(height: 20),
        SizedBox(
          width: double.infinity,
          child: FilledButton(onPressed: submit, child: Text(c.tr('save'))),
        ),
      ],
    );
  });
}

class _ScanCard extends StatelessWidget {
  const _ScanCard({required this.scan, required this.onTap});
  final Scan scan;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final t = UdTokens.of(context);
    final text = Theme.of(context).textTheme;
    final thumb = scan.thumb;
    return UdPressable(
      onTap: onTap,
      padding: const EdgeInsets.all(10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Container(
              width: double.infinity,
              decoration: BoxDecoration(
                color: t.paper,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: t.line),
              ),
              clipBehavior: Clip.antiAlias,
              child: thumb == null
                  ? Icon(Icons.description_outlined, color: t.inkFaint, size: 40)
                  : Image.file(thumb, fit: BoxFit.cover, cacheWidth: 400),
            ),
          ),
          const SizedBox(height: 10),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: Text(scan.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: text.titleMedium),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(4, 2, 4, 4),
            child: Text(
              '${udPagesLabel(context, scan.pages)} · ${udFormatDate(context, scan.created)}',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: text.bodySmall,
            ),
          ),
        ],
      ),
    );
  }
}

class ScanPage extends StatefulWidget {
  const ScanPage({super.key, required this.scan});
  final Scan scan;

  @override
  State<ScanPage> createState() => _ScanPageState();
}

class _ScanPageState extends State<ScanPage> {
  int _page = 0;
  final _pager = PageController(viewportFraction: 0.86);

  @override
  void dispose() {
    _pager.dispose();
    super.dispose();
  }

  Scan get scan => widget.scan;

  Future<void> _rename() async {
    final name = await _askName(context, initial: scan.name);
    if (name == null) return;
    setState(() => scan.name = name);
    await scan.saveMeta();
  }

  Future<void> _delete() async {
    if (!await udConfirm(context)) return;
    await scan.delete();
    if (mounted) Navigator.of(context).pop();
  }

  Future<void> _sharePdf() async {
    if (!scan.pdf.existsSync()) return;
    final path = await scan.exportPdf();
    await udShareFiles([path]);
  }

  @override
  Widget build(BuildContext context) {
    final t = UdTokens.of(context);
    final text = Theme.of(context).textTheme;
    final images = scan.images;
    final hasPdf = scan.pdf.existsSync();

    return UdPage(
      title: scan.name,
      subtitle:
          '${udPagesLabel(context, scan.pages)} · ${udFormatDate(context, scan.created)}',
      actions: [
        UdIconButton(
            icon: Icons.edit_outlined,
            tooltip: context.tr('rename'),
            onTap: _rename),
        UdIconButton(
            icon: Icons.delete_outline_rounded,
            tooltip: context.tr('delete'),
            onTap: _delete),
      ],
      dock: hasPdf
          ? UdDock(
              label: context.tr('share_pdf'),
              icon: Icons.ios_share_rounded,
              onPressed: _sharePdf,
              extras: [
                UdDockAction(
                  icon: Icons.open_in_new_rounded,
                  label: context.tr('open_pdf'),
                  onTap: () => OpenFilex.open(scan.pdf.path),
                ),
                UdDockAction(
                  icon: Icons.photo_library_outlined,
                  label: context.tr('share_images'),
                  onTap: () => udShareFiles([for (final f in images) f.path]),
                ),
              ],
            )
          : null,
      slivers: [
        if (images.isNotEmpty)
          SliverToBoxAdapter(
            child: SizedBox(
              height: MediaQuery.of(context).size.height * 0.56,
              child: PageView.builder(
                controller: _pager,
                itemCount: images.length,
                onPageChanged: (i) => setState(() => _page = i),
                itemBuilder: (context, i) => Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 6),
                  child: Container(
                    decoration: BoxDecoration(
                      color: t.card,
                      borderRadius: BorderRadius.circular(22),
                      border: Border.all(color: t.line),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.06),
                          blurRadius: 24,
                          offset: const Offset(0, 10),
                        ),
                      ],
                    ),
                    clipBehavior: Clip.antiAlias,
                    child: InteractiveViewer(
                      maxScale: 4,
                      child: Image.file(images[i], fit: BoxFit.contain),
                    ),
                  ),
                ),
              ),
            ),
          ),
        if (images.length > 1)
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.only(top: 16),
              child: Center(
                child: Text(
                  context.tr('page_of',
                      {'a': '${_page + 1}', 'b': '${images.length}'}),
                  style: text.labelMedium?.copyWith(color: t.inkSoft),
                ),
              ),
            ),
          ),
        if (images.isEmpty && hasPdf)
          SliverToBoxAdapter(
            child: UdEmpty(
              icon: Icons.picture_as_pdf_outlined,
              title: scan.name,
              body: context.tr('open_pdf'),
            ),
          ),
        if (!hasPdf && images.isEmpty)
          SliverToBoxAdapter(
            child: UdEmpty(
                icon: Icons.error_outline_rounded,
                title: context.tr('error_generic')),
          ),
      ],
    );
  }
}
