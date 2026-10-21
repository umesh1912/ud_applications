import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'data.dart';

/// App state. Everything is simulated: no money moves. A real build would
/// replace [quote], [send] and the rate feed with a licensed partner's API.
class Store extends ChangeNotifier {
  Store._(this._prefs);

  static const _key = 'pul_v1';
  final SharedPreferences _prefs;
  final _rand = Random();
  Timer? _ticker;

  // Account
  String phone = '';
  String name = '';
  String pan = '';
  KycState kyc = KycState.notStarted;
  String? txnPin;
  bool signedIn = false;

  // Money
  final Map<String, double> rates = {for (final c in currencies) c.code: c.inrPerUnit};
  final Map<String, double> prevRates = {for (final c in currencies) c.code: c.inrPerUnit};
  final Map<String, double> wallet = {'INR': 0};
  bool cardFrozen = false;
  final List<Recipient> recipients = [];
  final List<Transfer> transfers = [];
  final List<RateAlert> alerts = [];
  final List<Recurring> recurring = [];
  final List<Incoming> incoming = [];
  double perTransferLimit = 500000;

  /// Rate alerts that fired since the user last looked.
  final List<RateAlert> freshAlerts = [];

  static Future<Store> load() async {
    final prefs = await SharedPreferences.getInstance();
    final s = Store._(prefs);
    final raw = prefs.getString(_key);
    if (raw != null) {
      try {
        s._fromJson(jsonDecode(raw) as Map<String, dynamic>);
      } catch (_) {}
    }
    s._ticker = Timer.periodic(const Duration(seconds: 6), (_) => s._tick());
    return s;
  }

  void _fromJson(Map<String, dynamic> j) {
    List<T> list<T>(String k, T Function(Map<String, dynamic>) f) =>
        ((j[k] as List?) ?? []).map((e) => f(e as Map<String, dynamic>)).toList();
    phone = (j['phone'] as String?) ?? '';
    name = (j['name'] as String?) ?? '';
    pan = (j['pan'] as String?) ?? '';
    kyc = KycState.values[(j['kyc'] as int?) ?? 0];
    txnPin = j['txnPin'] as String?;
    signedIn = (j['signedIn'] as bool?) ?? false;
    wallet
      ..clear()
      ..addAll(((j['wallet'] as Map?) ?? {'INR': 0}).map((k, v) => MapEntry(k as String, (v as num).toDouble())));
    cardFrozen = (j['cardFrozen'] as bool?) ?? false;
    recipients.addAll(list('recipients', Recipient.fromJson));
    transfers.addAll(list('transfers', Transfer.fromJson));
    alerts.addAll(list('alerts', RateAlert.fromJson));
    recurring.addAll(list('recurring', Recurring.fromJson));
    perTransferLimit = ((j['perTransferLimit'] as num?) ?? 500000).toDouble();
    if (signedIn) _seedIncoming();
  }

  Map<String, dynamic> _toJson() => {
        'phone': phone,
        'name': name,
        'pan': pan,
        'kyc': kyc.index,
        'txnPin': txnPin,
        'signedIn': signedIn,
        'wallet': wallet,
        'cardFrozen': cardFrozen,
        'recipients': recipients.map((e) => e.toJson()).toList(),
        'transfers': transfers.map((e) => e.toJson()).toList(),
        'alerts': alerts.map((e) => e.toJson()).toList(),
        'recurring': recurring.map((e) => e.toJson()).toList(),
        'perTransferLimit': perTransferLimit,
      };

  void changed() {
    _prefs.setString(_key, jsonEncode(_toJson()));
    notifyListeners();
  }

