import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/formatters.dart';
import '../../../data/models/notification_model.dart';
import '../../../data/models/task_model.dart';

class NotificationCard extends StatelessWidget {
  final NotificationModel notification;
  final VoidCallback? onTap;

  const NotificationCard({super.key, required this.notification, this.onTap});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isUnread = notification.isUnread;
    final shaardlaga = notification.shaardlagaEsekh;
    // Хүлээн аваагүй шаардлага улаанаар ялгарна.
    final accent = shaardlaga ? AppColors.error : AppColors.primary;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 5),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: isUnread
              ? (shaardlaga ? AppColors.error.withOpacity(0.06) : context.appPrimaryContainer)
              : context.appCardBg,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isUnread
                ? (shaardlaga ? AppColors.error.withOpacity(0.4) : AppColors.primaryLight.withOpacity(0.4))
                : context.appDivider,
          ),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: isUnread ? accent : context.appInputFill,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(
                shaardlaga ? Icons.assignment_late_rounded : Icons.notifications_rounded,
                size: 20,
                color: isUnread ? Colors.white : context.appTextTertiary,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (shaardlaga) ...[
                    ShaardlagiinShoshgo(khuleenAvsan: !isUnread),
                    const SizedBox(height: 6),
                  ],
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          notification.title,
                          style: theme.textTheme.titleSmall?.copyWith(
                            fontWeight: isUnread ? FontWeight.w700 : FontWeight.w500,
                          ),
                        ),
                      ),
                      if (isUnread)
                        Container(
                          width: 8,
                          height: 8,
                          decoration: BoxDecoration(color: accent, shape: BoxShape.circle),
                        ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    notification.message,
                    style: theme.textTheme.bodySmall?.copyWith(color: context.appTextSecondary),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (notification.createdAt != null) ...[
                    const SizedBox(height: 6),
                    Text(
                      AppFormatters.dateTime(notification.createdAt),
                      style: theme.textTheme.labelSmall,
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// «Шаардлага» шошго + төлөв (хүлээн авах / хүлээн авсан).
class ShaardlagiinShoshgo extends StatelessWidget {
  final bool khuleenAvsan;

  const ShaardlagiinShoshgo({super.key, required this.khuleenAvsan});

  @override
  Widget build(BuildContext context) {
    final tuluvColor = khuleenAvsan ? AppColors.success : AppColors.warning;
    return Wrap(
      spacing: 6,
      runSpacing: 4,
      children: [
        _Shoshgo(text: 'Шаардлага', color: AppColors.error),
        _Shoshgo(
          text: khuleenAvsan ? 'Хүлээн авсан' : 'Хүлээн авах',
          color: tuluvColor,
        ),
      ],
    );
  }
}

class _Shoshgo extends StatelessWidget {
  final String text;
  final Color color;

  const _Shoshgo({required this.text, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        text,
        style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: color),
      ),
    );
  }
}

class TaskCard extends StatelessWidget {
  final TaskModel task;
  final VoidCallback? onTap;

  const TaskCard({super.key, required this.task, this.onTap});

  Color _statusColor() {
    switch (task.tuluv) {
      case 0: return AppColors.pendingChip;
      case 1: return AppColors.info;
      case 2: return AppColors.success;
      case 3: return AppColors.inactiveChip;
      default: return AppColors.textTertiary;
    }
  }

  Color _statusBg(BuildContext context) {
    switch (task.tuluv) {
      case 0: return context.appWarningLight;
      case 1: return context.appInfoLight;
      case 2: return context.appSuccessLight;
      case 3: return context.appInputFill;
      default: return context.appInputFill;
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final statusColor = _statusColor();
    final statusBg = _statusBg(context);

    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 5),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: context.appCardBg,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: context.appDivider),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: statusBg,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(Icons.build_rounded, size: 20, color: statusColor),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(task.title, style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600)),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: statusBg,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(task.statusLabel, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: statusColor)),
                      ),
                    ],
                  ),
                  if (task.description != null) ...[
                    const SizedBox(height: 4),
                    Text(
                      task.description!,
                      style: theme.textTheme.bodySmall,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                  if (task.createdAt != null) ...[
                    const SizedBox(height: 6),
                    Text(AppFormatters.date(task.createdAt), style: theme.textTheme.labelSmall),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
