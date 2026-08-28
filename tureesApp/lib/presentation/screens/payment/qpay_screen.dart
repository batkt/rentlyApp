import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/socket/socket_service.dart';
import '../../../core/constants/api_constants.dart';
import '../../../data/models/payment_model.dart';
import '../../providers/payment_provider.dart';
import '../../providers/auth_provider.dart';
import '../../providers/agreement_provider.dart';
import '../../widgets/common/app_button.dart';
import '../../../core/utils/app_snackbar.dart';

class QpayScreen extends ConsumerStatefulWidget {
  final QpayInvoiceModel invoice;

  const QpayScreen({super.key, required this.invoice});

  @override
  ConsumerState<QpayScreen> createState() => _QpayScreenState();
}

class _QpayScreenState extends ConsumerState<QpayScreen> with SingleTickerProviderStateMixin {
  late AnimationController _pulseController;
  bool _paymentDone = false;

  /// initState-д тогтоож, dispose-д ашиглана — `ref` тэр үед найдваргүй.
  String? _tulultUzegdel;
  SocketService? _sokhet;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(vsync: this, duration: const Duration(milliseconds: 1500))..repeat(reverse: true);

    final user = ref.read(currentUserProvider);
    final room = _qpayRoomId;
    if (user != null && room != null) {
      // Backend нь төлбөрийн callback дээрээ `qpay/<org>/<zakhialgiinDugaar>`
      // НЭРТЭЙ эвент цацдаг (`io.emit` — өрөө рүү биш бүгд рүү). Апп нь
      // `'qpaySuccess'` гэсэн, backend хэзээ ч цацдаггүй эвентийг сонсдог
      // байсан тул сокетоор төлбөр огт илэрдэггүй байв.
      _sokhet = ref.read(socketServiceProvider);
      _tulultUzegdel = SocketEvents.qpayRoom(user.baiguullagiinId, room);
      _sokhet!.joinQpayRoom(user.baiguullagiinId, room);
      _sokhet!.on(_tulultUzegdel!, _tulultSonsogch);
    }
  }

  void _tulultSonsogch(dynamic _) => _onPaymentConfirmed();

  /// The backend emits `qpay/<baiguullagiinId>/<zakhialgiinDugaar>` from its
  /// payment callback, so the room has to be keyed on the order number.
  String? get _qpayRoomId =>
      widget.invoice.zakhialgiinDugaar ?? widget.invoice.invoiceId;

  void _onPaymentConfirmed() {
    if (_paymentDone) return; // socket push and the manual check can both fire
    _paymentDone = true;
    ref.read(paymentNotifierProvider.notifier).markPaid();
    // Everything that quotes a balance is now stale.
    ref.invalidate(agreementsProvider);
    ref.invalidate(invoiceHistoryProvider);
    ref.invalidate(transactionHistoryProvider);
    ref.invalidate(niitUldegdelProvider);
    ref.invalidate(uldegdelProvider);
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => _PaymentSuccessDialog(
        amount: widget.invoice.amount,
        onClose: () {
          Navigator.pop(context);
          _clearAndLeave();
        },
      ),
    );
  }

  /// Drops the finished QPay invoice so neither this screen nor the payment
  /// form comes back carrying the amount that was just paid.
  void _clearAndLeave() {
    ref.read(paymentNotifierProvider.notifier).reset();
    ref.read(paymentClearSignalProvider.notifier).state++;
    context.go('/home');
  }

  @override
  void dispose() {
    _pulseController.dispose();
    final uzegdel = _tulultUzegdel;
    if (_sokhet != null && uzegdel != null) {
      _sokhet!.off(uzegdel, _tulultSonsogch);
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
      ),
      body: Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 560),
          child: SingleChildScrollView(
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
                const SizedBox(height: 12),
              ],
            ),
          ),
        ),
      ),
      // Pinned to the bottom: after paying in the bank app the tenant comes
      // back here to confirm, and the button used to sit below a QR, the
      // instructions and the bank list — off screen until they scrolled.
      bottomNavigationBar: _buildActions(paymentState),
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
                        showAppSnackBar(context, 'Хуулагдлаа',
                            duration: const Duration(seconds: 2));
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
              Text('Хэрхэн төлөх', style: TextStyle(color: AppColors.primary, fontWeight: FontWeight.w700, fontSize: 13)),
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
    return SafeArea(
      minimum: const EdgeInsets.fromLTRB(20, 0, 20, 12),
      child: Container(
        constraints: const BoxConstraints(maxWidth: 560),
        padding: const EdgeInsets.only(top: 8),
        child: AppButton(
          label: 'Төлөлт шалгах',
          loadingLabel: 'Шалгаж байна...',
          onPressed: paymentState.isVerifying ? null : _checkPayment,
          isLoading: paymentState.isVerifying,
          icon: Icons.verified_rounded,
        ),
      ),
    );
  }

  Future<void> _checkPayment() async {
    final paid = await ref
        .read(paymentNotifierProvider.notifier)
        .verifyPayment(widget.invoice);
    if (!mounted) return;
    if (paid) {
      _onPaymentConfirmed();
      return;
    }
    showAppSnackBar(context, 'Төлбөр хараахан хийгдээгүй байна',
        turul: SnackTurul.sanuulga);
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
