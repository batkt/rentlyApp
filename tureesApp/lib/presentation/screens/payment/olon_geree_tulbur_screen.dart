import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/app_snackbar.dart';
import '../../../core/utils/formatters.dart';
import '../../../data/models/agreement_model.dart';
import '../../../data/repositories/agreement_repository.dart';
import '../../providers/payment_provider.dart';
import '../../widgets/common/app_button.dart';

final _numFmt = NumberFormat('#,##0.00', 'mn');

/// Сонгосон гэрээ бүрийн бодит үлдэгдэл ба төлөх данс.
class _GereeniiTulbur {
  final AgreementModel geree;
  final double uldegdel;
  final String? dans;
  final TextEditingController dunController;

  _GereeniiTulbur({
    required this.geree,
    required this.uldegdel,
    required this.dans,
  }) : dunController = TextEditingController(
            text: uldegdel > 0 ? _numFmt.format(uldegdel) : '');

  double? get dun => double.tryParse(
      dunController.text.replaceAll(',', '').replaceAll(' ', ''));
}

/// Нэг QPay нэхэмжлэх зөвхөн нэг барилга, нэг данс руу явна — тиймээс
/// гэрээнүүдийг (барилга, данс)-аар бүлэглэж, бүлэг тус бүрээр төлүүлнэ.
class _DansniiBuleg {
  final String barilgiinId;
  final String dans;
  final List<_GereeniiTulbur> gereenuud;

  _DansniiBuleg(this.barilgiinId, this.dans, this.gereenuud);
}

class OlonGereeTulburScreen extends ConsumerStatefulWidget {
  final List<AgreementModel> gereenuud;

  const OlonGereeTulburScreen({super.key, required this.gereenuud});

  @override
  ConsumerState<OlonGereeTulburScreen> createState() =>
      _OlonGereeTulburScreenState();
}

class _OlonGereeTulburScreenState extends ConsumerState<OlonGereeTulburScreen> {
  bool _achaalj = true;
  List<_GereeniiTulbur> _muruud = [];

