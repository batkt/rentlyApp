import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/formatters.dart';
import '../../../data/models/agreement_model.dart';
import '../../providers/agreement_provider.dart';
import '../../widgets/common/app_loading.dart';

class AgreementDetailScreen extends ConsumerStatefulWidget {
  final String agreementId;
  final AgreementModel? initialData;

  const AgreementDetailScreen({
    super.key,
    required this.agreementId,
    this.initialData,
  });

  @override
  ConsumerState<AgreementDetailScreen> createState() => _AgreementDetailScreenState();
}

class _AgreementDetailScreenState extends ConsumerState<AgreementDetailScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final agreementAsync = widget.initialData != null
        ? AsyncValue.data(widget.initialData)
        : ref.watch(agreementDetailProvider(widget.agreementId));

    return Scaffold(
      body: agreementAsync.when(
        loading: () => const AppLoading(message: 'Ачаалж байна...'),
        error: (err, _) => AppErrorWidget(
          message: 'Мэдээлэл ачаалахад алдаа гарлаа',
          onRetry: () => ref.refresh(agreementDetailProvider(widget.agreementId)),
        ),
        data: (agreement) {
          if (agreement == null) return const AppEmpty(message: 'Гэрээ олдсонгүй');
          return _buildContent(context, ref, agreement);
        },
      ),
    );
  }

  Widget _buildContent(BuildContext context, WidgetRef ref, AgreementModel agreement) {
    final uldegdelAsync = ref.watch(uldegdelProvider((
      gereeniiDugaar: agreement.gereeniiDugaar,
      barilgiinId: agreement.barilgiinId,
    )));

    final realUldegdel = uldegdelAsync.whenOrNull(
      data: (d) => double.tryParse(d['uldegdel']?.toString() ?? '0') ?? 0.0,
    ) ?? agreement.uldegdel;

    final hasDebt = realUldegdel > 0;

    return NestedScrollView(
      headerSliverBuilder: (context, innerBoxIsScrolled) => [
        SliverAppBar(
          pinned: true,
          backgroundColor: AppColors.primary,
          foregroundColor: Colors.white,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_rounded, color: Colors.white),
            onPressed: () => context.pop(),
          ),
          title: Text(
            'Гэрээний дэлгэрэнгүй',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(color: Colors.white),
          ),
          actions: [
            if (agreement.isActive)
              TextButton.icon(
                onPressed: () => context.push('/payment', extra: agreement),
                icon: const Icon(Icons.payment_rounded, size: 16, color: Colors.white),
                label: const Text('Төлөх', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
              ),
          ],
          expandedHeight: 220,
          flexibleSpace: FlexibleSpaceBar(
            background: Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [AppColors.primaryDark, AppColors.primary],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
              ),
              child: SafeArea(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 60, 20, 16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: agreement.isActive
                                  ? Colors.white.withOpacity(0.25)
                                  : Colors.white.withOpacity(0.15),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Text(
                              agreement.isActive ? 'Идэвхтэй' : 'Дуусгавар',
                              style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w600),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        agreement.tenantName,
                        style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.w700),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        agreement.gereeniiDugaar,
                        style: const TextStyle(color: Colors.white70, fontSize: 13),
                      ),
                      const SizedBox(height: 12),
                      _BalanceBadge(uldegdel: realUldegdel, hasDebt: hasDebt, isLoading: uldegdelAsync.isLoading),
                    ],
                  ),
                ),
              ),
            ),
          ),
          bottom: TabBar(
            controller: _tabController,
            indicatorColor: Colors.white,
            labelColor: Colors.white,
            unselectedLabelColor: Colors.white60,
            tabs: const [
              Tab(text: 'Мэдээлэл'),
              Tab(text: 'Гүйлгээ'),
              Tab(text: 'Хуулга'),
            ],
          ),
        ),
      ],
      body: TabBarView(
        controller: _tabController,
        children: [
          _InfoTab(agreement: agreement),
          _TransactionsTab(agreement: agreement),
          _InvoiceTab(agreement: agreement),
        ],
      ),
    );
  }
}

