import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_colors.dart';
import '../../../data/models/notification_model.dart';
import '../../providers/auth_provider.dart';
import '../../providers/chat_provider.dart';
import '../../providers/notification_provider.dart';
import '../dashboard/dashboard_screen.dart';
import '../payment/payment_screen.dart';
import '../notifications/notifications_screen.dart';
import '../settings/settings_screen.dart';

final _navIndexProvider = StateProvider<int>((ref) => 0);

/// Controls whether the floating chat bubble is visible.
/// Hidden via drag-to-bottom; restored from Settings.
final chatVisibleProvider = StateProvider<bool>((ref) => true);

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  late final List<Widget> _screens;

  @override
  void initState() {
    super.initState();
    _screens = const [
      DashboardScreen(),
      PaymentScreen(),
      NotificationsScreen(),
      SettingsScreen(),
    ];
    // Reset to home tab on every fresh mount (prevents stale index after logout/login)
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) ref.read(_navIndexProvider.notifier).state = 0;
      // Load conversations early so the chat toast listener has data when a
      // message arrives even before the floating bubble is first rendered.
      if (mounted) ref.read(conversationsProvider.notifier).load();
    });
  }

  bool _canSee(List<String> erkhuud, String key) {
    return erkhuud.isEmpty || erkhuud.contains(key);
  }

  @override
  Widget build(BuildContext context) {
    final currentIndex = ref.watch(_navIndexProvider);
    final unreadCount = ref.watch(unreadCountProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final user = ref.watch(currentUserProvider);
    final erkhuud = user?.appErkhuud ?? [];

    final showPayment = _canSee(erkhuud, 'payment');
    final showNotifications = _canSee(erkhuud, 'notifications');
    final showProfile = _canSee(erkhuud, 'profile');
    final showChat = _canSee(erkhuud, 'chat');

    // Map actual screen index → visible destination index
    final visibleTabs = <int>[0]; // home always visible
    if (showPayment) visibleTabs.add(1);
    if (showNotifications) visibleTabs.add(2);
    if (showProfile) visibleTabs.add(3);

    // Real-time notification banner
    ref.listen<NotificationModel?>(incomingNotificationProvider, (_, next) {
      if (next == null || !mounted) return;
      final title = next.title.isNotEmpty ? next.title : 'Шинэ мэдэгдэл';
      final body = next.message;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
              if (body.isNotEmpty) ...[
                const SizedBox(height: 2),
                Text(body, style: const TextStyle(fontSize: 11), maxLines: 2, overflow: TextOverflow.ellipsis),
              ],
            ],
          ),
          backgroundColor: AppColors.primary,
          behavior: SnackBarBehavior.floating,
          action: SnackBarAction(
            label: 'Харах',
            textColor: Colors.white,
            onPressed: () {
              ref.read(incomingNotificationProvider.notifier).state = null;
              ref.read(_navIndexProvider.notifier).state = 2;
            },
          ),
        ),
      );
      Future.microtask(() {
        if (mounted) ref.read(incomingNotificationProvider.notifier).state = null;
      });
    });

    // Chat message banner — fires when unread count increases while not on chat screen
    ref.listen<ConversationsState>(conversationsProvider, (prev, next) {
      if (!mounted) return;
      final prevCount = prev?.conversations.fold<int>(0, (s, c) => s + c.unreadCount) ?? 0;
      final nextCount = next.conversations.fold<int>(0, (s, c) => s + c.unreadCount);
      if (nextCount <= prevCount) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Таньд шинэ чат мессеж ирлээ'),
          backgroundColor: AppColors.primary,
          behavior: SnackBarBehavior.floating,
          action: SnackBarAction(
            label: 'Нээх',
            textColor: Colors.white,
            onPressed: () {
              final conv = ref.read(conversationsProvider).conversations.firstOrNull;
              if (conv != null && context.mounted) {
                ref.read(conversationsProvider.notifier).markRead(conv.id);
                context.push('/chat/${conv.id}', extra: conv);
              }
            },
          ),
        ),
      );
    });

    // Clamp currentIndex to a valid visible tab
    final safeScreenIndex = visibleTabs.contains(currentIndex) ? currentIndex : 0;

    final destinations = <NavigationDestination>[
      const NavigationDestination(
        icon: Icon(Icons.home_outlined),
        selectedIcon: Icon(Icons.home_rounded),
        label: 'Нүүр',
      ),
      if (showPayment)
        const NavigationDestination(
          icon: Icon(Icons.payment_outlined),
          selectedIcon: Icon(Icons.payment_rounded),
          label: 'Төлбөр',
        ),
      if (showNotifications)
        NavigationDestination(
          icon: Badge(
            isLabelVisible: unreadCount > 0,
            label: Text(unreadCount > 99 ? '99+' : '$unreadCount'),
            child: const Icon(Icons.notifications_outlined),
          ),
          selectedIcon: Badge(
            isLabelVisible: unreadCount > 0,
            label: Text(unreadCount > 99 ? '99+' : '$unreadCount'),
            child: const Icon(Icons.notifications_rounded),
          ),
          label: 'Мэдэгдэл',
        ),
      if (showProfile)
        const NavigationDestination(
          icon: Icon(Icons.person_outline_rounded),
          selectedIcon: Icon(Icons.person_rounded),
          label: 'Профайл',
        ),
    ];

    // Visible destination index for the NavigationBar
    final navBarIndex = visibleTabs.indexOf(safeScreenIndex).clamp(0, destinations.length - 1);

    return Scaffold(
      body: Stack(
        children: [
          IndexedStack(
            index: safeScreenIndex,
            children: _screens,
          ),
          if (showChat && ref.watch(chatVisibleProvider) && safeScreenIndex < 2) const _FloatingChatBubble(),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: navBarIndex,
        onDestinationSelected: (i) {
          ref.read(_navIndexProvider.notifier).state = visibleTabs[i];
        },
        backgroundColor: isDark ? const Color(0xFF1E2A28) : AppColors.surface,
        indicatorColor: isDark ? const Color(0xFF1A3D37) : AppColors.primaryContainer,
        surfaceTintColor: Colors.transparent,
        shadowColor: isDark ? Colors.transparent : Colors.black12,
        elevation: 0,
        height: 68,
        labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
        destinations: destinations,
      ),
    );
  }
}

