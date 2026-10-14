import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:ud_core/ud_core.dart';

/// How a recording was made.
enum RecKind { incoming, outgoing, voice }

/// One recording: `<id>.m4a` with its details in `<id>.json` next to it.
/// Plain files (rather than shared preferences) so the background call
/// service and the app can both write them safely.
class Recording {
  Recording({
    required this.id,
    required this.name,
    required this.kind,
    required this.started,
    required this.duration,
    this.number,
    this.note = '',
    this.starred = false,
  });

  final String id;
  String name;
  final RecKind kind;
  final DateTime started;
  final Duration duration;
  final String? number;
  String note;
  bool starred;

  bool get isCall => kind != RecKind.voice;

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'kind': kind.name,
        'started': started.toIso8601String(),
        'ms': duration.inMilliseconds,
        if (number != null) 'number': number,
        'note': note,
        'starred': starred,
      };

  static Recording fromJson(Map<String, dynamic> j) => Recording(
        id: j['id'] as String,
        name: j['name'] as String? ?? '',
        kind: RecKind.values.firstWhere((k) => k.name == j['kind'], orElse: () => RecKind.voice),
        started: DateTime.tryParse(j['started'] as String? ?? '') ?? DateTime.now(),
        duration: Duration(milliseconds: (j['ms'] as num?)?.toInt() ?? 0),
        number: j['number'] as String?,
        note: j['note'] as String? ?? '',
        starred: j['starred'] as bool? ?? false,
      );
}

String audioPath(String dir, String id) => '$dir/$id.m4a';

/// Writes the details file. Used by both the app and the call service.
Future<void> writeMeta(String dir, Recording r) =>
    File('$dir/${r.id}.json').writeAsString(jsonEncode(r.toJson()));

class RecStore extends ChangeNotifier {
  RecStore._(this.dir);

  final String dir;
  List<Recording> items = [];

  static Future<RecStore> open() async {
    final d = await udDir('recordings');
    final s = RecStore._(d.path);
    await s.reload();
    return s;
  }

  /// Re-reads the folder (the call service may have added recordings).
  Future<void> reload() async {
    final out = <Recording>[];
    final d = Directory(dir);
    if (await d.exists()) {
      await for (final f in d.list()) {
        if (f is! File || !f.path.endsWith('.json')) continue;
        try {
          final r = Recording.fromJson(jsonDecode(await f.readAsString()) as Map<String, dynamic>);
          if (await File(audioPath(dir, r.id)).exists()) out.add(r);
        } catch (_) {}
      }
    }
    out.sort((a, b) => b.started.compareTo(a.started));
    items = out;
    notifyListeners();
  }

  String pathOf(Recording r) => audioPath(dir, r.id);

  int get totalBytes => items.fold(0, (s, r) {
        final f = File(pathOf(r));
        return s + (f.existsSync() ? f.lengthSync() : 0);
      });

  Future<void> save(Recording r) async {
    await writeMeta(dir, r);
    notifyListeners();
  }

  Future<void> remove(Recording r) async {
    for (final p in [pathOf(r), '$dir/${r.id}.json']) {
      final f = File(p);
      if (await f.exists()) await f.delete();
    }
    items.remove(r);
    notifyListeners();
  }

  Future<String> exportCopy(Recording r) async {
    final out = '${Directory.systemTemp.path}/${udSafeName(r.name)}.m4a';
    await File(pathOf(r)).copy(out);
    return out;
  }
}

String formatDuration(Duration d) {
  final h = d.inHours;
  final m = d.inMinutes.remainder(60);
  final s = d.inSeconds.remainder(60);
  return h > 0 ? '$h:${udTwo(m)}:${udTwo(s)}' : '${udTwo(m)}:${udTwo(s)}';
}
