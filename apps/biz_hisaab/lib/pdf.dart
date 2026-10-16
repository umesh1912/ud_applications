import 'dart:io';

import 'package:flutter/services.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import 'db.dart';
import 'gst.dart';

/// Invoice colour themes (user picks one in Invoice settings).
const pdfThemes = <int>[0xFFB4235A, 0xFF1E5A8C, 0xFF1F7A55, 0xFF3F4752, 0xFFA26B00, 0xFF6B3FA0];

String docTitle(Txn t, Business b) => switch (t.type) {
      TxnType.sale => b.gstEnabled && b.gstin.isNotEmpty ? 'TAX INVOICE' : 'INVOICE',
      TxnType.purchase => 'PURCHASE BILL',
      TxnType.paymentIn => 'PAYMENT RECEIPT',
      TxnType.paymentOut => 'PAYMENT VOUCHER',
      TxnType.expense => 'EXPENSE VOUCHER',
      TxnType.estimate => 'ESTIMATE / QUOTATION',
      TxnType.saleReturn => 'CREDIT NOTE',
      TxnType.purchaseReturn => 'DEBIT NOTE',
      TxnType.saleOrder => 'SALE ORDER',
      TxnType.challan => 'DELIVERY CHALLAN',
    };

class _Fonts {
  _Fonts(this.regular, this.bold, this.fallback);
  final pw.Font regular;
  final pw.Font bold;
  final List<pw.Font> fallback;
}

pw.Font? _regular, _bold;
List<pw.Font>? _fallback;

Future<_Fonts> _loadFonts() async {
  _regular ??= pw.Font.ttf(await rootBundle.load('assets/fonts/NotoSans-Regular.ttf'));
  _bold ??= pw.Font.ttf(await rootBundle.load('assets/fonts/NotoSans-Bold.ttf'));
  if (_fallback == null) {
    // For names written in Hindi or Gujarati. Needs internet once (then cached
    // by the printing package); without it those letters fall back to Latin.
    try {
      final f = [
        await PdfGoogleFonts.notoSansDevanagariRegular().timeout(const Duration(seconds: 6)),
        await PdfGoogleFonts.notoSansGujaratiRegular().timeout(const Duration(seconds: 6)),
      ];
      if (f.every((e) => e is pw.TtfFont)) _fallback = f;
    } catch (_) {}
  }
  return _Fonts(_regular!, _bold!, _fallback ?? const []);
}

Future<pw.ThemeData> _theme() async {
  final f = await _loadFonts();
  return pw.ThemeData.withFont(base: f.regular, bold: f.bold, fontFallback: f.fallback);
}

pw.ImageProvider? _image(String path) {
  if (path.isEmpty) return null;
  final f = File(path);
  if (!f.existsSync()) return null;
  try {
    return pw.MemoryImage(f.readAsBytesSync());
  } catch (_) {
    return null;
  }
}

String _m(num v) => money(v, symbol: false);

/// [c] at [f] strength over white (PDF fills ignore alpha).
PdfColor _tint(PdfColor c, double f) => PdfColor(1 - (1 - c.red) * f, 1 - (1 - c.green) * f, 1 - (1 - c.blue) * f);

PdfPageFormat pageFormat(String size) => switch (size) {
      'a5' => PdfPageFormat.a5,
      '80' => PdfPageFormat.roll80,
      '58' => PdfPageFormat.roll57,
      _ => PdfPageFormat.a4,
    };

/// PDF for one document. [size] is a4, a5, 80 or 58 (thermal roll).
Future<Uint8List> buildDocPdf(Txn t, {String? size}) async {
  final s = size ?? _db.biz.printSize;
  final theme = await _theme();
  final doc = pw.Document(title: '${docTitle(t, _db.biz)} ${t.number}', author: _db.biz.name, theme: theme);
  if (s == '80' || s == '58') {
    _thermal(doc, t, s == '58');
  } else if (t.type.hasLines) {
    _invoice(doc, t, pageFormat(s));
  } else {
    _voucher(doc, t, pageFormat(s));
  }
  return doc.save();
}

