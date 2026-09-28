import 'package:flutter/material.dart';

import 'app_colors.dart';
import 'app_typography.dart';

abstract final class AppTheme {
  static ThemeData get dark {
    final scheme =
        ColorScheme.fromSeed(
          seedColor: AppColors.leaf,
          brightness: Brightness.dark,
        ).copyWith(
          primary: AppColors.leaf,
          onPrimary: AppColors.textPrimary,
          secondary: AppColors.rust,
          onSecondary: AppColors.textPrimary,
          surface: AppColors.surface,
          onSurface: AppColors.textPrimary,
        );

    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      colorScheme: scheme,
      scaffoldBackgroundColor: AppColors.night,
      fontFamily: AppTypography.body,
      textTheme: AppTypography.textTheme,
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        // Float above the floating nav bar (and onboarding's bottom
        // buttons), so a snackbar never covers a tab or turns a tab tap into
        // an accidental Undo.
        insetPadding: const EdgeInsets.fromLTRB(16, 0, 16, 104),
        backgroundColor: AppColors.surfaceRaised,
        contentTextStyle: AppTypography.textTheme.bodyMedium?.copyWith(
          color: AppColors.textPrimary,
        ),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
      textSelectionTheme: TextSelectionThemeData(
        cursorColor: AppColors.leafBright,
        selectionColor: AppColors.leaf.withValues(alpha: 0.4),
        selectionHandleColor: AppColors.leafBright,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.night.withValues(alpha: 0.55),
        hintStyle: AppTypography.textTheme.bodyLarge?.copyWith(
          color: AppColors.textMuted,
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 18,
          vertical: 18,
        ),
        border: _fieldBorder(Colors.white.withValues(alpha: 0.08)),
        enabledBorder: _fieldBorder(Colors.white.withValues(alpha: 0.08)),
        focusedBorder: _fieldBorder(AppColors.leafBright, width: 1.8),
        errorBorder: _fieldBorder(AppColors.rust),
        focusedErrorBorder: _fieldBorder(AppColors.rust, width: 1.8),
      ),
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: AppColors.surface,
        showDragHandle: true,
        dragHandleColor: AppColors.textMuted,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
      ),
    );
  }

  static OutlineInputBorder _fieldBorder(Color color, {double width = 1}) =>
      OutlineInputBorder(
        borderRadius: BorderRadius.circular(20),
        borderSide: BorderSide(color: color, width: width),
      );
}
