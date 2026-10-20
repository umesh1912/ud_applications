import 'package:flutter/material.dart';

import '../data/models.dart';
import '../data/sample_data.dart';
import '../state/app_state.dart';
import '../theme/tokens.dart';
import '../widgets/common.dart';
import '../widgets/graph_paper.dart';

/// PDF library: notes, formula sheets, NCERT solutions, past papers.
/// Download once, read offline.
class LibraryScreen extends StatefulWidget {
  const LibraryScreen({super.key, this.offlineOnly = false});

  final bool offlineOnly;

  @override
  State<LibraryScreen> createState() => _LibraryScreenState();
}

class _LibraryScreenState extends State<LibraryScreen> {
  PdfKind? _kind;
  String? _subjectId;
  late bool _offline = widget.offlineOnly;

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    final items = SampleData.pdfs.where((p) {
      if (_kind != null && p.kind != _kind) return false;
      if (_subjectId != null && p.subjectId != _subjectId) return false;
      if (_offline && !state.isDownloaded(p.id)) return false;
      return true;
    }).toList();
    final offlineCount = SampleData.pdfs.where((p) => state.isDownloaded(p.id)).length;

    final list = ListView(
      padding: const EdgeInsets.fromLTRB(Space.gutter, Space.l, Space.gutter, Space.xxl),
      children: [
        if (!widget.offlineOnly) ...[
          Text('Library', style: context.text.headlineMedium),
          const SizedBox(height: Space.xs),
          Text('$offlineCount saved for offline reading', style: context.text.bodySmall),
          const SizedBox(height: Space.l),
        ],
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              FilterChip(
                label: const Text('Offline'),
                avatar: Icon(Icons.download_done, size: 16, color: context.vc.ink),
                selected: _offline,
                onSelected: (v) => setState(() => _offline = v),
              ),
              const SizedBox(width: Space.s),
              for (final k in PdfKind.values) ...[
                ChoiceChip(
                  label: Text(k.label),
                  selected: _kind == k,
                  onSelected: (v) => setState(() => _kind = v ? k : null),
                ),
                const SizedBox(width: Space.s),
              ],
            ],
          ),
        ),
        const SizedBox(height: Space.s),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              for (final s in SampleData.subjects) ...[
                ChoiceChip(
                  avatar: SubjectMark(s.id, size: 20),
                  label: Text(s.name),
                  selected: _subjectId == s.id,
                  onSelected: (v) => setState(() => _subjectId = v ? s.id : null),
                ),
                const SizedBox(width: Space.s),
              ],
            ],
          ),
        ),
        const SizedBox(height: Space.l),
        if (items.isEmpty)
          EmptyNote(
            icon: Icons.picture_as_pdf_outlined,
            title: _offline ? 'Nothing saved offline yet' : 'No PDFs match these filters',
            body: _offline
                ? 'Tap the download icon on any PDF to read it without internet.'
                : 'Clear a filter to see more.',
          ),
        for (final p in items)
          Padding(
            padding: const EdgeInsets.only(bottom: Space.s),
            child: _PdfRow(pdf: p),
          ),
      ],
    );

    if (widget.offlineOnly) {
      return Scaffold(appBar: AppBar(title: const Text('Downloads')), body: list);
    }
    return GraphPaper(child: SafeArea(child: list));
  }
}

class _PdfRow extends StatelessWidget {
  const _PdfRow({required this.pdf});

  final StudyPdf pdf;

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    final vc = context.vc;
    final s = SampleData.subject(pdf.subjectId);
    final downloaded = state.isDownloaded(pdf.id);
    final downloading = state.isDownloading(pdf.id);
    final progress = state.downloads[pdf.id] ?? 0.0;

