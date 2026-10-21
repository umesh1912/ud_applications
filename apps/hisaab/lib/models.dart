import 'package:flutter/material.dart';

enum AccountType { bank, card, wallet, cash, loan }

extension AccountTypeX on AccountType {
  String get label => const ['Bank account', 'Credit card', 'Wallet', 'Cash', 'Loan'][index];
  IconData get icon => const [
        Icons.account_balance_outlined,
        Icons.credit_card_outlined,
        Icons.account_balance_wallet_outlined,
        Icons.payments_outlined,
        Icons.request_quote_outlined,
      ][index];
  /// Cards and loans hold money you owe.
  bool get isLiability => this == AccountType.card || this == AccountType.loan;
}

class Account {
  Account({required this.id, required this.name, required this.type, this.opening = 0, this.limit});

  final String id;
  String name;
  AccountType type;
  double opening; // for cards/loans: amount owed at start, stored negative
  double? limit; // credit limit for cards

  Map<String, dynamic> toJson() => {'id': id, 'name': name, 'type': type.index, 'opening': opening, 'limit': limit};
  factory Account.fromJson(Map<String, dynamic> j) => Account(
        id: j['id'] as String,
        name: j['name'] as String,
        type: AccountType.values[j['type'] as int],
        opening: (j['opening'] as num).toDouble(),
        limit: (j['limit'] as num?)?.toDouble(),
      );
}

enum TxnType { expense, income, transfer }

class Category {
  const Category(this.id, this.name, this.icon, this.color, {this.income = false, this.keywords = const []});
  final String id;
  final String name;
  final IconData icon;
  final Color color;
  final bool income;
  final List<String> keywords; // for automatic suggestions from the note
}

const categories = [
  Category('food', 'Food & dining', Icons.restaurant_outlined, Color(0xFFD9822B),
      keywords: ['swiggy', 'zomato', 'restaurant', 'cafe', 'coffee', 'tea', 'pizza', 'dinner', 'lunch', 'breakfast', 'chai']),
  Category('grocery', 'Groceries', Icons.local_grocery_store_outlined, Color(0xFF4E9A3A),
      keywords: ['grocery', 'bigbasket', 'blinkit', 'zepto', 'dmart', 'vegetable', 'milk', 'kirana', 'fruits']),
  Category('transport', 'Transport', Icons.directions_car_outlined, Color(0xFF3B7DD8),
      keywords: ['uber', 'ola', 'rapido', 'petrol', 'diesel', 'fuel', 'metro', 'bus', 'auto', 'parking', 'fastag', 'toll']),
  Category('shopping', 'Shopping', Icons.shopping_bag_outlined, Color(0xFFC0508A),
      keywords: ['amazon', 'flipkart', 'myntra', 'ajio', 'meesho', 'clothes', 'shoes']),
  Category('bills', 'Bills & utilities', Icons.receipt_long_outlined, Color(0xFF7A6BD1),
      keywords: ['electricity', 'water', 'gas', 'recharge', 'broadband', 'wifi', 'dth', 'mobile bill', 'postpaid']),
  Category('rent', 'Rent & home', Icons.home_outlined, Color(0xFF8C6B4A), keywords: ['rent', 'maintenance', 'society']),
  Category('health', 'Health', Icons.medical_services_outlined, Color(0xFFD0453A),
      keywords: ['pharmacy', 'medicine', 'doctor', 'hospital', 'apollo', 'clinic', 'lab test']),
  Category('education', 'Education', Icons.school_outlined, Color(0xFF2E8A8A), keywords: ['school', 'fees', 'tuition', 'course', 'books']),
  Category('fun', 'Entertainment', Icons.movie_outlined, Color(0xFFB0558F),
      keywords: ['netflix', 'hotstar', 'prime', 'spotify', 'movie', 'pvr', 'inox', 'concert']),
  Category('travel', 'Travel', Icons.flight_outlined, Color(0xFF2F8FC4), keywords: ['irctc', 'train', 'flight', 'hotel', 'makemytrip', 'trip']),
  Category('emi', 'EMIs & loans', Icons.account_balance_outlined, Color(0xFF6B6B6B), keywords: ['emi', 'loan']),
  Category('invest', 'Investments', Icons.trending_up, Color(0xFF0B7A55), keywords: ['sip', 'mutual fund', 'ppf', 'nps', 'stocks', 'fd']),
  Category('other', 'Other', Icons.more_horiz, Color(0xFF7B8A85)),
  Category('salary', 'Salary', Icons.work_outline, Color(0xFF1D7F4E), income: true, keywords: ['salary', 'payroll']),
  Category('business', 'Business', Icons.storefront_outlined, Color(0xFF1D7F4E), income: true, keywords: ['client', 'invoice', 'sale']),
  Category('interest', 'Interest & dividends', Icons.savings_outlined, Color(0xFF1D7F4E), income: true, keywords: ['interest', 'dividend']),
  Category('gift', 'Gifts received', Icons.redeem_outlined, Color(0xFF1D7F4E), income: true, keywords: ['gift', 'shagun']),
  Category('otherin', 'Other income', Icons.add_card_outlined, Color(0xFF1D7F4E), income: true, keywords: ['refund', 'cashback']),
];

