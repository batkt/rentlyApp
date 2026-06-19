import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/formatters.dart';
import '../../../data/models/chat_model.dart';
import '../../providers/chat_provider.dart';
import '../../widgets/common/app_loading.dart';

class ChatDetailScreen extends ConsumerStatefulWidget {
  final String conversationId;
  final ConversationModel? conversation;

  const ChatDetailScreen({
    super.key,
    required this.conversationId,
    this.conversation,
  });

  @override
  ConsumerState<ChatDetailScreen> createState() => _ChatDetailScreenState();
}

class _ChatDetailScreenState extends ConsumerState<ChatDetailScreen> {
  final _messageController = TextEditingController();
  final _scrollController = ScrollController();

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Future<void> _sendMessage() async {
    final text = _messageController.text.trim();
    if (text.isEmpty) return;
    _messageController.clear();
    await ref.read(messagesProvider(widget.conversationId).notifier).send(text);
    _scrollToBottom();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(messagesProvider(widget.conversationId));
    final name = widget.conversation?.khariltsagchiinNer.isNotEmpty == true
        ? widget.conversation!.khariltsagchiinNer
        : 'Захиргаа';

    ref.listen(messagesProvider(widget.conversationId), (prev, next) {
      if ((prev?.messages.length ?? 0) < next.messages.length) {
        _scrollToBottom();
      }
    });

    return Scaffold(
      resizeToAvoidBottomInset: true,
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => context.pop(),
        ),
        title: Row(
          children: [
            CircleAvatar(
              radius: 18,
              backgroundColor: AppColors.success,
              child: Text(name.isNotEmpty ? name[0].toUpperCase() : 'З',
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(name, style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700)),
                  const Text('Онлайн', style: TextStyle(fontSize: 11, color: AppColors.success)),
                ],
              ),
            ),
          ],
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: Builder(builder: (context) {
              if (state.isLoading && state.messages.isEmpty) {
                return const AppLoading();
              }
              if (state.messages.isEmpty) {
                return const AppEmpty(
                  icon: Icons.chat_bubble_outline_rounded,
                  message: 'Мессеж байхгүй байна',
                  subMessage: 'Эхний мессежийг илгээнэ үү',
                );
              }
              return ListView.builder(
                controller: _scrollController,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                itemCount: state.messages.length,
                itemBuilder: (context, index) {
                  final message = state.messages[index];
                  final isMine = message.isFromUser;
                  final showDate = index == 0 ||
                      _isDifferentDay(state.messages[index - 1].createdAt, message.createdAt);

                  return Column(
                    children: [
                      if (showDate) _DateDivider(date: message.createdAt),
                      _MessageBubble(message: message, isMine: isMine),
                    ],
                  );
                },
              );
            }),
          ),
          _buildInputBar(state),
        ],
      ),
    );
  }

  bool _isDifferentDay(String? prev, String? curr) {
    if (prev == null || curr == null) return true;
    try {
      final d1 = DateTime.parse(prev);
      final d2 = DateTime.parse(curr);
      return d1.day != d2.day || d1.month != d2.month || d1.year != d2.year;
    } catch (_) {
      return false;
    }
  }

  Widget _buildInputBar(MessagesState state) {
    return Container(
      decoration: BoxDecoration(
        color: context.appSurface,
        border: Border(top: BorderSide(color: context.appDivider)),
      ),
      padding: EdgeInsets.fromLTRB(16, 10, 8, MediaQuery.of(context).padding.bottom + 10),
      child: Row(
        children: [
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                color: context.appInputFill,
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: context.appDivider),
              ),
              child: TextField(
                controller: _messageController,
                maxLines: 4,
                minLines: 1,
                textCapitalization: TextCapitalization.sentences,
                decoration: const InputDecoration(
                  hintText: 'Мессеж бичих...',
                  border: InputBorder.none,
                  contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  filled: false,
                ),
                onSubmitted: (_) => _sendMessage(),
              ),
            ),
          ),
          const SizedBox(width: 8),
          GestureDetector(
            onTap: state.isSending ? null : _sendMessage,
            child: Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: state.isSending ? context.appTextTertiary : AppColors.primary,
                shape: BoxShape.circle,
              ),
              child: state.isSending
                  ? const Padding(padding: EdgeInsets.all(12), child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : const Icon(Icons.send_rounded, color: Colors.white, size: 20),
            ),
          ),
        ],
      ),
    );
  }
}

class _MessageBubble extends StatelessWidget {
  final MessageModel message;
  final bool isMine;

  const _MessageBubble({required this.message, required this.isMine});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        mainAxisAlignment: isMine ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (!isMine) ...[
            CircleAvatar(
              radius: 16,
              backgroundColor: AppColors.success,
              child: Text(
                (message.ajiltanNer?.isNotEmpty == true) ? message.ajiltanNer![0].toUpperCase() : 'З',
                style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w700),
              ),
            ),
            const SizedBox(width: 8),
          ],
          Flexible(
            child: Container(
              constraints: BoxConstraints(maxWidth: MediaQuery.sizeOf(context).width * 0.72),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: isMine ? AppColors.primary : context.appCardBg,
                borderRadius: BorderRadius.only(
                  topLeft: const Radius.circular(16),
                  topRight: const Radius.circular(16),
                  bottomLeft: Radius.circular(isMine ? 16 : 4),
                  bottomRight: Radius.circular(isMine ? 4 : 16),
                ),
                border: isMine ? null : Border.all(color: context.appDivider),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    message.content,
                    style: TextStyle(
                      color: isMine ? Colors.white : context.appTextPrimary,
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    message.createdAt != null ? AppFormatters.dateTime(message.createdAt) : '',
                    style: TextStyle(
                      fontSize: 10,
                      color: isMine ? Colors.white60 : context.appTextTertiary,
                    ),
                  ),
                ],
              ),
            ),
          ),
          if (isMine) const SizedBox(width: 8),
        ],
      ),
    );
  }
}

class _DateDivider extends StatelessWidget {
  final String? date;

  const _DateDivider({this.date});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Row(
        children: [
          const Expanded(child: Divider()),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Text(
              date != null ? AppFormatters.date(date) : '',
              style: Theme.of(context).textTheme.labelSmall?.copyWith(color: context.appTextTertiary),
            ),
          ),
          const Expanded(child: Divider()),
        ],
      ),
    );
  }
}
