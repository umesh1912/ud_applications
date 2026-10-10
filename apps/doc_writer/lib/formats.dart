import 'dart:convert';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:syncfusion_flutter_pdf/pdf.dart' as sf;

/// One block of a document: a heading, paragraph or bullet point.
class Block {
  Block(this.type, this.text);
  String type; // h1, h2, p, li
  String text;

  Map<String, dynamic> toJson() => {'t': type, 'x': text};
  static Block fromJson(Map<String, dynamic> j) => Block(j['t'] as String, j['x'] as String);
}

String _esc(String s) => s
    .replaceAll('&', '&amp;')
    .replaceAll('<', '&lt;')
    .replaceAll('>', '&gt;')
    .replaceAll('"', '&quot;');

String _unesc(String s) => s
    .replaceAll('&lt;', '<')
    .replaceAll('&gt;', '>')
    .replaceAll('&quot;', '"')
    .replaceAll('&apos;', "'")
    .replaceAll('&amp;', '&');

// ---------------------------------------------------------------- Word (.docx)

Uint8List buildDocx(String title, List<Block> blocks) {
  String run(String text, {bool bold = false, int halfPoints = 24}) {
    final lines = text.split('\n');
    final buf = StringBuffer();
    for (var i = 0; i < lines.length; i++) {
      if (i > 0) buf.write('<w:br/>');
      buf.write('<w:t xml:space="preserve">${_esc(lines[i])}</w:t>');
    }
    return '<w:r><w:rPr>${bold ? '<w:b/><w:bCs/>' : ''}'
        '<w:sz w:val="$halfPoints"/><w:szCs w:val="$halfPoints"/></w:rPr>$buf</w:r>';
  }

  String para(Block b) {
    switch (b.type) {
      case 'h1':
        return '<w:p><w:pPr><w:pStyle w:val="Heading1"/><w:spacing w:before="240" w:after="120"/></w:pPr>'
            '${run(b.text, bold: true, halfPoints: 36)}</w:p>';
      case 'h2':
        return '<w:p><w:pPr><w:pStyle w:val="Heading2"/><w:spacing w:before="200" w:after="80"/></w:pPr>'
            '${run(b.text, bold: true, halfPoints: 28)}</w:p>';
      case 'li':
        return '<w:p><w:pPr><w:ind w:left="360" w:hanging="240"/></w:pPr>${run('•  ${b.text}')}</w:p>';
      default:
        return '<w:p><w:pPr><w:spacing w:after="120"/></w:pPr>${run(b.text)}</w:p>';
    }
  }

  final body = StringBuffer()
    ..write('<?xml version="1.0" encoding="UTF-8" standalone="yes"?>')
    ..write('<w:document xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main"><w:body>');
  for (final b in blocks) {
    body.write(para(b));
  }
  body.write('<w:sectPr><w:pgSz w:w="11906" w:h="16838"/>'
      '<w:pgMar w:top="1440" w:right="1440" w:bottom="1440" w:left="1440"/></w:sectPr></w:body></w:document>');

  const contentTypes = '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>'
      '<Types xmlns="http://schemas.openxmlformats.org/package/2006/content-types">'
      '<Default Extension="rels" ContentType="application/vnd.openxmlformats-package.relationships+xml"/>'
      '<Default Extension="xml" ContentType="application/xml"/>'
      '<Override PartName="/word/document.xml" '
      'ContentType="application/vnd.openxmlformats-officedocument.wordprocessingml.document.main+xml"/>'
      '<Override PartName="/docProps/core.xml" ContentType="application/vnd.openxmlformats-package.core-properties+xml"/>'
      '</Types>';
  const rels = '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>'
      '<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">'
      '<Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/officeDocument" Target="word/document.xml"/>'
      '<Relationship Id="rId2" Type="http://schemas.openxmlformats.org/package/2006/relationships/metadata/core-properties" Target="docProps/core.xml"/>'
      '</Relationships>';
  final core = '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>'
      '<cp:coreProperties xmlns:cp="http://schemas.openxmlformats.org/package/2006/metadata/core-properties" '
      'xmlns:dc="http://purl.org/dc/elements/1.1/"><dc:title>${_esc(title)}</dc:title></cp:coreProperties>';

  final archive = Archive();
  void add(String name, String content) {
    final bytes = utf8.encode(content);
    archive.addFile(ArchiveFile(name, bytes.length, bytes));
  }

  add('[Content_Types].xml', contentTypes);
  add('_rels/.rels', rels);
  add('docProps/core.xml', core);
  add('word/document.xml', body.toString());
  // `as` keeps this working across archive 3.x (nullable) and 4.x results.
  final out = ZipEncoder().encode(archive) as List<int>?;
  return Uint8List.fromList(out ?? const <int>[]);
}

