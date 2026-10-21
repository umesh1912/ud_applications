import 'dart:convert';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'data.dart';

/// App state. Payments are simulated; a real build would call a BBPS
/// aggregator and a payment gateway where [fetchBill] and [pay] are.
class Store extends ChangeNotifier {
  Store._(this._prefs);

  static const _key = 'jhatpat_v1';
  final SharedPreferences _prefs;
  final _rand = Random();

  String name = '';
  String phone = '';
  bool signedIn = false;
  double walletBalance = 0;
  int points = 0;
  final List<PayMethod> methods = [];
  String? defaultMethodId;
  final List<SavedBiller> saved = [];
  final List<Payment> payments = [];
  final List<ScratchCard> scratchCards = [];
  final Set<String> usedCodes = {};

  static Future<Store> load() async {
    final prefs = await SharedPreferences.getInstance();
    final s = Store._(prefs);
    final raw = prefs.getString(_key);
    if (raw != null) {
      try {
        s._fromJson(jsonDecode(raw) as Map<String, dynamic>);
      } catch (_) {}
    }
    return s;
  }

  void _fromJson(Map<String, dynamic> j) {
    List<T> list<T>(String k, T Function(Map<String, dynamic>) f) =>
        ((j[k] as List?) ?? []).map((e) => f(e as Map<String, dynamic>)).toList();
    name = (j['name'] as String?) ?? '';
    phone = (j['phone'] as String?) ?? '';
    signedIn = (j['signedIn'] as bool?) ?? false;
    walletBalance = ((j['walletBalance'] as num?) ?? 0).toDouble();
    points = (j['points'] as int?) ?? 0;
    methods.addAll(list('methods', PayMethod.fromJson));
    defaultMethodId = j['defaultMethodId'] as String?;
    saved.addAll(list('saved', SavedBiller.fromJson));
    payments.addAll(list('payments', Payment.fromJson));
    scratchCards.addAll(list('scratchCards', ScratchCard.fromJson));
    usedCodes.addAll(((j['usedCodes'] as List?) ?? []).cast<String>());
  }

  Map<String, dynamic> _toJson() => {
        'name': name,
        'phone': phone,
        'signedIn': signedIn,
        'walletBalance': walletBalance,
        'points': points,
        'methods': methods.map((e) => e.toJson()).toList(),
        'defaultMethodId': defaultMethodId,
        'saved': saved.map((e) => e.toJson()).toList(),
        'payments': payments.map((e) => e.toJson()).toList(),
        'scratchCards': scratchCards.map((e) => e.toJson()).toList(),
        'usedCodes': usedCodes.toList(),
      };

  void changed() {
    _prefs.setString(_key, jsonEncode(_toJson()));
    notifyListeners();
  }

  String newId() => '${DateTime.now().microsecondsSinceEpoch}${_rand.nextInt(999)}';

  // ── Account ────────────────────────────────────────────────────
  void signIn(String name, String phone) {
    this.name = name;
    this.phone = phone;
    signedIn = true;
    if (methods.isEmpty) {
      walletBalance = 500; // demo balance
      methods.addAll([
        PayMethod(newId(), PayMethodType.upi, 'UPI', '${phone.isEmpty ? 'you' : phone}@okbank (demo)'),
        PayMethod(newId(), PayMethodType.wallet, 'Jhatpat wallet', 'Balance'),
      ]);
      defaultMethodId = methods.first.id;
      final now = DateTime.now();
      saved.addAll([
        SavedBiller(id: newId(), kind: Kind.mobile, biller: detectOperator(phone).$1, accountId: phone, nickname: 'My phone',
            circle: detectOperator(phone).$2, nextDue: now.add(const Duration(days: 3)), lastAmount: 299),
        SavedBiller(id: newId(), kind: Kind.electricity, biller: 'MSEDCL (Maharashtra)', accountId: '170012345678', nickname: 'Home electricity',
            nextDue: now.add(const Duration(days: 6)), lastAmount: 1840),
      ]);
    }
    changed();
  }

  void signOut() {
    signedIn = false;
    changed();
  }

  PayMethod? methodById(String? id) {
    for (final m in methods) {
      if (m.id == id) return m;
    }
    return methods.isEmpty ? null : methods.first;
  }

  void addMethod(PayMethod m) {
    methods.add(m);
    changed();
  }

  void removeMethod(PayMethod m) {
    if (m.type == PayMethodType.wallet) return;
    methods.remove(m);
    if (defaultMethodId == m.id) defaultMethodId = methods.isEmpty ? null : methods.first.id;
    changed();
  }

  // ── Billers ────────────────────────────────────────────────────
  SavedBiller? findSaved(Kind k, String accountId) {
    for (final s in saved) {
      if (s.kind == k && s.accountId == accountId) return s;
    }
    return null;
  }

  void saveBiller(SavedBiller b) {
    saved.add(b);
    changed();
  }

  void removeBiller(SavedBiller b) {
    saved.remove(b);
    changed();
  }

  /// Things that need attention soon: due bills and expiring plans.
  List<SavedBiller> get dueSoon {
    final now = DateTime.now();
    final list = saved.where((s) => s.remind && s.nextDue != null && s.nextDue!.difference(now).inDays <= 7).toList()
      ..sort((a, b) => a.nextDue!.compareTo(b.nextDue!));
    return list;
  }

