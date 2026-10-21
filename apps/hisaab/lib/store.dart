import 'dart:convert';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'format.dart';
import 'models.dart';

class Insight {
  Insight(this.icon, this.text, {this.warn = false});
  final IconData icon;
  final String text;
  final bool warn;
}

class TaxEstimate {
  TaxEstimate(this.taxable, this.tax);
  final double taxable;
  final double tax;
}

class Store extends ChangeNotifier {
  Store._(this._prefs);

  static const _key = 'hisaab_v1';
  final SharedPreferences _prefs;

  // Profile & security
  String name = '';
  String? pin;
  bool hideBalances = false;
  bool unlocked = false;
  DateTime? _pausedAt;

  // Money
  final List<Account> accounts = [];
  final List<Txn> txns = [];
  final Map<String, double> budgets = {};
  final List<Bill> bills = [];
  final List<Goal> goals = [];
  final List<Holding> holdings = [];
  final List<ScoreEntry> scores = [];
  double annualIncome = 0;
  double other80C = 0; // EPF, life insurance, tuition fees, home-loan principal…
  double deduction80D = 0; // health insurance (old regime)

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

  bool get isSetUp => pin != null;

  void _fromJson(Map<String, dynamic> j) {
    List<T> list<T>(String k, T Function(Map<String, dynamic>) f) =>
        ((j[k] as List?) ?? []).map((e) => f(e as Map<String, dynamic>)).toList();
    name = (j['name'] as String?) ?? '';
    pin = j['pin'] as String?;
    hideBalances = (j['hideBalances'] as bool?) ?? false;
    accounts.addAll(list('accounts', Account.fromJson));
    txns.addAll(list('txns', Txn.fromJson));
    budgets.addAll(((j['budgets'] as Map?) ?? {}).map((k, v) => MapEntry(k as String, (v as num).toDouble())));
    bills.addAll(list('bills', Bill.fromJson));
    goals.addAll(list('goals', Goal.fromJson));
    holdings.addAll(list('holdings', Holding.fromJson));
    scores.addAll(list('scores', ScoreEntry.fromJson));
    annualIncome = ((j['annualIncome'] as num?) ?? 0).toDouble();
    other80C = ((j['other80C'] as num?) ?? 0).toDouble();
    deduction80D = ((j['deduction80D'] as num?) ?? 0).toDouble();
  }

  Map<String, dynamic> _toJson() => {
        'name': name,
        'pin': pin,
        'hideBalances': hideBalances,
        'accounts': accounts.map((e) => e.toJson()).toList(),
        'txns': txns.map((e) => e.toJson()).toList(),
        'budgets': budgets,
        'bills': bills.map((e) => e.toJson()).toList(),
        'goals': goals.map((e) => e.toJson()).toList(),
        'holdings': holdings.map((e) => e.toJson()).toList(),
        'scores': scores.map((e) => e.toJson()).toList(),
        'annualIncome': annualIncome,
        'other80C': other80C,
        'deduction80D': deduction80D,
      };

  void changed() {
    _prefs.setString(_key, jsonEncode(_toJson()));
    notifyListeners();
  }

  String newId() => '${DateTime.now().microsecondsSinceEpoch}${Random().nextInt(999)}';

  // ── Security ───────────────────────────────────────────────────
  void setUp({required String name, required String pin, required bool sample}) {
    this.name = name;
    this.pin = pin;
    unlocked = true;
    if (sample) _seedSample();
    if (accounts.isEmpty) {
      accounts.add(Account(id: newId(), name: 'Cash', type: AccountType.cash));
    }
    changed();
  }

  bool tryUnlock(String entered) {
    if (entered == pin) {
      unlocked = true;
      notifyListeners();
      return true;
    }
    return false;
  }

  void onPaused() => _pausedAt = DateTime.now();

  /// Lock again if the app was in the background for over a minute.
  void onResumed() {
    if (_pausedAt != null && DateTime.now().difference(_pausedAt!) > const Duration(minutes: 1) && pin != null) {
      unlocked = false;
      notifyListeners();
    }
    _pausedAt = null;
  }

