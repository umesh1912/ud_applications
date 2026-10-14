import 'dart:io';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:ud_core/ud_core.dart';

/// Kinds of file, used for icons and the quick filters on the home page.
enum FileKind { pdf, image, doc, sheet, audio, video, other }

FileKind kindOf(String path) {
  final dot = path.lastIndexOf('.');
  final ext = dot == -1 ? '' : path.substring(dot + 1).toLowerCase();
  return switch (ext) {
    'pdf' => FileKind.pdf,
    'jpg' || 'jpeg' || 'png' || 'webp' || 'heic' || 'gif' || 'bmp' => FileKind.image,
    'doc' || 'docx' || 'txt' || 'rtf' || 'odt' || 'md' || 'ppt' || 'pptx' => FileKind.doc,
    'xls' || 'xlsx' || 'csv' || 'ods' => FileKind.sheet,
    'mp3' || 'm4a' || 'aac' || 'wav' || 'ogg' || 'amr' || 'opus' => FileKind.audio,
    'mp4' || 'mkv' || 'mov' || '3gp' || 'webm' || 'avi' => FileKind.video,
    _ => FileKind.other,
  };
}

IconData kindIcon(FileKind k) => switch (k) {
      FileKind.pdf => Icons.picture_as_pdf_outlined,
      FileKind.image => Icons.image_outlined,
      FileKind.doc => Icons.description_outlined,
      FileKind.sheet => Icons.table_chart_outlined,
      FileKind.audio => Icons.audiotrack_outlined,
      FileKind.video => Icons.movie_outlined,
      FileKind.other => Icons.insert_drive_file_outlined,
    };

enum SortBy { newest, name, size }

/// One file as shown in lists.
class Entry {
  Entry(this.file, this.stat);
  final File file;
  final FileStat stat;

  String get path => file.path;
  String get fileName => path.split('/').last;
  String get name {
    final n = fileName;
    final dot = n.lastIndexOf('.');
    return dot > 0 ? n.substring(0, dot) : n;
  }

  String get ext {
    final dot = fileName.lastIndexOf('.');
    return dot > 0 ? fileName.substring(dot + 1).toLowerCase() : '';
  }

  FileKind get kind => kindOf(path);
  int get size => stat.size;
  DateTime get modified => stat.modified;
}

/// Files are kept as real files and folders inside the app's private storage,
/// so what the user sees is exactly what is on disk. Stars and the sort order
/// are small preferences stored next to them.
class DaftarStore extends ChangeNotifier {
  DaftarStore._(this.root, this._prefs);

  final Directory root;
  final SharedPreferences _prefs;

  static const _kStars = 'daftar.stars';
  static const _kSort = 'daftar.sort';
  static const _kSeeded = 'daftar.seeded';

  static Future<DaftarStore> open() async {
    final root = await udDir('daftar');
    return DaftarStore._(root, await SharedPreferences.getInstance());
  }

  /// Creates the starter folders once, named in the user's language.
  Future<void> seed(List<String> names) async {
    if (_prefs.getBool(_kSeeded) ?? false) return;
    for (final n in names) {
      await Directory('${root.path}/${udSafeName(n)}').create(recursive: true);
    }
    await _prefs.setBool(_kSeeded, true);
    notifyListeners();
  }

  // ---------------------------------------------------------------- reading

  SortBy get sort => SortBy.values[(_prefs.getInt(_kSort) ?? 0).clamp(0, SortBy.values.length - 1)];

  Future<void> setSort(SortBy s) async {
    await _prefs.setInt(_kSort, s.index);
    notifyListeners();
  }

  String relative(String path) =>
      path.startsWith(root.path) ? path.substring(root.path.length).replaceFirst(RegExp('^/'), '') : path;

  /// Folder path for display: "Bank / 2025", or the app name for the root.
  String crumbs(Directory d, String rootName) {
    final r = relative(d.path);
    return r.isEmpty ? rootName : r.split('/').join(' / ');
  }

  List<Directory> foldersIn(Directory dir) {
    if (!dir.existsSync()) return [];
    final out = dir.listSync().whereType<Directory>().toList()
      ..sort((a, b) => _base(a.path).toLowerCase().compareTo(_base(b.path).toLowerCase()));
    return out;
  }

  List<Entry> filesIn(Directory dir) {
    if (!dir.existsSync()) return [];
    return _sorted([
      for (final f in dir.listSync().whereType<File>()) Entry(f, f.statSync()),
    ]);
  }

  List<Entry> allFiles() {
    if (!root.existsSync()) return [];
    return _sorted([
      for (final f in root.listSync(recursive: true).whereType<File>()) Entry(f, f.statSync()),
    ]);
  }

  /// Every folder, for the "Move to" picker, root first.
  List<Directory> allFolders() {
    final out = [root];
    if (root.existsSync()) {
      out.addAll(root.listSync(recursive: true).whereType<Directory>().toList()
        ..sort((a, b) => a.path.toLowerCase().compareTo(b.path.toLowerCase())));
    }
    return out;
  }

  int countIn(Directory dir) {
    if (!dir.existsSync()) return 0;
    return dir.listSync(recursive: true).whereType<File>().length;
  }

