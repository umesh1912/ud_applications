import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:ud_core/ud_core.dart';

import 'gst.dart';

// ---------------------------------------------------------------- models

enum TxnType {
  sale('INV-'),
  purchase('PUR-'),
  paymentIn('RCPT-'),
  paymentOut('PAY-'),
  expense('EXP-'),
  estimate('EST-'),
  saleReturn('CN-'),
  purchaseReturn('DN-'),
  saleOrder('SO-'),
  challan('DC-');

  const TxnType(this.prefix);
  final String prefix;

  /// Has item lines (as opposed to a plain amount).
  bool get hasLines => this != paymentIn && this != paymentOut && this != expense;

  /// Sale side (customer) vs purchase side (supplier).
  bool get isSaleSide => this == sale || this == paymentIn || this == estimate || this == saleReturn || this == saleOrder || this == challan;

  /// Documents that don't move money, stock or balances.
  bool get isDraftDoc => this == estimate || this == saleOrder || this == challan;

  /// +1 if it increases what the party owes us, -1 if it decreases it.
  int get partySign => switch (this) {
        sale || purchaseReturn || paymentOut => 1,
        purchase || saleReturn || paymentIn => -1,
        _ => 0,
      };

  /// +1 money comes in, -1 money goes out (for the amount paid on the document).
  int get cashSign => switch (this) {
        sale || paymentIn || purchaseReturn => 1,
        purchase || paymentOut || expense || saleReturn => -1,
        _ => 0,
      };

  /// Stock direction for item lines.
  int get stockSign => switch (this) {
        purchase || saleReturn => 1,
        sale || purchaseReturn => -1,
        _ => 0,
      };

  static TxnType parse(String? s) => TxnType.values.firstWhere((e) => e.name == s, orElse: () => TxnType.sale);
}

const payModes = ['cash', 'upi', 'bank', 'cheque', 'card'];

const expenseCategories = [
  'rent', 'salary', 'electricity', 'transport', 'fuel', 'repair', 'tea_snacks',
  'telephone', 'stationery', 'marketing', 'bank_charges', 'tax_fees', 'other_exp',
];

double _d(dynamic v, [double def = 0]) => (v as num?)?.toDouble() ?? def;
String _s(dynamic v) => (v as String?) ?? '';
DateTime _dt(dynamic v) => DateTime.tryParse(_s(v)) ?? DateTime.now();

String newId() => '${DateTime.now().microsecondsSinceEpoch}${Random().nextInt(999)}';

class Business {
  Business();
  String name = '';
  String phone = '';
  String email = '';
  String gstin = '';
  String address = '';
  String state = '24';
  String upi = '';
  String bankName = '';
  String accountNo = '';
  String ifsc = '';
  String logoPath = '';
  String signPath = '';
  String terms = 'Goods once sold will not be taken back.\nSubject to local jurisdiction.';
  String invoicePrefix = 'INV-';
  bool gstEnabled = true;
  bool taxInclusive = false;
  bool roundOff = true;
  String printSize = 'a4'; // a4, a5, 80, 58
  int colour = 0;
  String pin = '';

  bool get isSetUp => name.trim().isNotEmpty;

  Map<String, dynamic> toJson() => {
        'name': name, 'phone': phone, 'email': email, 'gstin': gstin, 'address': address,
        'state': state, 'upi': upi, 'bankName': bankName, 'accountNo': accountNo, 'ifsc': ifsc,
        'logoPath': logoPath, 'signPath': signPath, 'terms': terms, 'invoicePrefix': invoicePrefix,
        'gstEnabled': gstEnabled, 'taxInclusive': taxInclusive, 'roundOff': roundOff,
        'printSize': printSize, 'colour': colour, 'pin': pin,
      };