Db get _db => Db.i;

// ---------------------------------------------------------------- A4 / A5 invoice

void _invoice(pw.Document doc, Txn t, PdfPageFormat format) {
  final b = _db.biz;
  final accent = PdfColor.fromInt(pdfThemes[b.colour.clamp(0, pdfThemes.length - 1)]);
  final soft = _tint(accent, 0.10);
  final small = format == PdfPageFormat.a5;
  final fs = small ? 7.5 : 9.0;
  final party = _db.party(t.partyId);
  final tot = _db.totals(t);
  final st = (t.type == TxnType.sale || t.type == TxnType.purchase) ? _db.docStatus(t) : null;
  final gst = b.gstEnabled;
  final logo = _image(b.logoPath);
  final sign = _image(b.signPath);
  final hasDisc = t.lines.any((l) => l.discountPct > 0);
  final hasHsn = gst && t.lines.any((l) => l.hsn.isNotEmpty);
  final balance = st?.due ?? 0;
  final showUpi = b.upi.isNotEmpty && (t.type == TxnType.sale || t.type == TxnType.estimate || t.type == TxnType.saleOrder);
  final upiAmount = t.type == TxnType.sale ? balance : tot.total;

  pw.TextStyle ts([double? size, bool bold = false, PdfColor? c]) =>
      pw.TextStyle(fontSize: size ?? fs, fontWeight: bold ? pw.FontWeight.bold : null, color: c);

  pw.Widget cell(String s, {bool bold = false, pw.TextAlign align = pw.TextAlign.left, PdfColor? c}) => pw.Padding(
        padding: const pw.EdgeInsets.symmetric(horizontal: 4, vertical: 4),
        child: pw.Text(s, textAlign: align, style: ts(fs, bold, c)),
      );

  final headers = ['#', 'Item', if (hasHsn) 'HSN', 'Qty', 'Rate', if (hasDisc) 'Disc', if (gst) 'GST', 'Amount'];
  final rows = <List<String>>[];
  for (var i = 0; i < t.lines.length; i++) {
    final l = t.lines[i];
    final c = calcLine(l, inclusive: t.taxInclusive, gst: gst);
    rows.add([
      '${i + 1}',
      l.name,
      if (hasHsn) l.hsn,
      '${qtyText(l.qty)} ${l.unit}',
      _m(l.rate),
      if (hasDisc) l.discountPct > 0 ? rateText(l.discountPct) : '',
      if (gst) rateText(l.gstRate),
      _m(c.total),
    ]);
  }
  final right = {for (var i = 0; i < headers.length; i++) i: i > (hasHsn ? 2 : 1) ? pw.Alignment.centerRight : pw.Alignment.centerLeft};

  final totalsRows = <(String, String, bool)>[
    ('Sub total', _m(tot.gross), false),
    if (tot.discount > 0) ('Discount', '- ${_m(tot.discount)}', false),
    if (gst && tot.tax > 0) ...[
      ('Taxable amount', _m(tot.taxable), false),
      if (tot.interState) ('IGST', _m(tot.igst), false) else ...[('CGST', _m(tot.cgst), false), ('SGST', _m(tot.sgst), false)],
    ],
    if (tot.extraDiscount > 0) ('Extra discount', '- ${_m(tot.extraDiscount)}', false),
    if (tot.charges > 0) ('Other charges', _m(tot.charges), false),
    if (tot.roundOff.abs() > 0.001) ('Round off', _m(tot.roundOff), false),
    ('Total', '₹ ${_m(tot.total)}', true),
    if (st != null && st.total - st.due > 0) ...[
      (t.type == TxnType.sale ? 'Received' : 'Paid', _m(st.total - st.due), false),
      ('Balance', '₹ ${_m(st.due)}', true),
    ],
  ];

  doc.addPage(pw.MultiPage(
    pageFormat: format,
    margin: pw.EdgeInsets.all(small ? 20 : 32),
    footer: (c) => pw.Row(children: [
      pw.Expanded(child: pw.Text('Made with Hisaab', style: ts(fs - 1.5, false, PdfColors.grey600))),
      if (c.pagesCount > 1) pw.Text('Page ${c.pageNumber} of ${c.pagesCount}', style: ts(fs - 1.5, false, PdfColors.grey600)),
    ]),
    build: (c) => [
      // header
      pw.Row(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
        if (logo != null) pw.Container(width: small ? 44 : 64, height: small ? 44 : 64, margin: const pw.EdgeInsets.only(right: 12), child: pw.Image(logo, fit: pw.BoxFit.contain)),
        pw.Expanded(
          child: pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
            pw.Text(b.name, style: ts(small ? 14 : 18, true, accent)),
            if (b.address.isNotEmpty) pw.Text(b.address, style: ts()),
            pw.Text([if (b.phone.isNotEmpty) 'Ph: ${b.phone}', if (b.email.isNotEmpty) b.email].join('  ·  '), style: ts()),
            if (gst && b.gstin.isNotEmpty) pw.Text('GSTIN: ${b.gstin}', style: ts(fs, true)),
            if (gst && b.gstin.isEmpty && gstStates[b.state] != null) pw.Text('State: ${gstStates[b.state]}', style: ts()),
          ]),
        ),
        pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.end, children: [
          pw.Text(docTitle(t, b), style: ts(small ? 11 : 14, true, accent)),
          pw.SizedBox(height: 4),
          pw.Text('No: ${t.number}', style: ts(fs, true)),
          pw.Text('Date: ${dmy(t.date)}', style: ts()),
          if (t.dueDate != null) pw.Text('${t.type == TxnType.estimate ? 'Valid till' : 'Due date'}: ${dmy(t.dueDate!)}', style: ts()),
          if (gst && t.placeOfSupply.isNotEmpty)
            pw.Text('Place of supply: ${gstStates[t.placeOfSupply] ?? ''} (${t.placeOfSupply})', style: ts()),
        ]),
      ]),
      pw.SizedBox(height: 12),
      pw.Container(height: 2, color: accent),
      pw.SizedBox(height: 10),
      // bill to
      pw.Row(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
        pw.Expanded(
          child: pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
            pw.Text(t.type.isSaleSide ? 'BILL TO' : 'FROM', style: ts(fs - 1, true, PdfColors.grey700)),
            pw.SizedBox(height: 2),
            pw.Text(t.partyName.isEmpty ? 'Cash sale' : t.partyName, style: ts(fs + 2, true)),
            if (party != null && party.address.isNotEmpty) pw.Text(party.address, style: ts()),
            if ((party?.phone ?? t.partyPhone).isNotEmpty) pw.Text('Ph: ${party?.phone ?? t.partyPhone}', style: ts()),
            if (gst && party != null && party.gstin.isNotEmpty) pw.Text('GSTIN: ${party.gstin}', style: ts(fs, true)),
            if (gst && party != null && party.state.isNotEmpty) pw.Text('State: ${gstStates[party.state] ?? ''} (${party.state})', style: ts()),
          ]),
        ),
        if (t.refNo.isNotEmpty) pw.Text('Ref: ${t.refNo}', style: ts()),
      ]),
      pw.SizedBox(height: 12),
      // items
      pw.TableHelper.fromTextArray(
        headers: headers,
        data: rows,
        border: null,
        headerStyle: ts(fs, true, PdfColors.white),
        headerDecoration: pw.BoxDecoration(color: accent),
        cellStyle: ts(),
        cellPadding: const pw.EdgeInsets.symmetric(horizontal: 4, vertical: 5),
        rowDecoration: const pw.BoxDecoration(border: pw.Border(bottom: pw.BorderSide(color: PdfColors.grey300, width: 0.5))),
        oddRowDecoration: pw.BoxDecoration(color: soft, border: const pw.Border(bottom: pw.BorderSide(color: PdfColors.grey300, width: 0.5))),
        columnWidths: {0: const pw.FixedColumnWidth(18), 1: const pw.FlexColumnWidth(4)},
        cellAlignments: right,
        headerAlignments: right,
      ),
      pw.SizedBox(height: 10),
      // totals + words
      pw.Row(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
        pw.Expanded(
          flex: 5,
          child: pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
            pw.Text('Amount in words', style: ts(fs - 1, true, PdfColors.grey700)),
            pw.Text(amountInWords(tot.total), style: ts(fs, true)),
            if (gst && tot.tax > 0) ...[
              pw.SizedBox(height: 10),
              pw.Table(
                border: pw.TableBorder.all(color: PdfColors.grey400, width: 0.5),
                children: [
                  pw.TableRow(decoration: pw.BoxDecoration(color: soft), children: [
                    cell('GST', bold: true),
                    cell('Taxable', bold: true, align: pw.TextAlign.right),
                    if (tot.interState) cell('IGST', bold: true, align: pw.TextAlign.right) else ...[
                      cell('CGST', bold: true, align: pw.TextAlign.right),
                      cell('SGST', bold: true, align: pw.TextAlign.right),
                    ],
                  ]),
                  for (final e in tot.byRate.entries.where((e) => e.key > 0))
                    pw.TableRow(children: [
                      cell(rateText(e.key)),
                      cell(_m(e.value.$1), align: pw.TextAlign.right),
                      if (tot.interState) cell(_m(e.value.$2), align: pw.TextAlign.right) else ...[
                        cell(_m(e.value.$2 / 2), align: pw.TextAlign.right),
                        cell(_m(e.value.$2 / 2), align: pw.TextAlign.right),
                      ],
                    ]),
                ],
              ),
            ],
          ]),
        ),
        pw.SizedBox(width: 16),
        pw.Expanded(
          flex: 4,
          child: pw.Column(children: [
            for (final r in totalsRows)
              pw.Container(
                padding: const pw.EdgeInsets.symmetric(vertical: 3, horizontal: 6),
                decoration: r.$3 ? pw.BoxDecoration(color: soft) : null,
                child: pw.Row(children: [
                  pw.Expanded(child: pw.Text(r.$1, style: ts(r.$3 ? fs + 1 : fs, r.$3))),
                  pw.Text(r.$2, style: ts(r.$3 ? fs + 1 : fs, r.$3)),
                ]),
              ),
          ]),
        ),
      ]),
      pw.SizedBox(height: 16),
      // payment details, terms, signature
      pw.Row(crossAxisAlignment: pw.CrossAxisAlignment.end, children: [
        pw.Expanded(
          child: pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
            if (b.accountNo.isNotEmpty && t.type.isSaleSide) ...[
              pw.Text('Bank details', style: ts(fs - 1, true, PdfColors.grey700)),
              if (b.bankName.isNotEmpty) pw.Text(b.bankName, style: ts()),
              pw.Text('A/c: ${b.accountNo}', style: ts()),
              if (b.ifsc.isNotEmpty) pw.Text('IFSC: ${b.ifsc}', style: ts()),
              pw.SizedBox(height: 8),
            ],
            if (t.notes.isNotEmpty) ...[
              pw.Text('Notes', style: ts(fs - 1, true, PdfColors.grey700)),
              pw.Text(t.notes, style: ts()),
              pw.SizedBox(height: 8),
            ],
            if (b.terms.isNotEmpty && t.type.isSaleSide) ...[
              pw.Text('Terms & conditions', style: ts(fs - 1, true, PdfColors.grey700)),
              pw.Text(b.terms, style: ts(fs - 0.5)),
            ],
          ]),
        ),
        if (showUpi && upiAmount > 0)
          pw.Padding(
            padding: const pw.EdgeInsets.symmetric(horizontal: 12),
            child: pw.Column(children: [
              pw.BarcodeWidget(
                barcode: pw.Barcode.qrCode(),
                drawText: false,
                data: upiLink(vpa: b.upi, payee: b.name, amount: upiAmount, note: '${t.number}'),
                width: small ? 60 : 80,
                height: small ? 60 : 80,
              ),
              pw.SizedBox(height: 3),
              pw.Text('Scan to pay ₹${_m(upiAmount)}', style: ts(fs - 1.5)),
              pw.Text(b.upi, style: ts(fs - 1.5)),
            ]),
          ),
        pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.center, children: [
          pw.Text('For ${b.name}', style: ts(fs, true)),
          pw.SizedBox(height: 4),
          if (sign != null) pw.SizedBox(height: 40, width: 110, child: pw.Image(sign, fit: pw.BoxFit.contain)) else pw.SizedBox(height: 40),
          pw.Container(width: 120, height: 0.6, color: PdfColors.grey600),
          pw.SizedBox(height: 2),
          pw.Text('Authorised signatory', style: ts(fs - 1)),
        ]),
      ]),
    ],
  ));
}

