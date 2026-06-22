import 'dart:io';

import 'package:dio/dio.dart';
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
    final conv = ConversationModel.fromJson(res.data['data'] as Map<String, dynamic>);
    // If the stored name is a placeholder and we have a real name, patch it.
    final storedName = conv.khariltsagchiinNer;
    if (khariltsagchiinNer.isNotEmpty &&
        khariltsagchiinNer != 'Хэрэглэгч' &&
        (storedName.isEmpty || storedName == 'Хэрэглэгч')) {
      try {
        await _client.put(
          '${ApiConstants.conversations}/${conv.id}',
          data: {'khariltsagchiinNer': khariltsagchiinNer},
        );
      } catch (_) {}
    }
    return conv;
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

  Future<String?> uploadImage(File file) async {
    try {
      final formData = FormData.fromMap({
        'file': await MultipartFile.fromFile(file.path, filename: file.path.split('/').last),
      });
      final res = await _client.post(ApiConstants.upload, data: formData);
      final data = res.data;
      return data['url']?.toString() ?? data['path']?.toString();
    } catch (_) {
      return null;
    }
  }

  Future<MessageModel> sendMessageWithImage(String conversationId, String? text, String imageUrl) async {
    final res = await _client.post(
      ApiConstants.conversationMessages(conversationId),
      data: {
        if (text != null && text.isNotEmpty) 'text': text,
        'imageUrl': imageUrl,
        'role': 'user',
      },
    );
    return MessageModel.fromJson(res.data['data']['msg']);
  }
}
