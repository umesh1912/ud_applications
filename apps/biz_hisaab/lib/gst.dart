/// GST helpers: states, tax rates, money rounding and amount in words.
library;

/// Indian states and union territories with their GST state codes.
const gstStates = <String, String>{
  '01': 'Jammu and Kashmir',
  '02': 'Himachal Pradesh',
  '03': 'Punjab',
  '04': 'Chandigarh',
  '05': 'Uttarakhand',
  '06': 'Haryana',
  '07': 'Delhi',
  '08': 'Rajasthan',
  '09': 'Uttar Pradesh',
  '10': 'Bihar',
  '11': 'Sikkim',
  '12': 'Arunachal Pradesh',
  '13': 'Nagaland',
  '14': 'Manipur',
  '15': 'Mizoram',
  '16': 'Tripura',
  '17': 'Meghalaya',
  '18': 'Assam',
  '19': 'West Bengal',
  '20': 'Jharkhand',
  '21': 'Odisha',
  '22': 'Chhattisgarh',
  '23': 'Madhya Pradesh',
  '24': 'Gujarat',
  '26': 'Dadra and Nagar Haveli and Daman and Diu',
  '27': 'Maharashtra',
  '29': 'Karnataka',
  '30': 'Goa',
  '31': 'Lakshadweep',
  '32': 'Kerala',
  '33': 'Tamil Nadu',
  '34': 'Puducherry',
  '35': 'Andaman and Nicobar Islands',
  '36': 'Telangana',
  '37': 'Andhra Pradesh',
  '38': 'Ladakh',
};

const gstRates = <double>[0, 0.25, 3, 5, 12, 18, 28, 40];

const units = <String>['pcs', 'kg', 'g', 'ltr', 'ml', 'm', 'box', 'pack', 'dozen', 'bag', 'set', 'pair', 'hr', 'day', 'job'];

final _gstinRe = RegExp(r'^[0-9]{2}[A-Z]{5}[0-9]{4}[A-Z][1-9A-Z]Z[0-9A-Z]$');

bool isValidGstin(String s) => _gstinRe.hasMatch(s.trim().toUpperCase());

/// State code from a GSTIN, e.g. "24" for a Gujarat GSTIN.
String? stateFromGstin(String s) {
  final g = s.trim();
  if (g.length < 2) return null;
  final code = g.substring(0, 2);
  return gstStates.containsKey(code) ? code : null;
}

double round2(double v) => (v * 100).roundToDouble() / 100;

/// "1234.5" → "1,234.50" with Indian grouping.
String money(num value, {bool symbol = true, int decimals = 2}) {
  final negative = value < 0;
  final fixed = value.abs().toStringAsFixed(decimals);
  final parts = fixed.split('.');
  final whole = parts[0];
  String grouped;
  if (whole.length <= 3) {
    grouped = whole;
  } else {
    final last3 = whole.substring(whole.length - 3);
    var rest = whole.substring(0, whole.length - 3);
    final buf = <String>[];
    while (rest.length > 2) {
      buf.insert(0, rest.substring(rest.length - 2));
      rest = rest.substring(0, rest.length - 2);
    }
    if (rest.isNotEmpty) buf.insert(0, rest);
    grouped = '${buf.join(',')},$last3';
  }
  final dec = parts.length > 1 ? '.${parts[1]}' : '';
  return '${negative ? '-' : ''}${symbol ? '₹' : ''}$grouped$dec';
}

/// Quantity without trailing zeros: 2, 2.5, 0.125.
String qtyText(num q) {
  if (q == q.roundToDouble()) return q.toInt().toString();
  return q.toStringAsFixed(3).replaceFirst(RegExp(r'0+$'), '').replaceFirst(RegExp(r'\.$'), '');
}

String rateText(double r) => r == r.roundToDouble() ? '${r.toInt()}%' : '$r%';

const _ones = [
  '', 'One', 'Two', 'Three', 'Four', 'Five', 'Six', 'Seven', 'Eight', 'Nine', 'Ten',
  'Eleven', 'Twelve', 'Thirteen', 'Fourteen', 'Fifteen', 'Sixteen', 'Seventeen', 'Eighteen', 'Nineteen',
];
const _tens = ['', '', 'Twenty', 'Thirty', 'Forty', 'Fifty', 'Sixty', 'Seventy', 'Eighty', 'Ninety'];

String _two(int n) => n < 20 ? _ones[n] : '${_tens[n ~/ 10]}${n % 10 > 0 ? ' ${_ones[n % 10]}' : ''}';

String _three(int n) {
  final h = n ~/ 100, r = n % 100;
  return [if (h > 0) '${_ones[h]} Hundred', if (r > 0) _two(r)].join(' ');
}

String _indianWords(int n) {
  if (n == 0) return 'Zero';
  final parts = <String>[];
  final crore = n ~/ 10000000;
  n %= 10000000;
  final lakh = n ~/ 100000;
  n %= 100000;
  final thousand = n ~/ 1000;
  n %= 1000;
  if (crore > 0) parts.add('${_indianWords(crore)} Crore');
  if (lakh > 0) parts.add('${_two(lakh)} Lakh');
  if (thousand > 0) parts.add('${_two(thousand)} Thousand');
  if (n > 0) parts.add(_three(n));
  return parts.join(' ');
}

/// "Rupees One Lakh Twenty Thousand and Fifty Paise Only".
String amountInWords(double amount) {
  final v = round2(amount.abs());
  final rupees = v.floor();
  final paise = ((v - rupees) * 100).round();
  final b = StringBuffer('Rupees ${_indianWords(rupees)}');
  if (paise > 0) b.write(' and ${_two(paise)} Paise');
  b.write(' Only');
  return b.toString();
}

/// Indian financial year label for a date, e.g. "2026-27".
String financialYear(DateTime d) {
  final start = d.month >= 4 ? d.year : d.year - 1;
  return '$start-${two((start + 1) % 100)}';
}

DateTime fyStart(DateTime d) => DateTime(d.month >= 4 ? d.year : d.year - 1, 4, 1);

String two(int v) => v.toString().padLeft(2, '0');

String dmy(DateTime d) => '${two(d.day)}/${two(d.month)}/${d.year}';

DateTime dayOnly(DateTime d) => DateTime(d.year, d.month, d.day);

/// UPI payment link understood by every UPI app (GPay, PhonePe, Paytm, BHIM…).
String upiLink({required String vpa, required String payee, double? amount, String? note}) {
  final q = <String, String>{
    'pa': vpa.trim(),
    'pn': payee,
    if (amount != null && amount > 0) 'am': amount.toStringAsFixed(2),
    'cu': 'INR',
    if (note != null && note.isNotEmpty) 'tn': note,
  };
  return 'upi://pay?${q.entries.map((e) => '${e.key}=${Uri.encodeComponent(e.value)}').join('&')}';
}