// ---------------------------------------------------------------- receipts & vouchers

void _voucher(pw.Document doc, Txn t, PdfPageFormat format) {
  final b = _db.biz;
  final accent = PdfColor.fromInt(pdfThemes[b.colour.clamp(0, pdfThemes.length - 1)]);
  final sign = _image(b.signPath);
  final logo = _image(b.logoPath);
  final party = _db.party(t.partyId);
  final bal = party == null ? null : _db.partyBalance(party.id);
  final who = t.type == TxnType.expense ? 'Paid for' : (t.type == TxnType.paymentIn ? 'Received from' : 'Paid to');
  final whom = t.type == TxnType.expense ? (t.category.isEmpty ? 'Expense' : t.category.replaceAll('_', ' ')) : t.partyName;

  pw.Widget row(String k, String v, [bool bold = false]) => pw.Padding(
        padding: const pw.EdgeInsets.symmetric(vertical: 4),
        child: pw.Row(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
          pw.SizedBox(width: 120, child: pw.Text(k, style: const pw.TextStyle(color: PdfColors.grey700))),
          pw.Expanded(child: pw.Text(v, style: pw.TextStyle(fontWeight: bold ? pw.FontWeight.bold : null))),
        ]),
      );

  doc.addPage(pw.Page(
    pageFormat: format == PdfPageFormat.a4 ? PdfPageFormat.a5.landscape : format,
    margin: const pw.EdgeInsets.all(28),
    build: (c) => pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
      pw.Row(children: [
        if (logo != null) pw.Container(width: 44, height: 44, margin: const pw.EdgeInsets.only(right: 10), child: pw.Image(logo)),
        pw.Expanded(
          child: pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
            pw.Text(b.name, style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold, color: accent)),
            if (b.address.isNotEmpty) pw.Text(b.address, style: const pw.TextStyle(fontSize: 9)),
            if (b.phone.isNotEmpty) pw.Text('Ph: ${b.phone}', style: const pw.TextStyle(fontSize: 9)),
          ]),
        ),
        pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.end, children: [
          pw.Text(docTitle(t, b), style: pw.TextStyle(fontSize: 13, fontWeight: pw.FontWeight.bold, color: accent)),
          pw.Text('No: ${t.number}'),
          pw.Text('Date: ${dmy(t.date)}'),
        ]),
      ]),
      pw.SizedBox(height: 10),
      pw.Container(height: 2, color: accent),
      pw.SizedBox(height: 14),
      row(who, whom, true),
      row('Amount', '₹ ${_m(t.amount)}', true),
      row('In words', amountInWords(t.amount)),
      row('Mode', t.mode.toUpperCase() + (t.refNo.isNotEmpty ? '  ·  Ref ${t.refNo}' : '')),
      if (t.notes.isNotEmpty) row('Notes', t.notes),
      if (bal != null && t.type != TxnType.expense)
        row('Balance now', bal.abs() < 0.01 ? 'Settled' : (bal > 0 ? '₹ ${_m(bal)} to receive' : '₹ ${_m(-bal)} to pay')),
      pw.Spacer(),
      pw.Align(
        alignment: pw.Alignment.centerRight,
        child: pw.Column(children: [
          if (sign != null) pw.SizedBox(height: 40, width: 110, child: pw.Image(sign)) else pw.SizedBox(height: 30),
          pw.Container(width: 120, height: 0.6, color: PdfColors.grey600),
          pw.Text('Authorised signatory', style: const pw.TextStyle(fontSize: 8)),
        ]),
      ),
    ]),
  ));
}

