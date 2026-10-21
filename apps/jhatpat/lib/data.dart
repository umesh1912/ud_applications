import 'package:flutter/material.dart';

/// What the user is paying for.
enum Kind {
  mobile('Mobile recharge', Icons.smartphone, 'Mobile number', 10, plans: true),
  postpaid('Mobile postpaid', Icons.phone_android, 'Mobile number', 10),
  dth('DTH', Icons.satellite_alt_outlined, 'Subscriber ID', 10, plans: true),
  broadband('Broadband', Icons.wifi, 'Account number', 8),
  landline('Landline', Icons.phone_in_talk_outlined, 'Phone number with STD code', 10),
  electricity('Electricity', Icons.bolt, 'Consumer number', 9),
  water('Water', Icons.water_drop_outlined, 'Connection number', 8),
  gas('Piped gas', Icons.local_fire_department_outlined, 'BP / customer number', 8),
  lpg('LPG cylinder', Icons.propane_tank_outlined, 'Registered mobile or LPG ID', 10),
  fastag('FASTag', Icons.toll_outlined, 'Vehicle number', 8),
  creditCard('Credit card', Icons.credit_card, 'Last 4 digits and registered mobile', 4),
  loan('Loan EMI', Icons.account_balance_outlined, 'Loan account number', 8),
  insurance('Insurance', Icons.health_and_safety_outlined, 'Policy number', 8),
  municipal('Municipal tax', Icons.location_city_outlined, 'Property ID', 6),
  education('Education fees', Icons.school_outlined, 'Student ID', 5),
  subscription('Subscriptions', Icons.live_tv_outlined, 'Registered email or mobile', 6, plans: true);

  const Kind(this.label, this.icon, this.idLabel, this.minLen, {this.plans = false});
  final String label;
  final IconData icon;
  final String idLabel;
  final int minLen;
  final bool plans; // true = pick a plan; false = fetch the bill
}

const kindGroups = <(String, List<Kind>)>[
  ('Recharge', [Kind.mobile, Kind.dth, Kind.fastag, Kind.subscription]),
  ('Bills', [Kind.electricity, Kind.postpaid, Kind.broadband, Kind.water, Kind.gas, Kind.lpg, Kind.landline]),
  ('Finance & more', [Kind.creditCard, Kind.loan, Kind.insurance, Kind.municipal, Kind.education]),
];

/// Billers per category (operators, boards, banks…). Shown as plain names.
const billers = <Kind, List<String>>{
  Kind.mobile: ['Jio', 'Airtel', 'Vi', 'BSNL'],
  Kind.postpaid: ['Jio Postpaid', 'Airtel Postpaid', 'Vi Postpaid', 'BSNL Postpaid'],
  Kind.dth: ['Tata Play', 'Airtel Digital TV', 'Dish TV', 'd2h', 'Sun Direct'],
  Kind.broadband: ['Airtel Xstream Fiber', 'JioFiber', 'BSNL Bharat Fiber', 'ACT Fibernet', 'Hathway'],
  Kind.landline: ['BSNL Landline', 'Airtel Landline'],
  Kind.electricity: ['MSEDCL (Maharashtra)', 'BESCOM (Bengaluru)', 'TPDDL (Delhi)', 'Adani Electricity Mumbai', 'TNPDCL (Tamil Nadu)', 'UPPCL (Uttar Pradesh)', 'PGVCL (Gujarat)', 'WBSEDCL (West Bengal)'],
  Kind.water: ['Delhi Jal Board', 'BWSSB (Bengaluru)', 'MCGM Water (Mumbai)', 'Hyderabad Metro Water'],
  Kind.gas: ['Mahanagar Gas', 'Indraprastha Gas', 'Gujarat Gas', 'Adani Total Gas'],
  Kind.lpg: ['Indane', 'HP Gas', 'Bharat Gas'],
  Kind.fastag: ['ICICI Bank FASTag', 'HDFC Bank FASTag', 'Paytm Payments Bank FASTag', 'SBI FASTag', 'Axis Bank FASTag'],
  Kind.creditCard: ['HDFC Bank', 'SBI Card', 'ICICI Bank', 'Axis Bank', 'Kotak Mahindra Bank'],
  Kind.loan: ['Bajaj Finance', 'HDFC Bank', 'Tata Capital', 'ICICI Bank', 'Muthoot Finance'],
  Kind.insurance: ['LIC', 'HDFC Life', 'ICICI Prudential Life', 'Star Health', 'Niva Bupa'],
  Kind.municipal: ['Greater Chennai Corporation', 'BBMP (Bengaluru)', 'MCD (Delhi)', 'Pune Municipal Corporation'],
  Kind.education: ['Kendriya Vidyalaya', 'Delhi Public School', 'Amity University', 'Manipal Academy'],
  Kind.subscription: ['JioHotstar', 'Netflix', 'Amazon Prime', 'SonyLIV', 'Spotify'],
};

