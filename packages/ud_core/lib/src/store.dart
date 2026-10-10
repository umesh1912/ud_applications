import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// A small persisted list of JSON records (bills, contacts, listings…).
/// Every record gets an `id` field.
class UdListStore extends ChangeNotifier {
  UdListStore(this.key);

  final String key;
  List<Map<String, dynamic>> items = [];
  bool loaded = false;

  Future<UdListStore> load() async {
    final p = await SharedPreferences.getInstance();
    final raw = p.getString(key);
    if (raw != null) {
      try {
        items = [
          for (final e in jsonDecode(raw) as List<dynamic>)
            Map<String, dynamic>.from(e as Map),
        ];
      } catch (_) {
        items = [];
      }
    }
    loaded = true;
    notifyListeners();
    return this;
  }

  Future<void> save() async {
    final p = await SharedPreferences.getInstance();
    await p.setString(key, jsonEncode(items));
    notifyListeners();
  }

  Future<Map<String, dynamic>> add(Map<String, dynamic> item) async {
    final withId = {...item, 'id': item['id'] ?? DateTime.now().microsecondsSinceEpoch.toString()};
    items.insert(0, withId);
    await save();
    return withId;
  }

  Future<void> put(Map<String, dynamic> item) async {
    final i = items.indexWhere((e) => e['id'] == item['id']);
    if (i == -1) {
      items.insert(0, item);
    } else {
      items[i] = item;
    }
    await save();
  }

  Future<void> remove(String id) async {
    items.removeWhere((e) => e['id'] == id);
    await save();
  }
}

/// Indian-style rupee formatting: ₹12,34,567 (no decimals unless asked).
String udRupees(num value, {int decimals = 0}) {
  final negative = value < 0;
  final fixed = value.abs().toStringAsFixed(decimals);
  final parts = fixed.split('.');
  var whole = parts[0];
  String grouped;
  if (whole.length <= 3) {
    grouped = whole;
  } else {
    final last3 = whole.substring(whole.length - 3);
    var rest = whole.substring(0, whole.length - 3);
    final buf = <String>[];
    while (rest.length > 2) {
      buf.insert(0, rest.substring(rest.length - 2));
      rest = rest.substring(0, rest.length - 2);
    }
    if (rest.isNotEmpty) buf.insert(0, rest);
    grouped = '${buf.join(',')},$last3';
  }
  final dec = parts.length > 1 ? '.${parts[1]}' : '';
  return '${negative ? '-' : ''}₹$grouped$dec';
}

/// Short Indian amount: ₹45 L, ₹1.2 Cr.
String udRupeesShort(num value) {
  final v = value.abs();
  if (v >= 1e7) return '₹${(value / 1e7).toStringAsFixed(v >= 1e8 ? 0 : 2)} Cr';
  if (v >= 1e5) return '₹${(value / 1e5).toStringAsFixed(v >= 1e6 ? 1 : 2)} L';
  return udRupees(value);
}

double? udParseNum(String s) => double.tryParse(s.replaceAll(',', '').replaceAll('₹', '').trim());