// ---------------------------------------------------------------- thermal roll

void _thermal(pw.Document doc, Txn t, bool narrow) {
  final b = _db.biz;
  final fs = narrow ? 7.0 : 8.5;
  final tot = _db.totals(t);
  final st = (t.type == TxnType.sale || t.type == TxnType.purchase) ? _db.docStatus(t) : null;
  pw.TextStyle ts([bool bold = false, double? size]) => pw.TextStyle(fontSize: size ?? fs, fontWeight: bold ? pw.FontWeight.bold : null);
  pw.Widget kv(String k, String v, [bool bold = false]) => pw.Row(children: [
        pw.Expanded(child: pw.Text(k, style: ts(bold))),
        pw.Text(v, style: ts(bold)),
      ]);
  pw.Widget dash() => pw.Padding(
        padding: const pw.EdgeInsets.symmetric(vertical: 3),
        child: pw.Text('-' * (narrow ? 38 : 52), style: ts(), maxLines: 1, overflow: pw.TextOverflow.clip),
      );

  doc.addPage(pw.Page(
    pageFormat: (narrow ? PdfPageFormat.roll57 : PdfPageFormat.roll80).copyWith(marginLeft: 6, marginRight: 6, marginTop: 8, marginBottom: 12),
    build: (c) => pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.stretch, children: [
      pw.Text(b.name, textAlign: pw.TextAlign.center, style: ts(true, fs + 3)),
      if (b.address.isNotEmpty) pw.Text(b.address, textAlign: pw.TextAlign.center, style: ts()),
      if (b.phone.isNotEmpty) pw.Text('Ph: ${b.phone}', textAlign: pw.TextAlign.center, style: ts()),
      if (b.gstEnabled && b.gstin.isNotEmpty) pw.Text('GSTIN: ${b.gstin}', textAlign: pw.TextAlign.center, style: ts()),
      dash(),
      pw.Text(docTitle(t, b), textAlign: pw.TextAlign.center, style: ts(true)),
      kv('No: ${t.number}', dmy(t.date)),
      if (t.partyName.isNotEmpty) pw.Text('To: ${t.partyName}', style: ts()),
      dash(),
      if (t.type.hasLines) ...[
        for (final l in t.lines) ...[
          pw.Text(l.name, style: ts(true)),
          kv('  ${qtyText(l.qty)} x ${_m(l.rate)}${l.discountPct > 0 ? ' -${rateText(l.discountPct)}' : ''}',
              _m(calcLine(l, inclusive: t.taxInclusive, gst: b.gstEnabled).total)),
        ],
        dash(),
        kv('Items: ${t.lines.length}', 'Qty: ${qtyText(t.lines.fold<double>(0, (s, l) => s + l.qty))}'),
        if (b.gstEnabled && tot.tax > 0) ...[
          kv('Taxable', _m(tot.taxable)),
          if (tot.interState) kv('IGST', _m(tot.igst)) else ...[kv('CGST', _m(tot.cgst)), kv('SGST', _m(tot.sgst))],
        ],
        if (tot.extraDiscount > 0) kv('Discount', '-${_m(tot.extraDiscount)}'),
        if (tot.charges > 0) kv('Charges', _m(tot.charges)),
        if (tot.roundOff.abs() > 0.001) kv('Round off', _m(tot.roundOff)),
        kv('TOTAL', '₹${_m(tot.total)}', true),
        if (st != null && st.total - st.due > 0) kv(t.type == TxnType.sale ? 'Received' : 'Paid', _m(st.total - st.due)),
        if (st != null && st.due > 0) kv('Balance', '₹${_m(st.due)}', true),
      ] else ...[
        kv('Amount', '₹${_m(t.amount)}', true),
        pw.Text('Mode: ${t.mode.toUpperCase()}', style: ts()),
      ],
      dash(),
      if (b.upi.isNotEmpty && t.type == TxnType.sale && (st?.due ?? 0) > 0) ...[
        pw.Center(
          child: pw.BarcodeWidget(
            barcode: pw.Barcode.qrCode(),
                drawText: false,
            data: upiLink(vpa: b.upi, payee: b.name, amount: st!.due, note: t.number),
            width: narrow ? 70 : 90,
            height: narrow ? 70 : 90,
          ),
        ),
        pw.Text('Scan & pay with any UPI app', textAlign: pw.TextAlign.center, style: ts()),
      ],
      pw.SizedBox(height: 4),
      pw.Text('Thank you! Visit again.', textAlign: pw.TextAlign.center, style: ts(true)),
    ]),
  ));
}

