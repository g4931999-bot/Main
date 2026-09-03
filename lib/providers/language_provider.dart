import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../l10n/app_strings.dart';

/// Holds the app's currently active language and notifies listeners when it
/// changes, so every screen using `context.tr('key')` rebuilds with the new
/// language immediately — no app restart needed.
///
/// Persists the choice locally (SharedPreferences) so the language survives
/// app restarts even before the backend value comes back from /auth/me.
class LanguageProvider extends ChangeNotifier {
  static const _prefsKey = 'app_language_code';

  String _languageCode = 'en';
  String get languageCode => _languageCode;
  String get languageName => AppStrings.codeToLanguageName[_languageCode] ?? 'English';

  /// Call once at app startup (see main.dart) to restore the last-selected
  /// language before the first frame, avoiding a flash of English → chosen
  /// language.
  Future<void> loadSaved() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final saved = prefs.getString(_prefsKey);
      if (saved != null && AppStrings.supportedLanguageCodes.contains(saved)) {
        _languageCode = saved;
        notifyListeners();
      }
    } catch (_) {
      // If prefs fail for any reason, just stay on the 'en' default.
    }
  }

  /// Call this whenever the user picks a language in Settings — accepts the
  /// friendly name shown in the picker (e.g. 'Hindi') for convenience since
  /// that's what settings_screen.dart already works with.
  Future<void> setLanguageByName(String languageName) async {
    final code = AppStrings.languageNameToCode[languageName] ?? 'en';
    await setLanguageByCode(code);
  }

  Future<void> setLanguageByCode(String code) async {
    if (code == _languageCode) return;
    _languageCode = code;
    notifyListeners();
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_prefsKey, code);
    } catch (_) {
      // Non-fatal — the in-memory language still applies for this session
      // even if persisting it fails.
    }
  }

  String tr(String key) => AppStrings.tr(key, _languageCode);
}

/// Convenience extension so screens can write `context.tr('key')` instead of
/// `context.watch<LanguageProvider>().tr('key')` everywhere.
extension LocalizationExtension on BuildContext {
  String tr(String key) {
    final provider = this.dependOnInheritedWidgetOfExactType<_LanguageInherited>();
    if (provider != null) return provider.languageProvider.tr(key);
    // Fallback: still works even if used outside the InheritedWidget scope,
    // just won't auto-rebuild on language change in that spot.
    return AppStrings.tr(key, 'en');
  }
}

/// Lightweight InheritedWidget wrapper so context.tr() rebuilds the exact
/// widgets that call it whenever the language changes, without requiring
/// every screen to explicitly `context.watch<LanguageProvider>()`.
/// Wrap MaterialApp's builder (or home) with this once — see main.dart.
class LanguageScope extends StatelessWidget {
  final LanguageProvider languageProvider;
  final Widget child;
  const LanguageScope({super.key, required this.languageProvider, required this.child});

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: languageProvider,
      builder: (context, _) {
        return _LanguageInherited(languageProvider: languageProvider, child: child);
      },
    );
  }
}

class _LanguageInherited extends InheritedWidget {
  final LanguageProvider languageProvider;
  const _LanguageInherited({required this.languageProvider, required super.child});

  @override
  bool updateShouldNotify(_LanguageInherited oldWidget) =>
      oldWidget.languageProvider.languageCode != languageProvider.languageCode;
}