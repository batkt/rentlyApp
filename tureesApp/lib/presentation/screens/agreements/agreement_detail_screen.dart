import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/constants/api_constants.dart';
import '../../../core/socket/socket_service.dart';
import '../../../data/models/agreement_model.dart';
import '../../../data/repositories/agreement_repository.dart';
import '../../providers/agreement_provider.dart';
import '../../providers/auth_provider.dart';
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
  String? _socketEvent;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      final user = ref.read(currentUserProvider);
      if (user != null) {
        _socketEvent = 'khariltsagch${user.id}';
        ref.read(socketServiceProvider).on(_socketEvent!, _onSocketEvent);
      }
    });
  }

  void _onSocketEvent(dynamic _) {
    if (!mounted) return;
    final initialData = widget.initialData;
    if (initialData != null) {
      ref.invalidate(niitUldegdelProvider((
        gereeniiDugaar: initialData.gereeniiDugaar,
        barilgiinId: initialData.barilgiinId,
      )));
    }
    ref.invalidate(agreementDetailProvider(widget.agreementId));
    ref.invalidate(transactionHistoryProvider(widget.agreementId));
  }

  @override
  void dispose() {
    _tabController.dispose();
    if (_socketEvent != null) {
      ref.read(socketServiceProvider).off(_socketEvent!, _onSocketEvent);
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final agreementAsync = ref.watch(agreementDetailProvider(widget.agreementId));
    final placeholder = widget.initialData;

    return Scaffold(
      body: agreementAsync.when(
        loading: () => placeholder != null
            ? _buildContent(context, ref, placeholder)
            : const AppLoading(message: 'Ачаалж байна...'),
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
    final uldegdelAsync = ref.watch(niitUldegdelProvider((
      gereeniiDugaar: agreement.gereeniiDugaar,
      barilgiinId: agreement.barilgiinId,
    )));
    final realUldegdel = uldegdelAsync.valueOrNull ?? agreement.uldegdel;
    final hasDebt = realUldegdel > 0;

    return RefreshIndicator(
      onRefresh: () async {
        ref.invalidate(agreementDetailProvider(widget.agreementId));
        ref.invalidate(transactionHistoryProvider(widget.agreementId));
        ref.invalidate(invoiceHistoryProvider(widget.agreementId));
        ref.invalidate(niitUldegdelProvider((
          gereeniiDugaar: agreement.gereeniiDugaar,
          barilgiinId: agreement.barilgiinId,
        )));
      },
      color: AppColors.primary,
      child: NestedScrollView(
        headerSliverBuilder: (context, innerBoxIsScrolled) => [
          SliverAppBar(
            pinned: true,
            snap: false,
            floating: false,
            backgroundColor: AppColors.primary,
            foregroundColor: Colors.white,
            elevation: 0,
            leading: IconButton(
              icon: const Icon(Icons.arrow_back_rounded, color: Colors.white),
              onPressed: () => context.pop(),
            ),
            title: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  agreement.tenantName,
                  style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w700),
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  agreement.gereeniiDugaar,
                  style: const TextStyle(color: Colors.white60, fontSize: 11),
                ),
              ],
            ),
            actions: [
              Container(
                margin: const EdgeInsets.only(right: 4),
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(agreement.isActive ? 0.2 : 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  agreement.isActive ? 'Идэвхтэй' : 'Дуусгавар',
                  style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w600),
                ),
              ),
              if (agreement.isActive)
                TextButton.icon(
                  onPressed: () => context.push('/payment', extra: agreement),
                  icon: const Icon(Icons.payment_rounded, size: 15, color: Colors.white),
                  label: const Text('Төлөх', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 13)),
                ),
            ],
            bottom: PreferredSize(
              preferredSize: const Size.fromHeight(90),
              child: Container(
                color: AppColors.primary,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 6, 16, 8),
                      child: Row(
                        children: [
                          _BalanceBadge(
                            uldegdel: realUldegdel,
                            hasDebt: hasDebt,
                            isLoading: uldegdelAsync.isLoading,
                          ),
                          const Spacer(),
                          if (agreement.uneKhemjee != null)
                            _InfoChip(icon: Icons.monetization_on_rounded, label: AppFormatters.currency(agreement.uneKhemjee)),
                        ],
                      ),
                    ),
                    TabBar(
                      controller: _tabController,
                      indicatorColor: Colors.white,
                      labelColor: Colors.white,
                      unselectedLabelColor: Colors.white60,
                      indicatorWeight: 2.5,
                      labelStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                      tabs: const [
                        Tab(text: 'Мэдээлэл'),
                        Tab(text: 'Гүйлгээ'),
                        Tab(text: 'Нэхэмжлэх'),
                        Tab(text: 'Файл'),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
        body: TabBarView(
          controller: _tabController,
          children: [
            _InfoTab(agreement: agreement),
            _TransactionsTab(agreement: agreement),
            _InvoiceTab(agreement: agreement),
            _FilesTab(agreement: agreement),
          ],
        ),
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
    const amber = Color(0xFFF59E0B);
    final iconColor = hasDebt ? amber : AppColors.success;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.12), blurRadius: 10, offset: const Offset(0, 3)),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            hasDebt ? Icons.warning_amber_rounded : Icons.check_circle_rounded,
            color: iconColor,
            size: 15,
          ),
          const SizedBox(width: 7),
          if (isLoading)
            const SizedBox(
              width: 14, height: 14,
              child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.primary),
            )
          else
            Text(
              AppFormatters.currency(uldegdel),
              style: const TextStyle(color: Color(0xFF1E293B), fontSize: 15, fontWeight: FontWeight.w800),
            ),
        ],
      ),
    );
  }
}

