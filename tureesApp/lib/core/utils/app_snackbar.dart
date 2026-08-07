import 'package:flutter/material.dart';
import '../theme/app_colors.dart';

/// Snackbar төрлүүд — фон болон текстийн өнгийг хамтад нь шийднэ.
enum SnackTurul { medee, amjilt, aldaa, sanuulga }

/// Snackbar бүр өөр өөрийнхөөрөө өнгө тавьдаг байсан тул theme-ийн фон
/// өөрчлөгдөхөд текстийн контраст чимээгүйхэн эвдэрдэг байсан. Одоо бүгд эндүүр
/// дамжина: фон болон түүнд тохирох текстийн өнгийг нэг газар тодорхойлно.
void showAppSnackBar(
  BuildContext context,
  String message, {
  SnackTurul turul = SnackTurul.medee,
  SnackBarAction? action,
  Duration duration = const Duration(seconds: 3),
}) {
  final theme = Theme.of(context);
  final Color? bg;
  final Color fg;
  final IconData? icon;

  switch (turul) {
    case SnackTurul.amjilt:
      bg = AppColors.success;
      fg = Colors.white;
      icon = Icons.check_circle_rounded;
    case SnackTurul.aldaa:
      bg = AppColors.error;
      fg = Colors.white;
      icon = Icons.error_rounded;
    case SnackTurul.sanuulga:
      // Шар дээр цагаан текст уншигдахгүй тул бараан текст.
      bg = AppColors.warning;
      fg = AppColors.textPrimary;
      icon = Icons.warning_amber_rounded;
    case SnackTurul.medee:
      bg = null; // theme-ийн өнгө
      fg = theme.snackBarTheme.contentTextStyle?.color ?? theme.colorScheme.onSurface;
      icon = null;
  }

  final textStyle = (theme.snackBarTheme.contentTextStyle ?? const TextStyle())
      .copyWith(color: fg);

  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(
      SnackBar(
        backgroundColor: bg,
        duration: duration,
        action: action,
        content: Row(
          children: [
            if (icon != null) ...[
              Icon(icon, color: fg, size: 20),
              const SizedBox(width: 10),
            ],
            Expanded(child: Text(message, style: textStyle)),
          ],
        ),
      ),
    );
}