  /// Аль бүлгийн нэхэмжлэхийг үүсгэж байгаа (товчны ачаалал харуулах).
  String? _tulj;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) ref.read(paymentNotifierProvider.notifier).reset();
    });
    _achaalya();
  }

  @override
  void dispose() {
    for (final m in _muruud) {
      m.dunController.dispose();
    }
    super.dispose();
  }

  /// PaymentScreen._fetchRealUldegdel-тэй ижил эх сурвалж: сүүлийн
  /// нэхэмжлэлийн данс, байхгүй бол гэрээний данс; үлдэгдэл алдангитай.
  Future<_GereeniiTulbur> _gereeAchaalya(AgreementModel a) async {
    final repo = ref.read(agreementRepositoryProvider);
    String? dans;
    double uldegdel = a.uldegdel;
    try {
      final info = await repo.getLatestInvoiceInfo(a.id);
      final invoiceDans = info.dansniiDugaar;
      dans = (invoiceDans != null && invoiceDans.isNotEmpty)
          ? invoiceDans
          : a.dans;
      try {
        final uld = await repo.getUldegdelInfo(
          a.gereeniiDugaar,
          a.barilgiinId,
          tsutsalsan: a.tuluv == -1,
        );
        // Илүү төлөгдсөн түрээс алдангийг нөхөхгүй (payment_screen-тэй ижил).
        uldegdel = (uld.uldegdel > 0 ? uld.uldegdel : 0) + uld.aldangi;
      } catch (_) {
        uldegdel = info.niitUldegdel ?? a.uldegdel;
      }
    } catch (_) {
      dans = a.dans;
    }
    return _GereeniiTulbur(geree: a, uldegdel: uldegdel, dans: dans);
  }

  Future<void> _achaalya() async {
    final muruud = await Future.wait(widget.gereenuud.map(_gereeAchaalya));
    if (!mounted) return;
    setState(() {
      _muruud = muruud;
      _achaalj = false;
    });
  }

  List<_DansniiBuleg> get _buleguud {
    final map = <String, _DansniiBuleg>{};
    for (final m in _muruud) {
      final dans = m.dans;
      if (dans == null || dans.isEmpty) continue;
      final key = '${m.geree.barilgiinId}|$dans';
      map.putIfAbsent(
          key, () => _DansniiBuleg(m.geree.barilgiinId, dans, [])).gereenuud.add(m);
    }
    return map.values.toList();
  }

  List<_GereeniiTulbur> get _dansgui =>
      _muruud.where((m) => m.dans == null || m.dans!.isEmpty).toList();

  Future<void> _tulukh(_DansniiBuleg buleg) async {
    // Дүн шалгах: 0-ээс их, үлдэгдлээс хэтрэхгүй.
    final gereenuud = <({String gereeniiId, double dun})>[];
    for (final m in buleg.gereenuud) {
      final dun = m.dun;
      if (dun == null || dun <= 0) {
        _aldaa('${m.geree.gereeniiDugaar}: дүн оруулна уу');
        return;
      }
      if (m.uldegdel > 0 && dun > m.uldegdel + 0.01) {
        _aldaa('${m.geree.gereeniiDugaar}: үлдэгдлээс '
            '(${AppFormatters.currency(m.uldegdel)}) их дүн төлөх боломжгүй');
        return;
      }
      gereenuud.add((gereeniiId: m.geree.id, dun: dun));
    }

    FocusScope.of(context).unfocus();
    setState(() => _tulj = buleg.dans + buleg.barilgiinId);
    final notifier = ref.read(paymentNotifierProvider.notifier);
    final ekhnii = buleg.gereenuud.first.geree;
    if (gereenuud.length == 1) {
      await notifier.generateQpay(
        gereeniiId: ekhnii.id,
        barilgiinId: ekhnii.barilgiinId,
        register: ekhnii.register ?? '',
        amount: gereenuud.first.dun,
        dansniiDugaar: buleg.dans,
      );
    } else {
      await notifier.generateOlonQpay(
        barilgiinId: buleg.barilgiinId,
        register: ekhnii.register ?? '',
        dansniiDugaar: buleg.dans,
        gereenuud: gereenuud,
      );
    }
    if (!mounted) return;
    setState(() => _tulj = null);

    final state = ref.read(paymentNotifierProvider);
    if (state.invoice != null) {
      context.push('/qpay', extra: state.invoice);
    } else {
      _aldaa(state.error ?? 'Qpay нэхэмжлэх үүсгэхэд алдаа гарлаа');
    }
  }

  void _aldaa(String msg) =>
      showAppSnackBar(context, msg, turul: SnackTurul.aldaa);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final buleguud = _achaalj ? const <_DansniiBuleg>[] : _buleguud;
    final dansgui = _achaalj ? const <_GereeniiTulbur>[] : _dansgui;

    return Scaffold(
      backgroundColor: context.appBackground,
      appBar: AppBar(title: const Text('Олон гэрээ төлөх')),
      body: _achaalj
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
              children: [
                if (buleguud.length > 1)
                  _Sanuulga(
                    icon: Icons.warning_amber_rounded,
                    color: AppColors.warning,
                    title: 'Өөр өөр дансанд төлөгдөнө',
                    text: 'Сонгосон гэрээнүүд ${buleguud.length} өөр дансанд '
                        'төлөгддөг. Нэг QR кодоор зөвхөн нэг данс руу төлөх '
                        'боломжтой тул данс тус бүрээр тусад нь төлнө үү.',
                  ),
                if (dansgui.isNotEmpty)
                  _Sanuulga(
                    icon: Icons.error_outline_rounded,
                    color: AppColors.error,
                    title: 'Төлбөрийн данс олдсонгүй',
                    text: '${dansgui.map((m) => m.geree.gereeniiDugaar).join(', ')} '
                        'гэрээний төлбөрийн данс олдсонгүй. Менежертэй холбогдоно уу.',
                  ),
                for (final (i, buleg) in buleguud.indexed) ...[
                  _BulegKart(
                    buleg: buleg,
                    garchig: buleguud.length > 1 ? 'Данс ${i + 1}' : null,
                    tulj: _tulj == buleg.dans + buleg.barilgiinId,
                    idevkhgui: _tulj != null,
                    onChanged: () => setState(() {}),
                    onTulukh: () => _tulukh(buleg),
                  ),
                  const SizedBox(height: 14),
                ],
                if (buleguud.isEmpty && dansgui.isEmpty)
                  Padding(
                    padding: const EdgeInsets.all(24),
                    child: Text('Төлөх гэрээ олдсонгүй',
                        textAlign: TextAlign.center,
                        style: theme.textTheme.bodyMedium),
                  ),
              ],
            ),
    );
  }
}

