import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/formatters.dart';
import '../../../data/models/agreement_model.dart';
import '../../../data/repositories/agreement_repository.dart';
import '../../providers/agreement_provider.dart';
import '../../providers/auth_provider.dart';
import '../../providers/payment_provider.dart';
import '../../widgets/common/app_button.dart';
import '../../widgets/common/app_loading.dart';
import '../../widgets/common/app_text_field.dart';

class PaymentScreen extends ConsumerStatefulWidget {
  final AgreementModel? selectedAgreement;

  const PaymentScreen({super.key, this.selectedAgreement});

  @override
  ConsumerState<PaymentScreen> createState() => _PaymentScreenState();
}

final _numFmt = NumberFormat('#,##0.00', 'mn');

class _PaymentScreenState extends ConsumerState<PaymentScreen> {
  final _amountController = TextEditingController();
  AgreementModel? _selectedAgreement;
  double? _realUldegdel;
  String? _dansniiDugaar;
  bool _loadingUldegdel = false;
  bool _autoSelectDone = false;

  @override
  void initState() {
    super.initState();
    _selectedAgreement = widget.selectedAgreement;
    if (_selectedAgreement != null) {
      _fetchRealUldegdel(_selectedAgreement!);
    }
    // Reset any stale QPay invoice from a previous session so the old amount
    // is never carried over to this payment.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) ref.read(paymentNotifierProvider.notifier).reset();
    });
  }

  @override
  void dispose() {
    _amountController.dispose();
    super.dispose();
  }

  Future<void> _fetchRealUldegdel(AgreementModel agreement) async {
    setState(() {
      _loadingUldegdel = true;
      _realUldegdel = null;
    });
    try {
      final repo = ref.read(agreementRepositoryProvider);
      final info = await repo.getLatestInvoiceInfo(agreement.id);
      if (!mounted) return;
      final uldegdel = info.niitUldegdel;
      setState(() {
        _realUldegdel = uldegdel;
        _dansniiDugaar = info.dansniiDugaar;
        _loadingUldegdel = false;
      });
      if ((uldegdel ?? 0) > 0 && _amountController.text.isEmpty) {
        _amountController.text = _numFmt.format(uldegdel!);
      }
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _realUldegdel = _selectedAgreement?.uldegdel;
        _loadingUldegdel = false;
      });
    }
  }

  double get _displayUldegdel => _realUldegdel ?? _selectedAgreement?.uldegdel ?? 0;

  Future<void> _generateQpay() async {
    final rawText = _amountController.text.replaceAll(',', '').replaceAll(' ', '');
    final amount = double.tryParse(rawText);
    if (_selectedAgreement == null) {
      _showError('Гэрээ сонгоно уу');
      return;
    }
    if (amount == null || amount <= 0) {
      _showError('Мөнгөн дүн оруулна уу');
      return;
    }
    FocusScope.of(context).unfocus();

    await ref.read(paymentNotifierProvider.notifier).generateQpay(
      gereeniiId: _selectedAgreement!.id,
      amount: amount,
      dansniiDugaar: _dansniiDugaar,
    );

    final state = ref.read(paymentNotifierProvider);
    if (state.invoice != null && mounted) {
      context.push('/qpay', extra: state.invoice);
    }
  }

  void _showError(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: AppColors.error,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.all(16),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // This screen lives inside HomeScreen's IndexedStack, so its State is
    // never disposed when the tenant switches buildings from the Dashboard —
    // without this listener a contract picked in one building would stay
    // selected (and payable) after switching to another building/salbar.
    ref.listen<String>(selectedBarilgiinIdProvider, (previous, next) {
      if (previous != null && previous != next && _selectedAgreement != null) {
        setState(() {
          _selectedAgreement = null;
          _realUldegdel = null;
          _dansniiDugaar = null;
          _autoSelectDone = false;
          _amountController.clear();
        });
      }
    });
    final paymentState = ref.watch(paymentNotifierProvider);
    final agreementsAsync = ref.watch(agreementsProvider);

    return Scaffold(
      backgroundColor: context.appBackground,
      appBar: AppBar(
        title: const Text('Төлбөр төлөх'),
      ),
      body: GestureDetector(
        onTap: () => FocusScope.of(context).unfocus(),
        behavior: HitTestBehavior.opaque,
        child: Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 600),
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildAgreementSelector(agreementsAsync),
            const SizedBox(height: 16),
            _buildAmountInput(),
            const SizedBox(height: 8),
            _buildQuickAmounts(),
            const SizedBox(height: 24),
            _buildPaymentMethods(paymentState),
          ],
          ),
          ),
        ),
        ),
      ),
    );
  }

  Widget _buildAgreementSelector(AsyncValue<List<AgreementModel>> agreementsAsync) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Гэрээ сонгох',
          style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 10),
        agreementsAsync.when(
          loading: () => const ShimmerList(itemCount: 1, itemHeight: 60),
          error: (_, __) => const AppErrorWidget(message: 'Гэрээнүүд ачаалахад алдаа гарлаа'),
          data: (agreements) {
            final active = agreements.where((a) => a.isActive).toList();
            if (active.isEmpty) return const AppEmpty(message: 'Идэвхтэй гэрээ байхгүй');

            // Auto-select single agreement
            if (active.length == 1 && !_autoSelectDone) {
              WidgetsBinding.instance.addPostFrameCallback((_) {
                if (!mounted || _autoSelectDone) return;
                setState(() {
                  _autoSelectDone = true;
                  _selectedAgreement = active.first;
                  _realUldegdel = null;
                  _amountController.clear();
                });
                _fetchRealUldegdel(active.first);
              });
            }

            if (_selectedAgreement != null) {
              // Show a change button whenever there is more than one active
              // agreement — even when the screen was opened with a pre-selected
              // agreement from AgreementDetailScreen.
              return _SelectedAgreementTile(
                agreement: _selectedAgreement!,
                onClear: active.length > 1
                    ? () => setState(() {
                          _selectedAgreement = null;
                          _realUldegdel = null;
                          _dansniiDugaar = null;
                          _amountController.clear();
                        })
                    : null,
              );
            }

            return Container(
              decoration: BoxDecoration(
                color: context.appCardBg,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: context.appDivider),
              ),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<AgreementModel>(
                  value: _selectedAgreement,
                  isExpanded: true,
                  dropdownColor: context.appCardBg,
                  hint: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Text('Гэрээ сонгох...', style: TextStyle(color: context.appTextTertiary)),
                  ),
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                  items: active.map((a) => DropdownMenuItem(
                    value: a,
                    child: Text(
                      '${a.tenantName} – ${a.gereeniiDugaar}',
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(color: context.appTextPrimary),
                    ),
                  )).toList(),
                  onChanged: (v) {
                    setState(() {
                      _selectedAgreement = v;
                      _realUldegdel = null;
                      _dansniiDugaar = null;
                      _amountController.clear();
                    });
                    if (v != null) _fetchRealUldegdel(v);
                  },
                ),
              ),
            );
          },
        ),
      ],
    );
  }

  Widget _buildAmountInput() {
    return AppTextField(
      label: 'Төлөх дүн (₮)',
      hint: '0',
      controller: _amountController,
      keyboardType: const TextInputType.numberWithOptions(decimal: false),
      inputFormatters: [_ThousandsSeparatorFormatter()],
      prefixIcon: Icon(Icons.monetization_on_rounded, size: 18, color: context.appTextTertiary),
    );
  }

  Widget _buildQuickAmounts() {
    const fixed = [10000, 50000, 100000, 200000, 500000];
    final uldegdel = _displayUldegdel;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Нийт үлдэгдэл button — shown prominently when there's a balance
        if (uldegdel > 0 && !_loadingUldegdel) ...[
          GestureDetector(
            onTap: () => setState(() => _amountController.text = _numFmt.format(uldegdel)),
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: AppColors.error.withOpacity(0.08),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: AppColors.error.withOpacity(0.35), width: 1.5),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.receipt_long_rounded, size: 16, color: AppColors.error),
                      const SizedBox(width: 8),
                      const Text(
                        'Нэхэмжлэлийн нийт дүн',
                        style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.error),
                      ),
                    ],
                  ),
                  Text(
                    AppFormatters.currency(uldegdel),
                    style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: AppColors.error),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 10),
        ],
        // Fixed quick-pick chips
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: fixed.map((amount) {
            final isSelected = _amountController.text == _numFmt.format(amount);
            return GestureDetector(
              onTap: () => setState(() => _amountController.text = _numFmt.format(amount)),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                decoration: BoxDecoration(
                  color: isSelected ? AppColors.primary.withOpacity(0.1) : context.appInputFill,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: isSelected ? AppColors.primary : context.appDivider,
                    width: isSelected ? 1.5 : 1,
                  ),
                ),
                child: Text(
                  AppFormatters.currency(amount),
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                    color: isSelected ? AppColors.primary : context.appTextSecondary,
                  ),
                ),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }

  Widget _buildPaymentMethods(PaymentState paymentState) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Төлбөрийн арга',
          style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 12),
        _PaymentMethodCard(
          icon: Icons.qr_code_2_rounded,
          title: 'QPay',
          subtitle: 'Бүх банкны аппаар QR кодоор төлөх',
          isSelected: true,
          onTap: () {},
        ),
        const SizedBox(height: 24),
        AppButton(
          label: 'QPay нэхэмжлэл үүсгэх',
          onPressed: paymentState.isLoading ? null : _generateQpay,
          isLoading: paymentState.isLoading,
          icon: Icons.qr_code_rounded,
        ),
        if (paymentState.error != null) ...[
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: context.appErrorLight,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.error.withOpacity(0.2)),
            ),
            child: Row(
              children: [
                const Icon(Icons.error_outline, color: AppColors.error, size: 16),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    paymentState.error!,
                    style: const TextStyle(color: AppColors.error, fontSize: 13),
                  ),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }
}