  void lockNow() {
    unlocked = false;
    notifyListeners();
  }

  String money(num v, {bool sign = false}) => hideBalances ? '₹ ••••' : inr(v, sign: sign);
  String moneyShort(num v) => hideBalances ? '₹ ••' : inrShort(v);

  // ── Accounts & balances ────────────────────────────────────────
  Account? accountById(String id) {
    for (final a in accounts) {
      if (a.id == id) return a;
    }
    return null;
  }

  double balanceOf(Account a) {
    var b = a.opening;
    for (final t in txns) {
      if (t.type == TxnType.expense && t.accountId == a.id) b -= t.amount;
      if (t.type == TxnType.income && t.accountId == a.id) b += t.amount;
      if (t.type == TxnType.transfer) {
        if (t.accountId == a.id) b -= t.amount;
        if (t.toAccountId == a.id) b += t.amount;
      }
    }
    return b;
  }

  double get cashTotal =>
      accounts.where((a) => !a.type.isLiability).fold(0.0, (s, a) => s + balanceOf(a));
  double get owedTotal =>
      accounts.where((a) => a.type.isLiability).fold(0.0, (s, a) => s + balanceOf(a)); // negative
  double get investedValue => holdings.fold(0.0, (s, h) => s + h.current);
  double get investedCost => holdings.fold(0.0, (s, h) => s + h.invested);
  double get netWorth => cashTotal + investedValue + owedTotal;

  // ── Transactions ───────────────────────────────────────────────
  List<Txn> get sortedTxns => [...txns]..sort((a, b) => b.date.compareTo(a.date));

  void addTxn(Txn t) {
    txns.add(t);
    changed();
  }

  void updateTxn() => changed();

  void deleteTxn(Txn t) {
    txns.remove(t);
    changed();
  }

  bool _sameMonth(DateTime a, DateTime b) => a.year == b.year && a.month == b.month;

  double spentIn(DateTime month, {String? category}) => txns
      .where((t) => t.type == TxnType.expense && _sameMonth(t.date, month) && (category == null || t.category == category))
      .fold(0.0, (s, t) => s + t.amount);

  double earnedIn(DateTime month) =>
      txns.where((t) => t.type == TxnType.income && _sameMonth(t.date, month)).fold(0.0, (s, t) => s + t.amount);

  Map<String, double> spendByCategory(DateTime month) {
    final m = <String, double>{};
    for (final t in txns) {
      if (t.type == TxnType.expense && _sameMonth(t.date, month)) m[t.category] = (m[t.category] ?? 0) + t.amount;
    }
    return m;
  }

  double avgMonthlySpend({int months = 3}) {
    final now = DateTime.now();
    var total = 0.0;
    var counted = 0;
    for (var i = 1; i <= months; i++) {
      final m = DateTime(now.year, now.month - i);
      final s = spentIn(m);
      if (s > 0) {
        total += s;
        counted++;
      }
    }
    if (counted == 0) return spentIn(now);
    return total / counted;
  }

  // ── Budgets ────────────────────────────────────────────────────
  void setBudget(String category, double? limit) {
    if (limit == null || limit <= 0) {
      budgets.remove(category);
    } else {
      budgets[category] = limit;
    }
    changed();
  }

  // ── Bills ──────────────────────────────────────────────────────
  List<Bill> get upcomingBills => bills.where((b) => !b.done).toList()..sort((a, b) => a.due.compareTo(b.due));

  void addBill(Bill b) {
    bills.add(b);
    changed();
  }

  void removeBill(Bill b) {
    bills.remove(b);
    changed();
  }

