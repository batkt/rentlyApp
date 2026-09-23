class QpayInvoiceModel {
  final String? invoiceId;

  /// The order number the backend assigns to this QPay invoice. It — not the
  /// QPay invoice id — is what the payment callback and the `qpay/<org>/<id>`
  /// socket event are keyed on.
  final String? zakhialgiinDugaar;
  final String? qrText;
  final String? qrImage;
  final List<QpayUrlModel> urls;

  /// QPay шимтгэл орсон нийт дүн.
  final double amount;

  /// Хэрэглэгчийн оруулсан шимтгэлгүй дүн, шимтгэл, түүний төрөл ("300" /
  /// "1%"). Backend хуучин хувилбартай бол null байна.
  final double? anhniiDun;
  final double? shimtgel;
  final String? shimtgelTurul;
  final String gereeniiId;

  /// Нэхэмжлэлийг үүсгэсэн барилга. Түрээслэгч олон барилгад гэрээтэй байж
  /// болох тул төлөлт шалгахдаа нэвтэрсэн хэрэглэгчийн барилга биш, ЭНЭ
  /// нэхэмжлэлийнхийг ашиглана.
  final String barilgiinId;

  const QpayInvoiceModel({
    this.invoiceId,
    this.zakhialgiinDugaar,
    this.qrText,
    this.qrImage,
    required this.urls,
    required this.amount,
    this.anhniiDun,
    this.shimtgel,
    this.shimtgelTurul,
    required this.gereeniiId,
    this.barilgiinId = '',
  });

  bool get shimtgelteiEsekh => (shimtgel ?? 0) > 0;

  /// `POST /qpayGargaya`-н хариуг унших. Сервер `qpayShimtgelTusdaa`
  /// тохиргоотой үед нэхэмжлэхийн дүн дээр QPay шимтгэл нэмдэг тул нийт
  /// дүнг ЗААВАЛ хариунаас (`niitDun`) авна — [oruulsanDun] бол хэрэглэгч
  /// бичсэн шимтгэлгүй дүн ба зөвхөн хариу нийт дүн агуулаагүй тохиолдолд
  /// нөөц болгож хэрэглэнэ. Үүнийг сольвол QR 400₮ гуйж байхад дэлгэц дээр
  /// 100₮ харагдана.
  factory QpayInvoiceModel.fromQpayGargaya(
    Map<String, dynamic> data, {
    required double oruulsanDun,
    required String gereeniiId,
    required String barilgiinId,
  }) {
    return QpayInvoiceModel(
      invoiceId: data['id']?.toString() ??
          data['invoice_id']?.toString() ??
          data['invoiceId']?.toString(),
      zakhialgiinDugaar: data['zakhialgiinDugaar']?.toString(),
      qrText: data['qr_code']?.toString() ??
          data['qr_text']?.toString() ??
          data['qrText']?.toString(),
      qrImage: data['qr_image']?.toString() ?? data['qrImage']?.toString(),
      urls: (data['urls'] as List?)
              ?.map((e) => QpayUrlModel.fromJson(e))
              .toList() ??
          [],
      amount: double.tryParse(data['niitDun']?.toString() ?? '') ??
          double.tryParse(data['_actualDun']?.toString() ?? '') ??
          oruulsanDun,
      anhniiDun: double.tryParse(data['anhniiDun']?.toString() ?? ''),
      shimtgel: double.tryParse(data['shimtgel']?.toString() ?? ''),
      shimtgelTurul: data['shimtgelTurul']?.toString(),
      gereeniiId: gereeniiId,
      barilgiinId: barilgiinId,
    );
  }

  factory QpayInvoiceModel.fromJson(Map<String, dynamic> json) {
    return QpayInvoiceModel(
      invoiceId: json['invoice_id']?.toString() ?? json['invoiceId']?.toString(),
      zakhialgiinDugaar: json['zakhialgiinDugaar']?.toString(),
      qrText: json['qr_text']?.toString() ?? json['qrText']?.toString(),
      qrImage: json['qr_image']?.toString() ?? json['qrImage']?.toString(),
      urls: (json['urls'] as List?)?.map((e) => QpayUrlModel.fromJson(e)).toList() ?? [],
      amount: double.tryParse(json['amount']?.toString() ?? '0') ?? 0.0,
      gereeniiId: json['gereeniiId']?.toString() ?? '',
      barilgiinId: json['barilgiinId']?.toString() ?? '',
    );
  }
}

class QpayUrlModel {
  final String name;
  final String description;
  final String logo;
  final String link;

  const QpayUrlModel({
    required this.name,
    required this.description,
    required this.logo,
    required this.link,
  });

  factory QpayUrlModel.fromJson(Map<String, dynamic> json) {
    return QpayUrlModel(
      name: json['name']?.toString() ?? '',
      description: json['description']?.toString() ?? '',
      logo: json['logo']?.toString() ?? '',
      link: json['link']?.toString() ?? '',
    );
  }
}

class InvoiceModel {
  final String id;
  final String? ognoo;
  final double dun;
  final String? tailbar;
  final int tuluv;
  final String? tuluvsanOgnoo;
  final String gereeniiId;
  final String? gereeniiDugaar;
  final String? tenantName;

  const InvoiceModel({
    required this.id,
    this.ognoo,
    required this.dun,
    this.tailbar,
    required this.tuluv,
    this.tuluvsanOgnoo,
    required this.gereeniiId,
    this.gereeniiDugaar,
    this.tenantName,
  });

  bool get isPaid => tuluv == 1;

  factory InvoiceModel.fromJson(Map<String, dynamic> json) {
    return InvoiceModel(
      id: json['_id']?.toString() ?? '',
      ognoo: json['ognoo']?.toString(),
      dun: double.tryParse(json['dun']?.toString() ?? '0') ?? 0.0,
      tailbar: json['tailbar']?.toString(),
      tuluv: int.tryParse(json['tuluv']?.toString() ?? '0') ?? 0,
      tuluvsanOgnoo: json['tuluvsanOgnoo']?.toString(),
      gereeniiId: json['gereeniiId']?.toString() ?? '',
      gereeniiDugaar: json['gereeniiDugaar']?.toString(),
      tenantName: json['tenantName']?.toString(),
    );
  }
}