class _SelectedAgreementTile extends StatelessWidget {
  final AgreementModel agreement;
  final VoidCallback? onClear;

  const _SelectedAgreementTile({required this.agreement, required this.onClear});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: context.appPrimaryContainer,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.primary.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: AppColors.primary.withOpacity(0.15),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(Icons.assignment_rounded, color: AppColors.primary, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  agreement.tenantName,
                  style: const TextStyle(
                    color: AppColors.primary,
                    fontWeight: FontWeight.w700,
                    fontSize: 14,
                  ),
                ),
                Text(
                  agreement.gereeniiDugaar,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
          ),
          if (onClear != null)
            GestureDetector(
              onTap: onClear,
              child: Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: AppColors.primary.withOpacity(0.12),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.swap_horiz_rounded, color: AppColors.primary, size: 18),
              ),
            ),
        ],
      ),
    );
  }
}

class _ThousandsSeparatorFormatter extends TextInputFormatter {
  static final _intFmt = NumberFormat('#,###', 'mn');

  @override
  TextEditingValue formatEditUpdate(TextEditingValue oldValue, TextEditingValue newValue) {
    final text = newValue.text;
    final hasDot = text.contains('.');
    final parts = text.split('.');
    final intDigits = parts[0].replaceAll(RegExp(r'[^0-9]'), '');
    final decDigits = hasDot ? (parts.length > 1 ? parts[1].replaceAll(RegExp(r'[^0-9]'), '') : '') : null;

    if (intDigits.isEmpty && decDigits == null) {
      return newValue.copyWith(text: '', selection: const TextSelection.collapsed(offset: 0));
    }

    final intNumber = int.tryParse(intDigits.isEmpty ? '0' : intDigits) ?? 0;
    var formatted = intDigits.isEmpty ? '0' : _intFmt.format(intNumber);
    if (decDigits != null) formatted = '$formatted.${decDigits.substring(0, decDigits.length > 2 ? 2 : decDigits.length)}';

    return TextEditingValue(
      text: formatted,
      selection: TextSelection.collapsed(offset: formatted.length),
    );
  }
}

class _PaymentMethodCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final bool isSelected;
  final VoidCallback onTap;

  const _PaymentMethodCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isSelected ? context.appPrimaryContainer : context.appCardBg,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected ? AppColors.primary : context.appDivider,
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: isSelected ? AppColors.primary : context.appInputFill,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(icon, color: isSelected ? Colors.white : context.appTextTertiary, size: 24),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 15,
                      color: isSelected ? AppColors.primary : context.appTextPrimary,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(subtitle, style: Theme.of(context).textTheme.bodySmall),
                ],
              ),
            ),
            if (isSelected)
              Container(
                width: 24,
                height: 24,
                decoration: BoxDecoration(
                  color: AppColors.primary,
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.check_rounded, color: Colors.white, size: 14),
              ),
          ],
        ),
      ),
    );
  }
}