class _FloatingChatBubble extends ConsumerStatefulWidget {
  const _FloatingChatBubble();

  @override
  ConsumerState<_FloatingChatBubble> createState() => _FloatingChatBubbleState();
}

class _FloatingChatBubbleState extends ConsumerState<_FloatingChatBubble>
    with SingleTickerProviderStateMixin {
  Offset _position = const Offset(20, 200);
  bool _isDragging = false;
  bool _isNearDropZone = false;
  late AnimationController _pulseController;
  late Animation<double> _pulseAnim;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..repeat(reverse: true);
    _pulseAnim = Tween<double>(begin: 1.0, end: 1.12).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    WidgetsBinding.instance.addPostFrameCallback((_) {
      final size = MediaQuery.sizeOf(context);
      final topPad = MediaQuery.of(context).padding.top;
      final minY = topPad + 8;
      final initY = (size.height * 0.55).clamp(minY, size.height - 100.0);
      setState(() => _position = Offset(size.width - 72, initY));
      ref.read(conversationsProvider.notifier).load();
    });
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  void _openChat() {
    final convState = ref.read(conversationsProvider);
    if (convState.conversations.isNotEmpty) {
      final conv = convState.conversations.first;
      ref.read(conversationsProvider.notifier).markRead(conv.id);
      context.push('/chat/${conv.id}', extra: conv);
    } else if (convState.error != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(convState.error!), backgroundColor: AppColors.error),
      );
    } else {
      context.push('/chat/loading');
    }
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    final convState = ref.watch(conversationsProvider);
    final hasConv = convState.conversations.isNotEmpty;
    final unread = convState.conversations.fold<int>(0, (s, c) => s + c.unreadCount);

    return Stack(
      children: [
        // Drop zone: X circle at bottom center, visible while dragging
        if (_isDragging)
          Positioned(
            bottom: 48,
            left: 0,
            right: 0,
            child: IgnorePointer(
              child: Center(
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 150),
                  width: _isNearDropZone ? 72 : 60,
                  height: _isNearDropZone ? 72 : 60,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: _isNearDropZone
                        ? AppColors.error
                        : Colors.black.withOpacity(0.55),
                    border: Border.all(color: Colors.white.withOpacity(0.5), width: 2),
                    boxShadow: _isNearDropZone
                        ? [BoxShadow(color: AppColors.error.withOpacity(0.4), blurRadius: 16, spreadRadius: 2)]
                        : [],
                  ),
                  child: Icon(Icons.close_rounded, color: Colors.white, size: _isNearDropZone ? 34 : 28),
                ),
              ),
            ),
          ),
        // Draggable bubble
        Positioned(
          left: _position.dx,
          top: _position.dy,
          child: GestureDetector(
            onPanStart: (_) => setState(() => _isDragging = true),
            onPanUpdate: (details) {
              final topPad = MediaQuery.of(context).padding.top + 8;
              final newPos = Offset(
                (_position.dx + details.delta.dx).clamp(0, size.width - 60),
                (_position.dy + details.delta.dy).clamp(topPad, size.height - 100),
              );
              // Drop zone: bottom 25% of screen, within 110px of horizontal center
              final near = newPos.dy > size.height * 0.72 &&
                  (newPos.dx + 28 - size.width / 2).abs() < 110;
              setState(() {
                _position = newPos;
                _isNearDropZone = near;
              });
            },
            onPanEnd: (_) {
              if (_isNearDropZone) {
                ref.read(chatVisibleProvider.notifier).state = false;
                setState(() { _isDragging = false; _isNearDropZone = false; });
                return;
              }
              setState(() { _isDragging = false; _isNearDropZone = false; });
              final snapX = _position.dx < size.width / 2 ? 12.0 : size.width - 72.0;
              setState(() => _position = Offset(snapX, _position.dy));
            },
            onTap: _isDragging ? null : _openChat,
            child: AnimatedBuilder(
              animation: _pulseAnim,
              builder: (_, child) => Transform.scale(
                scale: _isDragging
                    ? (_isNearDropZone ? 0.85 : 1.1)
                    : (hasConv ? _pulseAnim.value : 1.0),
                child: child,
              ),
              child: _ChatBubble(isLoading: convState.isLoading, hasConv: hasConv, unread: unread),
            ),
          ),
        ),
      ],
    );
  }
}

