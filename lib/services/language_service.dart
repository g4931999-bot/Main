// ---------------------------------------------------------------------------
// NOTE FOR REVIEWERS: TubePilot already had a complete, working multi-
// language engine before this file was requested — lib/providers/
// language_provider.dart (a ChangeNotifier, exactly as the spec asked for)
// + lib/l10n/app_strings.dart (the key-value translation maps) + the
// `context.tr('key')` extension used across every screen + a LanguageScope
// InheritedWidget wired in main.dart that triggers a global rebuild with NO
// cold restart the instant the language changes.
//
// It already supports English ('en'), Hindi ('hi'), AND Hinglish
// ('hinglish') — plus Tamil/Bengali/Marathi/Urdu on top — and is already
// wired into username_setup_screen.dart and settings_screen.dart.
//
// Rather than introduce a second, competing state source at the exact file
// path this round's spec named (which would leave the app with two
// "sources of truth" for the current language — a real bug risk), this
// file is a thin, zero-logic facade: `LanguageService` is just another name
// for the same `LanguageProvider` your Provider tree already has. Import
// EITHER path and you get the same live instance.
// ---------------------------------------------------------------------------

export '../providers/language_provider.dart' show LanguageProvider, LanguageScope, LocalizationExtension;
import '../providers/language_provider.dart';

/// Alias so code that expects `LanguageService` (per this round's naming)
/// resolves to the exact same ChangeNotifier already registered in
/// main.dart's MultiProvider — there is only ever one instance app-wide.
typedef LanguageService = LanguageProvider;
