import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/socket/socket_service.dart';
import '../../../data/models/payment_model.dart';
import '../../providers/payment_provider.dart';
import '../../providers/auth_provider.dart';
import '../../providers/agreement_provider.dart';
import '../../widgets/common/app_button.dart';

class QpayScreen extends ConsumerStatefulWidget {
  final QpayInvoiceModel invoice;

  const QpayScreen({super.key, required this.invoice});

  @override
  ConsumerState<QpayScreen> createState() => _QpayScreenState();
}

class _QpayScreenState extends ConsumerState<QpayScreen> with SingleTickerProviderStateMixin {
  Timer? _pollTimer;
  late AnimationController _pulseController;
  bool _isCheckingPayment = false;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(vsync: this, duration: const Duration(milliseconds: 1500))..repeat(reverse: true);
    _startPolling();

    final user = ref.read(currentUserProvider);
    if (user != null && widget.invoice.invoiceId != null) {
      ref.read(socketServiceProvider).joinQpayRoom(user.baiguullagiinId, widget.invoice.invoiceId!);
      ref.read(socketServiceProvider).on('qpaySuccess', (_) => _onPaymentConfirmed());
    }
  }

  void _startPolling() {
    _pollTimer = Timer.periodic(const Duration(seconds: 5), (_) async {
      if (!mounted || _isCheckingPayment) return;
      if (widget.invoice.invoiceId == null) return;
      setState(() => _isCheckingPayment = true);
      final paid = await ref.read(paymentNotifierProvider.notifier).verifyPayment(widget.invoice.invoiceId!);
      if (mounted) setState(() => _isCheckingPayment = false);
      if (paid) _onPaymentConfirmed();
    });
  }

  void _onPaymentConfirmed() {
    _pollTimer?.cancel();
    ref.read(paymentNotifierProvider.notifier).markPaid();
    ref.invalidate(agreementsProvider);
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => _PaymentSuccessDialog(
        amount: widget.invoice.amount,
        onClose: () {
          Navigator.pop(context);
          context.go('/home');
        },
      ),
    );
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    _pulseController.dispose();
    final user = ref.read(currentUserProvider);
    if (user != null && widget.invoice.invoiceId != null) {
      ref.read(socketServiceProvider).leaveQpayRoom(user.baiguullagiinId, widget.invoice.invoiceId!);
      ref.read(socketServiceProvider).off('qpaySuccess');
    }
    super.dispose();
  }

  Future<void> _openApp(String link) async {
    try {
      final uri = Uri.parse(link);
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final paymentState = ref.watch(paymentNotifierProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Qpay Төлбөр'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => context.pop(),
        ),
        actions: [
          if (_isCheckingPayment)
            const Padding(
              padding: EdgeInsets.only(right: 16),
              child: Center(child: SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.primary))),
            ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            _buildAmountHeader(),
            const SizedBox(height: 24),
            _buildQrSection(widget.invoice.qrImage, widget.invoice.qrText),
            const SizedBox(height: 24),
            _buildInstructions(),
            if (widget.invoice.urls.isNotEmpty) ...[
              const SizedBox(height: 24),
              _buildBankApps(),
            ],
            const SizedBox(height: 24),
            _buildActions(paymentState),
          ],
        ),
      ),
    );
  }

  Widget _buildAmountHeader() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [AppColors.primaryDark, AppColors.primary],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        children: [
          const Text('Төлөх дүн', style: TextStyle(color: Colors.white70, fontSize: 14)),
          const SizedBox(height: 4),
          Text(
            AppFormatters.currency(widget.invoice.amount),
            style: const TextStyle(color: Colors.white, fontSize: 32, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.2),
              borderRadius: BorderRadius.circular(20),
            ),
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.access_time_rounded, color: Colors.white, size: 12),
                SizedBox(width: 4),
                Text('Төлөлтийг хүлээж байна...', style: TextStyle(color: Colors.white, fontSize: 11)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQrSection(String? qrImage, String? qrText) {
    final hasImage = qrImage != null && qrImage.isNotEmpty;
    final hasText = qrText != null && qrText.isNotEmpty;
    final safeQrText = qrText ?? '';

    if (!hasImage && !hasText) {
      return Container(
        height: 240,
        decoration: BoxDecoration(
          color: context.appCardBg,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: context.appDivider),
        ),
        child: Center(child: Text('QR код байхгүй', style: TextStyle(color: context.appTextTertiary))),
      );
    }

    Widget qrWidget;
    if (hasImage) {
      try {
        final bytes = base64Decode(qrImage);
        qrWidget = Image.memory(bytes, width: 220, height: 220, fit: BoxFit.contain);
      } catch (_) {
        qrWidget = const Icon(Icons.qr_code_2_rounded, size: 120, color: AppColors.primary);
      }
    } else {
      qrWidget = Container(
        width: 220,
        height: 220,
        color: Colors.white,
        child: Center(child: Text(safeQrText, style: const TextStyle(fontSize: 8))),
      );
    }

    return AnimatedBuilder(
      animation: _pulseController,
      builder: (context, child) {
        return Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: context.appCardBg,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: Color.lerp(AppColors.primary.withOpacity(0.3), AppColors.primary, _pulseController.value)!,
              width: 2,
            ),
            boxShadow: [
              BoxShadow(
                color: AppColors.primary.withOpacity(0.1 * _pulseController.value),
                blurRadius: 20,
                spreadRadius: 4,
              ),
            ],
          ),
          child: Column(
            children: [
              qrWidget,
              if (hasText) ...[
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    TextButton.icon(
                      onPressed: () {
                        Clipboard.setData(ClipboardData(text: safeQrText));
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Хуулагдлаа'), duration: Duration(seconds: 2)),
                        );
                      },
                      icon: const Icon(Icons.copy_rounded, size: 16),
                      label: const Text('Хуулах', style: TextStyle(fontSize: 13)),
                    ),
                  ],
                ),
              ],
            ],
          ),
        );
      },
    );
  }

  Widget _buildInstructions() {
    final steps = [
      ('1', 'Банкны аппаа нээнэ үү'),
      ('2', 'QPay хэсгийг сонгоно уу'),
      ('3', 'QR кодыг уншуулна уу'),
      ('4', 'Дүнг баталгаажуулна уу'),
    ];

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: context.appPrimaryContainer,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.info_outline_rounded, color: AppColors.primary, size: 16),
              SizedBox(width: 8),
              Text('Хэрхэн төлэх', style: TextStyle(color: AppColors.primary, fontWeight: FontWeight.w700, fontSize: 13)),
            ],
          ),
          const SizedBox(height: 10),
          ...steps.map((step) => Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: Row(
              children: [
                Container(
                  width: 20,
                  height: 20,
                  decoration: const BoxDecoration(color: AppColors.primary, shape: BoxShape.circle),
                  child: Center(child: Text(step.$1, style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w700))),
                ),
                const SizedBox(width: 10),
                Text(step.$2, style: TextStyle(fontSize: 13, color: context.appTextSecondary)),
              ],
            ),
          )),
        ],
      ),
    );
  }

  Widget _buildBankApps() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Банкны апп сонгох', style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600)),
        const SizedBox(height: 12),
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 3,
            childAspectRatio: 0.9,
            crossAxisSpacing: 10,
            mainAxisSpacing: 10,
          ),
          itemCount: widget.invoice.urls.length,
          itemBuilder: (context, index) {
            final url = widget.invoice.urls[index];
            return GestureDetector(
              onTap: () => _openApp(url.link),
              child: Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: context.appCardBg,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: context.appDivider),
                  boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 8)],
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    if (url.logo.isNotEmpty)
                      ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: Image.network(url.logo, width: 40, height: 40, errorBuilder: (_, __, ___) => const Icon(Icons.account_balance_rounded, size: 32, color: AppColors.primary)),
                      )
                    else
                      const Icon(Icons.account_balance_rounded, size: 32, color: AppColors.primary),
                    const SizedBox(height: 6),
                    Text(url.name, style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: context.appTextSecondary), textAlign: TextAlign.center, maxLines: 2, overflow: TextOverflow.ellipsis),
                  ],
                ),
              ),
            );
          },
        ),
      ],
    );
  }

  Widget _buildActions(PaymentState paymentState) {
    return Column(
      children: [
        AppButton(
          label: 'Төлөлт шалгах',
          variant: ButtonVariant.outline,
          onPressed: paymentState.isVerifying ? null : () async {
            if (widget.invoice.invoiceId == null) return;
            final paid = await ref.read(paymentNotifierProvider.notifier).verifyPayment(widget.invoice.invoiceId!);
            if (!paid && mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Төлбөр хийгдээгүй байна'), backgroundColor: AppColors.warning),
              );
            }
          },
          isLoading: paymentState.isVerifying,
          icon: Icons.refresh_rounded,
        ),
      ],
    );
  }
}

class _PaymentSuccessDialog extends StatelessWidget {
  final double amount;
  final VoidCallback onClose;

  const _PaymentSuccessDialog({required this.amount, required this.onClose});

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(color: context.appSuccessLight, shape: BoxShape.circle),
              child: const Icon(Icons.check_circle_rounded, color: AppColors.success, size: 44),
            ),
            const SizedBox(height: 20),
            Text('Төлбөр амжилттай!', style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w700)),
            const SizedBox(height: 8),
            Text(AppFormatters.currency(amount), style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w800, color: AppColors.success)),
            const SizedBox(height: 8),
            Text('Таны төлбөр амжилттай хийгдлээ', style: Theme.of(context).textTheme.bodyMedium, textAlign: TextAlign.center),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: onClose,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
                child: const Text('Хаах', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
