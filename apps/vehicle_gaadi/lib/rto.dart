/// Number-plate state codes (all of India) and Gujarat RTO offices.
const stateCodes = <String, String>{
  'AN': 'Andaman & Nicobar', 'AP': 'Andhra Pradesh', 'AR': 'Arunachal Pradesh',
  'AS': 'Assam', 'BR': 'Bihar', 'CG': 'Chhattisgarh', 'CH': 'Chandigarh',
  'DD': 'Dadra & Nagar Haveli and Daman & Diu', 'DL': 'Delhi', 'GA': 'Goa',
  'GJ': 'Gujarat', 'HP': 'Himachal Pradesh', 'HR': 'Haryana', 'JH': 'Jharkhand',
  'JK': 'Jammu & Kashmir', 'KA': 'Karnataka', 'KL': 'Kerala', 'LA': 'Ladakh',
  'LD': 'Lakshadweep', 'MH': 'Maharashtra', 'ML': 'Meghalaya', 'MN': 'Manipur',
  'MP': 'Madhya Pradesh', 'MZ': 'Mizoram', 'NL': 'Nagaland', 'OD': 'Odisha',
  'OR': 'Odisha', 'PB': 'Punjab', 'PY': 'Puducherry', 'RJ': 'Rajasthan',
  'SK': 'Sikkim', 'TN': 'Tamil Nadu', 'TR': 'Tripura', 'TS': 'Telangana',
  'UK': 'Uttarakhand', 'UA': 'Uttarakhand', 'UP': 'Uttar Pradesh', 'WB': 'West Bengal',
  'BH': 'Bharat series (all-India)',
};

const gujaratRto = <int, String>{
  1: 'Ahmedabad', 2: 'Mehsana', 3: 'Rajkot', 4: 'Bhavnagar', 5: 'Surat',
  6: 'Vadodara', 7: 'Nadiad (Kheda)', 8: 'Palanpur (Banaskantha)',
  9: 'Himmatnagar (Sabarkantha)', 10: 'Jamnagar', 11: 'Junagadh',
  12: 'Bhuj (Kutch)', 13: 'Surendranagar', 14: 'Amreli', 15: 'Valsad',
  16: 'Bharuch', 17: 'Godhra (Panchmahal)', 18: 'Gandhinagar', 19: 'Bardoli',
  20: 'Dahod', 21: 'Navsari', 22: 'Rajpipla (Narmada)', 23: 'Anand',
  24: 'Patan', 25: 'Porbandar', 26: 'Vyara (Tapi)', 27: 'Ahmedabad East',
  28: 'Surat (Pal)', 29: 'Vadodara (Darjipura)', 30: 'Ahwa (Dang)',
  31: 'Modasa (Aravalli)', 32: 'Veraval (Gir Somnath)', 33: 'Botad',
  34: 'Chhota Udaipur', 35: 'Lunawada (Mahisagar)', 36: 'Morbi',
  37: 'Khambhalia (Devbhumi Dwarka)', 38: 'Bavla (Ahmedabad Rural)',
};

class PlateInfo {
  PlateInfo(this.formatted, this.state, this.rto);
  final String formatted;
  final String? state;
  final String? rto;
}

/// Reads a plate like "gj05ab1234" → "GJ 05 AB 1234", Gujarat, Surat.
PlateInfo? decodePlate(String raw) {
  final s = raw.toUpperCase().replaceAll(RegExp(r'[^A-Z0-9]'), '');
  final m = RegExp(r'^([A-Z]{2})(\d{1,2})([A-Z]{0,3})(\d{1,4})$').firstMatch(s);
  if (m == null) {
    // Bharat series: 22 BH 1234 AA
    final bh = RegExp(r'^(\d{2})BH(\d{4})([A-Z]{1,2})$').firstMatch(s);
    if (bh != null) {
      return PlateInfo('${bh[1]} BH ${bh[2]} ${bh[3]}', stateCodes['BH'], null);
    }
    return null;
  }
  final code = m[1]!;
  final num = int.parse(m[2]!);
  final formatted = [code, m[2]!.padLeft(2, '0'), if (m[3]!.isNotEmpty) m[3]!, m[4]!].join(' ');
  return PlateInfo(formatted, stateCodes[code], code == 'GJ' ? gujaratRto[num] : null);
}
