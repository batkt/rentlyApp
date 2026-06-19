import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/formatters.dart';
import '../../../data/models/agreement_model.dart';
import '../common/app_loading.dart';

class AgreementCard extends StatelessWidget {
  final AgreementModel agreement;
  final VoidCallback? onTap;
  final VoidCallback? onPay;

  const AgreementCard({
    super.key,
    required this.agreement,
    this.onTap,
    this.onPay,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isActive = agreement.isActive;
    final hasDebt = agreement.uldegdel > 0;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: context.appCardBg,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: hasDebt ? AppColors.overdueChipBg : context.appDivider,
            width: hasDebt ? 1.5 : 1,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.04),
              blurRadius: 10,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _AgreementAvatar(name: agreement.shortName),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                agreement.tenantName,
                                style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            const SizedBox(width: 8),
                            isActive ? StatusChip.active() : StatusChip.inactive(),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            Icon(Icons.receipt_long_rounded, size: 13, color: context.appTextTertiary),
                            const SizedBox(width: 4),
                            Text(
                              agreement.gereeniiDugaar,
                              style: theme.textTheme.bodySmall,
                            ),
                            if (agreement.talbainDugaar != null) ...[
                              const SizedBox(width: 8),
                              Icon(Icons.door_front_door_rounded, size: 13, color: context.appTextTertiary),
                              const SizedBox(width: 4),
                              Text(
                                agreement.talbainDugaar!,
                                style: theme.textTheme.bodySmall,
                              ),
                            ],
                          ],
                        ),
                        if (agreement.utas.isNotEmpty) ...[
                          const SizedBox(height: 4),
                          Row(
                            children: [
                              Icon(Icons.phone_rounded, size: 13, color: context.appTextTertiary),
                              const SizedBox(width: 4),
                              Text(
                                AppFormatters.phone(agreement.utas.first),
                                style: theme.textTheme.bodySmall,
                              ),
                            ],
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Үлдэгдэл', style: theme.textTheme.labelSmall),
                        const SizedBox(height: 2),
                        Text(
                          AppFormatters.currency(agreement.uldegdel),
                          style: theme.textTheme.titleMedium?.copyWith(
                            color: hasDebt ? AppColors.error : AppColors.success,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (isActive && onPay != null)
                    FilledButton.icon(
                      onPressed: onPay,
                      icon: const Icon(Icons.payment_rounded, size: 16),
                      label: const Text('Төлөх', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                      style: FilledButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        minimumSize: Size.zero,
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AgreementAvatar extends StatelessWidget {
  final String name;

  const _AgreementAvatar({required this.name});

  @override
  Widget build(BuildContext context) {
    final initials = name.isNotEmpty ? name[0].toUpperCase() : '?';
    return Container(
      width: 46,
      height: 46,
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [AppColors.primary, AppColors.primaryLight],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        shape: BoxShape.circle,
      ),
      child: Center(
        child: Text(
          initials,
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w700,
            fontSize: 18,
          ),
        ),
      ),
    );
  }
}
