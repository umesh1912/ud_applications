import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:printing/printing.dart';
import 'package:ud_core/ud_core.dart';

import 'db.dart';
import 'gst.dart';
import 'pdf.dart';
import 'ui.dart';

/// Digits for wa.me: adds India's 91 to plain 10-digit numbers.
String waNumber(String phone) {
  var d = phone.replaceAll(RegExp(r'\D'), '');
  if (d.startsWith('0')) d = d.substring(1);
  if (d.length == 10) d = '91$d';
  return d;
}

Future<void> openWhatsApp(BuildContext context, String phone, String message) async {
  final n = waNumber(phone);
  final ok = await udOpenUrl('https://wa.me/$n?text=${Uri.encodeComponent(message)}', external: true);
  if (!ok) {
    final sms = await udOpenUrl('sms:$phone?body=${Uri.encodeComponent(message)}', external: true);
    if (!sms && context.mounted) await udShareText(message);
  }
}

Future<String> savePdf(Uint8List bytes, String name) async {
  final dir = await udDir('hisaab/pdf');
  final path = '${dir.path}/${udSafeName(name)}.pdf';
  await File(path).writeAsBytes(bytes, flush: true);
  return path;
}

/// "Tax Invoice INV-12", "Payment Receipt RCPT-3".
String docFileName(Txn t) {
  final title = docTitle(t, db.biz).split(' / ').first.split(' ').map((w) => w[0] + w.substring(1).toLowerCase()).join(' ');
  return '$title ${t.number}';
}

/// Short message that goes with a shared document.
String docMessage(BuildContext context, Txn t) {
  final b = db.biz;
  final total = db.totalOf(t);
  final st = (t.type == TxnType.sale) ? db.docStatus(t) : null;
  final lines = <String>[
    context.tr('msg_hello', {'n': t.partyName.isEmpty ? context.tr('sir_madam') : t.partyName}),
    context.tr('msg_doc', {'d': '${typeLabel(context, t.type)} ${t.number}', 'a': money(total), 'dt': dmy(t.date)}),
    if (st != null && st.due > 0) context.tr('msg_due', {'a': money(st.due)}),
    if (st != null && st.due > 0 && b.upi.isNotEmpty)
      '${context.tr('msg_upi')} ${upiLink(vpa: b.upi, payee: b.name, amount: st.due, note: t.number)}',
    '',
    context.tr('msg_thanks'),
    b.name,
    if (b.phone.isNotEmpty) b.phone,
  ];
  return lines.join('\n');
}

Future<void> shareDocPdf(BuildContext context, Txn t, {String? size}) async {
  try {
    final path = await udBusy(context, () async => savePdf(await buildDocPdf(t, size: size), docFileName(t)));
    if (!context.mounted) return;
    await udShareFiles([path], text: docMessage(context, t));
  } catch (e) {
    if (context.mounted) udToast(context, context.tr('error_generic'));
  }
}

Future<void> printDoc(BuildContext context, Txn t, {String? size}) async {
  final s = size ?? db.biz.printSize;
  try {
    await Printing.layoutPdf(
      name: docFileName(t),
      format: pageFormat(s),
      onLayout: (_) => buildDocPdf(t, size: s),
    );
  } catch (e) {
    if (context.mounted) udToast(context, context.tr('error_generic'));
  }
}

/// Opens the PDF in the system preview, where it can be printed or saved.
Future<void> previewDoc(BuildContext context, Txn t, {String? size}) async {
  final bytes = await udBusy(context, () => buildDocPdf(t, size: size));
  if (!context.mounted) return;
  await Navigator.of(context).push(MaterialPageRoute(
    builder: (c) => Scaffold(
      appBar: AppBar(title: Text('${typeLabel(c, t.type)} ${t.number}')),
      body: PdfPreview(
        build: (_) async => bytes,
        canChangeOrientation: false,
        canChangePageFormat: false,
        canDebug: false,
        pdfFileName: '${udSafeName(docFileName(t))}.pdf',
      ),
    ),
  ));
}

Future<void> shareTablePdf(BuildContext context, Future<Uint8List> Function() build, String name) async {
  try {
    final path = await udBusy(context, () async => savePdf(await build(), name));
    await udShareFiles([path]);
  } catch (e) {
    if (context.mounted) udToast(context, context.tr('error_generic'));
  }
}

Future<void> shareCsv(BuildContext context, String name, List<String> headers, List<List<String>> rows) async {
  String esc(String s) => s.contains(RegExp(r'[",\n]')) ? '"${s.replaceAll('"', '""')}"' : s;
  final csv = [headers, ...rows].map((r) => r.map(esc).join(',')).join('\n');
  final dir = await udDir('hisaab/export');
  final path = '${dir.path}/${udSafeName(name)}.csv';
  await File(path).writeAsString('﻿$csv');
  await udShareFiles([path]);
}

/// WhatsApp (or SMS) payment reminder with a UPI link.
Future<void> sendReminder(BuildContext context, Party p, {required double amount, Txn? invoice}) async {
  final b = db.biz;
  final msg = [
    context.tr('msg_hello', {'n': p.name}),
    invoice == null
        ? context.tr('msg_reminder', {'a': money(amount), 'b': b.name})
        : context.tr('msg_reminder_inv', {'a': money(amount), 'b': b.name, 'i': invoice.number, 'dt': dmy(invoice.date)}),
    if (b.upi.isNotEmpty) '${context.tr('msg_upi')} ${upiLink(vpa: b.upi, payee: b.name, amount: amount, note: invoice?.number ?? 'Payment')}',
    '',
    context.tr('msg_thanks'),
    b.name,
    if (b.phone.isNotEmpty) b.phone,
  ].join('\n');
  if (p.phone.isEmpty) {
    await udShareText(msg);
  } else {
    await openWhatsApp(context, p.phone, msg);
  }
}