class _Sanuulga extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String title;
  final String text;

  const _Sanuulga({
    required this.icon,
    required this.color,
    required this.title,
    required this.text,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.4)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 22),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: theme.textTheme.titleSmall?.copyWith(
                        color: color, fontWeight: FontWeight.w700)),
                const SizedBox(height: 2),
                Text(text, style: theme.textTheme.bodySmall),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _BulegKart extends StatelessWidget {
  final _DansniiBuleg buleg;
  final String? garchig;
  final bool tulj;
  final bool idevkhgui;
  final VoidCallback onChanged;
  final VoidCallback onTulukh;

  const _BulegKart({
    required this.buleg,
    required this.garchig,
    required this.tulj,
    required this.idevkhgui,
    required this.onChanged,
    required this.onTulukh,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final niit =
        buleg.gereenuud.fold<double>(0, (a, m) => a + (m.dun ?? 0));
    return Container(
      decoration: BoxDecoration(
        color: context.appCardBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: context.appDivider),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
            child: Row(
              children: [
                const Icon(Icons.account_balance_rounded,
                    size: 18, color: AppColors.primary),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    [if (garchig != null) garchig!, 'Данс: ${buleg.dans}']
                        .join(' · '),
                    style: theme.textTheme.titleSmall
                        ?.copyWith(fontWeight: FontWeight.w700),
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          for (final m in buleg.gereenuud)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(m.geree.gereeniiDugaar,
                            style: theme.textTheme.bodyMedium
                                ?.copyWith(fontWeight: FontWeight.w600)),
                        const SizedBox(height: 2),
                        Text(
                          [
                            if (m.geree.talbainDugaar != null)
                              'Талбай ${m.geree.talbainDugaar}',
                            'Үлдэгдэл ${AppFormatters.currency(m.uldegdel)}',
                          ].join(' · '),
                          style: theme.textTheme.labelSmall,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 10),
                  SizedBox(
                    width: 140,
                    child: TextField(
                      controller: m.dunController,
                      enabled: !idevkhgui,
                      textAlign: TextAlign.right,
                      keyboardType:
                          const TextInputType.numberWithOptions(decimal: true),
                      inputFormatters: [
                        FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]')),
                      ],
                      onChanged: (_) => onChanged(),
                      decoration: InputDecoration(
                        isDense: true,
                        suffixText: '₮',
                        contentPadding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 10),
                        border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10)),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          const Divider(height: 1),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Text('Нийт (${buleg.gereenuud.length} гэрээ)',
                        style: theme.textTheme.bodyMedium),
                    const Spacer(),
                    Text(AppFormatters.currency(niit),
                        style: theme.textTheme.titleMedium
                            ?.copyWith(fontWeight: FontWeight.w700)),
                  ],
                ),
                const SizedBox(height: 12),
                AppButton(
                  label: 'QPay-ээр төлөх',
                  loadingLabel: 'Үүсгэж байна...',
                  icon: Icons.qr_code_2_rounded,
                  isLoading: tulj,
                  onPressed: idevkhgui ? null : onTulukh,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
