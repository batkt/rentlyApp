import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/models/payment_model.dart';
import '../../data/repositories/payment_repository.dart';
import 'auth_provider.dart';

final qpayInvoiceProvider = StateProvider<QpayInvoiceModel?>((ref) => null);
final paymentAmountProvider = StateProvider<double>((ref) => 0.0);
final paymentLoadingProvider = StateProvider<bool>((ref) => false);
final paymentSuccessProvider = StateProvider<bool>((ref) => false);

class PaymentNotifier extends StateNotifier<PaymentState> {
  final PaymentRepository _repo;
  final Ref _ref;

  PaymentNotifier(this._repo, this._ref) : super(const PaymentState());

  Future<void> generateQpay({
    required String gereeniiId,
    required double amount,
    String? dans,
  }) async {
    final user = _ref.read(currentUserProvider);
    if (user == null) return;

    state = state.copyWith(isLoading: true, error: null, invoice: null);
    try {
      final invoice = await _repo.generateQpay(
        barilgiinId: user.barilgiinId,
        gereeniiId: gereeniiId,
        register: user.register ?? '',
        amount: amount,
        dans: dans,
      );
      state = state.copyWith(isLoading: false, invoice: invoice);
    } catch (e) {
      state = state.copyWith(isLoading: false, error: 'Qpay нэхэмжлэх үүсгэхэд алдаа гарлаа');
    }
  }

  Future<bool> verifyPayment(String invoiceId) async {
    final user = _ref.read(currentUserProvider);
    if (user == null) return false;

    state = state.copyWith(isVerifying: true);
    try {
      final paid = await _repo.verifyPayment(invoiceId, user.barilgiinId);
      state = state.copyWith(isVerifying: false, isPaid: paid);
      return paid;
    } catch (_) {
      state = state.copyWith(isVerifying: false);
      return false;
    }
  }

  void reset() => state = const PaymentState();
  void markPaid() => state = state.copyWith(isPaid: true);
}

final paymentNotifierProvider = StateNotifierProvider<PaymentNotifier, PaymentState>((ref) {
  return PaymentNotifier(ref.read(paymentRepositoryProvider), ref);
});

class PaymentState {
  final bool isLoading;
  final bool isVerifying;
  final bool isPaid;
  final QpayInvoiceModel? invoice;
  final String? error;

  const PaymentState({
    this.isLoading = false,
    this.isVerifying = false,
    this.isPaid = false,
    this.invoice,
    this.error,
  });

  PaymentState copyWith({
    bool? isLoading,
    bool? isVerifying,
    bool? isPaid,
    QpayInvoiceModel? invoice,
    String? error,
  }) {
    return PaymentState(
      isLoading: isLoading ?? this.isLoading,
      isVerifying: isVerifying ?? this.isVerifying,
      isPaid: isPaid ?? this.isPaid,
      invoice: invoice ?? this.invoice,
      error: error,
    );
  }
}
