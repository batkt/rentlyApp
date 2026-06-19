class TaskModel {
  final String id;
  final String title;
  final String? description;
  final int tuluv;
  final String? createdBy;
  final String? assignedTo;
  final String? createdAt;
  final String? duurssanOgnoo;
  final String? baiguullagiinId;
  final String? khariltsagchiinId;
  final String? tenantName;
  final String? turul;

  const TaskModel({
    required this.id,
    required this.title,
    this.description,
    required this.tuluv,
    this.createdBy,
    this.assignedTo,
    this.createdAt,
    this.duurssanOgnoo,
    this.baiguullagiinId,
    this.khariltsagchiinId,
    this.tenantName,
    this.turul,
  });

  bool get isNew => tuluv == 0;
  bool get isInProgress => tuluv == 1;
  bool get isCompleted => tuluv == 2;
  bool get isCancelled => tuluv == 3;

  String get statusLabel {
    switch (tuluv) {
      case 0: return 'Шинэ';
      case 1: return 'Хийгдэж байна';
      case 2: return 'Дууссан';
      case 3: return 'Цуцлагдсан';
      default: return 'Тодорхойгүй';
    }
  }

  factory TaskModel.fromJson(Map<String, dynamic> json) {
    return TaskModel(
      id: json['_id']?.toString() ?? '',
      title: json['title']?.toString() ?? '',
      description: json['description']?.toString(),
      tuluv: int.tryParse(json['tuluv']?.toString() ?? '0') ?? 0,
      createdBy: json['createdBy']?.toString(),
      assignedTo: json['assignedTo']?.toString(),
      createdAt: json['createdAt']?.toString(),
      duurssanOgnoo: json['duurssanOgnoo']?.toString(),
      baiguullagiinId: json['baiguullagiinId']?.toString(),
      khariltsagchiinId: json['khariltsagchiinId']?.toString(),
      tenantName: json['tenantName']?.toString(),
      turul: json['turul']?.toString(),
    );
  }
}
