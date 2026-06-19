class QpayInvoiceModel {
  final String? invoiceId;
  final String? qrText;
  final String? qrImage;
  final List<QpayUrlModel> urls;
  final double amount;
  final String gereeniiId;

  const QpayInvoiceModel({
    this.invoiceId,
    this.qrText,
    this.qrImage,
    required this.urls,
    required this.amount,
    required this.gereeniiId,
  });

  factory QpayInvoiceModel.fromJson(Map<String, dynamic> json) {
    return QpayInvoiceModel(
      invoiceId: json['invoice_id']?.toString() ?? json['invoiceId']?.toString(),
      qrText: json['qr_text']?.toString() ?? json['qrText']?.toString(),
      qrImage: json['qr_image']?.toString() ?? json['qrImage']?.toString(),
      urls: (json['urls'] as List?)?.map((e) => QpayUrlModel.fromJson(e)).toList() ?? [],
      amount: double.tryParse(json['amount']?.toString() ?? '0') ?? 0.0,
      gereeniiId: json['gereeniiId']?.toString() ?? '',
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
