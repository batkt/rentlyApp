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

    return Scaffold(
      backgroundColor: context.appBackground,
      body: CustomScrollView(
        slivers: [
          _buildAppBar(context, user),
          SliverToBoxAdapter(child: _buildSummaryCards(agreementsAsync.valueOrNull)),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
              child: AppSearchField(
                controller: _searchController,
                hint: 'Нэр, гэрээний дугаар хайх...',
                onChanged: (v) => setState(() => _searchQuery = v.toLowerCase()),
              ),
            ),
          ),
          SliverToBoxAdapter(child: _buildFilterTabs(filter)),
          _buildAgreementsList(agreementsAsync),
        ],
      ),
    );
  }

  Widget _buildAppBar(BuildContext context, dynamic user) {
    return SliverAppBar(
      floating: true,
      snap: true,
      backgroundColor: context.appSurface,
      elevation: 0,
      title: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            'Сайн байна уу,',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(color: context.appTextTertiary),
          ),
          Text(
            user?.shortName?.isNotEmpty == true ? user!.shortName : 'Хэрэглэгч',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
          ),
        ],
      ),
      actions: [
        IconButton(
          icon: Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: context.appInputFill,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(Icons.refresh_rounded, size: 20, color: context.appTextSecondary),
          ),
          onPressed: () => ref.refresh(agreementsProvider),
        ),
        const SizedBox(width: 8),
      ],
      bottom: user?.baiguullagiinId?.isNotEmpty == true
          ? PreferredSize(
              preferredSize: const Size.fromHeight(44),
              child: _OrgBuildingBar(user: user),
            )
          : null,
    );
  }

  Widget _buildSummaryCards(List<AgreementModel>? agreements) {
    if (agreements == null) return const SizedBox.shrink();

    final total = agreements.length;
    final active = agreements.where((a) => a.isActive).length;
    final totalDebt = agreements.fold<double>(0, (sum, a) => sum + (a.uldegdel > 0 ? a.uldegdel : 0));
    final debtCount = agreements.where((a) => a.uldegdel > 0).length;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
      child: Row(
        children: [
          Expanded(child: _SummaryCard(
            icon: Icons.assignment_rounded,
            label: 'Нийт гэрээ',
            value: '$total',
            color: AppColors.primary,
            bgColor: AppColors.primaryContainer,
          )),
          const SizedBox(width: 10),
          Expanded(child: _SummaryCard(
            icon: Icons.check_circle_rounded,
            label: 'Идэвхтэй',
            value: '$active',
            color: AppColors.success,
            bgColor: AppColors.successLight,
          )),
          const SizedBox(width: 10),
          Expanded(child: _SummaryCard(
            icon: Icons.warning_rounded,
            label: 'Нийт үлдэгдэл',
            value: debtCount > 0 ? AppFormatters.currency(totalDebt) : '—',
            color: AppColors.error,
            bgColor: AppColors.errorLight,
            small: totalDebt > 999999,
          )),
        ],
      ),
    );
  }

  Widget _buildFilterTabs(int? currentFilter) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
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

  Widget _buildAgreementsList(AsyncValue<List<AgreementModel>> agreementsAsync) {
    return agreementsAsync.when(
      loading: () => const SliverFillRemaining(child: ShimmerList()),
      error: (err, _) => SliverFillRemaining(
        child: AppErrorWidget(
          message: 'Гэрээнүүд ачаалахад алдаа гарлаа',
          onRetry: () => ref.refresh(agreementsProvider),
        ),
      ),
      data: (agreements) {
        var filtered = _searchQuery.isEmpty
            ? agreements
            : agreements.where((a) =>
                a.tenantName.toLowerCase().contains(_searchQuery) ||
                a.gereeniiDugaar.toLowerCase().contains(_searchQuery)).toList();

        if (filtered.isEmpty) {
          return SliverFillRemaining(
            child: AppEmpty(
              icon: Icons.assignment_outlined,
              message: _searchQuery.isNotEmpty ? 'Хайлтын үр дүн олдсонгүй' : 'Гэрээ байхгүй байна',
            ),
          );
        }

        return SliverPadding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 32),
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

class _OrgBuildingBar extends StatelessWidget {
  final dynamic user;

  const _OrgBuildingBar({required this.user});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
      child: Row(
        children: [
          Icon(Icons.business_rounded, size: 13, color: context.appTextTertiary),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              user?.baiguullagiinId ?? '',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: context.appTextTertiary,
                fontSize: 11,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(width: 8),
          Icon(Icons.apartment_rounded, size: 13, color: context.appTextTertiary),
          const SizedBox(width: 4),
          Text(
            user?.barilgiinId ?? '',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: context.appTextTertiary,
              fontSize: 11,
            ),
          ),
        ],
      ),
    );
  }
}

class _SummaryCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color color;
  final Color bgColor;
  final bool small;

  const _SummaryCard({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
    required this.bgColor,
    this.small = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: context.appCardBg,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: context.appDivider),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 8, offset: const Offset(0, 2)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(color: bgColor, borderRadius: BorderRadius.circular(10)),
            child: Icon(icon, color: color, size: 18),
          ),
          const SizedBox(height: 10),
          Text(
            label,
            style: Theme.of(context).textTheme.labelSmall?.copyWith(color: context.appTextTertiary),
          ),
          const SizedBox(height: 2),
          Text(
            value,
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w700,
              color: context.appTextPrimary,
              fontSize: small ? 11 : 13,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
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