List<Block> readDocx(Uint8List bytes) {
  final archive = ZipDecoder().decodeBytes(bytes);
  final file = archive.findFile('word/document.xml');
  if (file == null) return [];
  final xml = utf8.decode(file.content as List<int>, allowMalformed: true);
  final blocks = <Block>[];
  final paraRe = RegExp(r'<w:p[ >].*?</w:p>', dotAll: true);
  final styleRe = RegExp(r'<w:pStyle w:val="([^"]+)"');
  final textRe = RegExp(r'<w:t(?: [^>]*)?>(.*?)</w:t>|<w:br/>|<w:tab/>', dotAll: true);
  for (final m in paraRe.allMatches(xml)) {
    final p = m.group(0)!;
    final buf = StringBuffer();
    for (final t in textRe.allMatches(p)) {
      final g = t.group(0)!;
      if (g == '<w:br/>') {
        buf.write('\n');
      } else if (g == '<w:tab/>') {
        buf.write('\t');
      } else {
        buf.write(_unesc(t.group(1) ?? ''));
      }
    }
    final text = buf.toString();
    final style = styleRe.firstMatch(p)?.group(1)?.toLowerCase() ?? '';
    var type = 'p';
    if (style.contains('title') || style.contains('heading1')) {
      type = 'h1';
    } else if (style.contains('heading')) {
      type = 'h2';
    } else if (p.contains('<w:numPr>') || style.contains('list')) {
      type = 'li';
    }
    if (text.trim().isEmpty && type == 'p') continue;
    blocks.add(Block(type, text.startsWith('•') ? text.substring(1).trim() : text));
  }
  return blocks;
}

List<Block> readText(String text) {
  return [
    for (final para in text.split(RegExp(r'\n\s*\n')))
      if (para.trim().isNotEmpty) Block('p', para.trim()),
  ];
}

List<Block> readPdfText(Uint8List bytes) {
  final doc = sf.PdfDocument(inputBytes: bytes);
  final text = sf.PdfTextExtractor(doc).extractText();
  doc.dispose();
  return readText(text);
}

// ---------------------------------------------------------------- PDF

Future<Uint8List> buildPdf(String title, List<Block> blocks) async {
  pw.Font? regular, bold;
  final fallback = <pw.Font>[];
  try {
    regular = await PdfGoogleFonts.notoSerifRegular();
    bold = await PdfGoogleFonts.notoSerifBold();
    fallback
      ..add(await PdfGoogleFonts.notoSansDevanagariRegular())
      ..add(await PdfGoogleFonts.notoSansGujaratiRegular());
  } catch (_) {
    // Offline: fall back to the built-in Latin fonts.
  }
  final theme = regular == null
      ? pw.ThemeData.base()
      : pw.ThemeData.withFont(base: regular, bold: bold, fontFallback: fallback);

  final doc = pw.Document(title: title, theme: theme);
  doc.addPage(pw.MultiPage(
    pageFormat: PdfPageFormat.a4,
    margin: const pw.EdgeInsets.all(56),
    build: (context) => [
      for (final b in blocks)
        switch (b.type) {
          'h1' => pw.Padding(
              padding: const pw.EdgeInsets.only(top: 12, bottom: 8),
              child: pw.Text(b.text, style: pw.TextStyle(fontSize: 22, fontWeight: pw.FontWeight.bold)),
            ),
          'h2' => pw.Padding(
              padding: const pw.EdgeInsets.only(top: 10, bottom: 6),
              child: pw.Text(b.text, style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold)),
            ),
          'li' => pw.Bullet(text: b.text, style: const pw.TextStyle(fontSize: 12)),
          _ => pw.Padding(
              padding: const pw.EdgeInsets.only(bottom: 8),
              child: pw.Text(b.text, style: const pw.TextStyle(fontSize: 12, lineSpacing: 3)),
            ),
        },
    ],
  ));
  return doc.save();
}
