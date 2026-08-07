import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/models/payment_model.dart';
import '../../data/repositories/payment_repository.dart';
import 'auth_provider.dart';

final qpayInvoiceProvider = StateProvider<QpayInvoiceModel?>((ref) => null);

/// Bumped once a payment has been confirmed so PaymentScreen — which lives in
/// the home IndexedStack and is never disposed — wipes the amount it was left
/// holding and refetches the balance instead of showing the pre-payment one.
final paymentClearSignalProvider = StateProvider<int>((ref) => 0);
final paymentAmountProvider = StateProvider<double>((ref) => 0.0);
final paymentLoadingProvider = StateProvider<bool>((ref) => false);
final paymentSuccessProvider = StateProvider<bool>((ref) => false);

class PaymentNotifier extends StateNotifier<PaymentState> {
  final PaymentRepository _repo;
  final Ref _ref;

  PaymentNotifier(this._repo, this._ref) : super(const PaymentState());

  /// [barilgiinId] and [register] must come from the contract being paid, not
  /// from the logged-in user: a tenant can hold contracts in several buildings,
  /// and the backend files the payment under whatever building it is handed.
  Future<void> generateQpay({
    required String gereeniiId,
    required String barilgiinId,
    required String register,
    required double amount,
    String? dansniiDugaar,
  }) async {
    final user = _ref.read(currentUserProvider);
    if (user == null) return;

    state = state.copyWith(isLoading: true, error: null, invoice: null);
    try {
      final invoice = await _repo.generateQpay(
        barilgiinId: barilgiinId.isNotEmpty ? barilgiinId : user.barilgiinId,
        gereeniiId: gereeniiId,
        register: register.isNotEmpty ? register : (user.register ?? ''),
        amount: amount,
        dansniiDugaar: dansniiDugaar,
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
