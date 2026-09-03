import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

/// The exact circular-pill decoration from the spec, factored out so both
/// [CustomDropdown] and [PickerField] below (and any future dropdown-style
/// field) stay pixel-identical instead of copy-pasted per screen.
///
/// Deliberately NOT applied via the global `inputDecorationTheme` in
/// app_theme.dart — that theme also styles ordinary multi-line text fields
/// (captions, descriptions), which should NOT become pill-shaped. This is
/// scoped to dropdown/picker-style fields only, per "App ke saare dropdown
/// fields par circular pill border" — dropdowns, not every text field.
InputDecoration circularDropdownDecoration(
  BuildContext context, {
  String? hintText,
  Widget? prefixIcon,
}) {
  final isDark = Theme.of(context).brightness == Brightness.dark;
  return InputDecoration(
    hintText: hintText,
    prefixIcon: prefixIcon,
    filled: true,
    fillColor: isDark ? AppColors.darkCard : Colors.white,
    contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(30.0),
      borderSide: const BorderSide(color: AppColors.purple),
    ),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(30.0),
      borderSide: const BorderSide(color: AppColors.purple),
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(30.0),
      borderSide: const BorderSide(color: AppColors.purple, width: 2.0),
    ),
    disabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(30.0),
      borderSide: BorderSide(color: AppColors.purple.withOpacity(0.35)),
    ),
  );
}

/// Drop-in replacement for `DropdownButtonFormField<T>` with the Plum
/// circular pill border applied. Use this for any REAL native dropdown
/// (a fixed list of selectable values) anywhere in the app.
///
/// Example:
/// ```dart
/// CustomDropdown<String>(
///   value: _language,
///   items: const ['English', 'Hindi', 'Hinglish'],
///   labelBuilder: (v) => v,
///   onChanged: (v) => setState(() => _language = v),
///   prefixIcon: const Icon(Icons.language_rounded, size: 18),
/// )
/// ```
class CustomDropdown<T> extends StatelessWidget {
  final T? value;
  final List<T> items;
  final String Function(T value) labelBuilder;
  final ValueChanged<T?> onChanged;
  final String? hintText;
  final Widget? prefixIcon;

  const CustomDropdown({
    super.key,
    required this.value,
    required this.items,
    required this.labelBuilder,
    required this.onChanged,
    this.hintText,
    this.prefixIcon,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    // ⚠️ FIX ("standard, outdated white dropdown menus"): the FIELD itself
    // was already styled via `decoration` above, but Flutter renders the
    // opened POPUP MENU as a separate overlay that ignores the field's
    // decoration entirely — it falls back to Material's default canvas
    // color (white) unless `dropdownColor` is set explicitly, which is
    // exactly the bug being reported. Setting it here (plus explicit
    // bright text per item, since dark-mode default item text is also
    // black-on-transparent by default) makes the opened menu match the
    // dark Plum theme instead of popping up as a plain white list.
    final menuColor = isDark ? AppColors.darkCard2 : Colors.white;
    final itemTextColor = isDark ? Colors.white : Colors.black;

    return DropdownButtonFormField<T>(
      initialValue: value,
      isExpanded: true,
      icon: const Icon(Icons.keyboard_arrow_down_rounded, color: AppColors.purple),
      borderRadius: BorderRadius.circular(20),
      dropdownColor: menuColor,
      elevation: 6,
      decoration: circularDropdownDecoration(context, hintText: hintText, prefixIcon: prefixIcon),
      items: items
          .map((v) => DropdownMenuItem<T>(
                value: v,
                child: Text(labelBuilder(v), overflow: TextOverflow.ellipsis, style: TextStyle(color: itemTextColor)),
              ))
          .toList(),
      onChanged: onChanged,
    );
  }
}

/// The app's existing "tap to open a bottom-sheet picker" pattern (used
/// wherever a value is chosen from a modal list rather than an inline
/// dropdown menu — category/audience/privacy/media-type pickers etc.),
/// restyled to the same circular pill so it reads as the same control
/// family as [CustomDropdown] even though it opens a sheet instead of an
/// inline menu. This replaces the various private `_pickerField()` copies
/// that were duplicated per-screen.
class PickerField extends StatelessWidget {
  final String value;
  final VoidCallback onTap;
  final bool isPlaceholder;
  final Widget? prefixIcon;

  const PickerField({
    super.key,
    required this.value,
    required this.onTap,
    this.isPlaceholder = false,
    this.prefixIcon,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        decoration: BoxDecoration(
          color: isDark ? AppColors.darkCard : Colors.white,
          borderRadius: BorderRadius.circular(30.0),
          border: Border.all(color: AppColors.purple),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            if (prefixIcon != null) ...[prefixIcon!, const SizedBox(width: 10)],
            Expanded(
              child: Text(
                value,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontWeight: isPlaceholder ? FontWeight.w400 : FontWeight.w700,
                  color: isPlaceholder ? context.surfaces.textDim : null,
                ),
              ),
            ),
            const Icon(Icons.keyboard_arrow_down_rounded, color: AppColors.purple),
          ],
        ),
      ),
    );
  }
}