  static Business fromJson(Map<String, dynamic> j) => Business()
    ..name = _s(j['name'])
    ..phone = _s(j['phone'])
    ..email = _s(j['email'])
    ..gstin = _s(j['gstin'])
    ..address = _s(j['address'])
    ..state = j['state'] as String? ?? '24'
    ..upi = _s(j['upi'])
    ..bankName = _s(j['bankName'])
    ..accountNo = _s(j['accountNo'])
    ..ifsc = _s(j['ifsc'])
    ..logoPath = _s(j['logoPath'])
    ..signPath = _s(j['signPath'])
    ..terms = j['terms'] as String? ?? Business().terms
    ..invoicePrefix = j['invoicePrefix'] as String? ?? 'INV-'
    ..gstEnabled = j['gstEnabled'] as bool? ?? true
    ..taxInclusive = j['taxInclusive'] as bool? ?? false
    ..roundOff = j['roundOff'] as bool? ?? true
    ..printSize = j['printSize'] as String? ?? 'a4'
    ..colour = (j['colour'] as num?)?.toInt() ?? 0
    ..pin = _s(j['pin']);
}

class Party {
  Party({String? id, this.name = ''}) : id = id ?? newId();
  final String id;
  String name;
  String phone = '';
  String email = '';
  String gstin = '';
  String address = '';
  String state = '';
  String kind = 'customer'; // customer, supplier
  /// Positive: they owe us. Negative: we owe them.
  double opening = 0;
  DateTime openingDate = DateTime.now();
  int creditDays = 0;
  DateTime createdAt = DateTime.now();

  Map<String, dynamic> toJson() => {
        'id': id, 'name': name, 'phone': phone, 'email': email, 'gstin': gstin,
        'address': address, 'state': state, 'kind': kind, 'opening': opening,
        'openingDate': openingDate.toIso8601String(), 'creditDays': creditDays,
        'createdAt': createdAt.toIso8601String(),
      };

  static Party fromJson(Map<String, dynamic> j) => Party(id: j['id'] as String, name: _s(j['name']))
    ..phone = _s(j['phone'])
    ..email = _s(j['email'])
    ..gstin = _s(j['gstin'])
    ..address = _s(j['address'])
    ..state = _s(j['state'])
    ..kind = j['kind'] as String? ?? 'customer'
    ..opening = _d(j['opening'])
    ..openingDate = _dt(j['openingDate'])
    ..creditDays = (j['creditDays'] as num?)?.toInt() ?? 0
    ..createdAt = _dt(j['createdAt']);
}

class Item {
  Item({String? id, this.name = ''}) : id = id ?? newId();
  final String id;
  String name;
  String code = '';
  String hsn = '';
  String unit = 'pcs';
  String category = '';
  double salePrice = 0;
  double purchasePrice = 0;
  double mrp = 0;
  double gstRate = 0;
  bool taxInclusive = false;
  bool isService = false;
  double openingStock = 0;
  double lowStock = 0;
  DateTime createdAt = DateTime.now();

  Map<String, dynamic> toJson() => {
        'id': id, 'name': name, 'code': code, 'hsn': hsn, 'unit': unit, 'category': category,
        'salePrice': salePrice, 'purchasePrice': purchasePrice, 'mrp': mrp, 'gstRate': gstRate,
        'taxInclusive': taxInclusive, 'isService': isService, 'openingStock': openingStock,
        'lowStock': lowStock, 'createdAt': createdAt.toIso8601String(),
      };

  static Item fromJson(Map<String, dynamic> j) => Item(id: j['id'] as String, name: _s(j['name']))
    ..code = _s(j['code'])
    ..hsn = _s(j['hsn'])
    ..unit = j['unit'] as String? ?? 'pcs'
    ..category = _s(j['category'])
    ..salePrice = _d(j['salePrice'])
    ..purchasePrice = _d(j['purchasePrice'])
    ..mrp = _d(j['mrp'])
    ..gstRate = _d(j['gstRate'])
    ..taxInclusive = j['taxInclusive'] as bool? ?? false
    ..isService = j['isService'] as bool? ?? false
    ..openingStock = _d(j['openingStock'])
    ..lowStock = _d(j['lowStock'])
    ..createdAt = _dt(j['createdAt']);
}

class Line {
  Line();
  String itemId = '';
  String name = '';
  String hsn = '';
  String unit = 'pcs';
  double qty = 1;
  double rate = 0;
  double discountPct = 0;
  double gstRate = 0;

  Line copy() => Line.fromJson(toJson());

  Map<String, dynamic> toJson() => {
        'itemId': itemId, 'name': name, 'hsn': hsn, 'unit': unit, 'qty': qty,
        'rate': rate, 'discountPct': discountPct, 'gstRate': gstRate,
      };

