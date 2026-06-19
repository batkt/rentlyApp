import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/network/dio_client.dart';
import '../../core/constants/api_constants.dart';
import '../models/chat_model.dart';

final chatRepositoryProvider = Provider<ChatRepository>((ref) {
  return ChatRepository(ref.read(dioClientProvider));
});

class ChatRepository {
  final DioClient _client;

  ChatRepository(this._client);

  Future<ConversationModel> getOrCreateConversation({
    required String khariltsagchiinId,
    required String khariltsagchiinNer,
    required String baiguullagiinId,
    required String barilgiinId,
  }) async {
    final res = await _client.post(ApiConstants.conversations, data: {
      'khariltsagchiinId': khariltsagchiinId,
      'khariltsagchiinNer': khariltsagchiinNer,
      'baiguullagiinId': baiguullagiinId,
      'barilgiinId': barilgiinId,
    });
    return ConversationModel.fromJson(res.data['data'] as Map<String, dynamic>);
  }

  Future<List<MessageModel>> getMessages(String conversationId) async {
    final res = await _client.get(ApiConstants.conversationMessages(conversationId));
    final list = (res.data['data'] as List?) ?? [];
    return list.map((e) => MessageModel.fromJson(e)).toList();
  }

  Future<MessageModel> sendMessage(String conversationId, String content) async {
    final res = await _client.post(
      ApiConstants.conversationMessages(conversationId),
      data: {'text': content, 'role': 'user'},
    );
    return MessageModel.fromJson(res.data['data']['msg']);
  }

  Future<void> markAsRead(String conversationId) async {
    await _client.put(ApiConstants.markConversationRead(conversationId));
  }
}
