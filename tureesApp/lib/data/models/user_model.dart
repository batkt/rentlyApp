class UserModel {
  final String id;
  final String ner;
  final String ovog;
  final List<String> utas;
  final String? mail;
  final String? register;
  final String? customerTin;
  final String baiguullagiinId;
  final String barilgiinId;
  final String zochinTurul;
  final String? token;

  const UserModel({
    required this.id,
    required this.ner,
    required this.ovog,
    required this.utas,
    this.mail,
    this.register,
    this.customerTin,
    required this.baiguullagiinId,
    required this.barilgiinId,
    required this.zochinTurul,
    this.token,
  });

  String get fullName => '$ovog $ner'.trim();
  String get shortName => ovog.isNotEmpty ? '${ovog[0]}.$ner' : ner;
  String get primaryPhone => utas.isNotEmpty ? utas.first : '';

  factory UserModel.fromJson(Map<String, dynamic> json) {
    return UserModel(
      id: json['_id']?.toString() ?? '',
      ner: json['ner']?.toString() ?? '',
      ovog: json['ovog']?.toString() ?? '',
      utas: (json['utas'] as List?)?.map((e) => e.toString()).toList() ?? [],
      mail: json['mail']?.toString(),
      register: json['register']?.toString(),
      customerTin: json['customerTin']?.toString(),
      baiguullagiinId: json['baiguullagiinId']?.toString() ?? '',
      barilgiinId: json['barilgiinId']?.toString() ?? '',
      zochinTurul: json['zochinTurul']?.toString() ?? '',
      token: json['token']?.toString(),
    );
  }

  Map<String, dynamic> toJson() => {
    '_id': id,
    'ner': ner,
    'ovog': ovog,
    'utas': utas,
    'mail': mail,
    'register': register,
    'baiguullagiinId': baiguullagiinId,
    'barilgiinId': barilgiinId,
    'zochinTurul': zochinTurul,
  };
}

class OrgSelectionModel {
  final String id;
  final String ner;
  final String register;
  final String barilgiinId;
  final String barilgiinNer;

  const OrgSelectionModel({
    required this.id,
    required this.ner,
    required this.register,
    required this.barilgiinId,
    required this.barilgiinNer,
  });

  factory OrgSelectionModel.fromJson(Map<String, dynamic> json) {
    return OrgSelectionModel(
      id: json['_id']?.toString() ?? json['baiguullagiinId']?.toString() ?? '',
      ner: json['ner']?.toString() ?? '',
      register: json['register']?.toString() ?? '',
      barilgiinId: json['barilgiinId']?.toString() ?? '',
      barilgiinNer: json['barilgiinNer']?.toString() ?? '',
    );
  }
}