  static Line fromJson(Map<String, dynamic> j) => Line()
    ..itemId = _s(j['itemId'])
    ..name = _s(j['name'])
    ..hsn = _s(j['hsn'])
    ..unit = j['unit'] as String? ?? 'pcs'
    ..qty = _d(j['qty'], 1)
    ..rate = _d(j['rate'])
    ..discountPct = _d(j['discountPct'])
    ..gstRate = _d(j['gstRate']);
}

/// Calculated amounts for one line.
class LineCalc {
  LineCalc(this.gross, this.discount, this.taxable, this.tax);
  final double gross, discount, taxable, tax;
  double get total => taxable + tax;
}

LineCalc calcLine(Line l, {required bool inclusive, required bool gst}) {
  final rate = gst ? l.gstRate : 0.0;
  final gross = l.qty * l.rate;
  final discount = gross * l.discountPct / 100;
  final after = gross - discount;
  final taxable = inclusive ? after / (1 + rate / 100) : after;
  return LineCalc(gross, discount, taxable, taxable * rate / 100);
}

class Totals {
  double gross = 0, discount = 0, taxable = 0, tax = 0, extraDiscount = 0, charges = 0, roundOff = 0, total = 0;
  bool interState = false;

  /// Taxable value and tax amount per GST rate.
  final Map<double, (double, double)> byRate = {};
  double get cgst => interState ? 0 : tax / 2;
  double get sgst => cgst;
  double get igst => interState ? tax : 0;
}

class Txn {
  Txn({String? id, required this.type}) : id = id ?? newId();
  final String id;
  TxnType type;
  String number = '';
  DateTime date = DateTime.now();
  DateTime? dueDate;
  String partyId = '';
  String partyName = '';
  String partyPhone = '';
  List<Line> lines = [];
  double extraDiscount = 0;
  double charges = 0; // shipping / packing
  bool roundOff = true;
  bool taxInclusive = false;

  /// Plain amount for payments and expenses.
  double amount = 0;

  /// Paid or received at the time of the document.
  double paid = 0;
  String mode = 'cash';
  String accountId = 'cash';
  String category = '';
  String refNo = '';
  String notes = '';
  String placeOfSupply = '';
  String convertedTo = '';
  String linkedId = ''; // e.g. the invoice a payment was made against
  DateTime createdAt = DateTime.now();

  Map<String, dynamic> toJson() => {
        'id': id, 'type': type.name, 'number': number, 'date': date.toIso8601String(),
        if (dueDate != null) 'dueDate': dueDate!.toIso8601String(),
        'partyId': partyId, 'partyName': partyName, 'partyPhone': partyPhone,
        'lines': [for (final l in lines) l.toJson()],
        'extraDiscount': extraDiscount, 'charges': charges, 'roundOff': roundOff,
        'taxInclusive': taxInclusive, 'amount': amount, 'paid': paid, 'mode': mode,
        'accountId': accountId, 'category': category, 'refNo': refNo, 'notes': notes,
        'placeOfSupply': placeOfSupply, 'convertedTo': convertedTo, 'linkedId': linkedId,
        'createdAt': createdAt.toIso8601String(),
      };

  static Txn fromJson(Map<String, dynamic> j) => Txn(id: j['id'] as String, type: TxnType.parse(j['type'] as String?))
    ..number = _s(j['number'])
    ..date = _dt(j['date'])
    ..dueDate = j['dueDate'] == null ? null : _dt(j['dueDate'])
    ..partyId = _s(j['partyId'])
    ..partyName = _s(j['partyName'])
    ..partyPhone = _s(j['partyPhone'])
    ..lines = [for (final l in (j['lines'] as List?) ?? const []) Line.fromJson(Map<String, dynamic>.from(l as Map))]
    ..extraDiscount = _d(j['extraDiscount'])
    ..charges = _d(j['charges'])
    ..roundOff = j['roundOff'] as bool? ?? true
    ..taxInclusive = j['taxInclusive'] as bool? ?? false
    ..amount = _d(j['amount'])
    ..paid = _d(j['paid'])
    ..mode = j['mode'] as String? ?? 'cash'
    ..accountId = j['accountId'] as String? ?? 'cash'
    ..category = _s(j['category'])
    ..refNo = _s(j['refNo'])
    ..notes = _s(j['notes'])
    ..placeOfSupply = _s(j['placeOfSupply'])
    ..convertedTo = _s(j['convertedTo'])
    ..linkedId = _s(j['linkedId'])
    ..createdAt = _dt(j['createdAt']);

