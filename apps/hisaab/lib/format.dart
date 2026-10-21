/// Indian number formatting without extra packages.
String _group(String digits) {
  if (digits.length <= 3) return digits;
  final last3 = digits.substring(digits.length - 3);
  var rest = digits.substring(0, digits.length - 3);
  final parts = <String>[];
  while (rest.length > 2) {
    parts.insert(0, rest.substring(rest.length - 2));
    rest = rest.substring(0, rest.length - 2);
  }
  if (rest.isNotEmpty) parts.insert(0, rest);
  return '${parts.join(',')},$last3';
}

/// ₹1,23,456 (or ₹1,23,456.50 with [paise]).
String inr(num v, {bool paise = false, bool sign = false}) {
  final neg = v < 0;
  final n = v.abs();
  final whole = n.truncate();
  var s = '₹${_group(whole.toString())}';
  if (paise) {
    final p = ((n - whole) * 100).round().clamp(0, 99);
    s += '.${p.toString().padLeft(2, '0')}';
  }
  if (neg) return '−$s';
  if (sign && v > 0) return '+$s';
  return s;
}

/// ₹4.2K, ₹3.5L, ₹1.2Cr — for tight spaces.
String inrShort(num v) {
  final neg = v < 0;
  final n = v.abs();
  String body;
  if (n >= 1e7) {
    body = '${(n / 1e7).toStringAsFixed(n >= 1e8 ? 0 : 1)}Cr';
  } else if (n >= 1e5) {
    body = '${(n / 1e5).toStringAsFixed(n >= 1e6 ? 0 : 1)}L';
  } else if (n >= 1e3) {
    body = '${(n / 1e3).toStringAsFixed(n >= 1e4 ? 0 : 1)}K';
  } else {
    body = n.round().toString();
  }
  body = body.replaceAll('.0', '');
  return '${neg ? '−' : ''}₹$body';
}

const _months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
const _monthsLong = ['January', 'February', 'March', 'April', 'May', 'June', 'July', 'August', 'September', 'October', 'November', 'December'];

String dayMonth(DateTime d) => '${d.day} ${_months[d.month - 1]}';
String dayMonthYear(DateTime d) => '${d.day} ${_months[d.month - 1]} ${d.year}';
String monthName(DateTime d) => _monthsLong[d.month - 1];
String monthShort(DateTime d) => _months[d.month - 1];
String monthYear(DateTime d) => '${_monthsLong[d.month - 1]} ${d.year}';

DateTime dateOnly(DateTime d) => DateTime(d.year, d.month, d.day);

int daysBetween(DateTime from, DateTime to) => dateOnly(to).difference(dateOnly(from)).inDays;

String dueLabel(DateTime due) {
  final d = daysBetween(DateTime.now(), due);
  if (d < 0) return 'Overdue by ${-d} day${d == -1 ? '' : 's'}';
  if (d == 0) return 'Due today';
  if (d == 1) return 'Due tomorrow';
  return 'Due in $d days';
}

/// Parse "1,23,456.5" or "₹ 2500" into a number. Returns null if invalid.
double? parseAmount(String s) {
  final cleaned = s.replaceAll(RegExp(r'[₹,\s]'), '');
  if (cleaned.isEmpty) return null;
  return double.tryParse(cleaned);
}
