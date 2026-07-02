import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:webview_flutter/webview_flutter.dart' as webview_flutter;
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
            backgroundColor: AppColors.primaryDark,
            foregroundColor: Colors.white,
            elevation: 0,
            flexibleSpace: Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [AppColors.primaryDark, AppColors.primary],
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                ),
              ),
            ),
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
                  maxLines: 2,
                  softWrap: true,
                ),
                Text(
                  agreement.gereeniiDugaar,
                  style: const TextStyle(color: Colors.white70, fontSize: 11),
                  maxLines: 1,
                  softWrap: true,
                ),
              ],
            ),
            actions: [
              Padding(
                padding: const EdgeInsets.only(right: 4),
                child: Icon(
                  agreement.isActive ? Icons.check_circle_rounded : Icons.cancel_rounded,
                  color: agreement.isActive ? const Color(0xFF69F0AE) : Colors.white38,
                  size: 18,
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
              preferredSize: const Size.fromHeight(46),
              child: TabBar(
                controller: _tabController,
                indicator: BoxDecoration(
                  color: Colors.white.withOpacity(0.22),
                  borderRadius: BorderRadius.circular(20),
                ),
                indicatorSize: TabBarIndicatorSize.tab,
                indicatorPadding: const EdgeInsets.symmetric(horizontal: 4, vertical: 5),
                dividerColor: Colors.transparent,
                labelColor: Colors.white,
                unselectedLabelColor: Colors.white60,
                labelStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                tabs: const [
                  Tab(text: 'Мэдээлэл'),
                  Tab(text: 'Гүйлгээ'),
                  Tab(text: 'Нэхэмжлэх'),
                  Tab(text: 'Файл'),
                ],
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
              icon: _zardalIcon(z.ner),
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

IconData _zardalIcon(String ner) {
  final n = ner.toLowerCase();
  if (n.contains('цахилгаан')) return Icons.bolt_rounded;
  if (n.contains('менежмент')) return Icons.manage_accounts_rounded;
  if (n.contains('засвар')) return Icons.build_rounded;
  if (n.contains('ус')) return Icons.water_drop_rounded;
  if (n.contains('дулаан')) return Icons.local_fire_department_rounded;
  if (n.contains('хог')) return Icons.delete_outline_rounded;
  return Icons.receipt_long_rounded;
}

String _turulNer(String? turul) {
  switch (turul) {
    case 'khuvaari': return 'Түрээсийн төлбөр';
    case 'avlaga': return 'Авлага';
    case 'aldangi': return 'Алданги';
    case 'bank': return 'Банк';
    case 'qpay': return 'QPay';
    case 'khyamdral': return 'Хямдрал';
    case 'khungulult': return 'Хөнгөлөлт';
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
      final d = DateTime.parse(dateStr).toLocal();
      return '${d.year}-${d.month.toString().padLeft(2, '0')}';
    } catch (_) {
      return '';
    }
  }

  static String _monthLabel(String? dateStr) {
    if (dateStr == null) return 'Тодорхойгүй';
    try {
      final d = DateTime.parse(dateStr).toLocal();
      const months = ['1-р сар', '2-р сар', '3-р сар', '4-р сар', '5-р сар', '6-р сар',
        '7-р сар', '8-р сар', '9-р сар', '10-р сар', '11-р сар', '12-р сар'];
      return '${d.year} / ${months[d.month - 1]}';
    } catch (_) {
      return 'Тодорхойгүй';
    }
  }

  // Balance shown per row in the month sheet resets to 0 at the start of
  // every month instead of carrying the account's overall running balance —
  // that total (niitUldegdel) already lives on Home/Payment, so this view
  // should only reflect that month's own charges/payments/discounts.
  //
  // monthTxs arrives newest-first (built from the API's chronological-ascending
  // order via .reversed at the call site), so reversing it back gives true
  // chronological order. We deliberately don't re-sort by date string instead —
  // several transactions can share the exact same day, which makes that
  // comparison ambiguous and scrambles same-day ordering.
  static List<Map<String, dynamic>> _perMonthUldegdel(List<Map<String, dynamic>> monthTxs) {
    final chronological = monthTxs.reversed;

    double uldegdel = 0;
    final computed = <Map<String, dynamic>, double>{};
    for (final tx in chronological) {
      final tulukhDun = (tx['tulukhDun'] as num?)?.toDouble() ?? 0.0;
      final tulsunDun = (tx['tulsunDun'] as num?)?.toDouble() ?? 0.0;
      final khyamdral = (tx['khyamdral'] as num?)?.toDouble() ?? 0.0;
      uldegdel = uldegdel + tulukhDun - tulsunDun - khyamdral;
      computed[tx] = uldegdel;
    }

    return monthTxs.map((tx) {
      final c = computed[tx];
      return c != null ? {...tx, '_perMonthUldegdel': c} : tx;
    }).toList();
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

            // Net balance for the month (charges minus discounts/payments) —
            // same figure as the detail sheet's final Үлд, so the summary card
            // and the drill-down agree.
            final enrichedMonthTxs = _perMonthUldegdel(monthTxs);
            final monthNetTotal = (enrichedMonthTxs.first['_perMonthUldegdel'] as num?)?.toDouble() ?? 0.0;

            return GestureDetector(
              onTap: () => showModalBottomSheet(
                context: context,
                isScrollControlled: true,
                backgroundColor: Colors.transparent,
                constraints: BoxConstraints(
                  maxWidth: MediaQuery.sizeOf(context).width > 600 ? 600 : double.infinity,
                ),
                builder: (_) => _MonthTransactionsSheet(monthLabel: label, txs: enrichedMonthTxs),
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
                    if (monthNetTotal != 0) ...[
                      Text(
                        AppFormatters.currency(monthNetTotal),
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 14,
                          color: monthNetTotal < 0 ? AppColors.success : AppColors.error,
                        ),
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
                final isKhyamdral = turul == 'khyamdral' || turul == 'khungulult';
                final isAldangi = turul == 'aldangi';
                final tulukhDun = (tx['tulukhDun'] as num?)?.toDouble() ?? 0.0;
                final tulsunDun = (tx['tulsunDun'] as num?)?.toDouble() ?? 0.0;
                final tulsunAldangi = (tx['tulsunAldangi'] as num?)?.toDouble() ?? 0.0;
                final khyamdral = (tx['khyamdral'] as num?)?.toDouble() ?? 0.0;
                final undsenDun = (tx['undsenDun'] as num?)?.toDouble() ?? 0.0;
                final staffName = tx['guilgeeKhiisenAjiltniiNer']?.toString() ?? '';
                final tulsunDans = tx['tulsunDans']?.toString() ?? '';
                // Per-month balance (resets to 0 each month — see _perMonthUldegdel).
                // Can go negative (e.g. a discount before any charge offsets it) —
                // that's shown as-is, not floored to 0.
                final uldegdel = (tx['_perMonthUldegdel'] as num?)?.toDouble()
                    ?? (tx['uldegdel'] as num?)?.toDouble() ?? 0.0;
                final ekhniiUldegdel = (tx['ekhniiUldegdel'] as num?)?.toDouble() ?? 0.0;
                final tailbar = tx['tailbar']?.toString() ?? '';
                final dateStr = tx['ognoo']?.toString() ?? tx['guilgeeKhiisenOgnoo']?.toString();
                final registeredDateStr = tx['guilgeeKhiisenOgnoo']?.toString();
                final turulNer = isEkhniiUldegdel ? 'Эхний үлдэгдэл' : _turulNer(turul);
                // khuvaari always shows "Түрээсийн төлбөр" matching web; others prefer tailbar
                final description = turul == 'khuvaari'
                    ? 'Түрээсийн төлбөр'
                    : (tailbar.isNotEmpty ? tailbar : turulNer);
                // Хэлбэр: matches web Khuulga — bank uses tulsunDans or aldangi label
                final helber = turul == 'bank'
                    ? (tulsunAldangi > 0
                        ? 'Төлсөн алданги'
                        : (tulsunDans.isNotEmpty && tulsunDans.trim() != '' ? tulsunDans : 'Банк'))
                    : (isPayment && turul != 'bank' ? turulNer : '');

                double displayAmount;
                if (isPayment) {
                  displayAmount = tulsunAldangi > 0 ? tulsunAldangi : (tulsunDun > 0 ? tulsunDun : tulukhDun);
                } else if (isKhyamdral) {
                  // Discounts reduce the month's balance — show as a negative amount.
                  displayAmount = -(khyamdral > 0 ? khyamdral : tulukhDun);
                } else {
                  displayAmount = tulukhDun;
                }

                // khungulult reduces balance → same green direction as payments
                final isCredit = isPayment || isKhyamdral;
                final amountColor = isEkhniiUldegdel
                    ? AppColors.info
                    : isCredit
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
                              : (isCredit ? AppColors.success : isAldangi ? AppColors.error : AppColors.primary)
                                  .withOpacity(0.12),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Icon(
                          isEkhniiUldegdel
                              ? Icons.account_balance_wallet_rounded
                              : isCredit ? Icons.arrow_downward_rounded : Icons.arrow_upward_rounded,
                          size: 17,
                          color: isEkhniiUldegdel
                              ? AppColors.info
                              : isCredit ? AppColors.success : isAldangi ? AppColors.error : AppColors.primary,
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
                            if (undsenDun > 0 && !isPayment && !isKhyamdral)
                              Text(
                                'Түрээс: ${AppFormatters.currency(undsenDun)}',
                                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                  color: context.appTextTertiary, fontSize: 11,
                                ),
                              ),
                            if (helber.isNotEmpty)
                              Text(
                                helber,
                                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                  color: context.appTextSecondary, fontSize: 11, fontStyle: FontStyle.italic,
                                ),
                              ),
                            if (staffName.isNotEmpty)
                              Text(
                                staffName,
                                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                  color: context.appTextTertiary, fontSize: 10,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
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
                          if (uldegdel != 0)
                            Text(
                              'Үлд: ${AppFormatters.currency(uldegdel)}',
                              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                color: uldegdel < 0 ? AppColors.success : AppColors.error,
                                fontSize: 11,
                              ),
                            ),
                          if (registeredDateStr != null && registeredDateStr.isNotEmpty)
                            Text(
                              AppFormatters.date(registeredDateStr),
                              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                color: context.appTextTertiary, fontSize: 10,
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
      final d = DateTime.parse(dateStr).toLocal();
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
      final d = DateTime.parse(dateStr).toLocal();
      return '${d.year}-${d.month.toString().padLeft(2, '0')}';
    } catch (_) {
      return '';
    }
  }

  void _showDetail(BuildContext context, Map<String, dynamic> inv, AgreementModel agreement) {
    // Go straight to the rendered invoice template when available — the
    // breakdown sheet is only a fallback for invoices without saved HTML.
    final htmlContent = inv['nekhemjlekh']?.toString() ?? inv['content']?.toString();
    if (htmlContent != null && htmlContent.isNotEmpty) {
      Navigator.of(context, rootNavigator: true).push(
        MaterialPageRoute(builder: (_) => _InvoiceHtmlScreen(html: htmlContent)),
      );
      return;
    }
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

        // Group by month (newest first)
        final grouped = <String, List<Map<String, dynamic>>>{};
        for (final inv in sorted) {
          final dateStr = (inv['nekhemjlekhiinOgnoo'] ?? inv['createdAt'])?.toString();
          final key = _monthKey(dateStr);
          grouped.putIfAbsent(key, () => []).add(inv);
        }
        final keys = grouped.keys.toList()..sort((a, b) => b.compareTo(a));

        return ListView.builder(
          padding: const EdgeInsets.all(12),
          itemCount: keys.length,
          itemBuilder: (context, index) {
            final key = keys[index];
            final monthInvoices = grouped[key]!;
            final firstDateStr = monthInvoices.first['nekhemjlekhiinOgnoo']?.toString()
                ?? monthInvoices.first['createdAt']?.toString();
            final label = _monthLabel(firstDateStr);

            return GestureDetector(
              onTap: () => showModalBottomSheet(
                context: context,
                isScrollControlled: true,
                backgroundColor: Colors.transparent,
                constraints: BoxConstraints(
                  maxWidth: MediaQuery.sizeOf(context).width > 600 ? 600 : double.infinity,
                ),
                builder: (_) => _MonthInvoicesSheet(
                  monthLabel: label,
                  invoices: monthInvoices,
                  agreement: agreement,
                  onShowDetail: (inv) => _showDetail(context, inv, agreement),
                ),
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
                      child: const Icon(Icons.receipt_long_rounded, color: AppColors.primary, size: 20),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(label, style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700)),
                          Text('${monthInvoices.length} нэхэмжлэл',
                              style: Theme.of(context).textTheme.bodySmall?.copyWith(color: context.appTextTertiary)),
                        ],
                      ),
                    ),
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
// Month invoices sheet — shows all invoices for a month
// ────────────────────────────────────────────────────

class _MonthInvoicesSheet extends StatelessWidget {
  final String monthLabel;
  final List<Map<String, dynamic>> invoices;
  final AgreementModel agreement;
  final void Function(Map<String, dynamic> inv) onShowDetail;

  const _MonthInvoicesSheet({
    required this.monthLabel,
    required this.invoices,
    required this.agreement,
    required this.onShowDetail,
  });

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
                const Icon(Icons.receipt_long_rounded, color: AppColors.primary, size: 20),
                const SizedBox(width: 8),
                Text(monthLabel,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
                const Spacer(),
                Text('${invoices.length} нэхэмжлэл',
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
              itemCount: invoices.length,
              separatorBuilder: (_, __) => Divider(height: 1, color: context.appDivider),
              itemBuilder: (context, i) {
                final inv = invoices[i];
                final createdAt = inv['nekhemjlekhiinOgnoo']?.toString() ?? inv['createdAt']?.toString();

                return GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () {
                    Navigator.of(context).pop();
                    onShowDetail(inv);
                  },
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 20),
                    child: Row(
                      children: [
                        Container(
                          width: 38, height: 38,
                          decoration: BoxDecoration(
                            color: AppColors.primary.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Icon(Icons.receipt_long_rounded, color: AppColors.primary, size: 18),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                inv['tailbar']?.toString() ?? 'Нэхэмжлэл',
                                style: Theme.of(context).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              if (createdAt != null)
                                Text(AppFormatters.date(createdAt),
                                    style: Theme.of(context).textTheme.bodySmall?.copyWith(color: context.appTextTertiary)),
                            ],
                          ),
                        ),
                        Icon(Icons.chevron_right_rounded, size: 16, color: context.appTextTertiary),
                      ],
                    ),
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
  @override
  Widget build(BuildContext context) {
    final inv = widget.inv;
    final createdAt = inv['nekhemjlekhiinOgnoo']?.toString() ?? inv['createdAt']?.toString();
    final dans = inv['nekhemjlekhiinDans']?.toString();
    final invMedeelel = inv['medeelel'] as Map<String, dynamic>?;

    // All values come directly from medeelel (already computed by backend)
    final umnukhUldegdel = (invMedeelel?['umnukhSariinUrTulbur'] as num?)?.toDouble() ?? 0.0;
    final eneSardTulukhDun = (invMedeelel?['eneSardTulukhDun'] as num?)?.toDouble() ?? 0.0;
    final niitUldegdel = (invMedeelel?['niitUldegdel'] as num?)?.toDouble() ?? 0.0;
    final aldangi = (invMedeelel?['aldangiinUldegdel'] as num?)?.toDouble() ?? 0.0;

    // Задаргаа: rent (after discount) + aldangi + other zardluud net of their discounts
    final talbainNiitUne = (invMedeelel?['talbainNiitUne'] as num?)?.toDouble() ?? 0.0;
    final rentDiscount = (invMedeelel?['khungulult'] as num?)?.toDouble() ?? 0.0;
    final rentNet = talbainNiitUne - rentDiscount;

    final rawZardluud = (invMedeelel?['zardluud'] as List?) ?? [];
    final breakdownItems = <Map<String, dynamic>>[
      if (rentNet > 0) {'tailbar': 'Түрээсийн төлбөр', 'dun': rentNet, 'discount': rentDiscount},
      if (aldangi > 0) {'tailbar': 'Алданги', 'dun': aldangi, 'discount': 0.0},
      for (final z in rawZardluud)
        if (z is Map) ...() {
          final tailbar = z['tailbar']?.toString() ?? '';
          // Skip Хөнгөлөлт — it's the rent discount already applied above
          if (tailbar == 'Хөнгөлөлт' || tailbar == 'Хөнгөлөлт') return [];
          final gross = (z['tulukhDun'] as num?)?.toDouble() ?? 0.0;
          final disc = (z['khungulult'] as num?)?.toDouble() ?? 0.0;
          final net = gross - disc;
          if (net <= 0 && gross <= 0) return [];
          return [{'tailbar': tailbar.isNotEmpty ? tailbar : '-', 'dun': net > 0 ? net : gross, 'discount': disc}];
        }(),
    ];

    final htmlContent = inv['nekhemjlekh']?.toString() ?? inv['content']?.toString();

    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.65,
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
                  Expanded(
                    child: Text(
                      'Нэхэмжлэлийн дэлгэрэнгүй',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
                    ),
                  ),
                  if (htmlContent != null && htmlContent.isNotEmpty)
                    TextButton.icon(
                      onPressed: () => Navigator.of(context, rootNavigator: true).push(
                        MaterialPageRoute(
                          builder: (_) => _InvoiceHtmlScreen(html: htmlContent),
                        ),
                      ),
                      icon: const Icon(Icons.open_in_new_rounded, size: 15),
                      label: const Text('Харах', style: TextStyle(fontSize: 12)),
                      style: TextButton.styleFrom(foregroundColor: AppColors.primary),
                    ),
                ],
              ),
            ),
            Divider(height: 16, color: context.appDivider),
            Expanded(
              child: ListView(
                controller: scrollController,
                padding: const EdgeInsets.symmetric(horizontal: 20),
                children: [
                  _InvDetailRow(label: 'Огноо', value: createdAt != null ? AppFormatters.date(createdAt) : '-'),
                  if (dans != null && dans.isNotEmpty)
                    _InvDetailRow(label: 'Дансны дугаар', value: dans),
                  if (umnukhUldegdel != 0)
                    _InvDetailRow(
                      label: 'Өмнөх үлдэгдэл',
                      value: AppFormatters.currency(umnukhUldegdel.abs()),
                      valueColor: umnukhUldegdel > 0 ? AppColors.error : AppColors.success,
                    ),
                  if (eneSardTulukhDun > 0)
                    _InvDetailRow(label: 'Энэ сарын төлбөр', value: AppFormatters.currency(eneSardTulukhDun)),
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
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          breakdownItems[i]['tailbar']?.toString() ?? '-',
                                          style: Theme.of(context).textTheme.bodyMedium,
                                        ),
                                        if ((breakdownItems[i]['discount'] as double? ?? 0) > 0)
                                          Text(
                                            'Хөнгөлөлт: -${AppFormatters.currency(breakdownItems[i]['discount'] as double)}',
                                            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                              color: AppColors.success,
                                              fontSize: 11,
                                            ),
                                          ),
                                      ],
                                    ),
                                  ),
                                  Text(
                                    AppFormatters.currency(breakdownItems[i]['dun'] as double? ?? 0),
                                    style: const TextStyle(fontWeight: FontWeight.w600),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],
                  // Totals block matching the print invoice layout (Дүн / НӨАТ / Нийт үнэ)
                  if (niitUldegdel > 0) ...[
                    const SizedBox(height: 16),
                    Container(
                      decoration: BoxDecoration(
                        color: context.appSurface,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: context.appDivider),
                      ),
                      child: () {
                        // НӨАТ = niitUldegdel - preTax (same 10% formula used by print invoice)
                        final preTax = niitUldegdel / 1.1;
                        final nuat = niitUldegdel - preTax;
                        return Column(
                          children: [
                            Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Text('Дүн', style: Theme.of(context).textTheme.bodyMedium),
                                  Text(AppFormatters.currency(preTax),
                                      style: const TextStyle(fontWeight: FontWeight.w600)),
                                ],
                              ),
                            ),
                            Divider(height: 1, color: context.appDivider),
                            Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Text('НӨАТ (10%)', style: Theme.of(context).textTheme.bodyMedium),
                                  Text(AppFormatters.currency(nuat),
                                      style: const TextStyle(fontWeight: FontWeight.w600)),
                                ],
                              ),
                            ),
                            Divider(height: 1, color: context.appDivider),
                            Container(
                              decoration: BoxDecoration(
                                color: AppColors.error.withOpacity(0.06),
                                borderRadius: const BorderRadius.vertical(bottom: Radius.circular(14)),
                              ),
                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Text('Нийт үнэ',
                                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                                        fontWeight: FontWeight.w700, color: AppColors.error)),
                                  Text(AppFormatters.currency(niitUldegdel),
                                      style: const TextStyle(
                                        fontSize: 15, fontWeight: FontWeight.w800, color: AppColors.error)),
                                ],
                              ),
                            ),
                          ],
                        );
                      }(),
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

