import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_colors.dart';
import '../../../data/models/agreement_model.dart';
import '../../../data/models/mashin_model.dart';
import '../../providers/agreement_provider.dart';
import '../../providers/auth_provider.dart';
import '../../providers/mashin_provider.dart';
import '../../widgets/common/app_button.dart';
import '../../widgets/common/app_loading.dart';
import '../../widgets/common/app_text_field.dart';
import '../../../core/utils/app_snackbar.dart';

/// Машин бүртгэл — the tenant registers their own plates so parking sees them
/// as a resident. Mirrors the web app's `components/mashinNemekh.tsx`.
class MashinScreen extends ConsumerStatefulWidget {
  const MashinScreen({super.key});

  @override
  ConsumerState<MashinScreen> createState() => _MashinScreenState();
}

class _MashinScreenState extends ConsumerState<MashinScreen> {
  final _controller = TextEditingController();
  bool _saving = false;

  /// Contract the plate is registered against. The parking module lists a
  /// Түрээслэгч car by its талбай and гэрээ, so the record needs one.
  AgreementModel? _geree;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  /// `YYYY-MM-DD HH:mm:ss`, the shape the manager's own form sends.
  String? _ognoo(DateTime? date, {required bool ekhlekh}) {
    if (date == null) return null;
    final d = '${date.year}-${date.month.toString().padLeft(2, '0')}-'
        '${date.day.toString().padLeft(2, '0')}';
    return ekhlekh ? '$d 00:00:00' : '$d 23:59:59';
  }

  void _toast(String msg, {bool error = false}) {
    if (!mounted) return;
    showAppSnackBar(
      context,
      msg,
      turul: error ? SnackTurul.aldaa : SnackTurul.amjilt,
    );
  }

