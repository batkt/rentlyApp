import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/formatters.dart';
import '../../../data/models/chat_model.dart';
import '../../providers/chat_provider.dart';
import '../../widgets/common/app_loading.dart';

class ChatListScreen extends ConsumerStatefulWidget {
  const ChatListScreen({super.key});

  @override
  ConsumerState<ChatListScreen> createState() => _ChatListScreenState();
}

class _ChatListScreenState extends ConsumerState<ChatListScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(conversationsProvider.notifier).load();
    });
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(conversationsProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Мессеж'),
        backgroundColor: AppColors.surface,
        actions: [
          IconButton(
            icon: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(color: AppColors.inputFill, borderRadius: BorderRadius.circular(10)),
              child: const Icon(Icons.refresh_rounded, size: 20, color: AppColors.textSecondary),
            ),
            onPressed: () => ref.read(conversationsProvider.notifier).load(),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: Builder(
        builder: (context) {
          if (state.isLoading && state.conversations.isEmpty) {
            return const ShimmerList(itemCount: 6, itemHeight: 70);
          }
          if (state.error != null && state.conversations.isEmpty) {
            return AppErrorWidget(
              message: 'Мессежүүд ачаалахад алдаа гарлаа',
              onRetry: () => ref.read(conversationsProvider.notifier).load(),
            );
          }
          if (state.conversations.isEmpty) {
            return const AppEmpty(
              icon: Icons.chat_bubble_outline_rounded,
              message: 'Мессеж байхгүй байна',
              subMessage: 'Харилцаа холбоо эхлүүлэхийн тулд засвар үйлчилгээний хүсэлт илгээнэ үү',
            );
          }
          return RefreshIndicator(
            color: AppColors.primary,
            onRefresh: () async => ref.read(conversationsProvider.notifier).load(),
            child: ListView.separated(
              padding: const EdgeInsets.symmetric(vertical: 8),
              itemCount: state.conversations.length,
              separatorBuilder: (_, __) => const Divider(height: 1, indent: 76, endIndent: 16),
              itemBuilder: (context, index) {
                return _ConversationTile(
                  conversation: state.conversations[index],
                  onTap: () => context.push('/chat/${state.conversations[index].id}', extra: state.conversations[index]),
                );
              },
            ),
          );
        },
      ),
    );
  }
}

class _ConversationTile extends StatelessWidget {
  final ConversationModel conversation;
  final VoidCallback onTap;

  const _ConversationTile({required this.conversation, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final hasUnread = conversation.unreadCount > 0;
    final name = conversation.khariltsagchiinNer.isNotEmpty ? conversation.khariltsagchiinNer : 'Захиргаа';
    final initials = name.isNotEmpty ? name[0].toUpperCase() : 'З';

    return ListTile(
      onTap: onTap,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      leading: Stack(
        children: [
          Container(
            width: 50,
            height: 50,
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [Color(0xFF16A34A), Color(0xFF22C55E)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Text(initials, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 18)),
            ),
          ),
          if (hasUnread)
            Positioned(
              right: 0,
              top: 0,
              child: Container(
                width: 16,
                height: 16,
                decoration: const BoxDecoration(color: AppColors.error, shape: BoxShape.circle),
                child: Center(
                  child: Text(
                    '${conversation.unreadCount}',
                    style: const TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.w700),
                  ),
                ),
              ),
            ),
        ],
      ),
      title: Text(
        name,
        style: Theme.of(context).textTheme.titleSmall?.copyWith(
          fontWeight: hasUnread ? FontWeight.w700 : FontWeight.w500,
        ),
      ),
      subtitle: conversation.lastMessage != null
          ? Text(
              conversation.lastMessage!,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                fontWeight: hasUnread ? FontWeight.w600 : FontWeight.w400,
                color: hasUnread ? AppColors.textPrimary : AppColors.textTertiary,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            )
          : null,
      trailing: conversation.lastMessageAt != null
          ? Text(
              AppFormatters.date(conversation.lastMessageAt),
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                color: hasUnread ? AppColors.success : AppColors.textTertiary,
                fontWeight: hasUnread ? FontWeight.w600 : FontWeight.w400,
              ),
            )
          : null,
    );
  }
}
