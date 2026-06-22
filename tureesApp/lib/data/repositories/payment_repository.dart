import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/network/dio_client.dart';
import '../../core/constants/api_constants.dart';
import '../models/payment_model.dart';

final paymentRepositoryProvider = Provider<PaymentRepository>((ref) {
  return PaymentRepository(ref.read(dioClientProvider));
});

class PaymentRepository {
  final DioClient _client;

  PaymentRepository(this._client);

  Future<QpayInvoiceModel> generateQpay({
    required String barilgiinId,
    required String gereeniiId,
    required String register,
    required double amount,
    String? dansniiDugaar,
  }) async {
    final res = await _client.post(ApiConstants.qpayGenerate, data: {
      'barilgiinId': barilgiinId,
      'gereeniiId': gereeniiId,
      'burtgeliinDugaar': register,
      'dun': amount,
      if (dansniiDugaar != null) 'dansniiDugaar': dansniiDugaar,
    });

    final data = res.data as Map<String, dynamic>;
    return QpayInvoiceModel(
      invoiceId: data['id']?.toString() ?? data['invoice_id']?.toString() ?? data['invoiceId']?.toString(),
      qrText: data['qr_code']?.toString() ?? data['qr_text']?.toString() ?? data['qrText']?.toString(),
      qrImage: data['qr_image']?.toString() ?? data['qrImage']?.toString(),
      urls: (data['urls'] as List?)?.map((e) => QpayUrlModel.fromJson(e)).toList() ?? [],
      amount: amount,
      gereeniiId: gereeniiId,
    );
  }

  Future<bool> verifyPayment(String invoiceId, String barilgiinId) async {
    try {
      final res = await _client.post(ApiConstants.qpayVerify, data: {
        'invoiceId': invoiceId,
        'barilgiinId': barilgiinId,
      });
      final data = res.data as Map<String, dynamic>;
      return data['tuluv'] == 1 || data['paid'] == true;
    } catch (_) {
      return false;
    }
  }

  Future<double> getPaymentAmount(String gereeniiId) async {
    try {
      final res = await _client.post(ApiConstants.qpayAmount, data: {
        'gereeniiId': gereeniiId,
      });
      final data = res.data as Map<String, dynamic>;
      return double.tryParse(data['amount']?.toString() ?? '0') ?? 0.0;
    } catch (_) {
      return 0.0;
    }
  }
}
