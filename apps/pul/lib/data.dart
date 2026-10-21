import 'package:flutter/material.dart';

class Currency {
  const Currency(this.code, this.name, this.flag, this.country, this.inrPerUnit, {this.decimals = 2});
  final String code;
  final String name;
  final String flag;
  final String country;
  final double inrPerUnit; // demo mid-market starting point
  final int decimals;
}

/// Demo starting rates (₹ per unit). The app moves them a little over time.
const currencies = [
  Currency('USD', 'US dollar', '🇺🇸', 'United States', 88.60),
  Currency('GBP', 'British pound', '🇬🇧', 'United Kingdom', 118.40),
  Currency('EUR', 'Euro', '🇪🇺', 'Eurozone', 103.10),
  Currency('AED', 'UAE dirham', '🇦🇪', 'United Arab Emirates', 24.12),
  Currency('CAD', 'Canadian dollar', '🇨🇦', 'Canada', 63.40),
  Currency('AUD', 'Australian dollar', '🇦🇺', 'Australia', 58.20),
  Currency('SGD', 'Singapore dollar', '🇸🇬', 'Singapore', 68.50),
  Currency('NZD', 'New Zealand dollar', '🇳🇿', 'New Zealand', 52.80),
  Currency('SAR', 'Saudi riyal', '🇸🇦', 'Saudi Arabia', 23.62),
  Currency('CHF', 'Swiss franc', '🇨🇭', 'Switzerland', 110.90),
  Currency('JPY', 'Japanese yen', '🇯🇵', 'Japan', 0.590, decimals: 0),
  Currency('HKD', 'Hong Kong dollar', '🇭🇰', 'Hong Kong', 11.39),
];

Currency currencyByCode(String c) => currencies.firstWhere((x) => x.code == c, orElse: () => currencies.first);

enum Purpose { family, education, educationLoan, medical, gift, travel, investment, other }

extension PurposeX on Purpose {
  String get label => const [
        'Family support',
        'Education (my own money)',
        'Education (from an education loan)',
        'Medical treatment',
        'Gift',
        'Travel',
        'Investment abroad',
        'Other',
      ][index];
  IconData get icon => const [
        Icons.family_restroom,
        Icons.school_outlined,
        Icons.account_balance_outlined,
        Icons.local_hospital_outlined,
        Icons.redeem_outlined,
        Icons.luggage_outlined,
        Icons.trending_up,
        Icons.more_horiz,
      ][index];

  /// TCS rate on the part of this FY's remittances above ₹10 lakh.
  double get tcsRate => switch (this) {
        Purpose.educationLoan => 0.0,
        Purpose.education => 0.05,
        Purpose.medical => 0.05,
        _ => 0.20,
      };
}

class Recipient {
  Recipient({
    required this.id,
    required this.name,
    required this.currency,
    required this.bank,
    required this.account,
    required this.swift,
    this.relation = 'Family',
    this.email = '',
  });

  final String id;
  String name;
  String currency;
  String bank;
  String account; // account number or IBAN
  String swift;
  String relation;
  String email;

  String get masked => account.length <= 4 ? account : '••${account.substring(account.length - 4)}';

  Map<String, dynamic> toJson() =>
      {'id': id, 'name': name, 'currency': currency, 'bank': bank, 'account': account, 'swift': swift, 'relation': relation, 'email': email};
  factory Recipient.fromJson(Map<String, dynamic> j) => Recipient(
        id: j['id'] as String,
        name: j['name'] as String,
        currency: j['currency'] as String,
        bank: j['bank'] as String,
        account: j['account'] as String,
        swift: j['swift'] as String,
        relation: (j['relation'] as String?) ?? 'Family',
        email: (j['email'] as String?) ?? '',
      );
}

/// A fully priced transfer. All ₹ amounts are what the sender pays.
class Quote {
  Quote({
    required this.currency,
    required this.sendInr,
    required this.midRate,
    required this.ourRate,
    required this.fee,
    required this.gst,
    required this.tcs,
  });

  final String currency;
  final double sendInr; // converted amount
  final double midRate; // ₹ per unit, mid-market
  final double ourRate; // ₹ per unit, after our markup
  final double fee;
  final double gst;
  final double tcs;

  double get receive => sendInr / ourRate;
  double get totalInr => sendInr + fee + gst + tcs;
  double get markupCost => sendInr - sendInr / ourRate * midRate;
}

const transferSteps = ['Transfer created', 'Payment received from you', 'Money converted', 'Sent to their bank (SWIFT)', 'Delivered'];

/// Demo timings so the tracker visibly moves. Real transfers take 1–2 working days.
const stepSeconds = [0, 8, 25, 60, 150];