    return PaperCard(
      padding: const EdgeInsets.fromLTRB(Space.l, Space.m, Space.s, Space.m),
      onTap: () {
        if (downloaded) {
          Navigator.of(context).push(MaterialPageRoute(builder: (_) => PdfReaderScreen(pdf: pdf)));
        } else if (!downloading) {
          state.download(pdf);
        }
      },
      child: Row(
        children: [
          // Paper "page" icon with a subject-coloured corner fold.
          Container(
            width: 40,
            height: 50,
            decoration: BoxDecoration(
              color: vc.paper,
              border: Border.all(color: vc.rule),
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(4),
                bottomLeft: Radius.circular(4),
                bottomRight: Radius.circular(4),
                topRight: Radius.circular(12),
              ),
            ),
            alignment: Alignment.bottomLeft,
            padding: const EdgeInsets.all(4),
            child: Text('PDF', style: context.text.labelSmall!.copyWith(color: s.color)),
          ),
          const SizedBox(width: Space.m),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(pdf.title, style: context.text.titleSmall),
                const SizedBox(height: 2),
                Text('${pdf.kind.label} · ${pdf.pages} pages · ${pdf.sizeMb.toStringAsFixed(1)} MB',
                    style: context.text.bodySmall),
                if (downloading) ...[
                  const SizedBox(height: 6),
                  LinearProgressIndicator(value: progress, color: s.color, minHeight: 3),
                ],
              ],
            ),
          ),
          if (downloaded)
            PopupMenuButton<String>(
              tooltip: 'More options',
              onSelected: (v) {
                if (v == 'remove') state.removeDownload(pdf.id);
              },
              itemBuilder: (_) => const [
                PopupMenuItem(value: 'remove', child: Text('Remove download')),
              ],
              icon: Icon(Icons.download_done, color: s.color),
            )
          else if (downloading)
            const Padding(
              padding: EdgeInsets.all(12),
              child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)),
            )
          else
            IconButton(
              tooltip: 'Download for offline',
              onPressed: () => state.download(pdf),
              icon: const Icon(Icons.download_outlined),
            ),
        ],
      ),
    );
  }
}

/// Placeholder reader. Swap the body for a real viewer
/// (e.g. pdfx or syncfusion_flutter_pdfviewer) pointed at the downloaded file.
class PdfReaderScreen extends StatefulWidget {
  const PdfReaderScreen({super.key, required this.pdf});

  final StudyPdf pdf;

  @override
  State<PdfReaderScreen> createState() => _PdfReaderScreenState();
}

class _PdfReaderScreenState extends State<PdfReaderScreen> {
  final Set<int> _highlighted = {};
  int _page = 1;

  @override
  Widget build(BuildContext context) {
    final vc = context.vc;
    final topics = SampleData.subject(widget.pdf.subjectId).topics.toList();

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.pdf.title, style: context.text.titleSmall, maxLines: 1, overflow: TextOverflow.ellipsis),
        actions: [
          Center(
            child: Padding(
              padding: const EdgeInsets.only(right: Space.l),
              child: Text('$_page / ${widget.pdf.pages}', style: context.text.labelMedium),
            ),
          ),
        ],
      ),
      backgroundColor: Theme.of(context).colorScheme.surfaceContainerHighest,
      body: NotificationListener<ScrollUpdateNotification>(
        onNotification: (n) {
          final page = (n.metrics.pixels / 560).floor() + 1;
          if (page != _page && page >= 1 && page <= widget.pdf.pages) setState(() => _page = page);
          return false;
        },
        child: ListView.builder(
          padding: const EdgeInsets.all(Space.l),
          itemCount: widget.pdf.pages,
          itemBuilder: (context, i) {
            final t = topics[i % topics.length];
            return Container(
              height: 540,
              margin: const EdgeInsets.only(bottom: Space.l),
              padding: const EdgeInsets.all(Space.xl),
              decoration: BoxDecoration(color: vc.sheet, border: Border.all(color: vc.rule)),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(t.title, style: context.text.titleLarge),
                  const SizedBox(height: Space.m),
                  for (var n = 0; n < t.notes.length; n++)
                    GestureDetector(
                      onLongPress: () => setState(() {
                        final key = i * 100 + n;
                        if (!_highlighted.remove(key)) _highlighted.add(key);
                      }),
                      child: Container(
                        margin: const EdgeInsets.only(bottom: Space.s),
                        color: _highlighted.contains(i * 100 + n) ? vc.highlight : Colors.transparent,
                        child: Text(
                          t.notes[n],
                          style: context.text.bodyMedium!.copyWith(
                            color: _highlighted.contains(i * 100 + n) ? vc.highlightInk : null,
                          ),
                        ),
                      ),
                    ),
                  if (t.keyFormula != null) ...[
                    const SizedBox(height: Space.s),
                    Text(t.keyFormula!, style: context.text.titleMedium),
                  ],
                  const Spacer(),
                  Row(
                    children: [
                      Text('Long-press a line to highlight it', style: context.text.bodySmall),
                      const Spacer(),
                      Text('${i + 1}', style: context.text.labelSmall),
                    ],
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}
