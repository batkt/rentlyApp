import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_colors.dart';
import '../../providers/chat_provider.dart';
import '../../providers/notification_provider.dart';
import '../dashboard/dashboard_screen.dart';
import '../duudlaga/duudlaga_screen.dart';
import '../payment/payment_screen.dart';
import '../notifications/notifications_screen.dart';
import '../settings/settings_screen.dart';

final _navIndexProvider = StateProvider<int>((ref) => 0);

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
      DuudlagaScreen(),
      PaymentScreen(),
      NotificationsScreen(),
      SettingsScreen(),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final currentIndex = ref.watch(_navIndexProvider);
    final unreadCount = ref.watch(unreadCountProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      body: Stack(
        children: [
          IndexedStack(
            index: currentIndex,
            children: _screens,
          ),
          const _FloatingChatBubble(),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: currentIndex,
        onDestinationSelected: (i) => ref.read(_navIndexProvider.notifier).state = i,
        backgroundColor: isDark ? const Color(0xFF1E2A28) : AppColors.surface,
        indicatorColor: isDark ? const Color(0xFF1A3D37) : AppColors.primaryContainer,
        surfaceTintColor: Colors.transparent,
        shadowColor: isDark ? Colors.transparent : Colors.black12,
        elevation: 0,
        height: 68,
        labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
        destinations: [
          const NavigationDestination(
            icon: Icon(Icons.home_outlined),
            selectedIcon: Icon(Icons.home_rounded),
            label: 'Нүүр',
          ),
          const NavigationDestination(
            icon: Icon(Icons.campaign_outlined),
            selectedIcon: Icon(Icons.campaign_rounded),
            label: 'Дуудлага',
          ),
          const NavigationDestination(
            icon: Icon(Icons.payment_outlined),
            selectedIcon: Icon(Icons.payment_rounded),
            label: 'Төлбөр',
          ),
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
          const NavigationDestination(
            icon: Icon(Icons.person_outline_rounded),
            selectedIcon: Icon(Icons.person_rounded),
            label: 'Профайл',
          ),
        ],
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
      setState(() => _position = Offset(size.width - 72, size.height * 0.55));
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
    final convState = ref.watch(conversationsProvider);
    final hasConv = convState.conversations.isNotEmpty;

    return Positioned(
      left: _position.dx,
      top: _position.dy,
      child: GestureDetector(
        onPanStart: (_) => setState(() => _isDragging = true),
        onPanUpdate: (details) {
          final size = MediaQuery.sizeOf(context);
          setState(() {
            _position = Offset(
              (_position.dx + details.delta.dx).clamp(0, size.width - 60),
              (_position.dy + details.delta.dy).clamp(0, size.height - 140),
            );
          });
        },
        onPanEnd: (_) {
          setState(() => _isDragging = false);
          final size = MediaQuery.sizeOf(context);
          final snapX = _position.dx < size.width / 2 ? 12.0 : size.width - 72.0;
          setState(() => _position = Offset(snapX, _position.dy));
        },
        onTap: _isDragging ? null : _openChat,
        child: AnimatedBuilder(
          animation: _pulseAnim,
          builder: (_, child) => Transform.scale(
            scale: _isDragging ? 1.1 : (hasConv ? _pulseAnim.value : 1.0),
            child: child,
          ),
          child: _ChatBubble(isLoading: convState.isLoading, hasConv: hasConv),
        ),
      ),
    );
  }
}

class _ChatBubble extends StatelessWidget {
  final bool isLoading;
  final bool hasConv;

  const _ChatBubble({required this.isLoading, required this.hasConv});

  @override
  Widget build(BuildContext context) {
    return Material(
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
  }
}