  /// Marks a bill paid, optionally records the expense, and moves the due date on.
  void payBill(Bill b, {String? fromAccountId}) {
    b.paid.add(DateTime.now());
    if (fromAccountId != null) {
      txns.add(Txn(
        id: newId(),
        type: TxnType.expense,
        amount: b.amount,
        category: switch (b.kind) {
          BillKind.emi => 'emi',
          BillKind.subscription => 'fun',
          BillKind.insurance => 'health',
          _ => 'bills',
        },
        accountId: fromAccountId,
        date: DateTime.now(),
        note: b.name,
      ));
    }
    if (b.repeat != Repeat.once) {
      b.due = DateTime(b.due.year, b.due.month + b.repeat.months, b.due.day);
    }
    changed();
  }

  // ── Goals & investments ────────────────────────────────────────
  void addGoal(Goal g) {
    goals.add(g);
    changed();
  }

  void contribute(Goal g, double amount) {
    g.saved = (g.saved + amount).clamp(0, double.infinity).toDouble();
    changed();
  }

  void removeGoal(Goal g) {
    goals.remove(g);
    changed();
  }

  void addHolding(Holding h) {
    holdings.add(h);
    changed();
  }

  void removeHolding(Holding h) {
    holdings.remove(h);
    changed();
  }

  Map<HoldingKind, double> get allocation {
    final m = <HoldingKind, double>{};
    for (final h in holdings) {
      m[h.kind] = (m[h.kind] ?? 0) + h.current;
    }
    return m;
  }

  // ── Tax (FY 2026-27, individual under 60, estimate) ───────────
  double get invested80C =>
      holdings.where((h) => h.taxSaver).fold(0.0, (s, h) => s + h.invested) + other80C;

  static double _slabTax(double income, List<(double, double)> slabs) {
    // slabs: (upper limit of band, rate). Last band uses double.infinity.
    var tax = 0.0;
    var lower = 0.0;
    for (final (upper, rate) in slabs) {
      if (income <= lower) break;
      tax += (min(income, upper) - lower) * rate;
      lower = upper;
    }
    return tax;
  }

  TaxEstimate newRegime(double income) {
    final taxable = max(0.0, income - 75000);
    var tax = _slabTax(taxable, const [
      (400000.0, 0.0),
      (800000.0, 0.05),
      (1200000.0, 0.10),
      (1600000.0, 0.15),
      (2000000.0, 0.20),
      (2400000.0, 0.25),
      (double.infinity, 0.30),
    ]);
    if (taxable <= 1200000) {
      tax = 0; // Section 87A rebate
    } else {
      tax = min(tax, taxable - 1200000); // marginal relief
    }
    return TaxEstimate(taxable, tax * 1.04);
  }

  TaxEstimate oldRegime(double income) {
    final deductions = 50000 + min(150000.0, invested80C) + min(75000.0, deduction80D);
    final taxable = max(0.0, income - deductions);
    var tax = _slabTax(taxable, const [
      (250000.0, 0.0),
      (500000.0, 0.05),
      (1000000.0, 0.20),
      (double.infinity, 0.30),
    ]);
    if (taxable <= 500000) tax = 0; // Section 87A rebate
    return TaxEstimate(taxable, tax * 1.04);
  }

  // ── Credit score ───────────────────────────────────────────────
  void addScore(int s) {
    scores.add(ScoreEntry(DateTime.now(), s));
    scores.sort((a, b) => a.date.compareTo(b.date));
    changed();
  }

