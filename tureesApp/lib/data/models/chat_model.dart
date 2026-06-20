class ConversationModel {
  final String id;
  final String khariltsagchiinNer;
  final String khariltsagchiinId;
  final String? lastMessage;
  final String? lastMessageAt;
  final int unreadCount;

  const ConversationModel({
    required this.id,
    required this.khariltsagchiinNer,
    required this.khariltsagchiinId,
    this.lastMessage,
    this.lastMessageAt,
    required this.unreadCount,
  });

  factory ConversationModel.fromJson(Map<String, dynamic> json) {
    return ConversationModel(
      id: json['_id']?.toString() ?? '',
      khariltsagchiinNer: json['khariltsagchiinNer']?.toString() ?? '',
      khariltsagchiinId: json['khariltsagchiinId']?.toString() ?? '',
      lastMessage: json['lastMessage']?.toString(),
      lastMessageAt: json['lastMessageAt']?.toString(),
      unreadCount: int.tryParse(json['unreadCount']?.toString() ?? '0') ?? 0,
    );
  }
}

class MessageModel {
  final String id;
  final String conversationId;
  final String role; // "user" or "agent"
  final String? ajiltanNer;
  final String content;
  final String? imageUrl;
  final String? createdAt;

  const MessageModel({
    required this.id,
    required this.conversationId,
    required this.role,
    this.ajiltanNer,
    required this.content,
    this.imageUrl,
    this.createdAt,
  });

  bool get isFromUser => role == 'user';
  bool get hasImage => imageUrl != null && imageUrl!.isNotEmpty;

  factory MessageModel.fromJson(Map<String, dynamic> json) {
    return MessageModel(
      id: json['_id']?.toString() ?? '',
      conversationId: json['conversationId']?.toString() ?? '',
      role: json['role']?.toString() ?? 'user',
      ajiltanNer: json['ajiltanNer']?.toString(),
      content: json['text']?.toString() ?? '',
      imageUrl: json['imageUrl']?.toString() ?? json['image']?.toString(),
      createdAt: json['createdAt']?.toString(),
    );
  }
}
