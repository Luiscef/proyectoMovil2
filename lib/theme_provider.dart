import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ThemeProvider extends ChangeNotifier {
  static const String _darkModeKey = 'darkMode';
  static const String _notificationsKey = 'notifications';
  
  bool _darkMode = false;
  bool _notificationsEnabled = true;
  
  // Getters
  bool get darkMode => _darkMode;
  bool get isDarkMode => _darkMode;  // ← Este falta
  bool get notificationsEnabled => _notificationsEnabled;
  
  ThemeData get currentTheme => _darkMode ? _darkTheme : _lightTheme;
  
  // Tema claro
  static final ThemeData _lightTheme = ThemeData(
    useMaterial3: true,
    brightness: Brightness.light,
    colorSchemeSeed: Colors.teal,
  );
  
  // Tema oscuro
  static final ThemeData _darkTheme = ThemeData(
    useMaterial3: true,
    brightness: Brightness.dark,
    colorSchemeSeed: Colors.teal,
  );
  
  // ← Este método falta
  Future<void> loadPreferences() async {
    final prefs = await SharedPreferences.getInstance();
    _darkMode = prefs.getBool(_darkModeKey) ?? false;
    _notificationsEnabled = prefs.getBool(_notificationsKey) ?? true;
    notifyListeners();
  }
  
  // ← El parámetro debe ser opcional [bool? value]
  Future<void> toggleTheme([bool? value]) async {
    final newValue = value ?? !_darkMode;
    _darkMode = newValue;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_darkModeKey, newValue);
    notifyListeners();
  }
  
  Future<void> toggleNotifications(bool value) async {
    _notificationsEnabled = value;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_notificationsKey, value);
    notifyListeners();
  }
}