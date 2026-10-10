import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// App-wide user preferences (language, theme) persisted on device.
class UdSettings extends ChangeNotifier {
  UdSettings._(this.prefs);

  final SharedPreferences prefs;

  static Future<UdSettings> load() async =>
      UdSettings._(await SharedPreferences.getInstance());

  static const _kLang = 'ud.lang';
  static const _kTheme = 'ud.theme';

  bool get hasChosenLanguage => prefs.containsKey(_kLang);

  String get lang => prefs.getString(_kLang) ?? 'en';

  ThemeMode get themeMode {
    final i = prefs.getInt(_kTheme) ?? 0;
    return ThemeMode.values[i.clamp(0, ThemeMode.values.length - 1)];
  }

  Future<void> setLang(String code) async {
    await prefs.setString(_kLang, code);
    notifyListeners();
  }

  Future<void> setThemeMode(ThemeMode mode) async {
    await prefs.setInt(_kTheme, mode.index);
    notifyListeners();
  }
}

/// Makes [UdSettings] available to the widget tree.
class UdScope extends InheritedNotifier<UdSettings> {
  const UdScope({super.key, required UdSettings settings, required super.child})
      : super(notifier: settings);

  static UdSettings of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<UdScope>()!.notifier!;
}