// ---------------------------------------------------------------- tables (statements, reports)

/// A simple report: title, a subtitle line, a table and optional totals.
Future<Uint8List> buildTablePdf({
  required String title,
  String subtitle = '',
  required List<String> headers,
  required List<List<String>> rows,
  List<(String, String)> summary = const [],
  Set<int> rightAligned = const {},
}) async {
  final b = _db.biz;
  final accent = PdfColor.fromInt(pdfThemes[b.colour.clamp(0, pdfThemes.length - 1)]);
  final doc = pw.Document(title: title, author: b.name, theme: await _theme());
  doc.addPage(pw.MultiPage(
    pageFormat: PdfPageFormat.a4,
    margin: const pw.EdgeInsets.all(32),
    footer: (c) => pw.Row(children: [
      pw.Expanded(child: pw.Text('${b.name} · generated ${dmy(DateTime.now())}', style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey600))),
      pw.Text('Page ${c.pageNumber} of ${c.pagesCount}', style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey600)),
    ]),
    build: (c) => [
      pw.Text(b.name, style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold, color: accent)),
      if (b.gstEnabled && b.gstin.isNotEmpty) pw.Text('GSTIN: ${b.gstin}', style: const pw.TextStyle(fontSize: 9)),
      pw.SizedBox(height: 8),
      pw.Text(title, style: pw.TextStyle(fontSize: 13, fontWeight: pw.FontWeight.bold)),
      if (subtitle.isNotEmpty) pw.Text(subtitle, style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey700)),
      pw.SizedBox(height: 10),
      if (summary.isNotEmpty) ...[
        pw.Wrap(spacing: 18, runSpacing: 6, children: [
          for (final s in summary)
            pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
              pw.Text(s.$1, style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey700)),
              pw.Text(s.$2, style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold)),
            ]),
        ]),
        pw.SizedBox(height: 12),
      ],
      pw.TableHelper.fromTextArray(
        headers: headers,
        data: rows,
        border: null,
        headerStyle: pw.TextStyle(fontSize: 8.5, fontWeight: pw.FontWeight.bold, color: PdfColors.white),
        headerDecoration: pw.BoxDecoration(color: accent),
        cellStyle: const pw.TextStyle(fontSize: 8.5),
        cellPadding: const pw.EdgeInsets.symmetric(horizontal: 4, vertical: 4),
        rowDecoration: const pw.BoxDecoration(border: pw.Border(bottom: pw.BorderSide(color: PdfColors.grey300, width: 0.5))),
        cellAlignments: {for (final i in rightAligned) i: pw.Alignment.centerRight},
        headerAlignments: {for (final i in rightAligned) i: pw.Alignment.centerRight},
      ),
    ],
  ));
  return doc.save();
}
