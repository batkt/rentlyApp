import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_colors.dart';
import '../../../data/models/user_model.dart';
import '../../providers/auth_provider.dart';
import '../../widgets/common/app_button.dart';

class OrgSelectScreen extends ConsumerStatefulWidget {
  const OrgSelectScreen({super.key});

  @override
  ConsumerState<OrgSelectScreen> createState() => _OrgSelectScreenState();
}

class _OrgSelectScreenState extends ConsumerState<OrgSelectScreen> {
  OrgSelectionModel? _selected;

  Future<void> _continue() async {
    if (_selected == null) return;

    final result = await ref.read(authStateProvider.notifier).loginWithOrg(_selected!);
    if (!mounted) return;

    if (result == LoginResult.success) {
      context.go('/home');
    }
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authStateProvider);
    final orgs = authState.orgOptions;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Байгууллага сонгох'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => context.pop(),
        ),
      ),
      body: Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 520),
          child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Нэвтрэх байгууллагаа\nсонгоно уу',
              style: Theme.of(context).textTheme.headlineMedium,
            ),
            const SizedBox(height: 8),
            Text(
              'Та ${orgs.length} байгууллагад бүртгэлтэй байна',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 24),
            Expanded(
              child: ListView.separated(
                itemCount: orgs.length,
                separatorBuilder: (_, __) => const SizedBox(height: 12),
                itemBuilder: (context, index) {
                  final org = orgs[index];
                  final isSelected = _selected?.id == org.id;

                  return GestureDetector(
                    onTap: () => setState(() => _selected = org),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: isSelected ? AppColors.primaryContainer : AppColors.cardBg,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: isSelected ? AppColors.primary : AppColors.divider,
                          width: isSelected ? 2 : 1,
                        ),
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 48,
                            height: 48,
                            decoration: BoxDecoration(
                              color: isSelected ? AppColors.primary : AppColors.inputFill,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Icon(
                              Icons.business_rounded,
                              color: isSelected ? Colors.white : AppColors.textTertiary,
                              size: 24,
                            ),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  org.ner,
                                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                                    fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                                    color: isSelected ? AppColors.primary : AppColors.textPrimary,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  org.barilgiinNer.isNotEmpty ? org.barilgiinNer : org.register,
                                  style: Theme.of(context).textTheme.bodySmall,
                                ),
                              ],
                            ),
                          ),
                          if (isSelected)
                            const Icon(Icons.check_circle_rounded, color: AppColors.primary, size: 22),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 16),
            AppButton(
              label: 'Үргэлжлүүлэх',
              onPressed: (_selected != null && !authState.isLoading) ? _continue : null,
              isLoading: authState.isLoading,
            ),
          ],
        ),
          ),
        ),
      ),
    );
  }
}
