import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_colors.dart';
import '../../providers/chat_provider.dart';
import '../../providers/notification_provider.dart';
import '../dashboard/dashboard_screen.dart';
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
    _screens = [
      const DashboardScreen(),
      const PaymentScreen(),
      const NotificationsScreen(),
      const SettingsScreen(),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final currentIndex = ref.watch(_navIndexProvider);
    final unreadCount = ref.watch(unreadCountProvider);

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
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: context.appSurface,
          border: Border(top: BorderSide(color: context.appDivider, width: 1)),
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _NavItem(icon: Icons.home_rounded, label: 'Нүүр', index: 0, current: currentIndex),
                _NavItem(icon: Icons.payment_rounded, label: 'Төлбөр', index: 1, current: currentIndex),
                _NavItem(
                  icon: Icons.notifications_rounded,
                  label: 'Мэдэгдэл',
                  index: 2,
                  current: currentIndex,
                  badge: unreadCount > 0 ? unreadCount : null,
                ),
                _NavItem(icon: Icons.person_rounded, label: 'Профайл', index: 3, current: currentIndex),
              ],
            ),
          ),
        ),
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
      duration: const Duration(milliseconds: 1200),
    )..repeat(reverse: true);
    _pulseAnim = Tween<double>(begin: 1.0, end: 1.15).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    WidgetsBinding.instance.addPostFrameCallback((_) {
      final size = MediaQuery.sizeOf(context);
      setState(() => _position = Offset(size.width - 72, size.height * 0.6));

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
    } else {
      convState.error != null
          ? ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text(convState.error!), backgroundColor: AppColors.error),
            )
          : context.push('/chat/loading');
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
              (_position.dy + details.delta.dy).clamp(0, size.height - 120),
            );
          });
        },
        onPanEnd: (_) {
          setState(() => _isDragging = false);
          // snap to nearest horizontal edge
          final size = MediaQuery.sizeOf(context);
          final snapX = _position.dx < size.width / 2 ? 12.0 : size.width - 72.0;
          setState(() => _position = Offset(snapX, _position.dy));
        },
        onTap: _isDragging ? null : _openChat,
        child: AnimatedBuilder(
          animation: _pulseAnim,
          builder: (_, child) {
            return Transform.scale(
              scale: _isDragging ? 1.1 : (hasConv ? _pulseAnim.value : 1.0),
              child: child,
            );
          },
          child: _ChatBubble(
            isLoading: convState.isLoading,
            hasConv: hasConv,
          ),
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
      elevation: 8,
      shadowColor: AppColors.primary.withOpacity(0.4),
      shape: const CircleBorder(),
      child: Container(
        width: 56,
        height: 56,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: const LinearGradient(
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

class _NavItem extends ConsumerWidget {
  final IconData icon;
  final String label;
  final int index;
  final int current;
  final int? badge;

  const _NavItem({
    required this.icon,
    required this.label,
    required this.index,
    required this.current,
    this.badge,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isSelected = index == current;
    final color = isSelected ? AppColors.primary : AppColors.textTertiary;

    return GestureDetector(
      onTap: () => ref.read(_navIndexProvider.notifier).state = index,
      behavior: HitTestBehavior.opaque,
      child: SizedBox(
        width: 72,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Stack(
              clipBehavior: Clip.none,
              children: [
                AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: isSelected ? AppColors.primary.withOpacity(0.12) : Colors.transparent,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(icon, color: color, size: 24),
                ),
                if (badge != null)
                  Positioned(
                    top: -2,
                    right: -2,
                    child: Container(
                      padding: const EdgeInsets.all(3),
                      decoration: const BoxDecoration(color: AppColors.error, shape: BoxShape.circle),
                      constraints: const BoxConstraints(minWidth: 16, minHeight: 16),
                      child: Text(
                        badge! > 99 ? '99+' : '$badge',
                        style: const TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.w700),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: TextStyle(
                fontSize: 10,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                color: isSelected ? AppColors.primary : AppColors.textTertiary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
