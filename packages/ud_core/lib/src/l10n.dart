import 'package:flutter/widgets.dart';

import 'settings.dart';

class UdLanguage {
  const UdLanguage(this.code, this.nativeName, this.englishName);
  final String code;
  final String nativeName;
  final String englishName;
}

/// Languages every UD app ships with. Add a code here and a column in each
/// strings table to support another language.
const udLanguages = <UdLanguage>[
  UdLanguage('en', 'English', 'English'),
  UdLanguage('hi', 'हिन्दी', 'Hindi'),
  UdLanguage('gu', 'ગુજરાતી', 'Gujarati'),
];

typedef UdStringTable = Map<String, Map<String, String>>;

/// Merges several string tables (core + app) into one.
UdStringTable mergeStrings(List<UdStringTable> tables) {
  final out = <String, Map<String, String>>{};
  for (final t in tables) {
    t.forEach((lang, map) => (out[lang] ??= {}).addAll(map));
  }
  return out;
}

class UdL10n extends InheritedWidget {
  const UdL10n({
    super.key,
    required this.lang,
    required this.table,
    required super.child,
  });

  final String lang;
  final UdStringTable table;

  static UdL10n of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<UdL10n>()!;

  String t(String key, [Map<String, String>? args]) {
    var s = table[lang]?[key] ?? table['en']?[key] ?? key;
    args?.forEach((k, v) => s = s.replaceAll('{$k}', v));
    return s;
  }

  @override
  bool updateShouldNotify(UdL10n oldWidget) =>
      oldWidget.lang != lang || oldWidget.table != table;
}

extension UdContextX on BuildContext {
  /// Translate a key into the current language.
  String tr(String key, [Map<String, String>? args]) =>
      UdL10n.of(this).t(key, args);

  UdSettings get udSettings => UdScope.of(this);
}

/// Strings shared by every app.
const UdStringTable udCoreStrings = {
  'en': {
    'settings': 'Settings',
    'language': 'Language',
    'appearance': 'Appearance',
    'theme_system': 'Auto',
    'theme_light': 'Light',
    'theme_dark': 'Dark',
    'cancel': 'Cancel',
    'done': 'Done',
    'delete': 'Delete',
    'share': 'Share',
    'rename': 'Rename',
    'save': 'Save',
    'saved': 'Saved',
    'open': 'Open',
    'retry': 'Try again',
    'search': 'Search',
    'continue': 'Continue',
    'choose_language': 'Choose your language',
    'choose_language_sub': 'You can change this anytime in Settings.',
    'about': 'About',
    'version': 'Version',
    'privacy_note': 'Everything stays on your phone. Nothing is uploaded.',
    'made_in_india': 'Made with care in India',
    'confirm_delete': 'Delete this?',
    'confirm_delete_sub': 'This cannot be undone.',
    'error_generic': 'Something went wrong. Please try again.',
    'name': 'Name',
    'pages': '{n} pages',
    'one_page': '1 page',
    'just_now': 'Just now',
  },
  'hi': {
    'settings': 'सेटिंग्स',
    'language': 'भाषा',
    'appearance': 'दिखावट',
    'theme_system': 'ऑटो',
    'theme_light': 'लाइट',
    'theme_dark': 'डार्क',
    'cancel': 'रद्द करें',
    'done': 'हो गया',
    'delete': 'हटाएँ',
    'share': 'शेयर करें',
    'rename': 'नाम बदलें',
    'save': 'सेव करें',
    'saved': 'सेव हो गया',
    'open': 'खोलें',
    'retry': 'फिर से कोशिश करें',
    'search': 'खोजें',
    'continue': 'आगे बढ़ें',
    'choose_language': 'अपनी भाषा चुनें',
    'choose_language_sub': 'आप इसे कभी भी सेटिंग्स में बदल सकते हैं।',
    'about': 'जानकारी',
    'version': 'वर्ज़न',
    'privacy_note': 'सब कुछ आपके फ़ोन में ही रहता है। कुछ भी अपलोड नहीं होता।',
    'made_in_india': 'भारत में प्यार से बनाया गया',
    'confirm_delete': 'इसे हटाएँ?',
    'confirm_delete_sub': 'यह वापस नहीं लाया जा सकता।',
    'error_generic': 'कुछ गलत हो गया। कृपया फिर से कोशिश करें।',
    'name': 'नाम',
    'pages': '{n} पेज',
    'one_page': '1 पेज',
    'just_now': 'अभी-अभी',
  },
  'gu': {
    'settings': 'સેટિંગ્સ',
    'language': 'ભાષા',
    'appearance': 'દેખાવ',
    'theme_system': 'ઑટો',
    'theme_light': 'લાઇટ',
    'theme_dark': 'ડાર્ક',
    'cancel': 'રદ કરો',
    'done': 'થઈ ગયું',
    'delete': 'કાઢી નાખો',
    'share': 'શેર કરો',
    'rename': 'નામ બદલો',
    'save': 'સેવ કરો',
    'saved': 'સેવ થઈ ગયું',
    'open': 'ખોલો',
    'retry': 'ફરી પ્રયાસ કરો',
    'search': 'શોધો',
    'continue': 'આગળ વધો',
    'choose_language': 'તમારી ભાષા પસંદ કરો',
    'choose_language_sub': 'તમે આને ક્યારેય પણ સેટિંગ્સમાં બદલી શકો છો.',
    'about': 'માહિતી',
    'version': 'વર્ઝન',
    'privacy_note': 'બધું તમારા ફોનમાં જ રહે છે. કંઈ પણ અપલોડ થતું નથી.',
    'made_in_india': 'ભારતમાં પ્રેમથી બનાવેલ',
    'confirm_delete': 'આને કાઢી નાખવું છે?',
    'confirm_delete_sub': 'આ પાછું લાવી શકાશે નહીં.',
    'error_generic': 'કંઈક ખોટું થયું. કૃપા કરીને ફરી પ્રયાસ કરો.',
    'name': 'નામ',
    'pages': '{n} પેજ',
    'one_page': '1 પેજ',
    'just_now': 'હમણાં જ',
  },
};
