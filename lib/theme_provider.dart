import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ThemeProvider extends ChangeNotifier {
  static const String _darkModeKey = 'darkMode';
  static const String _notificationsKey = 'notifications';
  
  bool _darkMode = false;
  bool _notificationsEnabled = true;
  
  // Mantener getter existente
  bool get darkMode => _darkMode;
  // Alias para compatibilidad con main.dart
  bool get isDarkMode => _darkMode;

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
  
  // Cargar preferencias guardadas
  Future<void> loadPreferences() async {
    final prefs = await SharedPreferences.getInstance();
    _darkMode = prefs.getBool(_darkModeKey) ?? false;
    _notificationsEnabled = prefs.getBool(_notificationsKey) ?? true;
    notifyListeners();
  }
  
  // toggleTheme ahora acepta un parámetro opcional.
  // Si value == null => invierte el tema actual (comportamiento para toggleTheme()).
  // Si se pasa true/false => establece el valor explícitamente (comportamiento para toggleTheme(true/false)).
  Future<void> toggleTheme([bool? value]) async {
    final newValue = value ?? !_darkMode; // si value es null invertimos
    _darkMode = newValue;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_darkModeKey, newValue);
    notifyListeners();
  }
  
  // Cambiar notificaciones
  Future<void> toggleNotifications(bool value) async {
    _notificationsEnabled = value;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_notificationsKey, value);
    notifyListeners();
  }
}
