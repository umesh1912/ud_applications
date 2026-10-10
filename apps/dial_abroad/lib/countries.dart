class Country {
  const Country(this.name, this.code, this.flag, this.tz);
  final String name;
  final String code; // calling code without +
  final String flag;
  final String tz; // IANA time zone of the main city
}

/// Countries most often called from India, by calling code.
const countries = <Country>[
  Country('United Arab Emirates', '971', '🇦🇪', 'Asia/Dubai'),
  Country('United States', '1', '🇺🇸', 'America/New_York'),
  Country('United States (West)', '1', '🇺🇸', 'America/Los_Angeles'),
  Country('United Kingdom', '44', '🇬🇧', 'Europe/London'),
  Country('Canada', '1', '🇨🇦', 'America/Toronto'),
  Country('Australia', '61', '🇦🇺', 'Australia/Sydney'),
  Country('Saudi Arabia', '966', '🇸🇦', 'Asia/Riyadh'),
  Country('Qatar', '974', '🇶🇦', 'Asia/Qatar'),
  Country('Kuwait', '965', '🇰🇼', 'Asia/Kuwait'),
  Country('Oman', '968', '🇴🇲', 'Asia/Muscat'),
  Country('Bahrain', '973', '🇧🇭', 'Asia/Bahrain'),
  Country('Singapore', '65', '🇸🇬', 'Asia/Singapore'),
  Country('Malaysia', '60', '🇲🇾', 'Asia/Kuala_Lumpur'),
  Country('New Zealand', '64', '🇳🇿', 'Pacific/Auckland'),
  Country('Germany', '49', '🇩🇪', 'Europe/Berlin'),
  Country('France', '33', '🇫🇷', 'Europe/Paris'),
  Country('Italy', '39', '🇮🇹', 'Europe/Rome'),
  Country('Netherlands', '31', '🇳🇱', 'Europe/Amsterdam'),
  Country('Ireland', '353', '🇮🇪', 'Europe/Dublin'),
  Country('Switzerland', '41', '🇨🇭', 'Europe/Zurich'),
  Country('Sweden', '46', '🇸🇪', 'Europe/Stockholm'),
  Country('Spain', '34', '🇪🇸', 'Europe/Madrid'),
  Country('Russia (Moscow)', '7', '🇷🇺', 'Europe/Moscow'),
  Country('Japan', '81', '🇯🇵', 'Asia/Tokyo'),
  Country('China', '86', '🇨🇳', 'Asia/Shanghai'),
  Country('Hong Kong', '852', '🇭🇰', 'Asia/Hong_Kong'),
  Country('Thailand', '66', '🇹🇭', 'Asia/Bangkok'),
  Country('Indonesia', '62', '🇮🇩', 'Asia/Jakarta'),
  Country('Philippines', '63', '🇵🇭', 'Asia/Manila'),
  Country('Nepal', '977', '🇳🇵', 'Asia/Kathmandu'),
  Country('Bangladesh', '880', '🇧🇩', 'Asia/Dhaka'),
  Country('Sri Lanka', '94', '🇱🇰', 'Asia/Colombo'),
  Country('Maldives', '960', '🇲🇻', 'Indian/Maldives'),
  Country('Mauritius', '230', '🇲🇺', 'Indian/Mauritius'),
  Country('South Africa', '27', '🇿🇦', 'Africa/Johannesburg'),
  Country('Kenya', '254', '🇰🇪', 'Africa/Nairobi'),
  Country('Tanzania', '255', '🇹🇿', 'Africa/Dar_es_Salaam'),
  Country('Uganda', '256', '🇺🇬', 'Africa/Kampala'),
  Country('India', '91', '🇮🇳', 'Asia/Kolkata'),
];
