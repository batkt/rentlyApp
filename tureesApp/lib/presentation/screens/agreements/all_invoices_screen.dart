import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/formatters.dart';
import '../../providers/agreement_provider.dart';
import '../../widgets/common/app_loading.dart';
import '../../widgets/common/sar_songolt.dart';
import 'agreement_detail_screen.dart' show InvoiceHtmlScreen, kAgreementInvoiceTab;

/// Which contract the list is narrowed to; null = бүх гэрээ.
final _shuultProvider = StateProvider.autoDispose<String?>((ref) => null);

/// Selected month (`2026-08`) and day; the day is only meaningful inside a
/// month, so picking a new month clears it.
final _sarProvider = StateProvider.autoDispose<String?>((ref) => null);
final _udurProvider = StateProvider.autoDispose<int?>((ref) => null);

/// Нэхэмжлэх of every contract in one place: pick a month, optionally a day.
class AllInvoicesScreen extends ConsumerWidget {
  const AllInvoicesScreen({super.key});

  void _open(BuildContext context, NekhemjlekhBichlegT bichleg) {
    final inv = bichleg.invoice;
    final html = inv['nekhemjlekh']?.toString() ?? inv['content']?.toString();
    if (html != null && html.isNotEmpty) {
      Navigator.of(context, rootNavigator: true).push(
        MaterialPageRoute(builder: (_) => InvoiceHtmlScreen(html: html)),
      );
      return;
    }
    // No saved template — the contract's own Нэхэмжлэх tab still has the
    // breakdown sheet for it.
    context.push('/agreements/${bichleg.agreement.id}?tab=$kAgreementInvoiceTab');
  }

