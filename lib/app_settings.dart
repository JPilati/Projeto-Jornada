import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

final appSettings = AppSettings();

enum AppFontSize {
  small('Pequena', 0.92),
  medium('M\u00e9dia', 1),
  large('Grande', 1.12);

  final String label;
  final double scale;

  const AppFontSize(this.label, this.scale);
}

class AppSettings extends ChangeNotifier {
  static const _darkModeKey = 'settings_dark_mode';
  static const _fontSizeKey = 'settings_font_size';
  static const _notificationsKey = 'settings_notifications';
  static const _notificationSoundKey = 'settings_notification_sound';
  static const _notificationDaysKey = 'settings_notification_days';

  bool darkMode = false;
  AppFontSize fontSize = AppFontSize.medium;
  bool notificationsEnabled = true;
  bool notificationSoundEnabled = true;
  int notificationDays = 30;

  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();

    darkMode = prefs.getBool(_darkModeKey) ?? false;
    fontSize = AppFontSize.values.firstWhere(
      (value) => value.name == prefs.getString(_fontSizeKey),
      orElse: () => AppFontSize.medium,
    );
    notificationsEnabled = prefs.getBool(_notificationsKey) ?? true;
    notificationSoundEnabled = prefs.getBool(_notificationSoundKey) ?? true;
    notificationDays = prefs.getInt(_notificationDaysKey) ?? 30;

    if (![7, 15, 30].contains(notificationDays)) {
      notificationDays = 30;
    }

    notifyListeners();
  }

  Future<void> setDarkMode(bool value) async {
    darkMode = value;
    notifyListeners();

    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_darkModeKey, value);
  }

  Future<void> setFontSize(AppFontSize value) async {
    fontSize = value;
    notifyListeners();

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_fontSizeKey, value.name);
  }

  Future<void> setNotificationsEnabled(bool value) async {
    notificationsEnabled = value;
    notifyListeners();

    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_notificationsKey, value);
  }

  Future<void> setNotificationSoundEnabled(bool value) async {
    notificationSoundEnabled = value;
    notifyListeners();

    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_notificationSoundKey, value);
  }

  Future<void> setNotificationDays(int value) async {
    if (![7, 15, 30].contains(value)) {
      return;
    }

    notificationDays = value;
    notifyListeners();

    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_notificationDaysKey, value);
  }
}