class Transfer {
  Transfer({
    required this.id,
    required this.recipientId,
    required this.recipientName,
    required this.currency,
    required this.sendInr,
    required this.receive,
    required this.rate,
    required this.fee,
    required this.gst,
    required this.tcs,
    required this.purpose,
    required this.createdAt,
    required this.reference,
    this.cancelled = false,
  });

  final String id;
  final String recipientId;
  final String recipientName;
  final String currency;
  final double sendInr;
  final double receive;
  final double rate;
  final double fee;
  final double gst;
  final double tcs;
  final Purpose purpose;
  final DateTime createdAt;
  final String reference;
  bool cancelled;

  double get total => sendInr + fee + gst + tcs;

  int get step {
    if (cancelled) return 0;
    final s = DateTime.now().difference(createdAt).inSeconds;
    var i = 0;
    for (var k = 0; k < stepSeconds.length; k++) {
      if (s >= stepSeconds[k]) i = k;
    }
    return i;
  }

  bool get delivered => !cancelled && step == transferSteps.length - 1;
  bool get canCancel => !cancelled && step < 2;

  DateTime stepTime(int k) => createdAt.add(Duration(seconds: stepSeconds[k]));

  Map<String, dynamic> toJson() => {
        'id': id,
        'recipientId': recipientId,
        'recipientName': recipientName,
        'currency': currency,
        'sendInr': sendInr,
        'receive': receive,
        'rate': rate,
        'fee': fee,
        'gst': gst,
        'tcs': tcs,
        'purpose': purpose.index,
        'createdAt': createdAt.toIso8601String(),
        'reference': reference,
        'cancelled': cancelled,
      };

  factory Transfer.fromJson(Map<String, dynamic> j) => Transfer(
        id: j['id'] as String,
        recipientId: j['recipientId'] as String,
        recipientName: j['recipientName'] as String,
        currency: j['currency'] as String,
        sendInr: (j['sendInr'] as num).toDouble(),
        receive: (j['receive'] as num).toDouble(),
        rate: (j['rate'] as num).toDouble(),
        fee: (j['fee'] as num).toDouble(),
        gst: (j['gst'] as num).toDouble(),
        tcs: (j['tcs'] as num).toDouble(),
        purpose: Purpose.values[j['purpose'] as int],
        createdAt: DateTime.parse(j['createdAt'] as String),
        reference: j['reference'] as String,
        cancelled: (j['cancelled'] as bool?) ?? false,
      );
}

class RateAlert {
  RateAlert({required this.id, required this.currency, required this.target, this.triggeredAt});
  final String id;
  final String currency;
  final double target; // alert when 1 unit costs this many ₹ or less
  DateTime? triggeredAt;

  Map<String, dynamic> toJson() => {'id': id, 'currency': currency, 'target': target, 'triggeredAt': triggeredAt?.toIso8601String()};
  factory RateAlert.fromJson(Map<String, dynamic> j) => RateAlert(
        id: j['id'] as String,
        currency: j['currency'] as String,
        target: (j['target'] as num).toDouble(),
        triggeredAt: j['triggeredAt'] == null ? null : DateTime.parse(j['triggeredAt'] as String),
      );
}

class Recurring {
  Recurring({required this.id, required this.recipientId, required this.sendInr, required this.day, required this.purpose, this.lastDone});
  final String id;
  final String recipientId;
  double sendInr;
  int day; // day of month
  Purpose purpose;
  DateTime? lastDone;

  DateTime get nextDue {
    final now = DateTime.now();
    var d = DateTime(now.year, now.month, day);
    if (lastDone != null && lastDone!.year == d.year && lastDone!.month == d.month) {
      d = DateTime(now.year, now.month + 1, day);
    }
    return d;
  }

  bool get dueNow {
    final now = DateTime.now();
    return !nextDue.isAfter(DateTime(now.year, now.month, now.day));
  }

  Map<String, dynamic> toJson() =>
      {'id': id, 'recipientId': recipientId, 'sendInr': sendInr, 'day': day, 'purpose': purpose.index, 'lastDone': lastDone?.toIso8601String()};
  factory Recurring.fromJson(Map<String, dynamic> j) => Recurring(
        id: j['id'] as String,
        recipientId: j['recipientId'] as String,
        sendInr: (j['sendInr'] as num).toDouble(),
        day: j['day'] as int,
        purpose: Purpose.values[j['purpose'] as int],
        lastDone: j['lastDone'] == null ? null : DateTime.parse(j['lastDone'] as String),
      );
}

class Incoming {
  Incoming(this.from, this.currency, this.amount, this.inr, this.date, this.purpose);
  final String from;
  final String currency;
  final double amount;
  final double inr;
  final DateTime date;
  final String purpose;
}

enum KycState { notStarted, inReview, verified }