  String newId() => '${DateTime.now().microsecondsSinceEpoch}${_rand.nextInt(999)}';

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }

  // ── Rates (simulated feed) ─────────────────────────────────────
  void _tick() {
    rates.forEach((code, r) {
      prevRates[code] = r;
      final base = currencyByCode(code).inrPerUnit;
      // small random walk that stays within ±1.5% of the starting point
      var next = r * (1 + (_rand.nextDouble() - 0.5) * 0.0016);
      next = next.clamp(base * 0.985, base * 1.015);
      rates[code] = next;
    });
    var fired = false;
    for (final a in alerts) {
      if (a.triggeredAt == null && (rates[a.currency] ?? 1e9) <= a.target) {
        a.triggeredAt = DateTime.now();
        freshAlerts.add(a);
        fired = true;
      }
    }
    if (fired) {
      changed();
    } else {
      notifyListeners();
    }
  }

  double rate(String code) => rates[code] ?? currencyByCode(code).inrPerUnit;
  double change(String code) => rate(code) - (prevRates[code] ?? rate(code));

  // ── Account & KYC ──────────────────────────────────────────────
  void signIn(String phone) {
    this.phone = phone;
    signedIn = true;
    if (wallet['INR'] == 0 && transfers.isEmpty) {
      wallet['INR'] = 250000; // demo balance
      wallet['USD'] = 120;
    }
    _seedIncoming();
    changed();
  }

  void submitKyc({required String name, required String pan}) {
    this.name = name;
    this.pan = pan.toUpperCase();
    kyc = KycState.inReview;
    changed();
    // Demo: approval arrives a few seconds later.
    Timer(const Duration(seconds: 5), () {
      kyc = KycState.verified;
      changed();
    });
  }

  void setTxnPin(String p) {
    txnPin = p;
    changed();
  }

  void signOut() {
    signedIn = false;
    changed();
  }

  // ── Limits & tax ───────────────────────────────────────────────
  /// Indian financial year (April–March) that a date falls in.
  static DateTime fyStart(DateTime d) => d.month >= 4 ? DateTime(d.year, 4, 1) : DateTime(d.year - 1, 4, 1);

  double get fySentInr => transfers
      .where((t) => !t.cancelled && !t.createdAt.isBefore(fyStart(DateTime.now())))
      .fold(0.0, (s, t) => s + t.sendInr);

  double get fySentUsd => fySentInr / rate('USD');
  static const lrsUsd = 250000.0; // Liberalised Remittance Scheme yearly limit
  static const tcsThreshold = 1000000.0; // ₹10 lakh per FY

  double get fyTcsPaid => transfers
      .where((t) => !t.cancelled && !t.createdAt.isBefore(fyStart(DateTime.now())))
      .fold(0.0, (s, t) => s + t.tcs);

  /// GST on currency conversion (CGST rules value-of-supply slabs, 18%).
  static double gstOn(double inr) {
    double value;
    if (inr <= 100000) {
      value = max(250, inr * 0.01);
    } else if (inr <= 1000000) {
      value = 1000 + (inr - 100000) * 0.005;
    } else {
      value = min(60000, 5500 + (inr - 1000000) * 0.001);
    }
    return (value * 0.18).roundToDouble();
  }

  static const feeFlat = 249.0;
  static const markup = 0.0035; // 0.35% on the mid-market rate

  Quote quote({required String currency, required double sendInr, required Purpose purpose}) {
    final mid = rate(currency);
    final ours = mid * (1 + markup);
    final above = max(0.0, fySentInr + sendInr - tcsThreshold) - max(0.0, fySentInr - tcsThreshold);
    final tcs = (above * purpose.tcsRate).roundToDouble();
    return Quote(
      currency: currency,
      sendInr: sendInr,
      midRate: mid,
      ourRate: ours,
      fee: feeFlat,
      gst: gstOn(sendInr),
      tcs: tcs,
    );
  }

  /// Converts a target amount in foreign currency into the ₹ amount to send.
  double inrFor(String currency, double fx) => fx * rate(currency) * (1 + markup);

  // ── Transfers ──────────────────────────────────────────────────
  Transfer send({required Recipient to, required Quote q, required Purpose purpose}) {
    final t = Transfer(
      id: newId(),
      recipientId: to.id,
      recipientName: to.name,
      currency: q.currency,
      sendInr: q.sendInr,
      receive: q.receive,
      rate: q.ourRate,
      fee: q.fee,
      gst: q.gst,
      tcs: q.tcs,
      purpose: purpose,
      createdAt: DateTime.now(),
      reference: 'PUL${DateTime.now().millisecondsSinceEpoch.toString().substring(5)}',
    );
    transfers.insert(0, t);
    changed();
    return t;
  }

  void cancel(Transfer t) {
    t.cancelled = true;
    changed();
  }

  Recipient? recipientById(String id) {
    for (final r in recipients) {
      if (r.id == id) return r;
    }
    return null;
  }

  void addRecipient(Recipient r) {
    recipients.add(r);
    changed();
  }

  void removeRecipient(Recipient r) {
    recipients.remove(r);
    recurring.removeWhere((x) => x.recipientId == r.id);
    changed();
  }

  // ── Alerts & recurring ─────────────────────────────────────────
  void addAlert(String currency, double target) {
    alerts.add(RateAlert(id: newId(), currency: currency, target: target));
    changed();
  }

  void removeAlert(RateAlert a) {
    alerts.remove(a);
    freshAlerts.remove(a);
    changed();
  }

  void clearFreshAlerts() {
    freshAlerts.clear();
    notifyListeners();
  }

  void addRecurring(Recurring r) {
    recurring.add(r);
    changed();
  }

  void removeRecurring(Recurring r) {
    recurring.remove(r);
    changed();
  }

  void markRecurringDone(String recipientId) {
    for (final r in recurring) {
      if (r.recipientId == recipientId && r.dueNow) r.lastDone = DateTime.now();
    }
  }

  // ── Wallet ─────────────────────────────────────────────────────
  double balance(String code) => wallet[code] ?? 0;

  /// Converts between wallet currencies at our rate. Returns an error message or null.
  String? convert(String from, String to, double amount) {
    if (amount <= 0) return 'Enter an amount above zero.';
    if (balance(from) < amount) return 'Not enough ${from == 'INR' ? '₹' : from} in your wallet.';
    final inr = from == 'INR' ? amount : amount * rate(from) * (1 - markup);
    final out = to == 'INR' ? inr : inr / (rate(to) * (1 + markup));
    wallet[from] = balance(from) - amount;
    wallet[to] = balance(to) + out;
    changed();
    return null;
  }

  void setCardFrozen(bool v) {
    cardFrozen = v;
    changed();
  }

  void _seedIncoming() {
    if (incoming.isNotEmpty) return;
    final now = DateTime.now();
    incoming.addAll([
      Incoming('Brightline Design LLC (sample)', 'USD', 1200, 1200 * 88.1, now.subtract(const Duration(days: 9)), 'Software & design services'),
      Incoming('Priya Shah (sample)', 'GBP', 300, 300 * 117.9, now.subtract(const Duration(days: 23)), 'Family support'),
    ]);
  }
}

class StoreScope extends InheritedNotifier<Store> {
  const StoreScope({super.key, required Store store, required super.child}) : super(notifier: store);
  static Store of(BuildContext c) => c.dependOnInheritedWidgetOfExactType<StoreScope>()!.notifier!;
  static Store read(BuildContext c) => c.getInheritedWidgetOfExactType<StoreScope>()!.notifier!;
}

extension StoreX on BuildContext {
  Store get store => StoreScope.of(this);
}