  // ── Insights ───────────────────────────────────────────────────
  List<Insight> insights() {
    final out = <Insight>[];
    final now = DateTime.now();
    final last = DateTime(now.year, now.month - 1);
    final thisM = spendByCategory(now);
    final lastM = spendByCategory(last);

    // Biggest jump vs last month (only once we're a week into the month).
    if (now.day >= 7) {
      String? jumpCat;
      var jump = 0.0;
      thisM.forEach((c, v) {
        final prev = lastM[c] ?? 0;
        if (prev > 0 && v > prev * 1.2 && v - prev > jump) {
          jump = v - prev;
          jumpCat = c;
        }
      });
      if (jumpCat != null) {
        final prev = lastM[jumpCat]!;
        final pct = ((thisM[jumpCat]! - prev) / prev * 100).round();
        out.add(Insight(Icons.trending_up,
            'You\'ve spent $pct% more on ${categoryById(jumpCat!).name.toLowerCase()} than all of last month.',
            warn: true));
      }
    }

    // Budgets.
    budgets.forEach((c, limit) {
      final spent = thisM[c] ?? 0;
      if (spent >= limit) {
        out.add(Insight(Icons.error_outline, '${categoryById(c).name} is over budget by ${inr(spent - limit)}.', warn: true));
      } else if (spent >= limit * 0.8) {
        out.add(Insight(Icons.warning_amber_outlined,
            '${categoryById(c).name} has used ${(spent / limit * 100).round()}% of its budget.',
            warn: true));
      }
    });

    // Savings rate.
    final inc = earnedIn(last);
    final sp = spentIn(last);
    if (inc > 0) {
      final rate = ((inc - sp) / inc * 100).round();
      out.add(Insight(
        Icons.savings_outlined,
        rate >= 0
            ? 'In ${monthName(last)} you saved $rate% of your income.'
            : 'In ${monthName(last)} you spent ${-rate}% more than you earned.',
        warn: rate < 10,
      ));
    }

    // Emergency fund.
    final avg = avgMonthlySpend();
    if (avg > 0) {
      final months = cashTotal / avg;
      out.add(Insight(
        Icons.shield_outlined,
        months >= 6
            ? 'Your cash covers ${months.toStringAsFixed(1)} months of spending. That\'s a healthy emergency fund.'
            : 'Your cash covers ${months.toStringAsFixed(1)} months of spending. Aim for 6 months as an emergency fund.',
        warn: months < 3,
      ));
    }

    // Overdue bills.
    final overdue = bills.where((b) => !b.done && daysBetween(now, b.due) < 0).length;
    if (overdue > 0) {
      out.add(Insight(Icons.event_busy_outlined, '$overdue bill${overdue == 1 ? ' is' : 's are'} overdue. Pay soon to avoid late fees.', warn: true));
    }
    return out;
  }

  // ── Export ─────────────────────────────────────────────────────
  String exportCsv({DateTime? from, DateTime? to}) {
    final b = StringBuffer('Date,Type,Amount,Category,Account,To account,Note\n');
    String esc(String s) => '"${s.replaceAll('"', '""')}"';
    for (final t in sortedTxns.reversed) {
      if (from != null && t.date.isBefore(from)) continue;
      if (to != null && t.date.isAfter(to)) continue;
      b.writeln([
        t.date.toIso8601String().substring(0, 10),
        t.type.name,
        t.amount.toStringAsFixed(2),
        esc(categoryById(t.category).name),
        esc(accountById(t.accountId)?.name ?? ''),
        esc(t.toAccountId == null ? '' : (accountById(t.toAccountId!)?.name ?? '')),
        esc(t.note),
      ].join(','));
    }
    return b.toString();
  }

  void resetAll() {
    accounts.clear();
    txns.clear();
    budgets.clear();
    bills.clear();
    goals.clear();
    holdings.clear();
    scores.clear();
    annualIncome = 0;
    other80C = 0;
    deduction80D = 0;
    name = '';
    pin = null;
    unlocked = false;
    hideBalances = false;
    changed();
  }

