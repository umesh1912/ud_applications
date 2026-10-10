import 'dart:convert';
import 'dart:io';

import 'package:path_provider/path_provider.dart';
import 'package:ud_core/ud_core.dart';

/// One saved scan: a folder holding doc.pdf, page images p1.jpg… and meta.json.
class Scan {
  Scan({required this.dir, required this.name, required this.created, required this.pages});

  final Directory dir;
  String name;
  final DateTime created;
  final int pages;

  File get pdf => File('${dir.path}/doc.pdf');
  File get _meta => File('${dir.path}/meta.json');

  List<File> get images => [
        for (var i = 1; i <= pages; i++) File('${dir.path}/p$i.jpg'),
      ].where((f) => f.existsSync()).toList();

  File? get thumb {
    final f = File('${dir.path}/p1.jpg');
    return f.existsSync() ? f : null;
  }

  Future<void> saveMeta() => _meta.writeAsString(jsonEncode({
        'name': name,
        'created': created.toIso8601String(),
        'pages': pages,
      }));

  Future<void> delete() => dir.delete(recursive: true);

  /// Copies the PDF to a temp file named after the scan, for sharing.
  Future<String> exportPdf() async {
    final tmp = await getTemporaryDirectory();
    final out = File('${tmp.path}/${udSafeName(name)}.pdf');
    await pdf.copy(out.path);
    return out.path;
  }

  static Future<List<Scan>> loadAll() async {
    final root = await udDir('scans');
    final out = <Scan>[];
    await for (final e in root.list()) {
      if (e is! Directory) continue;
      final meta = File('${e.path}/meta.json');
      if (!await meta.exists()) continue;
      try {
        final m = jsonDecode(await meta.readAsString()) as Map<String, dynamic>;
        out.add(Scan(
          dir: e,
          name: m['name'] as String,
          created: DateTime.parse(m['created'] as String),
          pages: (m['pages'] as num).toInt(),
        ));
      } catch (_) {
        // Skip unreadable entries rather than failing the whole list.
      }
    }
    out.sort((a, b) => b.created.compareTo(a.created));
    return out;
  }

  /// Saves the scanner output (a PDF and page images) as a new scan.
  static Future<Scan> create({
    required String name,
    required String? pdfPath,
    required List<String> imagePaths,
  }) async {
    final root = await udDir('scans');
    final dir = Directory('${root.path}/${DateTime.now().microsecondsSinceEpoch}');
    await dir.create(recursive: true);
    for (var i = 0; i < imagePaths.length; i++) {
      await File(_toPath(imagePaths[i])).copy('${dir.path}/p${i + 1}.jpg');
    }
    if (pdfPath != null) {
      await File(_toPath(pdfPath)).copy('${dir.path}/doc.pdf');
    }
    final scan = Scan(
      dir: dir,
      name: name,
      created: DateTime.now(),
      pages: imagePaths.length,
    );
    await scan.saveMeta();
    return scan;
  }

  static String _toPath(String uriOrPath) =>
      uriOrPath.startsWith('file:') ? Uri.parse(uriOrPath).toFilePath() : uriOrPath;
}