class _BalanceBadge extends StatelessWidget {
  final double uldegdel;
  final bool hasDebt;
  final bool isLoading;

  const _BalanceBadge({required this.uldegdel, required this.hasDebt, required this.isLoading});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.15),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.white.withOpacity(0.3)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                hasDebt ? Icons.warning_rounded : Icons.check_circle_rounded,
                color: Colors.white,
                size: 16,
              ),
              const SizedBox(width: 8),
              if (isLoading)
                const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                )
              else
                Text(
                  AppFormatters.currency(uldegdel),
                  style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w800),
                ),
              const SizedBox(width: 6),
              Text(
                hasDebt ? 'өр' : 'хэвийн',
                style: const TextStyle(color: Colors.white70, fontSize: 12),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _InfoTab extends StatelessWidget {
  final AgreementModel agreement;

  const _InfoTab({required this.agreement});

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _Section(
          title: 'Гэрээний мэдээлэл',
          icon: Icons.assignment_rounded,
          children: [
            if (agreement.register != null && agreement.register!.isNotEmpty)
              _Row(icon: Icons.badge_rounded, label: 'Регистр', value: agreement.register!),
            _Row(
              icon: Icons.phone_rounded,
              label: 'Утас',
              value: agreement.utas.isNotEmpty ? AppFormatters.phone(agreement.utas.first) : '-',
            ),
            if (agreement.talbainDugaar != null)
              _Row(icon: Icons.door_front_door_rounded, label: 'Тасалгаа', value: agreement.talbainDugaar!),
            if (agreement.davkhar != null)
              _Row(icon: Icons.layers_rounded, label: 'Давхар', value: agreement.davkhar!),
            if (agreement.talbainKhemjee != null)
              _Row(icon: Icons.square_foot_rounded, label: 'Талбай', value: '${agreement.talbainKhemjee} м²'),
            if (agreement.uneKhemjee != null)
              _Row(icon: Icons.monetization_on_rounded, label: 'Сарын түрээс', value: AppFormatters.currency(agreement.uneKhemjee)),
            if (agreement.gereeniiOgnoo != null)
              _Row(icon: Icons.calendar_today_rounded, label: 'Эхэлсэн огноо', value: AppFormatters.date(agreement.gereeniiOgnoo)),
            if (agreement.duusakhOgnoo != null)
              _Row(icon: Icons.event_busy_rounded, label: 'Дуусах огноо', value: AppFormatters.date(agreement.duusakhOgnoo)),
            if (agreement.khugatsaa != null)
              _Row(icon: Icons.timer_rounded, label: 'Хугацаа', value: '${agreement.khugatsaa} сар'),
          ],
        ),
        if (agreement.zardluud.isNotEmpty) ...[
          const SizedBox(height: 16),
          _Section(
            title: 'Зардлын мэдээлэл',
            icon: Icons.receipt_rounded,
            children: agreement.zardluud.map((z) => _Row(
              icon: Icons.circle_rounded,
              label: z.ner,
              value: AppFormatters.currency(z.dun),
            )).toList(),
          ),
        ],
        const SizedBox(height: 32),
      ],
    );
  }
}

class _TransactionsTab extends StatelessWidget {
  final AgreementModel agreement;

  const _TransactionsTab({required this.agreement});