  Txn copyAs(TxnType t) {
    final c = Txn.fromJson({...toJson(), 'id': newId(), 'type': t.name});
    c
      ..convertedTo = ''
      ..paid = 0
      ..createdAt = DateTime.now();
    return c;
  }

  Totals totals({required String homeState, required bool gst}) {
    final out = Totals();
    if (!type.hasLines) {
      out.total = amount;
      return out;
    }
    out.interState = placeOfSupply.isNotEmpty && placeOfSupply != homeState;
    for (final l in lines) {
      final c = calcLine(l, inclusive: taxInclusive, gst: gst);
      out.gross += c.gross;
      out.discount += c.discount;
      out.taxable += c.taxable;
      out.tax += c.tax;
      final r = gst ? l.gstRate : 0.0;
      final prev = out.byRate[r] ?? (0, 0);
      out.byRate[r] = (prev.$1 + c.taxable, prev.$2 + c.tax);
    }
    out.extraDiscount = extraDiscount;
    out.charges = charges;
    final raw = out.taxable + out.tax - extraDiscount + charges;
    final rounded = roundOff ? raw.roundToDouble() : round2(raw);
    out.roundOff = rounded - raw;
    out.total = rounded;
    return out;
  }
}

class Account {
  Account({String? id, this.name = '', this.kind = 'bank'}) : id = id ?? newId();
  final String id;
  String name;
  String kind; // cash, bank
  double opening = 0;
  String accountNo = '';
  String ifsc = '';

  Map<String, dynamic> toJson() => {'id': id, 'name': name, 'kind': kind, 'opening': opening, 'accountNo': accountNo, 'ifsc': ifsc};

  static Account fromJson(Map<String, dynamic> j) =>
      Account(id: j['id'] as String, name: _s(j['name']), kind: j['kind'] as String? ?? 'bank')
        ..opening = _d(j['opening'])
        ..accountNo = _s(j['accountNo'])
        ..ifsc = _s(j['ifsc']);
}

class StockAdj {
  StockAdj({String? id, required this.itemId, required this.qty, this.note = ''}) : id = id ?? newId();
  final String id;
  final String itemId;
  final double qty;
  final String note;
  DateTime date = DateTime.now();

  Map<String, dynamic> toJson() => {'id': id, 'itemId': itemId, 'qty': qty, 'note': note, 'date': date.toIso8601String()};

  static StockAdj fromJson(Map<String, dynamic> j) =>
      StockAdj(id: j['id'] as String, itemId: _s(j['itemId']), qty: _d(j['qty']), note: _s(j['note']))..date = _dt(j['date']);
}

/// Payment state of a sale or purchase document.
enum PayStatus { paid, partial, unpaid, overdue }

class DocStatus {
  DocStatus(this.total, this.settled);
  final double total;
  final double settled;
  double get due => max(0, round2(total - settled));
  PayStatus statusOn(DateTime? dueDate) {
    if (due <= 0.009) return PayStatus.paid;
    if (dueDate != null && dayOnly(DateTime.now()).isAfter(dueDate)) return PayStatus.overdue;
    return settled > 0.009 ? PayStatus.partial : PayStatus.unpaid;
  }
}

// ---------------------------------------------------------------- store

/// All business data, kept in one JSON file in the app's private storage.
class Db extends ChangeNotifier {
  Db._();
  static final Db i = Db._();

  bool loaded = false;
  Business biz = Business();
  final List<Party> parties = [];
  final List<Item> items = [];
  final List<Txn> txns = [];
  final List<Account> accounts = [];
  final List<StockAdj> adjustments = [];

  File? _file;