const circles = ['Maharashtra & Goa', 'Mumbai', 'Delhi NCR', 'Karnataka', 'Tamil Nadu', 'Gujarat', 'Uttar Pradesh (East)', 'West Bengal', 'Kerala', 'Andhra Pradesh & Telangana'];

/// Demo operator detection from the number. A real app would call an
/// operator-lookup API (or BBPS/aggregator) here.
(String, String) detectOperator(String number) {
  final d = number.replaceAll(RegExp(r'\D'), '');
  if (d.length < 4) return ('Jio', circles[0]);
  final n = int.parse(d.substring(0, 4));
  final ops = billers[Kind.mobile]!;
  return (ops[n % ops.length], circles[(n ~/ 7) % circles.length]);
}

class Plan {
  const Plan(this.id, this.tab, this.price, this.validity, this.data, this.calls, {this.extras = '', this.popular = false});
  final String id;
  final String tab; // Popular, Unlimited, Data, Talktime, Annual
  final int price;
  final String validity;
  final String data;
  final String calls;
  final String extras;
  final bool popular;

  int get validityDays => int.tryParse(validity.split(' ').first) ?? 0;
  double get perDay => validityDays == 0 ? price.toDouble() : price / validityDays;
}

/// Sample prepaid plans (prices are illustrative, not an operator's live list).
const mobilePlans = [
  Plan('m1', 'Unlimited', 299, '28 days', '1.5 GB/day', 'Unlimited calls', extras: '100 SMS/day', popular: true),
  Plan('m2', 'Unlimited', 349, '28 days', '2 GB/day', 'Unlimited calls', extras: '100 SMS/day · unlimited 5G'),
  Plan('m3', 'Unlimited', 579, '56 days', '1.5 GB/day', 'Unlimited calls', extras: '100 SMS/day', popular: true),
  Plan('m4', 'Unlimited', 859, '84 days', '2 GB/day', 'Unlimited calls', extras: '100 SMS/day · unlimited 5G', popular: true),
  Plan('m5', 'Annual', 3599, '365 days', '2.5 GB/day', 'Unlimited calls', extras: '100 SMS/day · unlimited 5G'),
  Plan('m6', 'Annual', 1899, '336 days', '24 GB total', 'Unlimited calls', extras: '3600 SMS'),
  Plan('m7', 'Data', 19, '1 day', '1 GB', 'No calls', extras: 'Add-on to an active plan'),
  Plan('m8', 'Data', 61, '30 days', '6 GB', 'No calls', extras: 'Add-on to an active plan'),
  Plan('m9', 'Data', 151, '30 days', '9 GB', 'No calls', extras: 'Includes OTT app pack'),
  Plan('m10', 'Talktime', 10, '0 days', '—', '₹7.47 talktime'),
  Plan('m11', 'Talktime', 100, '0 days', '—', '₹81.75 talktime'),
  Plan('m12', 'Unlimited', 199, '18 days', '1.5 GB/day', 'Unlimited calls', extras: '100 SMS/day'),
];

const dthPlans = [
  Plan('d1', 'Popular', 299, '30 days', 'Hindi basic pack', '200+ channels', popular: true),
  Plan('d2', 'Popular', 449, '30 days', 'Family HD pack', '250+ channels incl. 40 HD', popular: true),
  Plan('d3', 'Popular', 599, '30 days', 'Sports + family HD', '280+ channels'),
  Plan('d4', 'Annual', 4999, '365 days', 'Family HD pack', '250+ channels incl. 40 HD', extras: '1 month free'),
  Plan('d5', 'Popular', 219, '30 days', 'Regional value pack', '150+ channels'),
];