  List<Entry> search(String q) {
    final s = q.toLowerCase();
    return allFiles().where((e) => relative(e.path).toLowerCase().contains(s)).toList();
  }

  List<Entry> recent({int days = 14}) {
    final since = DateTime.now().subtract(Duration(days: days));
    return allFiles().where((e) => e.modified.isAfter(since)).toList()
      ..sort((a, b) => b.modified.compareTo(a.modified));
  }

  List<Entry> ofKind(FileKind k) => allFiles().where((e) => e.kind == k).toList();

  List<Entry> _sorted(List<Entry> list) {
    switch (sort) {
      case SortBy.newest:
        list.sort((a, b) => b.modified.compareTo(a.modified));
      case SortBy.name:
        list.sort((a, b) => a.fileName.toLowerCase().compareTo(b.fileName.toLowerCase()));
      case SortBy.size:
        list.sort((a, b) => b.size.compareTo(a.size));
    }
    return list;
  }

  // ---------------------------------------------------------------- stars

  Set<String> get _stars => (_prefs.getStringList(_kStars) ?? const []).toSet();

  bool isStarred(String path) => _stars.contains(relative(path));

  List<Entry> starred() {
    final s = _stars;
    return allFiles().where((e) => s.contains(relative(e.path))).toList();
  }

  Future<void> toggleStar(String path) async {
    final s = _stars;
    final r = relative(path);
    s.contains(r) ? s.remove(r) : s.add(r);
    await _prefs.setStringList(_kStars, s.toList());
    notifyListeners();
  }

  /// Keeps stars pointing at the right files after a rename or move.
  Future<void> _renameStars(String from, String to, {bool folder = false}) async {
    final f = relative(from);
    final t = relative(to);
    final s = <String>{
      for (final r in _stars)
        if (r == f)
          t
        else if (folder && r.startsWith('$f/'))
          '$t${r.substring(f.length)}'
        else
          r,
    };
    await _prefs.setStringList(_kStars, s.toList());
  }

  Future<void> _dropStars(String path, {bool folder = false}) async {
    final p = relative(path);
    await _prefs.setStringList(_kStars, [
      for (final r in _stars)
        if (r != p && !(folder && r.startsWith('$p/'))) r,
    ]);
  }

  // ---------------------------------------------------------------- changes

  Future<Directory> createFolder(Directory parent, String name) async {
    final d = Directory(_uniqueDir(parent, name));
    await d.create(recursive: true);
    notifyListeners();
    return d;
  }

  /// Copies picked files into [dir], keeping their names. Returns how many.
  Future<int> import(Directory dir, List<String> paths, {String? namePrefix}) async {
    var n = 0;
    for (final p in paths) {
      final src = File(p);
      if (!await src.exists()) continue;
      final base = _base(p);
      final dot = base.lastIndexOf('.');
      final name = namePrefix ?? (dot > 0 ? base.substring(0, dot) : base);
      final ext = dot > 0 ? base.substring(dot + 1) : 'bin';
      await src.copy(udUniquePath(dir, name, ext));
      n++;
    }
    notifyListeners();
    return n;
  }

  Future<void> renameFile(Entry e, String newName) async {
    final dir = e.file.parent;
    final to = udUniquePath(dir, newName, e.ext.isEmpty ? 'bin' : e.ext);
    await e.file.rename(to);
    await _renameStars(e.path, to);
    notifyListeners();
  }

  Future<void> moveFile(Entry e, Directory to) async {
    if (e.file.parent.path == to.path) return;
    final dest = udUniquePath(to, e.name, e.ext.isEmpty ? 'bin' : e.ext);
    try {
      await e.file.rename(dest);
    } on FileSystemException {
      await e.file.copy(dest);
      await e.file.delete();
    }
    await _renameStars(e.path, dest);
    notifyListeners();
  }

  Future<void> duplicate(Entry e) async {
    await e.file.copy(udUniquePath(e.file.parent, e.name, e.ext.isEmpty ? 'bin' : e.ext));
    notifyListeners();
  }

  Future<void> deleteFile(Entry e) async {
    await e.file.delete();
    await _dropStars(e.path);
    notifyListeners();
  }

  Future<void> renameFolder(Directory d, String newName) async {
    final to = _uniqueDir(d.parent, newName);
    await d.rename(to);
    await _renameStars(d.path, to, folder: true);
    notifyListeners();
  }

  Future<void> deleteFolder(Directory d) async {
    await d.delete(recursive: true);
    await _dropStars(d.path, folder: true);
    notifyListeners();
  }

  /// Copies a file to a temp path so it can be shared with its real name.
  Future<String> exportCopy(Entry e) async {
    final out = '${Directory.systemTemp.path}/${e.fileName}';
    await e.file.copy(out);
    return out;
  }

  ({int files, int bytes}) totals() {
    final all = allFiles();
    return (files: all.length, bytes: all.fold(0, (s, e) => s + e.size));
  }

  String _uniqueDir(Directory parent, String name) {
    final base = udSafeName(name);
    var path = '${parent.path}/$base';
    var i = 2;
    while (Directory(path).existsSync() || File(path).existsSync()) {
      path = '${parent.path}/$base ($i)';
      i++;
    }
    return path;
  }

  static String _base(String p) => p.split('/').last;
}