  Future<void> load() async {
    final dir = await udDir('hisaab');
    _file = File('${dir.path}/data.json');
    if (await _file!.exists()) {
      try {
        _apply(jsonDecode(await _file!.readAsString()) as Map<String, dynamic>);
      } catch (e) {
        debugPrint('Hisaab: could not read data: $e');
        final bak = File('${dir.path}/data.bak.json');
        if (await bak.exists()) {
          _apply(jsonDecode(await bak.readAsString()) as Map<String, dynamic>);
        }
      }
    }
    if (!accounts.any((a) => a.id == 'cash')) {
      accounts.insert(0, Account(id: 'cash', name: 'Cash in hand', kind: 'cash'));
    }
    loaded = true;
    _invalidate();
    notifyListeners();
  }

  void _apply(Map<String, dynamic> j) {
    List<Map<String, dynamic>> list(String k) =>
        [for (final e in (j[k] as List?) ?? const []) Map<String, dynamic>.from(e as Map)];
    biz = Business.fromJson(Map<String, dynamic>.from((j['business'] as Map?) ?? const {}));
    parties
      ..clear()
      ..addAll(list('parties').map(Party.fromJson));
    items
      ..clear()
      ..addAll(list('items').map(Item.fromJson));
    txns
      ..clear()
      ..addAll(list('txns').map(Txn.fromJson));
    accounts
      ..clear()
      ..addAll(list('accounts').map(Account.fromJson));
    adjustments
      ..clear()
      ..addAll(list('adjustments').map(StockAdj.fromJson));
  }

  Map<String, dynamic> toJson() => {
        'app': 'hisaab',
        'version': 1,
        'savedAt': DateTime.now().toIso8601String(),
        'business': biz.toJson(),
        'parties': [for (final p in parties) p.toJson()],
        'items': [for (final p in items) p.toJson()],
        'txns': [for (final p in txns) p.toJson()],
        'accounts': [for (final p in accounts) p.toJson()],
        'adjustments': [for (final p in adjustments) p.toJson()],
      };

  Future<void> _write = Future.value();

  Future<void> save() {
    _invalidate();
    notifyListeners();
    final data = jsonEncode(toJson());
    _write = _write.then((_) async {
      final f = _file;
      if (f == null) return;
      final tmp = File('${f.path}.tmp');
      await tmp.writeAsString(data, flush: true);
      if (await f.exists()) await f.copy('${f.parent.path}/data.bak.json');
      await tmp.rename(f.path);
    });
    return _write;
  }

  /// Replaces everything with a backup. Returns false if the file isn't a Hisaab backup.
  Future<bool> restore(String json) async {
    final j = jsonDecode(json);
    if (j is! Map<String, dynamic> || j['app'] != 'hisaab') return false;
    _apply(j);
    if (!accounts.any((a) => a.id == 'cash')) {
      accounts.insert(0, Account(id: 'cash', name: 'Cash in hand', kind: 'cash'));
    }
    await save();
    return true;
  }

  // ------------------------------------------------ lookups

  Party? party(String id) => id.isEmpty ? null : parties.where((p) => p.id == id).firstOrNull;
  Item? item(String id) => id.isEmpty ? null : items.where((p) => p.id == id).firstOrNull;
  Txn? txn(String id) => id.isEmpty ? null : txns.where((p) => p.id == id).firstOrNull;
  Account account(String id) => accounts.where((a) => a.id == id).firstOrNull ?? accounts.first;

  Totals totals(Txn t) => t.totals(homeState: biz.state, gst: biz.gstEnabled);

  /// Total of a document (or the amount of a payment / expense).
  double totalOf(Txn t) => _totalCache[t.id] ??= totals(t).total;

  String nextNumber(TxnType type) {
    final prefix = type == TxnType.sale ? biz.invoicePrefix : type.prefix;
    var best = 0;
    for (final t in txns) {
      if (t.type != type) continue;
      final m = RegExp(r'(\d+)\D*$').firstMatch(t.number);
      if (m != null) best = max(best, int.tryParse(m.group(1)!) ?? 0);
    }
    return '$prefix${best + 1}';
  }

  // ------------------------------------------------ mutations

  Future<void> putParty(Party p) {
    final i = parties.indexWhere((e) => e.id == p.id);
    if (i == -1) {
      parties.add(p);
    } else {
      parties[i] = p;
    }
    // Keep the party's name on its documents in step.
    for (final t in txns) {
      if (t.partyId == p.id) t.partyName = p.name;
    }
    return save();
  }