const subscriptionPlans = [
  Plan('s1', 'Popular', 149, '30 days', 'Mobile, 1 screen', 'HD'),
  Plan('s2', 'Popular', 299, '30 days', 'Super, 2 screens', 'Full HD', popular: true),
  Plan('s3', 'Annual', 1499, '365 days', 'Premium, 4 screens', '4K', extras: 'Save 25% vs monthly'),
];

const fastagPlans = [
  Plan('f1', 'Popular', 200, '0 days', 'Top-up', 'Toll balance'),
  Plan('f2', 'Popular', 500, '0 days', 'Top-up', 'Toll balance', popular: true),
  Plan('f3', 'Popular', 1000, '0 days', 'Top-up', 'Toll balance'),
  Plan('f4', 'Popular', 2000, '0 days', 'Top-up', 'Toll balance'),
];

List<Plan> plansFor(Kind k) => switch (k) {
      Kind.mobile => mobilePlans,
      Kind.dth => dthPlans,
      Kind.subscription => subscriptionPlans,
      Kind.fastag => fastagPlans,
      _ => const [],
    };

class Offer {
  const Offer(this.code, this.title, this.detail, {this.pct = 0, this.flat = 0, this.max = 0, this.minAmount = 0, this.kinds = const []});
  final String code;
  final String title;
  final String detail;
  final double pct; // cashback %
  final double flat; // flat cashback
  final double max;
  final double minAmount;
  final List<Kind> kinds; // empty = all

  double cashbackFor(Kind k, double amount) {
    if (kinds.isNotEmpty && !kinds.contains(k)) return 0;
    if (amount < minAmount) return 0;
    final v = flat > 0 ? flat : amount * pct / 100;
    return max > 0 && v > max ? max : v;
  }

  String? whyNot(Kind k, double amount) {
    if (kinds.isNotEmpty && !kinds.contains(k)) return 'This code works on ${kinds.map((e) => e.label.toLowerCase()).join(', ')} only.';
    if (amount < minAmount) return 'Add ₹${(minAmount - amount).ceil()} more to use this code (minimum ₹${minAmount.round()}).';
    return null;
  }
}

const offers = [
  Offer('FIRST50', '₹50 back on your first payment', 'Any bill or recharge of ₹199 or more', flat: 50, minAmount: 199),
  Offer('POWER5', '5% back on electricity bills', 'Up to ₹100 · minimum ₹500', pct: 5, max: 100, minAmount: 500, kinds: [Kind.electricity]),
  Offer('RECH20', '₹20 back on mobile recharges', 'Recharges of ₹249 or more', flat: 20, minAmount: 249, kinds: [Kind.mobile]),
  Offer('DTH10', '10% back on DTH', 'Up to ₹60 · minimum ₹299', pct: 10, max: 60, minAmount: 299, kinds: [Kind.dth]),
];

Offer? offerByCode(String code) {
  final c = code.trim().toUpperCase();
  for (final o in offers) {
    if (o.code == c) return o;
  }
  return null;
}

enum PayMethodType { upi, card, netbanking, wallet }

class PayMethod {
  PayMethod(this.id, this.type, this.label, this.detail);
  final String id;
  final PayMethodType type;
  final String label;
  final String detail;

  IconData get icon => switch (type) {
        PayMethodType.upi => Icons.qr_code_2,
        PayMethodType.card => Icons.credit_card,
        PayMethodType.netbanking => Icons.account_balance,
        PayMethodType.wallet => Icons.account_balance_wallet_outlined,
      };

  Map<String, dynamic> toJson() => {'id': id, 'type': type.index, 'label': label, 'detail': detail};
  factory PayMethod.fromJson(Map<String, dynamic> j) =>
      PayMethod(j['id'] as String, PayMethodType.values[j['type'] as int], j['label'] as String, j['detail'] as String);
}

