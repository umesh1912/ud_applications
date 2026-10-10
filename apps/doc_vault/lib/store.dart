import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:ud_core/ud_core.dart';

class VaultCategory {
  const VaultCategory(this.id, this.icon);
  final String id;
  final IconData icon;
  String title(BuildContext c) => c.tr('cat_$id');
  String sub(BuildContext c) => c.tr('cat_${id}_sub');
}

const vaultCategories = <VaultCategory>[
  VaultCategory('identity', Icons.badge_outlined),
  VaultCategory('education', Icons.school_outlined),
  VaultCategory('finance', Icons.account_balance_outlined),
  VaultCategory('health', Icons.favorite_border_rounded),
  VaultCategory('property', Icons.home_work_outlined),
  VaultCategory('vehicle', Icons.directions_car_outlined),
  VaultCategory('bills', Icons.receipt_long_outlined),
  VaultCategory('other', Icons.folder_open_outlined),
];

VaultCategory categoryById(String id) =>
    vaultCategories.firstWhere((c) => c.id == id, orElse: () => vaultCategories.last);

class VaultDoc {
  VaultDoc({
    required this.id,
    required this.name,
    required this.cat,
    required this.ext,
    required this.size,
    required this.added,
    this.expiry,
  });

  final String id;
  String name;
  String cat;
  final String ext;
  final int size;
  final DateTime added;
  DateTime? expiry;

  bool get isImage => const ['jpg', 'jpeg', 'png', 'webp', 'heic'].contains(ext);
  bool get isPdf => ext == 'pdf';

  IconData get icon => isPdf
      ? Icons.picture_as_pdf_outlined
      : isImage
          ? Icons.image_outlined
          : Icons.insert_drive_file_outlined;

  /// Days until expiry (negative when expired), or null when no expiry.
  int? get daysLeft {
    final e = expiry;
    if (e == null) return null;
    final today = DateTime.now();
    return DateTime(e.year, e.month, e.day)
        .difference(DateTime(today.year, today.month, today.day))
        .inDays;
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'cat': cat,
        'ext': ext,
        'size': size,
        'added': added.toIso8601String(),
        if (expiry != null) 'expiry': expiry!.toIso8601String(),
      };

  static VaultDoc fromJson(Map<String, dynamic> j) => VaultDoc(
        id: j['id'] as String,
        name: j['name'] as String,
        cat: j['cat'] as String,
        ext: j['ext'] as String,
        size: (j['size'] as num).toInt(),
        added: DateTime.parse(j['added'] as String),
        expiry: j['expiry'] == null ? null : DateTime.parse(j['expiry'] as String),
      );
}

/// Documents live in the app's private folder; an index file keeps metadata.
class VaultStore extends ChangeNotifier {
  VaultStore._(this._root, this.docs);

  final Directory _root;
  final List<VaultDoc> docs;

  File get _index => File('${_root.path}/index.json');

  static Future<VaultStore> open() async {
    final root = await udDir('vault');
    final index = File('${root.path}/index.json');
    final docs = <VaultDoc>[];
    if (await index.exists()) {
      try {
        final list = jsonDecode(await index.readAsString()) as List<dynamic>;
        docs.addAll(list.map((e) => VaultDoc.fromJson(e as Map<String, dynamic>)));
      } catch (_) {}
    }
    return VaultStore._(root, docs);
  }

  String pathOf(VaultDoc d) => '${_root.path}/${d.id}.${d.ext}';

  List<VaultDoc> inCategory(String cat) =>
      docs.where((d) => d.cat == cat).toList()..sort((a, b) => b.added.compareTo(a.added));

  List<VaultDoc> search(String q) {
    final s = q.toLowerCase();
    return docs.where((d) => d.name.toLowerCase().contains(s)).toList();
  }

  /// Documents expiring within 45 days (or already expired), soonest first.
  List<VaultDoc> expiringSoon() => docs
      .where((d) => d.daysLeft != null && d.daysLeft! <= 45)
      .toList()
    ..sort((a, b) => a.daysLeft!.compareTo(b.daysLeft!));

  Future<void> _save() async {
    await _index.writeAsString(jsonEncode([for (final d in docs) d.toJson()]));
    notifyListeners();
  }

  Future<VaultDoc> add({
    required String sourcePath,
    required String name,
    required String cat,
    DateTime? expiry,
  }) async {
    final src = File(sourcePath);
    final dot = sourcePath.lastIndexOf('.');
    final ext = dot == -1 ? 'bin' : sourcePath.substring(dot + 1).toLowerCase();
    final id = DateTime.now().microsecondsSinceEpoch.toString();
    final doc = VaultDoc(
      id: id,
      name: name,
      cat: cat,
      ext: ext,
      size: await src.length(),
      added: DateTime.now(),
      expiry: expiry,
    );
    await src.copy(pathOf(doc));
    docs.add(doc);
    await _save();
    return doc;
  }

  Future<void> update(VaultDoc d) => _save();

  Future<void> remove(VaultDoc d) async {
    final f = File(pathOf(d));
    if (await f.exists()) await f.delete();
    docs.remove(d);
    await _save();
  }

  /// Copies the file to a temp name matching the document, for sharing.
  Future<String> exportCopy(VaultDoc d) async {
    final tmp = Directory.systemTemp;
    final out = '${tmp.path}/${udSafeName(d.name)}.${d.ext}';
    await File(pathOf(d)).copy(out);
    return out;
  }
}

/// Stores a salted hash of the PIN, never the PIN itself.
class PinStore {
  PinStore(this._prefs);
  final SharedPreferences _prefs;
  static const _k = 'vault.pin';

  static Future<PinStore> open() async => PinStore(await SharedPreferences.getInstance());

  bool get isSet => _prefs.containsKey(_k);

  String _hash(String pin) => sha256.convert(utf8.encode('ud-vault:$pin')).toString();

  bool check(String pin) => _prefs.getString(_k) == _hash(pin);

  Future<void> set(String pin) => _prefs.setString(_k, _hash(pin));

  Future<void> clear() => _prefs.remove(_k);
}