  Future<void> deleteParty(String id) {
    parties.removeWhere((p) => p.id == id);
    for (final t in txns) {
      if (t.partyId == id) t.partyId = '';
    }
    return save();
  }

  Future<void> putItem(Item it) {
    final i = items.indexWhere((e) => e.id == it.id);
    if (i == -1) {
      items.add(it);
    } else {
      items[i] = it;
    }
    return save();
  }

  Future<void> deleteItem(String id) {
    items.removeWhere((p) => p.id == id);
    adjustments.removeWhere((a) => a.itemId == id);
    return save();
  }

  Future<void> putTxn(Txn t) {
    final i = txns.indexWhere((e) => e.id == t.id);
    if (i == -1) {
      txns.add(t);
    } else {
      txns[i] = t;
    }
    return save();
  }

  Future<void> deleteTxn(String id) {
    txns.removeWhere((t) => t.id == id);
    for (final t in txns) {
      if (t.convertedTo == id) t.convertedTo = '';
      if (t.linkedId == id) t.linkedId = '';
    }
    return save();
  }

  Future<void> putAccount(Account a) {
    final i = accounts.indexWhere((e) => e.id == a.id);
    if (i == -1) {
      accounts.add(a);
    } else {
      accounts[i] = a;
    }
    return save();
  }

  Future<void> deleteAccount(String id) {
    if (id == 'cash') return Future.value();
    accounts.removeWhere((a) => a.id == id);
    for (final t in txns) {
      if (t.accountId == id) t.accountId = 'cash';
    }
    return save();
  }

  Future<void> addAdjustment(StockAdj a) {
    adjustments.add(a);
    return save();
  }

  // ------------------------------------------------ derived values (cached)

  final Map<String, double> _totalCache = {};
  Map<String, double>? _partyBal;
  Map<String, double>? _stock;
  Map<String, double>? _accBal;
  Map<String, DocStatus>? _docStatus;

  void _invalidate() {
    _totalCache.clear();
    _partyBal = null;
    _stock = null;
    _accBal = null;
    _docStatus = null;
  }

  /// Money that moved with this document (paid at the time, or the payment itself).
  double cashOf(Txn t) => switch (t.type) {
        TxnType.paymentIn || TxnType.paymentOut || TxnType.expense => t.amount,
        _ when t.type.isDraftDoc => 0,
        _ => t.paid,
      };

  /// Effect of one document on what the party owes us.
  double partyEffect(Txn t) {
    switch (t.type) {
      case TxnType.paymentIn:
      case TxnType.paymentOut:
        return t.type.partySign * t.amount;
      case TxnType.sale:
      case TxnType.purchaseReturn:
        return totalOf(t) - t.paid;
      case TxnType.purchase:
      case TxnType.saleReturn:
        return -(totalOf(t) - t.paid);
      default:
        return 0;
    }
  }

  /// Positive: party owes us. Negative: we owe the party.
  double partyBalance(String id) {
    _partyBal ??= () {
      final m = <String, double>{for (final p in parties) p.id: p.opening};
      for (final t in txns) {
        if (t.partyId.isEmpty || !m.containsKey(t.partyId)) continue;
        m[t.partyId] = m[t.partyId]! + partyEffect(t);
      }
      return m;
    }();
    return _partyBal![id] ?? 0;
  }

  double get toReceive => parties.fold(0.0, (s, p) => s + max(0, partyBalance(p.id)));
  double get toPay => parties.fold(0.0, (s, p) => s + max(0, -partyBalance(p.id)));

  double stockOf(String itemId) {
    _stock ??= () {
      final m = <String, double>{for (final it in items) it.id: it.openingStock};
      for (final t in txns) {
        final s = t.type.stockSign;
        if (s == 0) continue;
        for (final l in t.lines) {
          if (m.containsKey(l.itemId)) m[l.itemId] = m[l.itemId]! + s * l.qty;
        }
      }
      for (final a in adjustments) {
        if (m.containsKey(a.itemId)) m[a.itemId] = m[a.itemId]! + a.qty;
      }
      return m;
    }();
    return _stock![itemId] ?? 0;
  }