// ────────────────────────────────────────────────────
// Full-screen HTML invoice viewer
// ────────────────────────────────────────────────────

class _InvoiceHtmlScreen extends StatefulWidget {
  final String html;
  const _InvoiceHtmlScreen({required this.html});

  @override
  State<_InvoiceHtmlScreen> createState() => _InvoiceHtmlScreenState();
}

class _InvoiceHtmlScreenState extends State<_InvoiceHtmlScreen> {
  late final webview_flutter.WebViewController _controller;

  @override
  void initState() {
    super.initState();
    _controller = webview_flutter.WebViewController()
      ..setJavaScriptMode(webview_flutter.JavaScriptMode.unrestricted)
      ..loadHtmlString(
        '<html><head><meta name="viewport" content="width=device-width,initial-scale=1,maximum-scale=1">'
        '<style>'
        'html,body{margin:0;padding:8px;font-family:sans-serif;max-width:100%;overflow-x:hidden;}'
        // The invoice template is authored for print (fixed-width tables/divs) —
        // force everything to shrink to the device width instead of overflowing.
        '*{box-sizing:border-box;}'
        'table{width:100% !important;table-layout:fixed;}'
        'img,table,div,p{max-width:100% !important;}'
        'td,th{word-break:break-word;}'
        '</style></head>'
        '<body>${widget.html}</body></html>',
      );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Нэхэмжлэх'),
        backgroundColor: AppColors.primaryDark,
        foregroundColor: Colors.white,
      ),
      body: webview_flutter.WebViewWidget(controller: _controller),
    );
  }
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