  // ── Sample data so a first look isn't empty ────────────────────
  void _seedSample() {
    final now = DateTime.now();
    final bank = Account(id: newId(), name: 'HDFC Savings (sample)', type: AccountType.bank, opening: 84000);
    final card = Account(id: newId(), name: 'Credit card (sample)', type: AccountType.card, opening: -6200, limit: 150000);
    final upi = Account(id: newId(), name: 'UPI wallet (sample)', type: AccountType.wallet, opening: 1500);
    final cash = Account(id: newId(), name: 'Cash', type: AccountType.cash, opening: 3000);
    accounts.addAll([bank, card, upi, cash]);

    final r = Random(7);
    void add(TxnType type, double amt, String cat, Account a, DateTime d, String note) =>
        txns.add(Txn(id: newId(), type: type, amount: amt, category: cat, accountId: a.id, date: d, note: note));

    for (var m = 2; m >= 0; m--) {
      final base = DateTime(now.year, now.month - m);
      final lastDay = m == 0 ? now.day : 28;
      add(TxnType.income, 72000, 'salary', bank, DateTime(base.year, base.month, 1, 10), 'Salary');
      if (lastDay >= 3) add(TxnType.expense, 18000, 'rent', bank, DateTime(base.year, base.month, 3, 9), 'House rent');
      if (lastDay >= 5) add(TxnType.expense, 5000, 'invest', bank, DateTime(base.year, base.month, 5, 9), 'SIP — index fund');
      final notes = [
        ('food', 'Swiggy dinner', 450.0, upi),
        ('grocery', 'DMart groceries', 2100.0, card),
        ('transport', 'Petrol', 1500.0, card),
        ('food', 'Chai and snacks', 120.0, cash),
        ('fun', 'Movie tickets PVR', 700.0, card),
        ('shopping', 'Amazon order', 1300.0, card),
        ('bills', 'Electricity bill', 1850.0, bank),
        ('transport', 'Uber to office', 320.0, upi),
        ('health', 'Pharmacy', 640.0, upi),
      ];
      for (var i = 0; i < notes.length; i++) {
        final day = 6 + i * 2 + r.nextInt(2);
        if (day > lastDay) continue;
        final (cat, note, amt, acc) = notes[i];
        final extra = m == 0 && cat == 'food' ? 1.6 : 1.0; // so an insight shows this month
        add(TxnType.expense, (amt * (0.8 + r.nextDouble() * 0.5) * extra).roundToDouble(), cat, acc,
            DateTime(base.year, base.month, day, 19), note);
      }
    }
    budgets.addAll({'food': 3500, 'grocery': 7000, 'shopping': 3000, 'transport': 4000});
    bills.addAll([
      Bill(id: newId(), name: 'Credit card bill', amount: 6200, due: DateTime(now.year, now.month, now.day + 4), kind: BillKind.card),
      Bill(id: newId(), name: 'Home broadband', amount: 799, due: DateTime(now.year, now.month, now.day + 9)),
      Bill(id: newId(), name: 'Car loan EMI', amount: 9400, due: DateTime(now.year, now.month, now.day + 12), kind: BillKind.emi),
      Bill(id: newId(), name: 'Health insurance', amount: 14200, due: DateTime(now.year, now.month + 2, 10), kind: BillKind.insurance, repeat: Repeat.yearly),
      Bill(id: newId(), name: 'Netflix', amount: 199, due: DateTime(now.year, now.month, now.day - 1), kind: BillKind.subscription),
    ]);
    goals.addAll([
      Goal(id: newId(), name: 'Emergency fund', target: 300000, saved: 110000, by: DateTime(now.year + 1, now.month), icon: 0),
      Goal(id: newId(), name: 'Goa trip', target: 45000, saved: 12000, by: DateTime(now.year, now.month + 5), icon: 4),
    ]);
    holdings.addAll([
      Holding(id: newId(), name: 'Nifty 50 index fund', kind: HoldingKind.mutualFund, invested: 180000, current: 214500),
      Holding(id: newId(), name: 'ELSS tax saver fund', kind: HoldingKind.mutualFund, invested: 60000, current: 66800, taxSaver: true),
      Holding(id: newId(), name: 'PPF account', kind: HoldingKind.ppf, invested: 90000, current: 101200, taxSaver: true),
      Holding(id: newId(), name: 'SBI fixed deposit', kind: HoldingKind.fd, invested: 100000, current: 106900),
      Holding(id: newId(), name: 'Gold coins', kind: HoldingKind.gold, invested: 40000, current: 52300),
    ]);
    scores.addAll([
      ScoreEntry(DateTime(now.year, now.month - 4, 2), 742),
      ScoreEntry(DateTime(now.year, now.month - 1, 2), 756),
    ]);
    annualIncome = 864000;
    other80C = 21600;
    deduction80D = 14200;
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