  Future<void> _pickContract(
    BuildContext context,
    WidgetRef ref,
    List<NekhemjlekhBichlegT> bukh,
  ) async {
    final contracts = <String, String>{};
    for (final b in bukh) {
      contracts[b.agreement.id] = b.agreement.gereeniiDugaar +
          ((b.agreement.talbainDugaar ?? '').isNotEmpty ? ' · ${b.agreement.talbainDugaar}' : '');
    }
    final current = ref.read(_shuultProvider);

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: context.appCardBg,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (sheetContext) => SafeArea(
        child: ConstrainedBox(
          constraints: BoxConstraints(maxHeight: MediaQuery.sizeOf(sheetContext).height * 0.7),
          child: ListView(
            shrinkWrap: true,
            padding: const EdgeInsets.symmetric(vertical: 12),
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 4, 20, 12),
                child: Text(
                  'Гэрээгээр шүүх',
                  style: Theme.of(sheetContext).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                        color: sheetContext.appTextPrimary,
                      ),
                ),
              ),
              RadioListTile<String?>(
                value: null,
                groupValue: current,
                activeColor: AppColors.primary,
                title: Text('Бүх гэрээ', style: TextStyle(color: sheetContext.appTextPrimary)),
                onChanged: (v) {
                  ref.read(_shuultProvider.notifier).state = v;
                  Navigator.pop(sheetContext);
                },
              ),
              for (final entry in contracts.entries)
                RadioListTile<String?>(
                  value: entry.key,
                  groupValue: current,
                  activeColor: AppColors.primary,
                  title: Text(entry.value, style: TextStyle(color: sheetContext.appTextPrimary)),
                  onChanged: (v) {
                    ref.read(_shuultProvider.notifier).state = v;
                    Navigator.pop(sheetContext);
                  },
                ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final bukhAsync = ref.watch(bukhNekhemjlekhProvider);
    final shuult = ref.watch(_shuultProvider);

    return Scaffold(
      backgroundColor: context.appBackground,
      appBar: AppBar(
        title: const Text('Бүх нэхэмжлэх'),
        actions: [
          IconButton(
            tooltip: 'Гэрээгээр шүүх',
            icon: Icon(
              shuult == null ? Icons.filter_list_rounded : Icons.filter_list_off_rounded,
              color: shuult == null ? null : AppColors.primary,
            ),
            onPressed: () {
              final bukh = bukhAsync.valueOrNull;
              if (bukh == null || bukh.isEmpty) return;
              _pickContract(context, ref, bukh);
            },
          ),
        ],
      ),
      body: bukhAsync.when(
        loading: () => const ShimmerList(itemCount: 6, itemHeight: 76),
        error: (_, __) => AppErrorWidget(
          message: 'Нэхэмжлэх ачаалахад алдаа гарлаа',
          onRetry: () => ref.invalidate(bukhNekhemjlekhProvider),
        ),
        data: (bukh) {
          final jagsaalt = shuult == null
              ? bukh
              : bukh.where((b) => b.agreement.id == shuult).toList();

          if (jagsaalt.isEmpty) {
            return const AppEmpty(
              icon: Icons.receipt_outlined,
              message: 'Нэхэмжлэх байхгүй байна',
            );
          }

           
          final saruud = <String, List<NekhemjlekhBichlegT>>{};
          for (final b in jagsaalt) {
            final sariinMuruud = saruud.putIfAbsent(sariinTulkhuur(b.ognoo), () => []);
            if (sariinMuruud.any((m) => m.agreement.id == b.agreement.id)) continue;
            sariinMuruud.add(b);
          }
          final turluud = saruud.keys.toList();
          final sonssonSar = ref.watch(_sarProvider);
          final songosonSar = turluud.contains(sonssonSar) ? sonssonSar! : turluud.first;
          final sariinJagsaalt = saruud[songosonSar]!;

          final udruud = <int, int>{};
          for (final b in sariinJagsaalt) {
            final day = b.ognoo?.day;
            if (day != null) udruud[day] = (udruud[day] ?? 0) + 1;
          }
          final sonssonUdur = ref.watch(_udurProvider);
          final udur = udruud.containsKey(sonssonUdur) ? sonssonUdur : null;
          final muruud = udur == null
              ? sariinJagsaalt
              : sariinJagsaalt.where((b) => b.ognoo?.day == udur).toList();

          return Column(
            children: [
              SarSongolt(
                saruud: turluud,
                songoson: songosonSar,
                toolol: {for (final e in saruud.entries) e.key: e.value.length},
                onSelect: (key) {
                  ref.read(_sarProvider.notifier).state = key;
                  ref.read(_udurProvider.notifier).state = null;
                },
              ),
              UdriinKhuanli(
                sar: songosonSar,
                udruud: udruud,
                songoson: udur,
                onSelect: (u) => ref.read(_udurProvider.notifier).state = u,
              ),
              Expanded(
                child: RefreshIndicator(
                  color: AppColors.primary,
                  onRefresh: () async => ref.invalidate(bukhNekhemjlekhProvider),
                  child: muruud.isEmpty
                      ? const AppEmpty(
                          icon: Icons.receipt_outlined,
                          message: 'Энэ өдөр нэхэмжлэх байхгүй байна',
                        )
                      : Align(
                          alignment: Alignment.topCenter,
                          child: ConstrainedBox(
                            constraints: const BoxConstraints(maxWidth: 600),
                            child: ListView.builder(
                              padding: const EdgeInsets.fromLTRB(16, 4, 16, 32),
                              itemCount: muruud.length,
                              itemBuilder: (context, index) => _InvoiceRow(
                                bichleg: muruud[index],
                                onTap: () => _open(context, muruud[index]),
                              ),
                            ),
                          ),
                        ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _InvoiceRow extends StatelessWidget {
  final NekhemjlekhBichlegT bichleg;
  final VoidCallback onTap;

  const _InvoiceRow({required this.bichleg, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final agreement = bichleg.agreement;
    final medeelel = bichleg.invoice['medeelel'] as Map<String, dynamic>?;
    final dun = (medeelel?['niitUldegdel'] as num?)?.toDouble();
    final talbai = agreement.talbainDugaar ?? '';

    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
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
                color: context.appPrimaryContainer,
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.receipt_long_rounded, size: 20, color: AppColors.primary),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    talbai.isEmpty
                        ? agreement.gereeniiDugaar
                        : '${agreement.gereeniiDugaar} · $talbai',
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w700,
                          color: context.appTextPrimary,
                        ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    AppFormatters.date(bichleg.ognoo),
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: context.appTextTertiary,
                        ),
                  ),
                ],
              ),
            ),
            if (dun != null && dun > 0) ...[
              const SizedBox(width: 8),
              Text(
                AppFormatters.currency(dun),
                style: const TextStyle(fontWeight: FontWeight.w700, color: AppColors.error),
              ),
            ],
            Icon(Icons.chevron_right_rounded, size: 18, color: context.appTextTertiary),
          ],
        ),
      ),
    );
  }
}
