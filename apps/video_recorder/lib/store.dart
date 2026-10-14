import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:ud_core/ud_core.dart';

/// One recorded clip. The file lives in the app's private "clips" folder.
class Clip {
  Clip({
    required this.id,
    required this.name,
    required this.file,
    required this.duration,
    required this.created,
    required this.front,
    required this.quality,
  });

  final String id;
  String name;
  final String file;
  final Duration duration;
  final DateTime created;
  final bool front;
  final String quality;

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'file': file,
        'ms': duration.inMilliseconds,
        'created': created.toIso8601String(),
        'front': front,
        'quality': quality,
      };

  static Clip fromJson(Map<String, dynamic> j) => Clip(
        id: j['id'] as String,
        name: j['name'] as String,
        file: j['file'] as String,
        duration: Duration(milliseconds: (j['ms'] as num?)?.toInt() ?? 0),
        created: DateTime.tryParse(j['created'] as String? ?? '') ?? DateTime.now(),
        front: j['front'] as bool? ?? false,
        quality: j['quality'] as String? ?? 'hd',
      );
}

/// Recording qualities offered in the recorder, smallest first.
const qualities = ['sd', 'hd', 'fhd', 'uhd'];

class ClipStore extends ChangeNotifier {
  ClipStore._(this._dir, this._prefs);

  final Directory _dir;
  final SharedPreferences _prefs;
  final _list = UdListStore('clipcam.clips');

  static Future<ClipStore> open() async {
    final s = ClipStore._(await udDir('clips'), await SharedPreferences.getInstance());
    await s._list.load();
    s._dropMissing();
    return s;
  }

  List<Clip> get clips => [for (final j in _list.items) Clip.fromJson(j)];

  String pathOf(Clip c) => '${_dir.path}/${c.file}';

  Duration get totalDuration => clips.fold(Duration.zero, (s, c) => s + c.duration);

  int get totalBytes => clips.fold(0, (s, c) {
        final f = File(pathOf(c));
        return s + (f.existsSync() ? f.lengthSync() : 0);
      });

  // Recorder preferences.
  String get quality => _prefs.getString('clipcam.quality') ?? 'fhd';
  bool get saveToGallery => _prefs.getBool('clipcam.gallery') ?? true;
  bool get withSound => _prefs.getBool('clipcam.sound') ?? true;

  Future<void> setQuality(String q) => _prefs.setString('clipcam.quality', q);
  Future<void> setSaveToGallery(bool v) => _prefs.setBool('clipcam.gallery', v);
  Future<void> setWithSound(bool v) => _prefs.setBool('clipcam.sound', v);

  /// Moves a finished recording into the library.
  Future<Clip> add(String tempPath, {
    required String name,
    required Duration duration,
    required bool front,
    required String quality,
  }) async {
    final id = DateTime.now().microsecondsSinceEpoch.toString();
    final dot = tempPath.lastIndexOf('.');
    final ext = dot == -1 ? 'mp4' : tempPath.substring(dot + 1);
    final file = '$id.$ext';
    final src = File(tempPath);
    try {
      await src.rename('${_dir.path}/$file');
    } on FileSystemException {
      await src.copy('${_dir.path}/$file');
      await src.delete();
    }
    final clip = Clip(
      id: id,
      name: name,
      file: file,
      duration: duration,
      created: DateTime.now(),
      front: front,
      quality: quality,
    );
    await _list.add(clip.toJson());
    notifyListeners();
    return clip;
  }

  Future<void> rename(Clip c, String name) async {
    c.name = name;
    await _list.put(c.toJson());
    notifyListeners();
  }

  Future<void> remove(Clip c) async {
    final f = File(pathOf(c));
    if (await f.exists()) await f.delete();
    await _list.remove(c.id);
    notifyListeners();
  }

  /// A copy named after the clip, for sharing.
  Future<String> exportCopy(Clip c) async {
    final dot = c.file.lastIndexOf('.');
    final ext = dot == -1 ? 'mp4' : c.file.substring(dot + 1);
    final out = '${Directory.systemTemp.path}/${udSafeName(c.name)}.$ext';
    await File(pathOf(c)).copy(out);
    return out;
  }

  void _dropMissing() {
    final before = _list.items.length;
    _list.items.removeWhere((j) => !File('${_dir.path}/${j['file']}').existsSync());
    if (_list.items.length != before) _list.save();
  }
}

String formatDuration(Duration d) {
  final h = d.inHours;
  final m = d.inMinutes.remainder(60);
  final s = d.inSeconds.remainder(60);
  return h > 0 ? '$h:${udTwo(m)}:${udTwo(s)}' : '${udTwo(m)}:${udTwo(s)}';
}