/// Someone's phone, a meter, a card… saved for one-tap payment.
class SavedBiller {
  SavedBiller({
    required this.id,
    required this.kind,
    required this.biller,
    required this.accountId,
    required this.nickname,
    this.circle,
    this.autopay = false,
    this.autopayMax = 0,
    this.remind = true,
    this.nextDue,
    this.lastAmount,
  });

  final String id;
  final Kind kind;
  String biller;
  final String accountId;
  String nickname;
  String? circle;
  bool autopay;
  double autopayMax;
  bool remind;
  DateTime? nextDue; // bill due date or plan expiry
  double? lastAmount;

  Map<String, dynamic> toJson() => {
        'id': id,
        'kind': kind.index,
        'biller': biller,
        'accountId': accountId,
        'nickname': nickname,
        'circle': circle,
        'autopay': autopay,
        'autopayMax': autopayMax,
        'remind': remind,
        'nextDue': nextDue?.toIso8601String(),
        'lastAmount': lastAmount,
      };

  factory SavedBiller.fromJson(Map<String, dynamic> j) => SavedBiller(
        id: j['id'] as String,
        kind: Kind.values[j['kind'] as int],
        biller: j['biller'] as String,
        accountId: j['accountId'] as String,
        nickname: j['nickname'] as String,
        circle: j['circle'] as String?,
        autopay: (j['autopay'] as bool?) ?? false,
        autopayMax: ((j['autopayMax'] as num?) ?? 0).toDouble(),
        remind: (j['remind'] as bool?) ?? true,
        nextDue: j['nextDue'] == null ? null : DateTime.parse(j['nextDue'] as String),
        lastAmount: (j['lastAmount'] as num?)?.toDouble(),
      );
}

enum PayStatus { success, failed, refunded }

class Payment {
  Payment({
    required this.id,
    required this.kind,
    required this.biller,
    required this.accountId,
    required this.amount,
    required this.cashback,
    required this.method,
    required this.date,
    required this.status,
    required this.reference,
    this.planText,
    this.nickname,
    this.complaintId,
  });

  final String id;
  final Kind kind;
  final String biller;
  final String accountId;
  final double amount;
  final double cashback;
  final String method;
  final DateTime date;
  PayStatus status;
  final String reference;
  final String? planText;
  final String? nickname;
  String? complaintId;

  Map<String, dynamic> toJson() => {
        'id': id,
        'kind': kind.index,
        'biller': biller,
        'accountId': accountId,
        'amount': amount,
        'cashback': cashback,
        'method': method,
        'date': date.toIso8601String(),
        'status': status.index,
        'reference': reference,
        'planText': planText,
        'nickname': nickname,
        'complaintId': complaintId,
      };

  factory Payment.fromJson(Map<String, dynamic> j) => Payment(
        id: j['id'] as String,
        kind: Kind.values[j['kind'] as int],
        biller: j['biller'] as String,
        accountId: j['accountId'] as String,
        amount: (j['amount'] as num).toDouble(),
        cashback: ((j['cashback'] as num?) ?? 0).toDouble(),
        method: j['method'] as String,
        date: DateTime.parse(j['date'] as String),
        status: PayStatus.values[j['status'] as int],
        reference: j['reference'] as String,
        planText: j['planText'] as String?,
        nickname: j['nickname'] as String?,
        complaintId: j['complaintId'] as String?,
      );
}

class ScratchCard {
  ScratchCard({required this.id, required this.amount, required this.from, this.scratched = false});
  final String id;
  final int amount;
  final String from;
  bool scratched;

  Map<String, dynamic> toJson() => {'id': id, 'amount': amount, 'from': from, 'scratched': scratched};
  factory ScratchCard.fromJson(Map<String, dynamic> j) =>
      ScratchCard(id: j['id'] as String, amount: j['amount'] as int, from: j['from'] as String, scratched: (j['scratched'] as bool?) ?? false);
}

/// A fetched bill (simulated BBPS response).
class FetchedBill {
  FetchedBill(this.customer, this.amount, this.due, this.billDate, this.period);
  final String customer;
  final double amount;
  final DateTime due;
  final DateTime billDate;
  final String period;
}
