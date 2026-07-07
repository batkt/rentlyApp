/// Categories used to split sonorduulga records across the notification tabs,
/// mirroring tureesShine's requirements page (`turul` / `duudlagiinTurul`).
enum NotifCategory { medegdel, request, duudlaga }

class NotificationModel {
  final String id;
  final String title;
  final String message;
  final String? khariltsagchiinId;
  final String? baiguullagiinId;
  final int tuluv;
  final String? turul;
  final String? duudlagiinTurul;
  final String? createdAt;
  final String? gereeniiId;

  const NotificationModel({
    required this.id,
    required this.title,
    required this.message,
    this.khariltsagchiinId,
    this.baiguullagiinId,
    required this.tuluv,
    this.turul,
    this.duudlagiinTurul,
    this.createdAt,
    this.gereeniiId,
  });

  bool get isUnread => tuluv == 0;

  static const _requestTypes = {'sanal', 'sanalKhuselt', 'shaardlaga', 'gomdol'};

  /// Which tab this record belongs to.
  NotifCategory get category {
    if (turul == 'medegdel' || turul == 'sonorduulga') {
      return NotifCategory.medegdel;
    }
    if (_requestTypes.contains(turul)) return NotifCategory.request;
    if (turul == 'duudlaga') {
      // A "duudlaga" record carrying a request sub-type is really a request.
      if (_requestTypes.contains(duudlagiinTurul)) return NotifCategory.request;
      return NotifCategory.duudlaga;
    }
    // Fallback: treat unknown/general records as notifications.
    return NotifCategory.medegdel;
  }

  /// Human label for the request sub-type (Санал хүсэлт / Шаардлага / Гомдол).
  String get requestTypeLabel {
    final t = _requestTypes.contains(turul) ? turul : duudlagiinTurul;
    switch (t) {
      case 'shaardlaga':
        return 'Шаардлага';
      case 'gomdol':
        return 'Гомдол';
      case 'sanal':
      case 'sanalKhuselt':
        return 'Санал хүсэлт';
      default:
        return 'Хүсэлт';
    }
  }

  factory NotificationModel.fromJson(Map<String, dynamic> json) {
    return NotificationModel(
      id: json['_id']?.toString() ?? '',
      title: json['title']?.toString() ?? '',
      message: json['message']?.toString() ?? '',
      khariltsagchiinId: json['khariltsagchiinId']?.toString(),
      baiguullagiinId: json['baiguullagiinId'] is Map
          ? (json['baiguullagiinId']['_id']?.toString())
          : json['baiguullagiinId']?.toString(),
      tuluv: int.tryParse(json['tuluv']?.toString() ?? '0') ?? 0,
      turul: json['turul']?.toString(),
      duudlagiinTurul: json['duudlagiinTurul']?.toString(),
      createdAt: (json['createdAt'] ?? json['ognoo'])?.toString(),
      gereeniiId: json['gereeniiId']?.toString(),
    );
  }
}