  List<Item> get lowStockItems =>
      [for (final it in items) if (!it.isService && it.lowStock > 0 && stockOf(it.id) <= it.lowStock) it];

  double get stockValue => items.where((i) => !i.isService).fold(0.0, (s, i) => s + max(0, stockOf(i.id)) * i.purchasePrice);

  double accountBalance(String id) {
    _accBal ??= () {
      final m = <String, double>{for (final a in accounts) a.id: a.opening};
      for (final t in txns) {
        final s = t.type.cashSign;
        if (s == 0) continue;
        final key = m.containsKey(t.accountId) ? t.accountId : 'cash';
        m[key] = (m[key] ?? 0) + s * cashOf(t);
      }
      return m;
    }();
    return _accBal![id] ?? 0;
  }

  double get cashAndBank => accounts.fold(0.0, (s, a) => s + accountBalance(a.id));

  /// How much of each sale / purchase is settled: paid on the document plus
  /// later payments from the same party, allocated oldest bill first.
  DocStatus docStatus(Txn t) {
    _docStatus ??= _allocate();
    return _docStatus![t.id] ?? DocStatus(totalOf(t), cashOf(t));
  }

  Map<String, DocStatus> _allocate() {
    final out = <String, DocStatus>{};
    final sorted = [...txns]..sort((a, b) => a.date.compareTo(b.date));
    for (final side in [TxnType.sale, TxnType.purchase]) {
      final payType = side == TxnType.sale ? TxnType.paymentIn : TxnType.paymentOut;
      final retType = side == TxnType.sale ? TxnType.saleReturn : TxnType.purchaseReturn;
      final pool = <String, double>{};
      // Payments made against a particular bill settle that bill first.
      final direct = <String, double>{};
      for (final t in sorted) {
        if (t.partyId.isEmpty) continue;
        if (t.type == payType) {
          final target = t.linkedId.isEmpty ? null : txn(t.linkedId);
          if (target != null && target.type == side && target.partyId == t.partyId) {
            final room = max(0.0, totalOf(target) - target.paid - (direct[target.id] ?? 0));
            final use = min(room, t.amount);
            direct[target.id] = (direct[target.id] ?? 0) + use;
            pool[t.partyId] = (pool[t.partyId] ?? 0) + t.amount - use;
          } else {
            pool[t.partyId] = (pool[t.partyId] ?? 0) + t.amount;
          }
        }
        if (t.type == retType) pool[t.partyId] = (pool[t.partyId] ?? 0) + totalOf(t) - t.paid;
      }
      // Opening balances are the oldest dues.
      for (final p in parties) {
        final owed = side == TxnType.sale ? p.opening : -p.opening;
        if (owed > 0 && pool.containsKey(p.id)) pool[p.id] = max(0, pool[p.id]! - owed);
      }
      for (final t in sorted) {
        if (t.type != side) continue;
        final total = totalOf(t);
        var settled = t.paid + (direct[t.id] ?? 0);
        final left = pool[t.partyId] ?? 0;
        if (left > 0 && settled < total) {
          final use = min(left, total - settled);
          settled += use;
          pool[t.partyId] = left - use;
        }
        out[t.id] = DocStatus(total, settled);
      }
    }
    return out;
  }

  /// Unpaid sale invoices, most overdue first.
  List<Txn> get dueInvoices {
    final list = [for (final t in txns) if (t.type == TxnType.sale && docStatus(t).due > 0) t];
    list.sort((a, b) => (a.dueDate ?? a.date).compareTo(b.dueDate ?? b.date));
    return list;
  }

  // ------------------------------------------------ period figures

  Iterable<Txn> inRange(DateTime from, DateTime to, [Set<TxnType>? types]) => txns.where((t) =>
      !t.date.isBefore(from) && t.date.isBefore(to) && (types == null || types.contains(t.type)));

  double sumTotal(DateTime from, DateTime to, TxnType type) =>
      inRange(from, to, {type}).fold(0.0, (s, t) => s + totalOf(t));

  /// Cost of the goods in a sale, from each item's purchase price.
  double costOf(Txn t) => t.lines.fold(0.0, (s, l) => s + l.qty * (item(l.itemId)?.purchasePrice ?? 0));
}
