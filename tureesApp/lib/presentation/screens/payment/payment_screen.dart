import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/formatters.dart';
import '../../../data/models/agreement_model.dart';
import '../../../data/repositories/agreement_repository.dart';
import '../../providers/agreement_provider.dart';
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

class _PaymentScreenState extends ConsumerState<PaymentScreen> {
  final _amountController = TextEditingController();
  AgreementModel? _selectedAgreement;
  double? _realUldegdel;
  bool _loadingUldegdel = false;

  @override
  void initState() {
    super.initState();
    _selectedAgreement = widget.selectedAgreement;
    if (_selectedAgreement != null) {
      _fetchRealUldegdel(_selectedAgreement!);
    }
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
      final data = await repo.getUldegdel(agreement.gereeniiDugaar, agreement.barilgiinId);
      final uldegdel = (data['uldegdel'] as num?)?.toDouble() ?? 0.0;
      if (!mounted) return;
      setState(() {
        _realUldegdel = uldegdel;
        _loadingUldegdel = false;
      });
      // Auto-fill the amount if there is a debt
      if (uldegdel > 0 && _amountController.text.isEmpty) {
        _amountController.text = uldegdel.toStringAsFixed(0);
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
  bool get _hasDebt => _displayUldegdel > 0;

  Future<void> _generateQpay() async {
    final rawText = _amountController.text.replaceAll(',', '').replaceAll(' ', '');
    final amount = double.tryParse(rawText);
    if (_selectedAgreement == null) {
      _showError('Гэрээ сонгоно уу');
      return;
    }
    if (amount == null || amount <= 0) {
      _showError('Зөв дүн оруулна уу');
      return;
    }
    FocusScope.of(context).unfocus();

    await ref.read(paymentNotifierProvider.notifier).generateQpay(
      gereeniiId: _selectedAgreement!.id,
      amount: amount,
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
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final paymentState = ref.watch(paymentNotifierProvider);
    final agreementsAsync = ref.watch(agreementsProvider);

    return Scaffold(
      backgroundColor: context.appBackground,
      appBar: AppBar(
        title: const Text('Төлбөр төлөх'),
        backgroundColor: isDark ? const Color(0xFF1E2A28) : AppColors.primary,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildAgreementSelector(agreementsAsync),
            const SizedBox(height: 16),
            if (_selectedAgreement != null) _buildBalanceSummary(),
            const SizedBox(height: 16),
            _buildAmountInput(),
            const SizedBox(height: 8),
            _buildQuickAmounts(),
            const SizedBox(height: 24),
            _buildPaymentMethods(paymentState),
          ],
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

            if (widget.selectedAgreement != null) {
              return _SelectedAgreementTile(
                agreement: _selectedAgreement!,
                onClear: () {
                  setState(() {
                    _selectedAgreement = null;
                    _realUldegdel = null;
                    _amountController.clear();
                  });
                },
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

  Widget _buildBalanceSummary() {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _hasDebt ? context.appErrorLight : context.appSuccessLight,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: _hasDebt ? AppColors.error.withOpacity(0.25) : AppColors.success.withOpacity(0.25),
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: (_hasDebt ? AppColors.error : AppColors.success).withOpacity(0.12),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              _hasDebt ? Icons.warning_rounded : Icons.check_circle_rounded,
              color: _hasDebt ? AppColors.error : AppColors.success,
              size: 22,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: _loadingUldegdel
                ? Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Үлдэгдэл тооцоолж байна...', style: Theme.of(context).textTheme.bodySmall),
                      const SizedBox(height: 4),
                      LinearProgressIndicator(
                        color: AppColors.primary,
                        backgroundColor: AppColors.primary.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ],
                  )
                : Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _hasDebt ? 'Нийт өр' : 'Үлдэгдэл (0)',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: _hasDebt ? AppColors.error : AppColors.success,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        AppFormatters.currency(_displayUldegdel),
                        style: TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 20,
                          color: _hasDebt ? AppColors.error : AppColors.success,
                        ),
                      ),
                    ],
                  ),
          ),
          if (_hasDebt && !_loadingUldegdel)
            TextButton(
              onPressed: () {
                _amountController.text = _displayUldegdel.toStringAsFixed(0);
              },
              style: TextButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                backgroundColor: AppColors.error.withOpacity(0.1),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              child: const Text(
                'Бүгдийг\nтөлөх',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 11, color: AppColors.error, fontWeight: FontWeight.w700),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildAmountInput() {
    return AppTextField(
      label: 'Төлөх дүн (₮)',
      hint: '0',
      controller: _amountController,
      keyboardType: const TextInputType.numberWithOptions(decimal: false),
      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
      prefixIcon: Icon(Icons.monetization_on_rounded, size: 18, color: context.appTextTertiary),
    );
  }

  Widget _buildQuickAmounts() {
    final amounts = [10000, 50000, 100000, 200000, 500000];
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: amounts.map((amount) => GestureDetector(
        onTap: () => _amountController.text = amount.toString(),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
          decoration: BoxDecoration(
            color: context.appInputFill,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: context.appDivider),
          ),
          child: Text(
            AppFormatters.currency(amount),
            style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: context.appTextSecondary),
          ),
        ),
      )).toList(),
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
  final VoidCallback onClear;

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
        ],
      ),
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
