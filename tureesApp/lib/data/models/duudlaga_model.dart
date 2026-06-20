class DuudlagaModel {
  final String id;
  final String title;
  final String message;
  final String duudlagiinTurul;
  final int tuluv; // 0=active, 1=completed, -1=cancelled
  final String khariltsagchiinId;
  final String khariltsagchiinNer;
  final String khariltsagchiinUtas;
  final String? khariltsagchiinGereeniiDugaar;
  final String? khariltsagchiinTalbainDugaar;
  final String? khariltsagchiinRegister;
  final String? baiguullagiinId;
  final String? barilgiinId;
  final String? tailbar;
  final String? createdAt;
  final String? updatedAt;

  const DuudlagaModel({
    required this.id,
    required this.title,
    required this.message,
    required this.duudlagiinTurul,
    required this.tuluv,
    required this.khariltsagchiinId,
    required this.khariltsagchiinNer,
    required this.khariltsagchiinUtas,
    this.khariltsagchiinGereeniiDugaar,
    this.khariltsagchiinTalbainDugaar,
    this.khariltsagchiinRegister,
    this.baiguullagiinId,
    this.barilgiinId,
    this.tailbar,
    this.createdAt,
    this.updatedAt,
  });

  bool get isActive => tuluv == 0;
  bool get isCompleted => tuluv == 1;
  bool get isCancelled => tuluv == -1;

  String get statusText {
    switch (tuluv) {
      case 0: return 'Идэвхтэй';
      case 1: return 'Дууссан';
      case -1: return 'Цуцлагдсан';
      default: return 'Тодорхойгүй';
    }
  }

  factory DuudlagaModel.fromJson(Map<String, dynamic> json) {
    return DuudlagaModel(
      id: json['_id']?.toString() ?? '',
      title: json['title']?.toString() ?? '',
      message: json['message']?.toString() ?? '',
      duudlagiinTurul: json['duudlagiinTurul']?.toString() ?? 'duudlaga',
      tuluv: int.tryParse(json['tuluv']?.toString() ?? '0') ?? 0,
      khariltsagchiinId: json['khariltsagchiinId']?.toString() ?? '',
      khariltsagchiinNer: json['khariltsagchiinNer']?.toString() ?? '',
      khariltsagchiinUtas: json['khariltsagchiinUtas']?.toString() ?? '',
      khariltsagchiinGereeniiDugaar: json['khariltsagchiinGereeniiDugaar']?.toString(),
      khariltsagchiinTalbainDugaar: json['khariltsagchiinTalbainDugaar']?.toString(),
      khariltsagchiinRegister: json['khariltsagchiinRegister']?.toString(),
      baiguullagiinId: json['baiguullagiinId']?.toString(),
      barilgiinId: json['barilgiinId']?.toString(),
      tailbar: json['tailbar']?.toString(),
      createdAt: json['createdAt']?.toString(),
      updatedAt: json['updatedAt']?.toString(),
    );
  }

  DuudlagaModel copyWith({int? tuluv, String? tailbar}) {
    return DuudlagaModel(
      id: id,
      title: title,
      message: message,
      duudlagiinTurul: duudlagiinTurul,
      tuluv: tuluv ?? this.tuluv,
      khariltsagchiinId: khariltsagchiinId,
      khariltsagchiinNer: khariltsagchiinNer,
      khariltsagchiinUtas: khariltsagchiinUtas,
      khariltsagchiinGereeniiDugaar: khariltsagchiinGereeniiDugaar,
      khariltsagchiinTalbainDugaar: khariltsagchiinTalbainDugaar,
      khariltsagchiinRegister: khariltsagchiinRegister,
      baiguullagiinId: baiguullagiinId,
      barilgiinId: barilgiinId,
      tailbar: tailbar ?? this.tailbar,
      createdAt: createdAt,
      updatedAt: updatedAt,
    );
  }
}
