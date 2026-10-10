import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' show Offset, Rect;

import 'package:syncfusion_flutter_pdf/pdf.dart';

/// Thrown when a PDF needs a password (or the given one is wrong).
class PdfPasswordException implements Exception {}

PdfDocument openDoc(List<int> bytes, {String? password}) {
  try {
    return password == null
        ? PdfDocument(inputBytes: bytes)
        : PdfDocument(inputBytes: bytes, password: password);
  } catch (e) {
    final m = e.toString().toLowerCase();
    if (m.contains('password') || m.contains('encrypt')) {
      throw PdfPasswordException();
    }
    rethrow;
  }
}

Future<Uint8List> _finish(PdfDocument doc) async {
  final out = await doc.save();
  doc.dispose();
  return Uint8List.fromList(out);
}

int pageCountOf(List<int> bytes, {String? password}) {
  final d = openDoc(bytes, password: password);
  final n = d.pages.count;
  d.dispose();
  return n;
}

/// Parses "1-3, 5" into sorted zero-based page indexes within [count].
/// Returns null when the input has no valid page.
List<int>? parsePages(String input, int count) {
  final out = <int>{};
  for (final part in input.split(RegExp(r'[,\s]+'))) {
    if (part.isEmpty) continue;
    final range = part.split('-');
    if (range.length == 1) {
      final v = int.tryParse(range[0]);
      if (v == null || v < 1 || v > count) return null;
      out.add(v - 1);
    } else if (range.length == 2) {
      final a = int.tryParse(range[0]);
      final b = int.tryParse(range[1]);
      if (a == null || b == null || a < 1 || b > count || a > b) return null;
      for (var i = a; i <= b; i++) {
        out.add(i - 1);
      }
    } else {
      return null;
    }
  }
  if (out.isEmpty) return null;
  return out.toList()..sort();
}

void _copyPages(PdfDocument src, PdfDocument dst, Iterable<int> indexes) {
  for (final i in indexes) {
    final page = src.pages[i];
    final size = page.size;
    final template = page.createTemplate();
    final section = dst.sections!.add();
    section.pageSettings.margins.all = 0;
    section.pageSettings.size = size;
    final p = section.pages.add();
    p.graphics.drawPdfTemplate(template, Offset.zero, size);
  }
}

Future<Uint8List> mergePdfs(List<List<int>> files) async {
  final dst = PdfDocument();
  for (final bytes in files) {
    final src = openDoc(bytes);
    _copyPages(src, dst, List.generate(src.pages.count, (i) => i));
    src.dispose();
  }
  return _finish(dst);
}

Future<Uint8List> extractPages(List<int> bytes, List<int> indexes, {String? password}) async {
  final src = openDoc(bytes, password: password);
  final dst = PdfDocument();
  _copyPages(src, dst, indexes);
  src.dispose();
  return _finish(dst);
}

Future<Uint8List> deletePages(List<int> bytes, List<int> indexes, {String? password}) async {
  final doc = openDoc(bytes, password: password);
  for (final i in indexes.reversed) {
    doc.pages.removeAt(i);
  }
  return _finish(doc);
}

Future<Uint8List> rotatePages(List<int> bytes, int quarterTurns, {String? password}) async {
  final doc = openDoc(bytes, password: password);
  const angles = PdfPageRotateAngle.values;
  for (var i = 0; i < doc.pages.count; i++) {
    final page = doc.pages[i];
    page.rotation = angles[(page.rotation.index + quarterTurns) % angles.length];
  }
  return _finish(doc);
}

/// One photo per A4 page, centred and scaled to fit.
Future<Uint8List> imagesToPdf(List<Uint8List> images) async {
  final doc = PdfDocument();
  doc.pageSettings.size = PdfPageSize.a4;
  doc.pageSettings.margins.all = 24;
  for (final bytes in images) {
    final page = doc.pages.add();
    final bmp = PdfBitmap(bytes);
    final area = page.getClientSize();
    final scale = math.min(area.width / bmp.width, area.height / bmp.height);
    final w = bmp.width * scale;
    final h = bmp.height * scale;
    page.graphics.drawImage(
        bmp, Rect.fromLTWH((area.width - w) / 2, (area.height - h) / 2, w, h));
  }
  return _finish(doc);
}

Future<Uint8List> addPageNumbers(List<int> bytes, {String? password}) async {
  final doc = openDoc(bytes, password: password);
  final n = doc.pages.count;
  final font = PdfStandardFont(PdfFontFamily.helvetica, 10);
  final brush = PdfSolidBrush(PdfColor(90, 90, 90));
  for (var i = 0; i < n; i++) {
    final page = doc.pages[i];
    final size = page.getClientSize();
    final text = '${i + 1} / $n';
    final ts = font.measureString(text);
    page.graphics.drawString(
      text,
      font,
      brush: brush,
      bounds: Rect.fromLTWH(
          (size.width - ts.width) / 2, size.height - ts.height - 16, ts.width + 4, ts.height + 2),
    );
  }
  return _finish(doc);
}

Future<Uint8List> addWatermark(List<int> bytes, String text, {String? password}) async {
  final doc = openDoc(bytes, password: password);
  for (var i = 0; i < doc.pages.count; i++) {
    final page = doc.pages[i];
    final size = page.getClientSize();
    final fontSize = math.max(24.0, math.min(72.0, size.width * 1.1 / math.max(1, text.length)));
    final font = PdfStandardFont(PdfFontFamily.helvetica, fontSize, style: PdfFontStyle.bold);
    final ts = font.measureString(text);
    final g = page.graphics;
    g.save();
    g.setTransparency(0.18);
    g.translateTransform(size.width / 2, size.height / 2);
    g.rotateTransform(-40);
    g.drawString(
      text,
      font,
      brush: PdfSolidBrush(PdfColor(163, 39, 59)),
      bounds: Rect.fromLTWH(-ts.width / 2, -ts.height / 2, ts.width + 4, ts.height + 4),
    );
    g.restore();
  }
  return _finish(doc);
}

enum SignPos { bottomRight, bottomCenter, bottomLeft }

Future<Uint8List> addSignature(
  List<int> bytes,
  Uint8List png, {
  required SignPos pos,
  required bool allPages,
  String? password,
}) async {
  final doc = openDoc(bytes, password: password);
  final bmp = PdfBitmap(png);
  final pages = allPages
      ? List.generate(doc.pages.count, (i) => i)
      : [doc.pages.count - 1];
  for (final i in pages) {
    final page = doc.pages[i];
    final size = page.getClientSize();
    final w = math.min(150.0, size.width * 0.3);
    final h = w * bmp.height / bmp.width;
    const margin = 36.0;
    final x = switch (pos) {
      SignPos.bottomRight => size.width - w - margin,
      SignPos.bottomCenter => (size.width - w) / 2,
      SignPos.bottomLeft => margin,
    };
    page.graphics.drawImage(bmp, Rect.fromLTWH(x, size.height - h - margin, w, h));
  }
  return _finish(doc);
}

Future<Uint8List> protectPdf(List<int> bytes, String newPassword, {String? password}) async {
  final doc = openDoc(bytes, password: password);
  doc.security.algorithm = PdfEncryptionAlgorithm.aesx256Bit;
  doc.security.userPassword = newPassword;
  doc.security.ownerPassword = newPassword;
  return _finish(doc);
}

Future<Uint8List> unlockPdf(List<int> bytes, String password) async {
  final doc = openDoc(bytes, password: password);
  doc.security.userPassword = '';
  doc.security.ownerPassword = '';
  return _finish(doc);
}