  @override
  Widget build(BuildContext context) {
    final txs = agreement.avlaga;

    if (txs.isEmpty) {
      return const AppEmpty(
        icon: Icons.receipt_long_outlined,
        message: 'Гүйлгээ байхгүй байна',
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: txs.length,
      separatorBuilder: (_, __) => const SizedBox(height: 8),
      itemBuilder: (context, index) {
        final tx = txs[index];
        final isCharge = tx.dun > 0;
        return Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: context.appCardBg,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: context.appDivider),
          ),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: isCharge ? context.appErrorLight : context.appSuccessLight,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  isCharge ? Icons.arrow_upward_rounded : Icons.arrow_downward_rounded,
                  color: isCharge ? AppColors.error : AppColors.success,
                  size: 18,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      tx.tailbar ?? (isCharge ? 'Нэхэмжлэл' : 'Төлбөр'),
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600),
                    ),
                    if (tx.ognoo != null)
                      Text(AppFormatters.date(tx.ognoo), style: Theme.of(context).textTheme.bodySmall),
                  ],
                ),
              ),
              Text(
                '${isCharge ? '+' : '-'}${AppFormatters.currency(tx.dun.abs())}',
                style: TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 15,
                  color: isCharge ? AppColors.error : AppColors.success,
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _InvoiceTab extends ConsumerWidget {
  final AgreementModel agreement;

  const _InvoiceTab({required this.agreement});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final invoicesAsync = ref.watch(invoiceHistoryProvider(agreement.id));

    return invoicesAsync.when(
      loading: () => const ShimmerList(itemCount: 5, itemHeight: 72),
      error: (_, __) => AppErrorWidget(
        message: 'Хуулга ачаалахад алдаа гарлаа',
        onRetry: () => ref.refresh(invoiceHistoryProvider(agreement.id)),
      ),
      data: (invoices) {
        if (invoices.isEmpty) {
          return const AppEmpty(
            icon: Icons.receipt_outlined,
            message: 'Хуулга байхгүй байна',
          );
        }
        return ListView.separated(
          padding: const EdgeInsets.all(16),
          itemCount: invoices.length,
          separatorBuilder: (_, __) => const SizedBox(height: 8),
          itemBuilder: (context, index) {
            final inv = invoices[index];
            final tuluv = (inv['tuluv'] as num?)?.toInt() ?? 0;
            final isPaid = tuluv == 1;
            final amount = double.tryParse(inv['amount']?.toString() ?? '0') ?? 0.0;
            final createdAt = inv['createdAt']?.toString();

            return Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: context.appCardBg,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: context.appDivider),
              ),
              child: Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: isPaid ? context.appSuccessLight : context.appWarningLight,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(
                      isPaid ? Icons.check_circle_rounded : Icons.hourglass_empty_rounded,
                      color: isPaid ? AppColors.success : AppColors.warning,
                      size: 18,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          inv['tailbar']?.toString() ?? 'Нэхэмжлэл',
                          style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600),
                        ),
                        if (createdAt != null)
                          Text(AppFormatters.date(createdAt), style: Theme.of(context).textTheme.bodySmall),
                      ],
                    ),
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        AppFormatters.currency(amount),
                        style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15, color: context.appTextPrimary),
                      ),
                      Container(
                        margin: const EdgeInsets.only(top: 4),
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: isPaid ? context.appSuccessLight : context.appWarningLight,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          isPaid ? 'Төлөгдсөн' : 'Хүлээгдэж байна',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                            color: isPaid ? AppColors.success : AppColors.warning,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }
}

class _Section extends StatelessWidget {
  final String title;
  final IconData icon;
  final List<_Row> children;

  const _Section({required this.title, required this.icon, required this.children});

  @override
  Widget build(BuildContext context) {
    if (children.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, size: 18, color: AppColors.primary),
            const SizedBox(width: 8),
            Text(title, style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
          ],
        ),
        const SizedBox(height: 10),
        Container(
          decoration: BoxDecoration(
            color: context.appCardBg,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: context.appDivider),
          ),
          child: ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: children.length,
            separatorBuilder: (_, __) => const Divider(height: 1),
            itemBuilder: (_, i) => children[i],
          ),
        ),
      ],
    );
  }
}

class _Row extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _Row({required this.icon, required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return ListTile(
      dense: true,
      leading: Icon(icon, size: 17, color: AppColors.primary),
      title: Text(label, style: Theme.of(context).textTheme.bodySmall?.copyWith(color: context.appTextTertiary)),
      trailing: Text(
        value,
        style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600),
      ),
    );
  }
}