Category categoryById(String id) => categories.firstWhere((c) => c.id == id, orElse: () => categories[12]);

/// Suggest a category from what the user typed in the note.
Category? suggestCategory(String note, {required bool income}) {
  final n = note.toLowerCase();
  if (n.trim().length < 3) return null;
  for (final c in categories.where((c) => c.income == income)) {
    if (c.keywords.any(n.contains)) return c;
  }
  return null;
}

class Txn {
  Txn({
    required this.id,
    required this.type,
    required this.amount,
    required this.category,
    required this.accountId,
    required this.date,
    this.toAccountId,
    this.note = '',
  });

  final String id;
  TxnType type;
  double amount; // always positive
  String category;
  String accountId;
  String? toAccountId;
  DateTime date;
  String note;

  Map<String, dynamic> toJson() => {
        'id': id,
        'type': type.index,
        'amount': amount,
        'category': category,
        'accountId': accountId,
        'toAccountId': toAccountId,
        'date': date.toIso8601String(),
        'note': note,
      };

  factory Txn.fromJson(Map<String, dynamic> j) => Txn(
        id: j['id'] as String,
        type: TxnType.values[j['type'] as int],
        amount: (j['amount'] as num).toDouble(),
        category: j['category'] as String,
        accountId: j['accountId'] as String,
        toAccountId: j['toAccountId'] as String?,
        date: DateTime.parse(j['date'] as String),
        note: (j['note'] as String?) ?? '',
      );
}

enum Repeat { monthly, quarterly, yearly, once }

extension RepeatX on Repeat {
  String get label => const ['Every month', 'Every 3 months', 'Every year', 'One time'][index];
  int get months => const [1, 3, 12, 0][index];
}

enum BillKind { bill, emi, subscription, insurance, card }

extension BillKindX on BillKind {
  String get label => const ['Bill', 'EMI', 'Subscription', 'Insurance premium', 'Credit card bill'][index];
  IconData get icon => const [
        Icons.receipt_long_outlined,
        Icons.account_balance_outlined,
        Icons.subscriptions_outlined,
        Icons.health_and_safety_outlined,
        Icons.credit_card_outlined,
      ][index];
}

class Bill {
  Bill({
    required this.id,
    required this.name,
    required this.amount,
    required this.due,
    this.kind = BillKind.bill,
    this.repeat = Repeat.monthly,
    List<DateTime>? paid,
  }) : paid = paid ?? [];

