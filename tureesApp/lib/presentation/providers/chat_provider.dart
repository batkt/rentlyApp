import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/models/chat_model.dart';
import '../../data/models/user_model.dart';
import '../../data/repositories/chat_repository.dart';
import '../../core/socket/socket_service.dart';
import 'auth_provider.dart';

final conversationsProvider = StateNotifierProvider<ConversationsNotifier, ConversationsState>((ref) {
  final user = ref.watch(currentUserProvider);
  return ConversationsNotifier(ref.read(chatRepositoryProvider), user);
});

final activeConversationProvider = StateProvider<String?>((ref) => null);

final messagesProvider = StateNotifierProvider.family<MessagesNotifier, MessagesState, String>((ref, convId) {
  final userId = ref.read(currentUserProvider)?.id ?? '';
  return MessagesNotifier(
    ref.read(chatRepositoryProvider),
    ref.read(socketServiceProvider),
    convId,
    userId,
  );
});

class ConversationsState {
  final bool isLoading;
  final List<ConversationModel> conversations;
  final String? error;

  const ConversationsState({
    this.isLoading = false,
    this.conversations = const [],
    this.error,
  });

  ConversationsState copyWith({
    bool? isLoading,
    List<ConversationModel>? conversations,
    String? error,
  }) => ConversationsState(
    isLoading: isLoading ?? this.isLoading,
    conversations: conversations ?? this.conversations,
    error: error,
  );
}

class ConversationsNotifier extends StateNotifier<ConversationsState> {
  final ChatRepository _repo;
  final UserModel? _user;

  ConversationsNotifier(this._repo, this._user) : super(const ConversationsState());

  Future<void> load() async {
    final user = _user;
    if (user == null) return;
    state = state.copyWith(isLoading: true, error: null);
    try {
      final conv = await _repo.getOrCreateConversation(
        khariltsagchiinId: user.id,
        khariltsagchiinNer: user.fullName,
        baiguullagiinId: user.baiguullagiinId,
        barilgiinId: user.barilgiinId,
      );
      state = state.copyWith(isLoading: false, conversations: [conv]);
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }
}

class MessagesState {
  final bool isLoading;
  final bool isSending;
  final List<MessageModel> messages;
  final String? error;

  const MessagesState({
    this.isLoading = false,
    this.isSending = false,
    this.messages = const [],
    this.error,
  });

  MessagesState copyWith({
    bool? isLoading,
    bool? isSending,
    List<MessageModel>? messages,
    String? error,
  }) => MessagesState(
    isLoading: isLoading ?? this.isLoading,
    isSending: isSending ?? this.isSending,
    messages: messages ?? this.messages,
    error: error,
  );
}

class MessagesNotifier extends StateNotifier<MessagesState> {
  final ChatRepository _repo;
  final SocketService _socket;
  final String _convId;
  final String _userId;

  MessagesNotifier(this._repo, this._socket, this._convId, this._userId) : super(const MessagesState()) {
    load();
    _socket.on('shineChatKhariult$_userId', _onNewMessage);
  }

  void _onNewMessage(dynamic data) {
    if (data is Map && data['conversationId'] == _convId) {
      final msgData = data['message'];
      if (msgData is Map<String, dynamic>) {
        final msg = MessageModel.fromJson(msgData);
        state = state.copyWith(messages: [...state.messages, msg]);
      }
    }
  }

  Future<void> load() async {
    state = state.copyWith(isLoading: true);
    try {
      final msgs = await _repo.getMessages(_convId);
      state = state.copyWith(isLoading: false, messages: msgs);
      await _repo.markAsRead(_convId);
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  Future<void> send(String content) async {
    if (content.trim().isEmpty) return;
    state = state.copyWith(isSending: true);
    try {
      final msg = await _repo.sendMessage(_convId, content.trim());
      state = state.copyWith(isSending: false, messages: [...state.messages, msg]);
    } catch (e) {
      state = state.copyWith(isSending: false, error: 'Мессеж илгээхэд алдаа гарлаа');
    }
  }

  Future<void> sendWithImage(File imageFile, {String? text}) async {
    state = state.copyWith(isSending: true);
    try {
      final url = await _repo.uploadImage(imageFile);
      if (url == null) {
        state = state.copyWith(isSending: false, error: 'Зураг байршуулахад алдаа гарлаа');
        return;
      }
      final msg = await _repo.sendMessageWithImage(_convId, text, url);
      state = state.copyWith(isSending: false, messages: [...state.messages, msg]);
    } catch (_) {
      state = state.copyWith(isSending: false, error: 'Зураг илгээхэд алдаа гарлаа');
    }
  }

  @override
  void dispose() {
    _socket.off('shineChatKhariult$_userId');
    super.dispose();
  }
}
