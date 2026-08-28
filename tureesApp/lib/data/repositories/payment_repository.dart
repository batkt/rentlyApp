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
      zakhialgiinDugaar: data['zakhialgiinDugaar']?.toString(),
      qrText: data['qr_code']?.toString() ?? data['qr_text']?.toString() ?? data['qrText']?.toString(),
      qrImage: data['qr_image']?.toString() ?? data['qrImage']?.toString(),
      urls: (data['urls'] as List?)?.map((e) => QpayUrlModel.fromJson(e)).toList() ?? [],
      amount: double.tryParse(data['_actualDun']?.toString() ?? '') ?? amount,
      gereeniiId: gereeniiId,
      barilgiinId: barilgiinId,
    );
  }

  /// Нэхэмжлэл төлөгдсөн эсэхийг шалгана.
  ///
  /// Өмнө нь `/qpayShalgay` руу хандаад хариунаас `tuluv == 1` эсвэл
  /// `paid == true`-г уншдаг байсан. Backend ийм талбар хэзээ ч буцаадаггүй
  /// (`/qpayShalgay`-г өөр ямар ч клиент дуудахгүй тул хэн ч анзаараагүй) —
  /// улмаас төлбөр төлөгдсөн ч шалгалт үргэлж `false` буцаадаг байв.
  ///
  /// `/qpayMedeelelAvya` нь QPay-н callback-ийн бичсэн `tulsunEsekh`-ийг
  /// буцаадаг бөгөөд вэбийн /pay хуудас мөн энэ эх сурвалжийг ашигладаг.
  Future<bool> verifyPayment({
    required String baiguullagiinId,
    required String barilgiinId,
    required String zakhialgiinDugaar,
  }) async {
    try {
      final res = await _client.get(
        ApiConstants.qpayTuluv(baiguullagiinId, barilgiinId, zakhialgiinDugaar),
      );
      final data = res.data;
      return data is Map && data['tulsunEsekh'] == true;
    } catch (_) {
      // 404 = нэхэмжлэл олдсонгүй, сүлжээний алдаа г.м — төлөгдсөн гэж үзэхгүй.
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