  /// Simulated BBPS bill fetch.
  Future<FetchedBill?> fetchBill(Kind kind, String biller, String accountId) async {
    await Future<void>.delayed(const Duration(milliseconds: 1100));
    if (accountId.endsWith('000')) return null; // demo: "no bill found"
    final seed = accountId.codeUnits.fold(0, (a, b) => a + b);
    final r = Random(seed);
    final base = switch (kind) {
      Kind.electricity => 800 + r.nextInt(2600),
      Kind.water => 200 + r.nextInt(600),
      Kind.gas => 400 + r.nextInt(900),
      Kind.lpg => 853,
      Kind.broadband => 499 + r.nextInt(3) * 300,
      Kind.landline => 299 + r.nextInt(400),
      Kind.postpaid => 399 + r.nextInt(600),
      Kind.creditCard => 2000 + r.nextInt(30000),
      Kind.loan => 5000 + r.nextInt(20000),
      Kind.insurance => 6000 + r.nextInt(18000),
      Kind.municipal => 2500 + r.nextInt(9000),
      Kind.education => 12000 + r.nextInt(40000),
      _ => 300 + r.nextInt(500),
    };
    final now = DateTime.now();
    const names = ['R. Sharma', 'P. Iyer', 'A. Khan', 'S. Patel', 'M. Das', 'K. Reddy'];
    return FetchedBill(
      names[seed % names.length],
      base.toDouble(),
      DateTime(now.year, now.month, now.day + 4 + r.nextInt(10)),
      DateTime(now.year, now.month, max(1, now.day - 6)),
      '${_monthShort(now.month - 1)} ${now.month == 1 ? now.year - 1 : now.year}',
    );
  }

  static String _monthShort(int m) => const ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'][(m - 1 + 12) % 12];

  // ── Paying ─────────────────────────────────────────────────────
  /// Returns null if this method can't pay that amount, else an error message.
  String? canPay(PayMethod m, double amount) {
    if (m.type == PayMethodType.wallet && walletBalance < amount) {
      return 'Wallet has ₹${walletBalance.toStringAsFixed(0)}. Choose another way to pay.';
    }
    return null;
  }

  /// Simulated payment. About 1 in 12 fails so the refund flow can be seen.
  Future<Payment> pay({
    required Kind kind,
    required String biller,
    required String accountId,
    required double amount,
    required PayMethod method,
    Offer? offer,
    String? planText,
    String? nickname,
    DateTime? nextDue,
  }) async {
    await Future<void>.delayed(const Duration(milliseconds: 1600));
    final fail = _rand.nextInt(12) == 0;
    final cashback = fail || offer == null ? 0.0 : offer.cashbackFor(kind, amount).roundToDouble();
    final p = Payment(
      id: newId(),
      kind: kind,
      biller: biller,
      accountId: accountId,
      amount: amount,
      cashback: cashback,
      method: '${method.label} · ${method.detail}',
      date: DateTime.now(),
      status: fail ? PayStatus.failed : PayStatus.success,
      reference: 'JP${DateTime.now().millisecondsSinceEpoch.toString().substring(4)}',
      planText: planText,
      nickname: nickname,
    );
    payments.insert(0, p);
    if (!fail) {
      if (method.type == PayMethodType.wallet) walletBalance -= amount;
      walletBalance += cashback;
      if (offer != null) usedCodes.add(offer.code);
      points += (amount / 100).floor();
      if (amount >= 99) {
        final prize = [5, 10, 10, 15, 20, 25, 50][_rand.nextInt(7)];
        scratchCards.insert(0, ScratchCard(id: newId(), amount: prize, from: '${kind.label} · $biller'));
      }
      final s = findSaved(kind, accountId);
      if (s != null) {
        s.lastAmount = amount;
        s.nextDue = nextDue;
      }
    }
    changed();
    return p;
  }

  /// Failed payments are refunded automatically (demo: immediately marked).
  void markRefunded(Payment p) {
    p.status = PayStatus.refunded;
    changed();
  }

  String raiseComplaint(Payment p) {
    p.complaintId ??= 'BBPS${(100000 + _rand.nextInt(899999))}';
    changed();
    return p.complaintId!;
  }

  void scratch(ScratchCard c) {
    if (c.scratched) return;
    c.scratched = true;
    walletBalance += c.amount;
    changed();
  }

  void redeemPoints() {
    final rupees = points ~/ 10;
    if (rupees <= 0) return;
    points -= rupees * 10;
    walletBalance += rupees;
    changed();
  }

  double get totalCashback => payments.fold(0.0, (s, p) => s + p.cashback);

  String get referralCode => 'JHAT${(phone.isEmpty ? '0000' : phone.substring(max(0, phone.length - 4)))}';
}

class StoreScope extends InheritedNotifier<Store> {
  const StoreScope({super.key, required Store store, required super.child}) : super(notifier: store);
  static Store of(BuildContext c) => c.dependOnInheritedWidgetOfExactType<StoreScope>()!.notifier!;
  static Store read(BuildContext c) => c.getInheritedWidgetOfExactType<StoreScope>()!.notifier!;
}

extension StoreX on BuildContext {
  Store get store => StoreScope.of(this);
}
