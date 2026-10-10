import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/widgets.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import 'l10n.dart';

/// A folder inside the app's private storage, created on demand.
Future<Directory> udDir(String name) async {
  final base = await getApplicationDocumentsDirectory();
  final dir = Directory('${base.path}/$name');
  if (!await dir.exists()) await dir.create(recursive: true);
  return dir;
}

/// Picks files from the device and returns their local paths.
Future<List<String>> udPickFiles({List<String>? extensions}) async {
  final files = await FilePicker.pickFiles(
    type: extensions == null ? FileType.any : FileType.custom,
    allowedExtensions: extensions,
  );
  return [
    for (final f in files)
      if (f.path != null) f.path!,
  ];
}

Future<void> udShareFiles(List<String> paths, {String? text}) async {
  await SharePlus.instance.share(ShareParams(
    files: [for (final p in paths) XFile(p)],
    text: text,
  ));
}

/// Makes a string safe to use as a file name.
String udSafeName(String name) {
  final cleaned = name.replaceAll(RegExp(r'[\\/:*?"<>|\n\r\t]'), ' ').trim();
  return cleaned.isEmpty ? 'file' : cleaned;
}

/// Returns a path in [dir] for [name].[ext] that does not exist yet.
String udUniquePath(Directory dir, String name, String ext) {
  final base = udSafeName(name);
  var path = '${dir.path}/$base.$ext';
  var i = 2;
  while (File(path).existsSync()) {
    path = '${dir.path}/$base ($i).$ext';
    i++;
  }
  return path;
}

String udFormatBytes(int bytes) {
  if (bytes < 1024) return '$bytes B';
  if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(0)} KB';
  return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
}

String udTwo(int v) => v.toString().padLeft(2, '0');

/// Short, language-neutral timestamp: "10/10/2026 · 13:54", or "Just now".
String udFormatDate(BuildContext context, DateTime d) {
  if (DateTime.now().difference(d).inMinutes < 1) return context.tr('just_now');
  return '${udTwo(d.day)}/${udTwo(d.month)}/${d.year} · ${udTwo(d.hour)}:${udTwo(d.minute)}';
}

/// Default file name based on the current time, e.g. "Scan 10-10 13.54".
String udStampName(String prefix) {
  final d = DateTime.now();
  return '$prefix ${udTwo(d.day)}-${udTwo(d.month)} ${udTwo(d.hour)}.${udTwo(d.minute)}';
}

String udPagesLabel(BuildContext context, int n) =>
    n == 1 ? context.tr('one_page') : context.tr('pages', {'n': '$n'});

/// Opens a web link, phone number (tel:), SMS (sms:) or app link.
/// Web pages open in an in-app browser tab; returns false if nothing could open it.
Future<bool> udOpenUrl(String url, {bool external = false}) async {
  final uri = Uri.parse(url);
  final web = uri.scheme == 'http' || uri.scheme == 'https';
  try {
    return await launchUrl(
      uri,
      mode: web && !external
          ? LaunchMode.inAppBrowserView
          : LaunchMode.externalApplication,
    );
  } catch (_) {
    return false;
  }
}

Future<void> udShareText(String text) =>
    SharePlus.instance.share(ShareParams(text: text));
