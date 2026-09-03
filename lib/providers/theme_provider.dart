import 'package:flutter/material.dart';

/// ⚠️ Dark mode removed per request — the app is light-only now. Kept as a
/// (much simpler) ChangeNotifier, rather than deleting the class outright,
/// since main.dart's MultiProvider and MaterialApp.themeMode still
/// reference it — this way neither of those needed touching, and if dark
/// mode ever comes back, this is the one place to restore it.
class ThemeProvider extends ChangeNotifier {
  bool get isDark => false;
  ThemeMode get themeMode => ThemeMode.light;
}
