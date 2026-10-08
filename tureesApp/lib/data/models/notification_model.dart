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

  /// Менежер (ажилтан) үүсгэсэн бол дүүрдэг. Түрээслэгч өөрөө илгээсэн
  /// хүсэлт/дуудлагад байхгүй — [uuriinIlgeesenKhuselt] үүгээр ялгана.
  final String? ajiltniiId;

  /// Түрээслэгч олон барилгад гэрээтэй үед жагсаалтыг сонгосон барилгаар шүүнэ.
  final String? barilgiinId;

  /// Хавсаргасан зургуудын id (`/zuragAvya`).
  final List<String> zurguud;

  /// Менежерийн хариунууд: {message, zurguud, ajiltniiNer, ognoo}.
  final List<Map<String, dynamic>> khariultuud;

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
    this.ajiltniiId,
    this.barilgiinId,
    this.zurguud = const [],
    this.khariultuud = const [],
  });

  NotificationModel copyWith({String? message, int? tuluv}) => NotificationModel(
        id: id,
        title: title,
        message: message ?? this.message,
        khariltsagchiinId: khariltsagchiinId,
        baiguullagiinId: baiguullagiinId,
        tuluv: tuluv ?? this.tuluv,
        turul: turul,
        duudlagiinTurul: duudlagiinTurul,
        createdAt: createdAt,
        gereeniiId: gereeniiId,
        ajiltniiId: ajiltniiId,
        barilgiinId: barilgiinId,
        zurguud: zurguud,
        khariultuud: khariultuud,
      );

  /// Сонгосон барилгынх уу? Барилгагүй (хуучин) бичлэг бүх барилгад харагдана.
  bool barilgiinKhuu(String songosonBarilgiinId) =>
      songosonBarilgiinId.isEmpty ||
      barilgiinId == null ||
      barilgiinId!.isEmpty ||
      barilgiinId == songosonBarilgiinId;

  /// Түрээслэгч өөрөө илгээсэн бичлэг үү? Эдгээр нь менежерт (turees) очих
  /// зорилготой ба ижил `khariltsagchiinId`-тайгаа буцаж ирдэг тул
  /// түрээслэгчийн мэдэгдлийн жагсаалтад орох ёсгүй.
  /// tureesShine-ий `uuriinIlgeesenKhuselt`-тэй ижил дүрэм.
  bool get uuriinIlgeesenKhuselt {
    if ((ajiltniiId ?? '').isNotEmpty) return false;
    return const {'duudlaga', 'sanal', 'gomdol', 'sanalKhuselt'}
        .contains(turul);
  }

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
      ajiltniiId: json['ajiltniiId']?.toString(),
      barilgiinId: json['barilgiinId'] is Map
          ? (json['barilgiinId']['_id']?.toString())
          : json['barilgiinId']?.toString(),
      zurguud: (json['zurguud'] as List?)
              ?.map((e) => e.toString())
              .where((e) => e.isNotEmpty)
              .toList() ??
          const [],
      khariultuud: (json['khariultuud'] as List?)
              ?.whereType<Map>()
              .map((e) => Map<String, dynamic>.from(e))
              .toList() ??
          const [],
    );
  }
}