class _InfoChip extends StatelessWidget {
  final IconData icon;
  final String label;

  const _InfoChip({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.15),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 11, color: Colors.white70),
          const SizedBox(width: 4),
          Text(label, style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w500)),
        ],
      ),
    );
  }
}

// ────────────────────────────────────────────────────
// Info Tab
// ────────────────────────────────────────────────────

class _InfoTab extends StatelessWidget {
  final AgreementModel agreement;

  const _InfoTab({required this.agreement});

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(12),
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
              _Row(icon: Icons.door_front_door_rounded, label: 'Талбайн №', value: agreement.talbainDugaar!),
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

// ────────────────────────────────────────────────────
// Transactions Tab — grouped by month
// ────────────────────────────────────────────────────

String _turulNer(String? turul) {
  switch (turul) {
    case 'khuvaari': return 'Түрээс';
    case 'avlaga': return 'Авлага';
    case 'aldangi': return 'Алданги';
    case 'bank': return 'Банк';
    case 'qpay': return 'QPay';
    case 'khyamdral': return 'Хямдрал';
    case 'torguuli': return 'Торгууль';
    case 'voucher': return 'Ваучер';
    case 'barter': return 'Бартер';
    case 'baritsaa': return 'Барьцаа';
    case 'zalruulga': return 'Залруулга';
    case 'tulultBurtgekh': return 'Төлөлт';
    default: return turul ?? '-';
  }
}

class _TransactionsTab extends ConsumerWidget {
  final AgreementModel agreement;

  const _TransactionsTab({required this.agreement});

  static String _monthKey(String? dateStr) {
    if (dateStr == null) return '';
    try {
      final d = DateTime.parse(dateStr);
      return '${d.year}-${d.month.toString().padLeft(2, '0')}';
    } catch (_) {
      return '';
    }
  }

