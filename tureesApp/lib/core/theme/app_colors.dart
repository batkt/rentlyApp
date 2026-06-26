import 'package:flutter/material.dart';

extension AppColorsTheme on BuildContext {
  bool get _isDark => Theme.of(this).brightness == Brightness.dark;

  Color get appBackground => _isDark ? const Color(0xFF111918) : AppColors.background;
  Color get appSurface => _isDark ? const Color(0xFF1E2A28) : AppColors.surface;
  Color get appCardBg => _isDark ? const Color(0xFF1A2826) : AppColors.cardBg;
  Color get appDivider => _isDark ? const Color(0xFF2D3B39) : AppColors.divider;
  Color get appInputFill => _isDark ? const Color(0xFF1A2826) : AppColors.inputFill;
  Color get appTextPrimary => _isDark ? const Color(0xFFE2E8F0) : AppColors.textPrimary;
  Color get appTextSecondary => _isDark ? const Color(0xFF94A3B8) : AppColors.textSecondary;
  Color get appTextTertiary => _isDark ? const Color(0xFF64748B) : AppColors.textTertiary;
  Color get appPrimaryContainer => _isDark ? const Color(0xFF1A3D37) : AppColors.primaryContainer;
  Color get appErrorLight => _isDark ? const Color(0xFF3D1A1A) : AppColors.errorLight;
  Color get appSuccessLight => _isDark ? const Color(0xFF1A3D28) : AppColors.successLight;
  Color get appWarningLight => _isDark ? const Color(0xFF3D3010) : AppColors.warningLight;
  Color get appInfoLight => _isDark ? const Color(0xFF1A2D3D) : AppColors.infoLight;
}

class AppColors {
  // Primary - Deep Teal
  static const Color primary = Color(0xFF006B5B);
  static const Color primaryLight = Color(0xFF4D9E90);
  static const Color primaryDark = Color(0xFF004D40);
  static const Color primaryContainer = Color(0xFFE0F2F0);

  // Secondary - Amber accent
  static const Color secondary = Color(0xFFF59E0B);
  static const Color secondaryLight = Color(0xFFFCD34D);
  static const Color secondaryDark = Color(0xFFD97706);
  static const Color secondaryContainer = Color(0xFFFFF8E1);

  // Semantic
  static const Color success = Color(0xFF16A34A);
  static const Color successLight = Color(0xFFDCFCE7);
  static const Color warning = Color(0xFFF59E0B);
  static const Color warningLight = Color(0xFFFEF3C7);
  static const Color error = Color(0xFFDC2626);
  static const Color errorLight = Color(0xFFFEE2E2);
  static const Color info = Color(0xFF0284C7);
  static const Color infoLight = Color(0xFFE0F2FE);

  // Neutrals
  static const Color surface = Color(0xFFFFFFFF);
  static const Color background = Color(0xFFF8FAFC);
  static const Color cardBg = Color(0xFFFFFFFF);
  static const Color divider = Color(0xFFE2E8F0);
  static const Color inputFill = Color(0xFFF1F5F9);

  // Text
  static const Color textPrimary = Color(0xFF0F172A);
  static const Color textSecondary = Color(0xFF475569);
  static const Color textTertiary = Color(0xFF94A3B8);
  static const Color textOnPrimary = Color(0xFFFFFFFF);

  // Status chips
  static const Color activeChip = Color(0xFF16A34A);
  static const Color activeChipBg = Color(0xFFDCFCE7);
  static const Color inactiveChip = Color(0xFFD97706);
  static const Color inactiveChipBg = Color(0xFFFEF3C7);
  static const Color overdueChip = Color(0xFFDC2626);
  static const Color overdueChipBg = Color(0xFFFEE2E2);
  static const Color pendingChip = Color(0xFFF59E0B);
  static const Color pendingChipBg = Color(0xFFFEF3C7);
}