class _ChatBubble extends StatelessWidget {
  final bool isLoading;
  final bool hasConv;
  final int unread;

  const _ChatBubble({required this.isLoading, required this.hasConv, this.unread = 0});

  @override
  Widget build(BuildContext context) {
    final bubble = Material(
      elevation: 10,
      shadowColor: AppColors.primary.withOpacity(0.5),
      shape: const CircleBorder(),
      child: Container(
        width: 56,
        height: 56,
        decoration: const BoxDecoration(
          shape: BoxShape.circle,
          gradient: LinearGradient(
            colors: [AppColors.primaryLight, AppColors.primary],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: isLoading
            ? const Padding(
                padding: EdgeInsets.all(16),
                child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white),
              )
            : const Icon(Icons.chat_bubble_rounded, color: Colors.white, size: 26),
      ),
    );

    if (unread <= 0) return bubble;

    return Stack(
      clipBehavior: Clip.none,
      children: [
        bubble,
        Positioned(
          top: -4,
          right: -4,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            constraints: const BoxConstraints(minWidth: 20, minHeight: 20),
            decoration: BoxDecoration(
              color: AppColors.error,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.white, width: 1.5),
            ),
            child: Center(
              child: Text(
                unread > 99 ? '99+' : '$unread',
                style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w700),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
