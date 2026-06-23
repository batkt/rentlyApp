import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/formatters.dart';
import '../../../data/models/agreement_model.dart';
import '../../providers/auth_provider.dart';
import '../../providers/agreement_provider.dart';
import '../../widgets/cards/agreement_card.dart';
import '../../widgets/common/app_loading.dart';
import '../../widgets/common/app_text_field.dart';

class DashboardScreen extends ConsumerStatefulWidget {
  const DashboardScreen({super.key});

  @override
  ConsumerState<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends ConsumerState<DashboardScreen> {
  final _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(currentUserProvider);
    final filter = ref.watch(agreementFilterProvider);
    final agreementsAsync = ref.watch(agreementsProvider);
    final sw = MediaQuery.sizeOf(context).width;
    final hPad = ((sw - 720) / 2).clamp(16.0, 48.0);

    return Scaffold(
      backgroundColor: context.appBackground,
      body: RefreshIndicator(
        color: AppColors.primary,
        onRefresh: () async => ref.refresh(agreementsProvider),
        child: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            _buildSliverAppBar(context, user, agreementsAsync.valueOrNull),
            SliverToBoxAdapter(
              child: Padding(
                padding: EdgeInsets.fromLTRB(hPad, 16, hPad, 0),
                child: AppSearchField(
                  controller: _searchController,
                  hint: 'Нэр, гэрээ, талбайн дугаар хайх...',
                  onChanged: (v) => setState(() => _searchQuery = v.toLowerCase()),
                ),
              ),
            ),
            SliverToBoxAdapter(child: _buildFilterTabs(filter, hPad)),
            _buildAgreementsList(agreementsAsync, hPad),
          ],
        ),
      ),
    );
  }

  Widget _buildBarilgaSelector(BuildContext context) {
    final authState = ref.watch(authStateProvider);
    final allBarilguud = authState.barilguud;
    final withAgreements = ref.watch(barilguudWithAgreementsProvider).valueOrNull;
    final barilguud = withAgreements != null
        ? allBarilguud.where((b) => withAgreements.contains(b.id)).toList()
        : allBarilguud;
    if (barilguud.length <= 1) return const SizedBox.shrink();

    final selectedId = authState.selectedBarilgiinId ?? authState.user?.barilgiinId ?? '';
    final selected = barilguud.firstWhere((b) => b.id == selectedId, orElse: () => barilguud.first);

    return GestureDetector(
      onTap: () => _showBarilgaPicker(context, barilguud, selected.id),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.15),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.white.withOpacity(0.3)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.business_rounded, size: 13, color: Colors.white),
            const SizedBox(width: 5),
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 90),
              child: Text(
                selected.ner,
                style: const TextStyle(fontSize: 12, color: Colors.white, fontWeight: FontWeight.w600),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(width: 3),
            const Icon(Icons.expand_more_rounded, size: 14, color: Colors.white),
          ],
        ),
      ),
    );
  }

  void _showBarilgaPicker(BuildContext context, List<({String id, String ner})> barilguud, String currentId) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      constraints: BoxConstraints(
        maxWidth: MediaQuery.sizeOf(context).width > 600 ? 560 : double.infinity,
      ),
      builder: (_) => Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Барилга сонгох', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
            const SizedBox(height: 12),
            ...barilguud.map((b) {
              final isSelected = b.id == currentId;
              return ListTile(
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                tileColor: isSelected ? AppColors.primaryContainer : null,
                leading: Icon(
                  Icons.business_rounded,
                  color: isSelected ? AppColors.primary : AppColors.textTertiary,
                ),
                title: Text(b.ner, style: TextStyle(fontWeight: isSelected ? FontWeight.w700 : FontWeight.normal)),
                trailing: isSelected ? Icon(Icons.check_rounded, color: AppColors.primary) : null,
                onTap: () {
                  Navigator.pop(context);
                  ref.read(authStateProvider.notifier).switchBuilding(b.id);
                  ref.invalidate(agreementsProvider);
                },
              );
            }),
          ],
        ),
      ),
    );
  }

  Widget _buildSliverAppBar(BuildContext context, dynamic user, List<AgreementModel>? agreements) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final total = agreements?.length ?? 0;
    final active = agreements?.where((a) => a.isActive).length ?? 0;
    final totalDebt = agreements?.fold<double>(0, (s, a) => s + (a.uldegdel > 0 ? a.uldegdel : 0)) ?? 0;
    final hasDebt = totalDebt > 0;

    return SliverAppBar(
      expandedHeight: 200,
      pinned: true,
      floating: false,
      backgroundColor: isDark ? const Color(0xFF1E2A28) : AppColors.primary,
      elevation: 0,
      flexibleSpace: FlexibleSpaceBar(
        collapseMode: CollapseMode.pin,
        background: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: isDark
                  ? [const Color(0xFF1A3D37), const Color(0xFF0D1514)]
                  : [AppColors.primaryDark, AppColors.primary, AppColors.primaryLight],
            ),
          ),
          child: SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Сайн байна уу,',
                            style: TextStyle(
                              fontSize: 13,
                              color: Colors.white.withOpacity(0.7),
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            user?.shortName.isNotEmpty == true
                                ? user!.shortName
                                : (user?.primaryPhone.isNotEmpty == true ? user!.primaryPhone : 'Хэрэглэгч'),
                            style: const TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.w800,
                              color: Colors.white,
                              letterSpacing: -0.3,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                      const Spacer(),
                      _buildBarilgaSelector(context),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      _HeroStatCard(
                        label: 'Нийт гэрээ',
                        value: '$total',
                        icon: Icons.assignment_rounded,
                      ),
                      const SizedBox(width: 10),
                      _HeroStatCard(
                        label: 'Идэвхтэй',
                        value: '$active',
                        icon: Icons.check_circle_rounded,
                        color: Colors.greenAccent,
                      ),
                      const SizedBox(width: 10),
                      _HeroStatCard(
                        label: hasDebt ? 'Нийт үлдэгдэл' : 'Үлдэгдэл',
                        value: agreements == null
                            ? '...'
                            : hasDebt
                                ? AppFormatters.currency(totalDebt)
                                : '0.00₮',
                        icon: hasDebt ? Icons.warning_rounded : Icons.check_circle_outline_rounded,
                        color: hasDebt ? Colors.redAccent.shade100 : Colors.greenAccent,
                        small: totalDebt > 9999999,
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildFilterTabs(int? currentFilter, double hPad) {
    return Padding(
      padding: EdgeInsets.fromLTRB(hPad, 16, hPad, 8),
      child: Row(
        children: [
          Text(
            'Гэрээнүүд',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
          ),
          const Spacer(),
          _FilterChip(label: 'Идэвхтэй', value: 1, current: currentFilter),
          const SizedBox(width: 8),
          _FilterChip(label: 'Бүгд', value: null, current: currentFilter),
        ],
      ),
    );
  }

  Widget _buildAgreementsList(AsyncValue<List<AgreementModel>> agreementsAsync, double hPad) {
    return agreementsAsync.when(
      loading: () => const SliverFillRemaining(child: ShimmerList()),
      error: (err, _) => SliverFillRemaining(
        child: AppErrorWidget(
          message: 'Гэрээнүүд ачаалахад алдаа гарлаа',
          onRetry: () => ref.refresh(agreementsProvider),
        ),
      ),
      data: (agreements) {
        final filter = ref.watch(agreementFilterProvider);
        var filtered = filter == null
            ? agreements
            : agreements.where((a) => a.tuluv == filter).toList();

        if (_searchQuery.isNotEmpty) {
          filtered = filtered.where((a) =>
              a.tenantName.toLowerCase().contains(_searchQuery) ||
              a.gereeniiDugaar.toLowerCase().contains(_searchQuery) ||
              (a.talbainDugaar?.toLowerCase().contains(_searchQuery) ?? false)).toList();
        }

        if (filtered.isEmpty) {
          return SliverFillRemaining(
            child: AppEmpty(
              icon: Icons.assignment_outlined,
              message: _searchQuery.isNotEmpty ? 'Хайлтын үр дүн олдсонгүй' : 'Гэрээ байхгүй байна',
            ),
          );
        }

        return SliverPadding(
          padding: EdgeInsets.fromLTRB(hPad, 0, hPad, 32),
          sliver: SliverList.separated(
            itemCount: filtered.length,
            separatorBuilder: (_, __) => const SizedBox(height: 10),
            itemBuilder: (context, index) {
              final agreement = filtered[index];
              return AgreementCard(
                agreement: agreement,
                onTap: () => context.push('/agreements/${agreement.id}', extra: agreement),
                onPay: agreement.isActive
                    ? () => context.push('/payment', extra: agreement)
                    : null,
              );
            },
          ),
        );
      },
    );
  }
}

class _HeroStatCard extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color color;
  final bool small;

  const _HeroStatCard({
    required this.label,
    required this.value,
    required this.icon,
    this.color = Colors.white,
    this.small = false,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.12),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: Colors.white.withOpacity(0.15)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: color, size: 18),
            const SizedBox(height: 6),
            Text(
              value,
              style: TextStyle(
                fontSize: small ? 10 : 13,
                fontWeight: FontWeight.w800,
                color: Colors.white,
                letterSpacing: -0.2,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: TextStyle(
                fontSize: 10,
                color: Colors.white.withOpacity(0.65),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _FilterChip extends ConsumerWidget {
  final String label;
  final int? value;
  final int? current;

  const _FilterChip({required this.label, required this.value, required this.current});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isSelected = current == value;
    return GestureDetector(
      onTap: () => ref.read(agreementFilterProvider.notifier).state = value,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.primary : context.appInputFill,
          borderRadius: BorderRadius.circular(20),
          border: isSelected ? null : Border.all(color: context.appDivider),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: isSelected ? Colors.white : context.appTextSecondary,
          ),
        ),
      ),
    );
  }
}
