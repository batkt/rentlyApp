import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/formatters.dart';
import '../../../data/models/agreement_model.dart';
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

  @override
  void initState() {
    super.initState();
    _selectedAgreement = widget.selectedAgreement;
    if (_selectedAgreement != null) {
      _amountController.text = _selectedAgreement!.uldegdel > 0
          ? _selectedAgreement!.uldegdel.toStringAsFixed(2)
          : '';
    }
  }

  @override
  void dispose() {
    _amountController.dispose();
    super.dispose();
  }

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
      SnackBar(content: Text(msg), backgroundColor: AppColors.error, behavior: SnackBarBehavior.floating),
    );
  }

  @override
  Widget build(BuildContext context) {
    final paymentState = ref.watch(paymentNotifierProvider);
    final agreementsAsync = ref.watch(agreementsProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Төлбөр')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildAgreementSelector(agreementsAsync),
            const SizedBox(height: 20),
            if (_selectedAgreement != null) _buildBalanceSummary(),
            const SizedBox(height: 20),
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
        Text('Гэрээ сонгох', style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600)),
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
                onClear: () => setState(() {
                  _selectedAgreement = null;
                  _amountController.clear();
                }),
              );
            }

            return Container(
              decoration: BoxDecoration(
                color: context.appCardBg,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: context.appDivider),
              ),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<AgreementModel>(
                  value: _selectedAgreement,
                  isExpanded: true,
                  dropdownColor: context.appCardBg,
                  hint: const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 16),
                    child: Text('Гэрээ сонгох...'),
                  ),
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                  items: active.map((a) => DropdownMenuItem(
                    value: a,
                    child: Text('${a.tenantName} – ${a.gereeniiDugaar}', overflow: TextOverflow.ellipsis),
                  )).toList(),
                  onChanged: (v) {
                    setState(() {
                      _selectedAgreement = v;
                      if (v != null && v.uldegdel > 0) {
                        _amountController.text = v.uldegdel.toStringAsFixed(2);
                      }
                    });
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
    final ag = _selectedAgreement!;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: ag.hasDebt ? context.appErrorLight : context.appSuccessLight,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: ag.hasDebt ? AppColors.error.withOpacity(0.2) : AppColors.success.withOpacity(0.2)),
      ),
      child: Row(
        children: [
          Icon(
            ag.hasDebt ? Icons.warning_rounded : Icons.check_circle_rounded,
            color: ag.hasDebt ? AppColors.error : AppColors.success,
            size: 20,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(ag.hasDebt ? 'Нийт өр' : 'Үлдэгдэл', style: Theme.of(context).textTheme.bodySmall),
                Text(
                  AppFormatters.currency(ag.uldegdel),
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 18,
                    color: ag.hasDebt ? AppColors.error : AppColors.success,
                  ),
                ),
              ],
            ),
          ),
          if (ag.hasDebt)
            TextButton(
              onPressed: () {
                _amountController.text = ag.uldegdel.toStringAsFixed(2);
              },
              child: const Text('Бүгдийг төлөх', style: TextStyle(fontSize: 12)),
            ),
        ],
      ),
    );
  }

  Widget _buildAmountInput() {
    return AppTextField(
      label: 'Төлөх дүн (₮)',
      hint: '0.00',
      controller: _amountController,
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9.]'))],
      prefixIcon: Icon(Icons.monetization_on_rounded, size: 18, color: context.appTextTertiary),
    );
  }

  Widget _buildQuickAmounts() {
    final amounts = [10000, 50000, 100000, 200000, 500000];
    return Wrap(
      spacing: 8,
      children: amounts.map((amount) => GestureDetector(
        onTap: () => _amountController.text = amount.toDouble().toStringAsFixed(2),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: context.appInputFill,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: context.appDivider),
          ),
          child: Text(
            AppFormatters.currency(amount).replaceAll('₮', ''),
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
        Text('Төлбөрийн арга', style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600)),
        const SizedBox(height: 12),
        _PaymentMethodCard(
          icon: Icons.qr_code_rounded,
          title: 'QPay',
          subtitle: 'Бүх банкны аппаар төлөх',
          isSelected: true,
          onTap: () {},
        ),
        const SizedBox(height: 24),
        AppButton(
          label: 'Qpay нэхэмжлэл үүсгэх',
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
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(
              children: [
                const Icon(Icons.error_outline, color: AppColors.error, size: 16),
                const SizedBox(width: 8),
                Expanded(child: Text(paymentState.error!, style: const TextStyle(color: AppColors.error, fontSize: 13))),
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
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.primary.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          const Icon(Icons.assignment_rounded, color: AppColors.primary, size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(agreement.tenantName, style: Theme.of(context).textTheme.titleSmall?.copyWith(color: AppColors.primary, fontWeight: FontWeight.w600)),
                Text(agreement.gereeniiDugaar, style: Theme.of(context).textTheme.bodySmall),
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
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: isSelected ? context.appPrimaryContainer : context.appCardBg,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isSelected ? AppColors.primary : context.appDivider,
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: isSelected ? AppColors.primary : context.appInputFill,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: isSelected ? Colors.white : context.appTextTertiary, size: 22),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    color: isSelected ? AppColors.primary : context.appTextPrimary,
                    fontWeight: FontWeight.w600,
                  )),
                  Text(subtitle, style: Theme.of(context).textTheme.bodySmall),
                ],
              ),
            ),
            if (isSelected)
              const Icon(Icons.check_circle_rounded, color: AppColors.primary, size: 20),
          ],
        ),
      ),
    );
  }
}