  static String _monthLabel(String? dateStr) {
    if (dateStr == null) return 'Тодорхойгүй';
    try {
      final d = DateTime.parse(dateStr);
      const months = ['1-р сар', '2-р сар', '3-р сар', '4-р сар', '5-р сар', '6-р сар',
        '7-р сар', '8-р сар', '9-р сар', '10-р сар', '11-р сар', '12-р сар'];
      return '${d.year} / ${months[d.month - 1]}';
    } catch (_) {
      return 'Тодорхойгүй';
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final txAsync = ref.watch(transactionHistoryProvider(agreement.id));

    return txAsync.when(
      loading: () => const ShimmerList(itemCount: 6, itemHeight: 72),
      error: (_, __) => AppErrorWidget(
        message: 'Гүйлгээний түүх ачаалахад алдаа гарлаа',
        onRetry: () => ref.refresh(transactionHistoryProvider(agreement.id)),
      ),
      data: (txs) {
        if (txs.isEmpty) {
          return const AppEmpty(icon: Icons.receipt_long_outlined, message: 'Гүйлгээ байхгүй байна');
        }

        // Group by month, newest first
        final grouped = <String, List<Map<String, dynamic>>>{};
        for (final tx in txs.reversed) {
          final dateStr = tx['ognoo']?.toString() ?? tx['guilgeeKhiisenOgnoo']?.toString();
          final key = _monthKey(dateStr);
          grouped.putIfAbsent(key, () => []).add(tx);
        }
        final keys = grouped.keys.toList()..sort((a, b) => b.compareTo(a));

        return ListView.builder(
          padding: const EdgeInsets.all(12),
          itemCount: keys.length,
          itemBuilder: (context, index) {
            final key = keys[index];
            final monthTxs = grouped[key]!;
            final firstDateStr = monthTxs.first['ognoo']?.toString()
                ?? monthTxs.first['guilgeeKhiisenOgnoo']?.toString();
            final label = _monthLabel(firstDateStr);

            // Total tulukhDun (charges) for the month — matches tureesShine "Төлөх дүн"
            const paymentTypes = {'bank', 'qpay', 'voucher', 'barter', 'baritsaa', 'zalruulga', 'tulultBurtgekh'};
            double totalTulukhDun = 0;
            for (final tx in monthTxs) {
              final turul = tx['turul']?.toString() ?? '';
              if (!paymentTypes.contains(turul) && turul != 'khyamdral') {
                totalTulukhDun += (tx['tulukhDun'] as num?)?.toDouble() ?? 0.0;
              }
            }

            return GestureDetector(
              onTap: () => showModalBottomSheet(
                context: context,
                isScrollControlled: true,
                backgroundColor: Colors.transparent,
                constraints: BoxConstraints(
                  maxWidth: MediaQuery.sizeOf(context).width > 600 ? 600 : double.infinity,
                ),
                builder: (_) => _MonthTransactionsSheet(monthLabel: label, txs: monthTxs),
              ),
              child: Container(
                margin: const EdgeInsets.only(bottom: 10),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                decoration: BoxDecoration(
                  color: context.appCardBg,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: context.appDivider),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 42, height: 42,
                      decoration: BoxDecoration(
                        color: AppColors.primary.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(Icons.calendar_month_rounded, color: AppColors.primary, size: 20),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(label, style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700)),
                          Text('${monthTxs.length} гүйлгээ',
                              style: Theme.of(context).textTheme.bodySmall?.copyWith(color: context.appTextTertiary)),
                        ],
                      ),
                    ),
                    if (totalTulukhDun > 0) ...[
                      Text(
                        AppFormatters.currency(totalTulukhDun),
                        style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14, color: AppColors.error),
                      ),
                      const SizedBox(width: 4),
                    ],
                    Icon(Icons.chevron_right_rounded, size: 20, color: context.appTextTertiary),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }
}

// ────────────────────────────────────────────────────
// Month transactions detail sheet
// ────────────────────────────────────────────────────

class _MonthTransactionsSheet extends StatelessWidget {
  final String monthLabel;
  final List<Map<String, dynamic>> txs;

  const _MonthTransactionsSheet({required this.monthLabel, required this.txs});

  static const _paymentTypes = {'bank', 'qpay', 'voucher', 'barter', 'baritsaa', 'zalruulga', 'tulultBurtgekh'};

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: context.appCardBg,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 36, height: 4,
            margin: const EdgeInsets.symmetric(vertical: 12),
            decoration: BoxDecoration(color: context.appDivider, borderRadius: BorderRadius.circular(2)),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
            child: Row(
              children: [
                const Icon(Icons.calendar_month_rounded, color: AppColors.primary, size: 20),
                const SizedBox(width: 8),
                Text(monthLabel,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
                const Spacer(),
                Text('${txs.length} гүйлгээ',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(color: context.appTextTertiary)),
              ],
            ),
          ),
          Divider(height: 16, color: context.appDivider),
          ConstrainedBox(
            constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.65),
            child: ListView.separated(
              shrinkWrap: true,
              padding: const EdgeInsets.only(bottom: 24),
              itemCount: txs.length,
              separatorBuilder: (_, __) => Divider(height: 1, color: context.appDivider),
              itemBuilder: (context, i) {
                final tx = txs[i];
                final turul = tx['turul']?.toString() ?? '';
                final isEkhniiUldegdel = tx['ekhniiUldegdelEsekh'] == true;
                final isPayment = _paymentTypes.contains(turul);
                final isKhyamdral = turul == 'khyamdral';
                final isAldangi = turul == 'aldangi';
                final tulukhDun = (tx['tulukhDun'] as num?)?.toDouble() ?? 0.0;
                final tulsunDun = (tx['tulsunDun'] as num?)?.toDouble() ?? 0.0;
                final tulsunAldangi = (tx['tulsunAldangi'] as num?)?.toDouble() ?? 0.0;
                final khyamdral = (tx['khyamdral'] as num?)?.toDouble() ?? 0.0;
                final rawUldegdel = (tx['uldegdel'] as num?)?.toDouble() ?? 0.0;
                final uldegdel = (isKhyamdral && rawUldegdel < 0) ? 0.0 : rawUldegdel;
                final ekhniiUldegdel = (tx['ekhniiUldegdel'] as num?)?.toDouble() ?? 0.0;
                final tailbar = tx['tailbar']?.toString() ?? '';
                final dateStr = tx['ognoo']?.toString() ?? tx['guilgeeKhiisenOgnoo']?.toString();
                final turulNer = isEkhniiUldegdel ? 'Эхний үлдэгдэл' : _turulNer(turul);
                final description = tailbar.isNotEmpty ? tailbar : turulNer;

                double displayAmount;
                if (isPayment) {
                  displayAmount = tulsunAldangi > 0 ? tulsunAldangi : (tulsunDun > 0 ? tulsunDun : tulukhDun);
                } else if (isKhyamdral) {
                  displayAmount = khyamdral > 0 ? khyamdral : tulukhDun;
                } else {
                  displayAmount = tulukhDun;
                }

                final amountColor = isEkhniiUldegdel
                    ? AppColors.info
                    : isPayment
                        ? AppColors.success
                        : isAldangi
                            ? AppColors.error
                            : context.appTextPrimary;

                final rowBg = isEkhniiUldegdel ? context.appInfoLight : Colors.transparent;

                return Container(
                  color: rowBg,
                  padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                  child: Row(
                    children: [
                      Container(
                        width: 38, height: 38,
                        decoration: BoxDecoration(
                          color: isEkhniiUldegdel
                              ? AppColors.info.withOpacity(0.15)
                              : (isPayment ? AppColors.success : isAldangi ? AppColors.error : AppColors.primary)
                                  .withOpacity(0.12),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Icon(
                          isEkhniiUldegdel
                              ? Icons.account_balance_wallet_rounded
                              : isPayment ? Icons.arrow_downward_rounded : Icons.arrow_upward_rounded,
                          size: 17,
                          color: isEkhniiUldegdel
                              ? AppColors.info
                              : isPayment ? AppColors.success : isAldangi ? AppColors.error : AppColors.primary,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              description,
                              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                fontWeight: FontWeight.w600,
                                color: isEkhniiUldegdel ? AppColors.info : isAldangi ? AppColors.error : null,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            Text(
                              dateStr != null ? AppFormatters.date(dateStr) : '-',
                              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                color: isEkhniiUldegdel ? AppColors.info.withOpacity(0.7) : context.appTextTertiary,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            AppFormatters.currency(displayAmount),
                            style: Theme.of(context).textTheme.titleSmall?.copyWith(
                              fontWeight: FontWeight.w700,
                              color: amountColor,
                            ),
                          ),
                          if (ekhniiUldegdel > 0)
                            Text(
                              'Эхн: ${AppFormatters.currency(ekhniiUldegdel)}',
                              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                color: context.appTextTertiary,
                                fontSize: 11,
                              ),
                            ),
                          if (uldegdel > 0)
                            Text(
                              'Үлд: ${AppFormatters.currency(uldegdel)}',
                              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                color: AppColors.error,
                                fontSize: 11,
                              ),
                            ),
                        ],
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

// ────────────────────────────────────────────────────
// Invoice Tab (Нэхэмжлэх) — grouped by month
// ────────────────────────────────────────────────────

class _InvoiceTab extends ConsumerWidget {
  final AgreementModel agreement;

  const _InvoiceTab({required this.agreement});

  static String _monthLabel(String? dateStr) {
    if (dateStr == null) return 'Тодорхойгүй';
    try {
      final d = DateTime.parse(dateStr);
      const months = ['1-р сар', '2-р сар', '3-р сар', '4-р сар', '5-р сар', '6-р сар',
        '7-р сар', '8-р сар', '9-р сар', '10-р сар', '11-р сар', '12-р сар'];
      return '${d.year} / ${months[d.month - 1]}';
    } catch (_) {
      return 'Тодорхойгүй';
    }
  }

  static String _monthKey(String? dateStr) {
    if (dateStr == null) return '';
    try {
      final d = DateTime.parse(dateStr);
      return '${d.year}-${d.month.toString().padLeft(2, '0')}';
    } catch (_) {
      return '';
    }
  }

  void _showDetail(BuildContext context, Map<String, dynamic> inv, AgreementModel agreement) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      isDismissible: true,
      backgroundColor: Colors.transparent,
      constraints: BoxConstraints(
        maxWidth: MediaQuery.sizeOf(context).width > 600 ? 600 : double.infinity,
      ),
      builder: (ctx) => _InvoiceDetailSheet(inv: inv, agreement: agreement),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final invoicesAsync = ref.watch(invoiceHistoryProvider(agreement.id));

    return invoicesAsync.when(
      loading: () => const ShimmerList(itemCount: 5, itemHeight: 72),
      error: (_, __) => AppErrorWidget(
        message: 'Нэхэмжлэх ачаалахад алдаа гарлаа',
        onRetry: () => ref.refresh(invoiceHistoryProvider(agreement.id)),
      ),
      data: (invoices) {
        if (invoices.isEmpty) {
          return const AppEmpty(icon: Icons.receipt_outlined, message: 'Нэхэмжлэх байхгүй байна');
        }

        final sorted = [...invoices]..sort((a, b) {
          final ad = (a['nekhemjlekhiinOgnoo'] ?? a['createdAt'] ?? '').toString();
          final bd = (b['nekhemjlekhiinOgnoo'] ?? b['createdAt'] ?? '').toString();
          return bd.compareTo(ad);
        });

        final List<dynamic> items = [];
        String? lastKey;
        for (final inv in sorted) {
          final dateStr = (inv['nekhemjlekhiinOgnoo'] ?? inv['createdAt'])?.toString();
          final key = _monthKey(dateStr);
          if (key != lastKey) {
            items.add(_MonthHeader(label: _monthLabel(dateStr)));
            lastKey = key;
          }
          items.add(inv);
        }

        return ListView.builder(
          padding: const EdgeInsets.all(12),
          itemCount: items.length,
          itemBuilder: (context, index) {
            final item = items[index];
            if (item is _MonthHeader) {
              return Padding(
                padding: EdgeInsets.only(top: index == 0 ? 0 : 12, bottom: 8),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: AppColors.primary.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(item.label, style: Theme.of(context).textTheme.labelSmall?.copyWith(color: AppColors.primary, fontWeight: FontWeight.w700)),
                    ),
                    const SizedBox(width: 8),
                    Expanded(child: Divider(color: context.appDivider)),
                  ],
                ),
              );
            }

            final inv = item as Map<String, dynamic>;
            final createdAt = inv['nekhemjlekhiinOgnoo']?.toString() ?? inv['createdAt']?.toString();
            final invMedeelel = inv['medeelel'] as Map<String, dynamic>?;
            final amount = (invMedeelel?['eneSardTulukhDun'] as num?)?.toDouble() ?? 0.0;

            return GestureDetector(
              onTap: () => _showDetail(context, inv, agreement),
              child: Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: context.appCardBg,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: context.appDivider),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 40, height: 40,
                      decoration: BoxDecoration(
                        color: AppColors.primary.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(Icons.receipt_long_rounded, color: AppColors.primary, size: 18),
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
                    Text(
                      AppFormatters.currency(amount),
                      style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15, color: context.appTextPrimary),
                    ),
                    const SizedBox(width: 6),
                    Icon(Icons.chevron_right_rounded, size: 18, color: context.appTextTertiary),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }
}

// ────────────────────────────────────────────────────
// Invoice Detail Bottom Sheet — fetches zadargaa on open
// ────────────────────────────────────────────────────

class _InvoiceDetailSheet extends ConsumerStatefulWidget {
  final Map<String, dynamic> inv;
  final AgreementModel agreement;

  const _InvoiceDetailSheet({required this.inv, required this.agreement});

  @override
  ConsumerState<_InvoiceDetailSheet> createState() => _InvoiceDetailSheetState();
}

class _InvoiceDetailSheetState extends ConsumerState<_InvoiceDetailSheet> {
  Map<String, dynamic>? _zadargaa;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _fetchZadargaa();
  }

  Future<void> _fetchZadargaa() async {
    try {
      final ognoo = widget.inv['nekhemjlekhiinOgnoo']?.toString()
          ?? widget.inv['createdAt']?.toString()
          ?? DateTime.now().toIso8601String();
      final repo = ref.read(agreementRepositoryProvider);
      final result = await repo.getTulburZadargaa(widget.agreement.id, ognoo);
      if (mounted) setState(() { _zadargaa = result; _loading = false; });
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final inv = widget.inv;
    final createdAt = inv['nekhemjlekhiinOgnoo']?.toString() ?? inv['createdAt']?.toString();
    final dans = inv['nekhemjlekhiinDans']?.toString();
    final invMedeelel = inv['medeelel'] as Map<String, dynamic>?;
    final talbainNiitUne = (invMedeelel?['talbainNiitUne'] as num?)?.toDouble() ?? 0.0;
    final rawZardluud = (invMedeelel?['zardluud'] as List?) ?? [];
    final breakdownItems = <Map<String, dynamic>>[
      if (talbainNiitUne > 0) {'tailbar': 'Түрээсийн төлбөр', 'tulukhDun': talbainNiitUne},
      for (final z in rawZardluud)
        if (z is Map && (z['tulukhDun'] as num? ?? 0) > 0)
          {'tailbar': z['tailbar']?.toString() ?? z['ner']?.toString() ?? '-', 'tulukhDun': (z['tulukhDun'] as num).toDouble()},
    ];

    final umnukhUrDun = ((_zadargaa?['umnukhSariinUrTulbur'] as List?)?.firstOrNull as Map?)?['uldegdel'];
    final umnukhTulsunDun = ((_zadargaa?['umnukhSariinTulsun'] as List?)?.firstOrNull as Map?)?['uldegdel'];
    final niitUldegdelRaw = ((_zadargaa?['niitUldegdel'] as List?)?.firstOrNull as Map?)?['uldegdel'];
    final eneSardRaw = ((_zadargaa?['eneSardTulukhDun'] as List?)?.firstOrNull as Map?)?['uldegdel'];

    final umnukhUldegdel = (umnukhUrDun as num?)?.toDouble() != null
        ? ((umnukhUrDun as num).toDouble()) - ((umnukhTulsunDun as num?)?.toDouble() ?? 0.0)
        : 0.0;
    final niitUldegdel = (niitUldegdelRaw as num?)?.toDouble() ?? 0.0;
    final eneSardTulukhDun = (eneSardRaw as num?)?.toDouble()
        ?? (invMedeelel?['eneSardTulukhDun'] as num?)?.toDouble()
        ?? 0.0;

    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.6,
      maxChildSize: 0.92,
      minChildSize: 0.35,
      builder: (ctx, scrollController) => Container(
        decoration: BoxDecoration(
          color: context.appCardBg,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          children: [
            Container(
              width: 36, height: 4,
              margin: const EdgeInsets.symmetric(vertical: 12),
              decoration: BoxDecoration(color: context.appDivider, borderRadius: BorderRadius.circular(2)),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Row(
                children: [
                  Icon(Icons.receipt_long_rounded, color: AppColors.primary, size: 20),
                  const SizedBox(width: 8),
                  Text(
                    'Нэхэмжлэлийн дэлгэрэнгүй',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            Expanded(
              child: _loading
                  ? const Center(child: CircularProgressIndicator())
                  : ListView(
                      controller: scrollController,
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      children: [
                        _InvDetailRow(label: 'Огноо', value: createdAt != null ? AppFormatters.date(createdAt) : '-'),
                        if (dans != null && dans.isNotEmpty)
                          _InvDetailRow(label: 'Дансны дугаар', value: dans),
                        if (umnukhUldegdel != 0)
                          _InvDetailRow(
                            label: 'Өмнөх төлбөрийн үлдэгдэл',
                            value: AppFormatters.currency(umnukhUldegdel),
                            valueColor: umnukhUldegdel > 0 ? AppColors.error : AppColors.success,
                          ),
                        _InvDetailRow(label: 'Энэ сарын төлбөр', value: AppFormatters.currency(eneSardTulukhDun)),
                        if (niitUldegdel > 0)
                          _InvDetailRow(
                            label: 'Нийт дүн',
                            value: AppFormatters.currency(niitUldegdel),
                            valueColor: AppColors.error,
                          ),
                        if (breakdownItems.isNotEmpty) ...[
                          const SizedBox(height: 16),
                          Text('Задаргаа', style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700)),
                          const SizedBox(height: 8),
                          Container(
                            decoration: BoxDecoration(
                              color: context.appSurface,
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(color: context.appDivider),
                            ),
                            child: Column(
                              children: [
                                for (int i = 0; i < breakdownItems.length; i++) ...[
                                  if (i > 0) Divider(height: 1, color: context.appDivider),
                                  Padding(
                                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                                    child: Row(
                                      children: [
                                        Expanded(child: Text(breakdownItems[i]['tailbar']?.toString() ?? '-', style: Theme.of(context).textTheme.bodyMedium)),
                                        Text(AppFormatters.currency((breakdownItems[i]['tulukhDun'] as num?)?.toDouble() ?? 0.0), style: const TextStyle(fontWeight: FontWeight.w600)),
                                      ],
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),
                        ],
                        const SizedBox(height: 32),
                      ],
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MonthHeader {
  final String label;
  const _MonthHeader({required this.label});
}

class _InvDetailRow extends StatelessWidget {
  final String label;
  final String value;
  final Color? valueColor;

  const _InvDetailRow({required this.label, required this.value, this.valueColor});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 140,
            child: Text(label, style: Theme.of(context).textTheme.bodySmall?.copyWith(color: context.appTextTertiary)),
          ),
          Expanded(
            child: Text(
              value,
              textAlign: TextAlign.right,
              style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600, color: valueColor),
            ),
          ),
        ],
      ),
    );
  }
}

// ────────────────────────────────────────────────────
// Files Tab (Файл) — images + PDFs/Excel with delete
// ────────────────────────────────────────────────────

class _FilesTab extends ConsumerStatefulWidget {
  final AgreementModel agreement;

  const _FilesTab({required this.agreement});

  @override
  ConsumerState<_FilesTab> createState() => _FilesTabState();
}

class _FilesTabState extends ConsumerState<_FilesTab> {
  bool _uploading = false;

  List<dynamic> get _zurguud {
    final localList = ref.watch(agreementZurguudProvider(widget.agreement.id));
    if (localList.isNotEmpty) return localList;
    return widget.agreement.zurguud;
  }

  Future<void> _pickAndUploadImages() async {
    final picker = ImagePicker();
    final picked = await picker.pickMultiImage(imageQuality: 85);
    if (picked.isEmpty) return;

    final remaining = 5 - _zurguud.length;
    if (remaining <= 0) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Файлын дээд тоо 5 байна')));
      return;
    }

    setState(() => _uploading = true);
    try {
      final repo = ref.read(agreementRepositoryProvider);
      final newIds = <String>[];
      for (final xfile in picked.take(remaining)) {
        final id = await repo.uploadImage(File(xfile.path), widget.agreement.baiguullagiinId);
        if (id.isNotEmpty) newIds.add(id);
      }
      if (newIds.isNotEmpty) {
        final merged = [..._zurguud, ...newIds];
        await repo.saveZurguud(widget.agreement.id, merged);
        ref.read(agreementZurguudProvider(widget.agreement.id).notifier).state = merged;
        ref.invalidate(agreementDetailProvider(widget.agreement.id));
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Зураг оруулахад алдаа: $e')));
    } finally {
      if (mounted) setState(() => _uploading = false);
    }
  }

  Future<void> _pickAndUploadFiles() async {
    final result = await FilePicker.platform.pickFiles(
      allowMultiple: true,
      type: FileType.custom,
      allowedExtensions: ['pdf', 'xlsx', 'xls', 'doc', 'docx'],
    );
    if (result == null || result.files.isEmpty) return;

    final remaining = 5 - _zurguud.length;
    if (remaining <= 0) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Файлын дээд тоо 5 байна')));
      return;
    }

    setState(() => _uploading = true);
    try {
      final repo = ref.read(agreementRepositoryProvider);
      final newEntries = <Map<String, dynamic>>[];
      for (final pf in result.files.take(remaining)) {
        if (pf.path == null) continue;
        final id = await repo.uploadFile(File(pf.path!), widget.agreement.baiguullagiinId, pf.name);
        if (id.isNotEmpty) {
          newEntries.add({'id': id, 'ner': pf.name, 'turul': 'pdf'});
        }
      }
      if (newEntries.isNotEmpty) {
        final merged = [..._zurguud, ...newEntries];
        await repo.saveZurguud(widget.agreement.id, merged);
        ref.read(agreementZurguudProvider(widget.agreement.id).notifier).state = merged;
        ref.invalidate(agreementDetailProvider(widget.agreement.id));
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Файл оруулахад алдаа: $e')));
    } finally {
      if (mounted) setState(() => _uploading = false);
    }
  }

  Future<void> _deleteItem(int index) async {
    final updated = List<dynamic>.from(_zurguud)..removeAt(index);
    setState(() => _uploading = true);
    try {
      final repo = ref.read(agreementRepositoryProvider);
      await repo.saveZurguud(widget.agreement.id, updated);
      ref.read(agreementZurguudProvider(widget.agreement.id).notifier).state = updated;
      ref.invalidate(agreementDetailProvider(widget.agreement.id));
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Устгахад алдаа: $e')));
    } finally {
      if (mounted) setState(() => _uploading = false);
    }
  }

  void _confirmDelete(BuildContext context, int index) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Устгах уу?'),
        content: const Text('Энэ файлыг устгах уу?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Үгүй')),
          TextButton(
            onPressed: () { Navigator.pop(context); _deleteItem(index); },
            child: Text('Тийм', style: TextStyle(color: AppColors.error)),
          ),
        ],
      ),
    );
  }

  Future<void> _openUrl(String url) async {
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  @override
  Widget build(BuildContext context) {
    final zurguud = _zurguud;
    final canAdd = zurguud.length < 5 && !_uploading;

    if (zurguud.isEmpty && !_uploading) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.folder_open_rounded, size: 56, color: context.appTextTertiary),
            const SizedBox(height: 12),
            Text('Файл байхгүй байна', style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: context.appTextTertiary)),
            const SizedBox(height: 20),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                FilledButton.icon(
                  onPressed: _pickAndUploadImages,
                  icon: const Icon(Icons.add_photo_alternate_rounded, size: 18),
                  label: const Text('Зураг нэмэх'),
                  style: FilledButton.styleFrom(backgroundColor: AppColors.primary),
                ),
                const SizedBox(width: 10),
                FilledButton.icon(
                  onPressed: _pickAndUploadFiles,
                  icon: const Icon(Icons.attach_file_rounded, size: 18),
                  label: const Text('Файл нэмэх'),
                  style: FilledButton.styleFrom(backgroundColor: Colors.blueGrey),
                ),
              ],
            ),
          ],
        ),
      );
    }

    if (_uploading && zurguud.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }

    final imageItems = <Map<String, dynamic>>[];
    final fileItems = <Map<String, dynamic>>[];
    for (int i = 0; i < zurguud.length; i++) {
      final item = zurguud[i];
      if (item is String) {
        imageItems.add({'index': i, 'id': item});
      } else if (item is Map) {
        fileItems.add({'index': i, ...Map<String, dynamic>.from(item)});
      }
    }

    return ListView(
      padding: const EdgeInsets.all(12),
      children: [
        if (imageItems.isNotEmpty) ...[
          Text('Зурагнууд', style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700)),
          const SizedBox(height: 8),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2, crossAxisSpacing: 8, mainAxisSpacing: 8, childAspectRatio: 1,
            ),
            itemCount: imageItems.length,
            itemBuilder: (_, i) {
              final item = imageItems[i];
              final idx = item['index'] as int;
              final imageUrl = ApiConstants.zuragAvya(widget.agreement.baiguullagiinId, item['id'] as String);
              return Stack(
                children: [
                  GestureDetector(
                    onTap: () => _openUrl(imageUrl),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: Image.network(
                        imageUrl,
                        fit: BoxFit.cover,
                        width: double.infinity,
                        height: double.infinity,
                        errorBuilder: (_, __, ___) => Container(
                          color: context.appSurface,
                          child: Icon(Icons.broken_image_rounded, color: context.appTextTertiary),
                        ),
                        loadingBuilder: (_, child, progress) => progress == null ? child
                            : Center(child: CircularProgressIndicator(
                                value: progress.expectedTotalBytes != null
                                    ? progress.cumulativeBytesLoaded / progress.expectedTotalBytes! : null)),
                      ),
                    ),
                  ),
                  Positioned(
                    top: 6, right: 6,
                    child: GestureDetector(
                      onTap: () => _confirmDelete(context, idx),
                      child: Container(
                        width: 26, height: 26,
                        decoration: BoxDecoration(color: Colors.black.withOpacity(0.6), shape: BoxShape.circle),
                        child: const Icon(Icons.close_rounded, color: Colors.white, size: 16),
                      ),
                    ),
                  ),
                ],
              );
            },
          ),
          const SizedBox(height: 16),
        ],

        if (fileItems.isNotEmpty) ...[
          Text('Файлууд', style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700)),
          const SizedBox(height: 8),
          ...fileItems.map((item) {
            final idx = item['index'] as int;
            final fileUrl = ApiConstants.fileAvya(widget.agreement.baiguullagiinId, item['id']?.toString() ?? '');
            final name = item['ner']?.toString() ?? 'Файл';
            final isExcel = name.endsWith('.xlsx') || name.endsWith('.xls');
            return Container(
              margin: const EdgeInsets.only(bottom: 8),
              decoration: BoxDecoration(
                color: context.appCardBg,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: context.appDivider),
              ),
              child: ListTile(
                leading: Icon(
                  isExcel ? Icons.table_chart_rounded : Icons.picture_as_pdf_rounded,
                  color: isExcel ? Colors.green.shade600 : Colors.red.shade600,
                  size: 28,
                ),
                title: Text(name, style: Theme.of(context).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600), maxLines: 1, overflow: TextOverflow.ellipsis),
                onTap: () => _openUrl(fileUrl),
                trailing: IconButton(
                  icon: const Icon(Icons.delete_outline_rounded, size: 20),
                  color: AppColors.error,
                  onPressed: () => _confirmDelete(context, idx),
                ),
              ),
            );
          }),
          const SizedBox(height: 8),
        ],

        Row(
          children: [
            if (canAdd)
              FilledButton.icon(
                onPressed: _uploading ? null : _pickAndUploadImages,
                icon: _uploading
                    ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : const Icon(Icons.add_photo_alternate_rounded, size: 18),
                label: const Text('Зураг'),
                style: FilledButton.styleFrom(backgroundColor: AppColors.primary),
              ),
            if (canAdd) ...[
              const SizedBox(width: 8),
              FilledButton.icon(
                onPressed: _uploading ? null : _pickAndUploadFiles,
                icon: const Icon(Icons.attach_file_rounded, size: 18),
                label: const Text('Файл'),
                style: FilledButton.styleFrom(backgroundColor: Colors.blueGrey),
              ),
            ],
            const SizedBox(width: 8),
            Text('${zurguud.length}/5', style: Theme.of(context).textTheme.bodySmall?.copyWith(color: context.appTextTertiary)),
          ],
        ),
      ],
    );
  }
}

// ────────────────────────────────────────────────────
// Shared UI widgets
// ────────────────────────────────────────────────────

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
            padding: EdgeInsets.zero,
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
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 17, color: AppColors.primary),
          const SizedBox(width: 10),
          Expanded(
            flex: 4,
            child: Padding(
              padding: const EdgeInsets.only(top: 1),
              child: Text(label, style: Theme.of(context).textTheme.bodySmall?.copyWith(color: context.appTextTertiary)),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            flex: 6,
            child: Text(
              value,
              textAlign: TextAlign.right,
              style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }
}
