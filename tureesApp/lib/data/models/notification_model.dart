class NotificationModel {
  final String id;
  final String title;
  final String message;
  final String? khariltsagchiinId;
  final String? baiguullagiinId;
  final int tuluv;
  final int? turul;
  final String? createdAt;

  const NotificationModel({
    required this.id,
    required this.title,
    required this.message,
    this.khariltsagchiinId,
    this.baiguullagiinId,
    required this.tuluv,
    this.turul,
    this.createdAt,
  });

  bool get isUnread => tuluv == 0;

  factory NotificationModel.fromJson(Map<String, dynamic> json) {
    return NotificationModel(
      id: json['_id']?.toString() ?? '',
      title: json['title']?.toString() ?? '',
      message: json['message']?.toString() ?? '',
      khariltsagchiinId: json['khariltsagchiinId']?.toString(),
      baiguullagiinId: json['baiguullagiinId']?.toString(),
      tuluv: int.tryParse(json['tuluv']?.toString() ?? '0') ?? 0,
      turul: int.tryParse(json['turul']?.toString() ?? ''),
      createdAt: json['createdAt']?.toString(),
    );
  }
}