  Future<void> _add() async {
    final dugaar = _controller.text.trim();
    if (dugaar.isEmpty) {
      _toast('Дугаараа оруулна уу!', error: true);
      return;
    }
    // 4 digits + 3 Cyrillic letters, the format the parking system expects.
    if (dugaar.length != 7) {
      _toast('Та дугаараа зөв оруулна уу (жишээ: 1234АБВ)', error: true);
      return;
    }
    final user = ref.read(currentUserProvider);
    if (user == null) return;

    final geree = _geree;
    FocusScope.of(context).unfocus();
    setState(() => _saving = true);
    try {
      await ref.read(mashinRepositoryProvider).addMashin(
            baiguullagiinId: user.baiguullagiinId,
            // The contract's building, not the user's current one — the car
            // belongs to the parking lot of the building it is parked at.
            barilgiinId: geree?.barilgiinId.isNotEmpty == true
                ? geree!.barilgiinId
                : user.barilgiinId,
            dugaar: dugaar,
            ezemshigchiinId: user.id,
            ezemshigchiinNer: user.fullName,
            ezemshigchiinRegister: user.register ?? '',
            ezemshigchiinUtas: user.primaryPhone,
            talbainDugaar: geree?.talbainDugaar,
            gereeniiId: geree?.id,
            gereeniiDugaar: geree?.gereeniiDugaar,
            ekhlekhOgnoo: _ognoo(
              DateTime.tryParse(geree?.gereeniiOgnoo ?? ''),
              ekhlekh: true,
            ),
            duusakhOgnoo: _ognoo(geree?.duusakhDate, ekhlekh: false),
          );
      _controller.clear();
      ref.invalidate(mashinuudProvider);
      _toast('Амжилттай нэмэгдлээ.');
    } catch (_) {
      _toast('Нэмэхэд алдаа гарлаа', error: true);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _delete(MashinModel mashin) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Устгах уу?'),
        content: Text('${mashin.dugaar} дугаарыг бүртгэлээс хасах уу?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Болих')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(foregroundColor: AppColors.error),
            child: const Text('Устгах'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    try {
      await ref.read(mashinRepositoryProvider).deleteMashin(mashin.id);
      ref.invalidate(mashinuudProvider);
      _toast('Амжилттай устгагдлаа!');
    } catch (_) {
      _toast('Устгахад алдаа гарлаа', error: true);
    }
  }

  /// Picks which contract the plate belongs to. With a single active contract
  /// there is nothing to choose, so it just shows which one is being used.
  Widget _buildGereeSelector() {
    final agreementsAsync = ref.watch(agreementsProvider);

    return agreementsAsync.when(
      loading: () => const SizedBox(height: 56, child: Center(child: LinearProgressIndicator())),
      error: (_, __) => const SizedBox.shrink(),
      data: (agreements) {
        final idewkhtei = agreements.where((a) => a.isActive).toList();
        if (idewkhtei.isEmpty) return const SizedBox.shrink();

        if (_geree == null || !idewkhtei.any((a) => a.id == _geree!.id)) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) setState(() => _geree = idewkhtei.first);
          });
        }

        String shosoo(AgreementModel a) {
          final talbai = a.talbainDugaar ?? '';
          return talbai.isEmpty ? a.gereeniiDugaar : '${a.gereeniiDugaar} · $talbai';
        }

        if (idewkhtei.length == 1) {
          return Row(
            children: [
              Icon(Icons.receipt_long_rounded, size: 16, color: context.appTextTertiary),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  shosoo(idewkhtei.first),
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: context.appTextSecondary,
                      ),
                ),
              ),
            ],
          );
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Гэрээ',
              style: Theme.of(context).textTheme.labelMedium?.copyWith(
                    color: context.appTextSecondary,
                    fontWeight: FontWeight.w500,
                  ),
            ),
            const SizedBox(height: 6),
            Container(
              decoration: BoxDecoration(
                color: context.appInputFill,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: context.appDivider),
              ),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<String>(
                  value: _geree?.id,
                  isExpanded: true,
                  dropdownColor: context.appCardBg,
                  padding: const EdgeInsets.symmetric(horizontal: 14),
                  items: [
                    for (final a in idewkhtei)
                      DropdownMenuItem(
                        value: a.id,
                        child: Text(
                          shosoo(a),
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(color: context.appTextPrimary),
                        ),
                      ),
                  ],
                  onChanged: (id) => setState(
                    () => _geree = idewkhtei.firstWhere((a) => a.id == id),
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final mashinuudAsync = ref.watch(mashinuudProvider);

    return Scaffold(
      backgroundColor: context.appBackground,
      appBar: AppBar(title: const Text('Машин бүртгэл')),
      body: Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 600),
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: context.appCardBg,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: context.appDivider),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Та өөрийн авто машинаа бүртгэн зогсоолын хөнгөлөлт эдлэх боломжтой.',
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                    const SizedBox(height: 14),
                    _buildGereeSelector(),
                    const SizedBox(height: 12),
                    AppTextField(
                      label: 'Улсын дугаар',
                      hint: '1234АБВ',
                      controller: _controller,
                      maxLength: 7,
                      textCapitalization: TextCapitalization.characters,
                      inputFormatters: [_UlsiinDugaarFormatter()],
                      onSubmitted: (_) => _add(),
                    ),
                    const SizedBox(height: 10),
                    AppButton(
                      label: 'Нэмэх',
                      icon: Icons.add_rounded,
                      isLoading: _saving,
                      onPressed: _add,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              Text(
                'Бүртгэгдсэн дугаарууд',
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                      color: context.appTextPrimary,
                    ),
              ),
              const SizedBox(height: 8),
              mashinuudAsync.when(
                loading: () => const Padding(
                  padding: EdgeInsets.symmetric(vertical: 32),
                  child: AppLoading(message: 'Ачаалж байна...'),
                ),
                error: (_, __) => AppErrorWidget(
                  message: 'Машины жагсаалт ачаалахад алдаа гарлаа',
                  onRetry: () => ref.invalidate(mashinuudProvider),
                ),
                data: (mashinuud) {
                  if (mashinuud.isEmpty) {
                    return const Padding(
                      padding: EdgeInsets.symmetric(vertical: 24),
                      child: AppEmpty(
                        icon: Icons.directions_car_outlined,
                        message: 'Бүртгэгдсэн машин байхгүй байна',
                      ),
                    );
                  }
                  return Column(
                    children: [
                      for (final mashin in mashinuud)
                        Container(
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
                                child: const Icon(Icons.directions_car_rounded,
                                    size: 20, color: AppColors.primary),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      mashin.dugaar,
                                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                                            fontWeight: FontWeight.w700,
                                            letterSpacing: 1.1,
                                            color: context.appTextPrimary,
                                          ),
                                    ),
                                    Text(
                                      [
                                        if (mashin.turul.isNotEmpty) mashin.turul,
                                        if (mashin.tuluv.isNotEmpty)
                                          mashin.tuluv
                                        else
                                          'Хүлээгдэж буй',
                                        if (mashin.talbainDugaar.isNotEmpty)
                                          mashin.talbainDugaar,
                                      ].join(' · '),
                                      style: Theme.of(context).textTheme.labelSmall,
                                    ),
                                  ],
                                ),
                              ),
                              IconButton(
                                icon: const Icon(Icons.delete_outline_rounded,
                                    size: 20, color: AppColors.error),
                                onPressed: () => _delete(mashin),
                              ),
                            ],
                          ),
                        ),
                    ],
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Keeps the field in the `1234АБВ` shape the parking system expects: up to
/// four digits followed by up to three Cyrillic letters, regardless of the
/// order they were typed in. Same rule as the web app's `mashiniiFormatSolyo`.
class _UlsiinDugaarFormatter extends TextInputFormatter {
  static final _too = RegExp(r'[^0-9]');
  static final _useg = RegExp(r'[^А-Яа-яЁёӨөҮү]');

  @override
  TextEditingValue formatEditUpdate(TextEditingValue oldValue, TextEditingValue newValue) {
    final raw = newValue.text;
    final too = raw.replaceAll(_too, '');
    final useg = raw.replaceAll(_useg, '').toUpperCase();
    final formatted =
        too.substring(0, too.length > 4 ? 4 : too.length) +
        useg.substring(0, useg.length > 3 ? 3 : useg.length);

    return TextEditingValue(
      text: formatted,
      selection: TextSelection.collapsed(offset: formatted.length),
    );
  }
}
