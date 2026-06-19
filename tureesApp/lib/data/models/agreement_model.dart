class AgreementModel {
  final String id;
  final String gereeniiDugaar;
  final String? gereeniiOgnoo;
  final String ner;
  final String? ovog;
  final String? register;
  final List<String> utas;
  final String? talbainDugaar;
  final List<String> talbainIdnuud;
  final int? khugatsaa;
  final int tuluv;
  final double uldegdel;
  final String baiguullagiinId;
  final String barilgiinId;
  final String? davkhar;
  final double? talbainKhemjee;
  final double? uneKhemjee;
  final List<TransactionModel> avlaga;
  final List<ZardalModel> zardluud;
  final String? duusakhOgnoo;

  const AgreementModel({
    required this.id,
    required this.gereeniiDugaar,
    this.gereeniiOgnoo,
    required this.ner,
    this.ovog,
    this.register,
    required this.utas,
    this.talbainDugaar,
    required this.talbainIdnuud,
    this.khugatsaa,
    required this.tuluv,
    required this.uldegdel,
    required this.baiguullagiinId,
    required this.barilgiinId,
    this.davkhar,
    this.talbainKhemjee,
    this.uneKhemjee,
    required this.avlaga,
    required this.zardluud,
    this.duusakhOgnoo,
  });

  String get tenantName => '${ovog ?? ''} $ner'.trim();
  String get shortName => ovog != null && ovog!.isNotEmpty ? '${ovog![0]}.$ner' : ner;
  bool get isActive => tuluv == 1;
  bool get hasDebt => uldegdel > 0;

  factory AgreementModel.fromJson(Map<String, dynamic> json) {
    return AgreementModel(
      id: json['_id']?.toString() ?? '',
      gereeniiDugaar: json['gereeniiDugaar']?.toString() ?? '',
      gereeniiOgnoo: json['gereeniiOgnoo']?.toString(),
      ner: json['ner']?.toString() ?? '',
      ovog: json['ovog']?.toString(),
      register: json['register']?.toString(),
      utas: (json['utas'] as List?)?.map((e) => e.toString()).toList() ?? [],
      talbainDugaar: json['talbainDugaar']?.toString(),
      talbainIdnuud: (json['talbainIdnuud'] as List?)?.map((e) => e.toString()).toList() ?? [],
      khugatsaa: json['khugatsaa'] != null ? int.tryParse(json['khugatsaa'].toString()) : null,
      tuluv: int.tryParse(json['tuluv']?.toString() ?? '0') ?? 0,
      uldegdel: double.tryParse(json['uldegdel']?.toString() ?? '0') ?? 0.0,
      baiguullagiinId: json['baiguullagiinId']?.toString() ?? '',
      barilgiinId: json['barilgiinId']?.toString() ?? '',
      davkhar: json['davkhar']?.toString(),
      talbainKhemjee: double.tryParse(json['talbainKhemjee']?.toString() ?? ''),
      uneKhemjee: double.tryParse(json['uneKhemjee']?.toString() ?? ''),
      avlaga: (json['avlaga'] as List?)?.map((e) => TransactionModel.fromJson(e)).toList() ?? [],
      zardluud: (json['zardluud'] as List?)?.map((e) => ZardalModel.fromJson(e)).toList() ?? [],
      duusakhOgnoo: json['duusakhOgnoo']?.toString(),
    );
  }
}

class TransactionModel {
  final String id;
  final String? ognoo;
  final double dun;
  final String? tailbar;
  final int? turul;

  const TransactionModel({
    required this.id,
    this.ognoo,
    required this.dun,
    this.tailbar,
    this.turul,
  });

  factory TransactionModel.fromJson(Map<String, dynamic> json) {
    return TransactionModel(
      id: json['_id']?.toString() ?? '',
      ognoo: json['ognoo']?.toString(),
      dun: double.tryParse(json['dun']?.toString() ?? '0') ?? 0.0,
      tailbar: json['tailbar']?.toString(),
      turul: int.tryParse(json['turul']?.toString() ?? ''),
    );
  }
}

class ZardalModel {
  final String id;
  final String ner;
  final double dun;
  final int? turul;

  const ZardalModel({
    required this.id,
    required this.ner,
    required this.dun,
    this.turul,
  });

  factory ZardalModel.fromJson(Map<String, dynamic> json) {
    return ZardalModel(
      id: json['_id']?.toString() ?? '',
      ner: json['ner']?.toString() ?? '',
      dun: double.tryParse(json['dun']?.toString() ?? '0') ?? 0.0,
      turul: int.tryParse(json['turul']?.toString() ?? ''),
    );
  }
}