  final String id;
  String name;
  double amount;
  DateTime due;
  BillKind kind;
  Repeat repeat;
  final List<DateTime> paid;
  bool get done => repeat == Repeat.once && paid.isNotEmpty;

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'amount': amount,
        'due': due.toIso8601String(),
        'kind': kind.index,
        'repeat': repeat.index,
        'paid': paid.map((d) => d.toIso8601String()).toList(),
      };

  factory Bill.fromJson(Map<String, dynamic> j) => Bill(
        id: j['id'] as String,
        name: j['name'] as String,
        amount: (j['amount'] as num).toDouble(),
        due: DateTime.parse(j['due'] as String),
        kind: BillKind.values[(j['kind'] as int?) ?? 0],
        repeat: Repeat.values[(j['repeat'] as int?) ?? 0],
        paid: ((j['paid'] as List?) ?? []).map((e) => DateTime.parse(e as String)).toList(),
      );
}

class Goal {
  Goal({required this.id, required this.name, required this.target, required this.by, this.saved = 0, this.icon = 0});

  final String id;
  String name;
  double target;
  double saved;
  DateTime by;
  int icon;

  double get progress => target <= 0 ? 0 : (saved / target).clamp(0, 1).toDouble();

  /// How much to put aside each month from now to reach the target on time.
  double get monthlyNeeded {
    final now = DateTime.now();
    final months = (by.year - now.year) * 12 + by.month - now.month;
    final left = (target - saved).clamp(0, double.infinity);
    if (left == 0) return 0;
    return months <= 0 ? left.toDouble() : left / months;
  }

  Map<String, dynamic> toJson() => {'id': id, 'name': name, 'target': target, 'saved': saved, 'by': by.toIso8601String(), 'icon': icon};
  factory Goal.fromJson(Map<String, dynamic> j) => Goal(
        id: j['id'] as String,
        name: j['name'] as String,
        target: (j['target'] as num).toDouble(),
        saved: (j['saved'] as num).toDouble(),
        by: DateTime.parse(j['by'] as String),
        icon: (j['icon'] as int?) ?? 0,
      );
}

const goalIcons = [
  Icons.shield_outlined, // emergency fund
  Icons.home_outlined,
  Icons.directions_car_outlined,
  Icons.school_outlined,
  Icons.beach_access_outlined,
  Icons.favorite_border,
  Icons.elderly_outlined,
  Icons.devices_outlined,
];

enum HoldingKind { mutualFund, stock, fd, ppf, nps, gold, realEstate, other }

extension HoldingKindX on HoldingKind {
  String get label => const ['Mutual funds', 'Stocks', 'Fixed deposits', 'PPF', 'NPS', 'Gold', 'Real estate', 'Other'][index];
  Color get color => const [
        Color(0xFF0B7A55),
        Color(0xFF3B7DD8),
        Color(0xFF7A6BD1),
        Color(0xFF2E8A8A),
        Color(0xFF8C6B4A),
        Color(0xFFC9A227),
        Color(0xFFB8432C),
        Color(0xFF7B8A85),
      ][index];
}

class Holding {
  Holding({
    required this.id,
    required this.name,
    required this.kind,
    required this.invested,
    required this.current,
    this.taxSaver = false,
  });

  final String id;
  String name;
  HoldingKind kind;
  double invested;
  double current;
  bool taxSaver; // counts towards Section 80C (old regime)

  double get gain => current - invested;
  double get gainPct => invested == 0 ? 0 : gain / invested;

  Map<String, dynamic> toJson() =>
      {'id': id, 'name': name, 'kind': kind.index, 'invested': invested, 'current': current, 'taxSaver': taxSaver};
  factory Holding.fromJson(Map<String, dynamic> j) => Holding(
        id: j['id'] as String,
        name: j['name'] as String,
        kind: HoldingKind.values[j['kind'] as int],
        invested: (j['invested'] as num).toDouble(),
        current: (j['current'] as num).toDouble(),
        taxSaver: (j['taxSaver'] as bool?) ?? false,
      );
}

class ScoreEntry {
  ScoreEntry(this.date, this.score);
  final DateTime date;
  final int score;
  Map<String, dynamic> toJson() => {'date': date.toIso8601String(), 'score': score};
  factory ScoreEntry.fromJson(Map<String, dynamic> j) => ScoreEntry(DateTime.parse(j['date'] as String), j['score'] as int);
}
