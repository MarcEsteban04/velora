import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'app_colors.dart';
import 'app_typography.dart';

abstract final class AppTheme {
  /// Activates [palette] app-wide and builds the matching Material theme.
  static ThemeData forPalette(Palette palette) {
    AppColors.palette = palette;
    return _build();
  }

  /// The Night theme. Tests use it.
  static ThemeData get dark => forPalette(Palette.nightPalette);

  /// Status and navigation bars that suit the active scene: light icons at
  /// night, dark icons by day.
  static SystemUiOverlayStyle get overlayStyle =>
      (AppColors.isLight
              ? SystemUiOverlayStyle.dark
              : SystemUiOverlayStyle.light)
          .copyWith(
            statusBarColor: Colors.transparent,
            systemNavigationBarColor: AppColors.night,
          );

  static ThemeData _build() {
    final brightness = AppColors.isLight ? Brightness.light : Brightness.dark;
    final scheme =
        ColorScheme.fromSeed(
          seedColor: AppColors.accent,
          brightness: brightness,
        ).copyWith(
          primary: AppColors.accent,
          onPrimary: AppColors.onBrand,
          secondary: AppColors.rust,
          onSecondary: AppColors.onBrand,
          surface: AppColors.surface,
          onSurface: AppColors.textPrimary,
        );

    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: scheme,
      scaffoldBackgroundColor: AppColors.night,
      fontFamily: AppTypography.body,
      textTheme: AppTypography.textTheme,
      iconTheme: IconThemeData(color: AppColors.textSecondary),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        // Float above the floating nav bar (and onboarding's bottom
        // buttons), so a snackbar never covers a tab or turns a tab tap into
        // an accidental Undo.
        insetPadding: const EdgeInsets.fromLTRB(16, 0, 16, 104),
        backgroundColor: AppColors.isLight
            ? const Color(0xFF1C2630)
            : AppColors.surfaceRaised,
        contentTextStyle: AppTypography.textTheme.bodyMedium?.copyWith(
          color: const Color(0xFFFBF7F1),
        ),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
      textSelectionTheme: TextSelectionThemeData(
        cursorColor: AppColors.accentBright,
        selectionColor: AppColors.accent.withValues(alpha: 0.4),
        selectionHandleColor: AppColors.accentBright,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.isLight
            ? Colors.white.withValues(alpha: 0.85)
            : AppColors.night.withValues(alpha: 0.55),
        hintStyle: AppTypography.textTheme.bodyLarge?.copyWith(
          color: AppColors.textMuted,
        ),
        prefixIconColor: AppColors.textMuted,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 18,
          vertical: 18,
        ),
        border: _fieldBorder(AppColors.hairline()),
        enabledBorder: _fieldBorder(AppColors.hairline()),
        focusedBorder: _fieldBorder(AppColors.accentBright, width: 1.8),
        errorBorder: _fieldBorder(AppColors.rust),
        focusedErrorBorder: _fieldBorder(AppColors.rust, width: 1.8),
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: AppColors.surface,
        showDragHandle: true,
        dragHandleColor: AppColors.textMuted,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
      ),
      dialogTheme: DialogThemeData(backgroundColor: AppColors.surfaceRaised),
    );
  }

  static OutlineInputBorder _fieldBorder(Color color, {double width = 1}) =>
      OutlineInputBorder(
        borderRadius: BorderRadius.circular(20),
        borderSide: BorderSide(color: color, width: width),
      );
}
