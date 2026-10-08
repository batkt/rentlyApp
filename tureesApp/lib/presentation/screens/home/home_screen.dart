import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/constants/api_constants.dart';
import '../../../core/socket/socket_service.dart';
import '../../../data/models/agreement_model.dart';
import '../../../core/theme/app_colors.dart';
import '../../../data/models/notification_model.dart';
import '../../providers/agreement_provider.dart';
import '../../providers/ai_tuslakh_provider.dart';
import '../../providers/auth_provider.dart';
import '../../providers/chat_provider.dart';
import '../../providers/notification_provider.dart';
import '../agreements/agreement_detail_screen.dart' show kAgreementInvoiceTab;
import '../dashboard/dashboard_screen.dart';
import '../payment/payment_screen.dart';
import '../notifications/notifications_screen.dart';
import '../settings/settings_screen.dart';
import '../../../core/utils/responsive.dart';
import '../../widgets/common/ai_tuslakh_tovch.dart';

final _navIndexProvider = StateProvider<int>((ref) => 0);

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> with WidgetsBindingObserver {
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
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) ref.read(_navIndexProvider.notifier).state = 0;
      // Эрх устсан эсэхийг `ErkhKhamgaalagch` бүх дэлгэц дээр хянана.
      if (mounted) ref.read(conversationsProvider.notifier).load();
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _uldegdelSergeekhTimer?.cancel();
    _uldegdliinSonsogchdiigSalgaya();
    super.dispose();
  }

  /// Одоо сонсож буй гэрээнүүд. HomeScreen нь бүх табын бүрхүүл тул сонсогчийг
  /// энд нэг л удаа барина — тухайн үед аль дэлгэц нээлттэй байгаагаас
  /// үл хамааран үлдэгдэл харуулдаг БҮХ дэлгэц шинэчлэгдэнэ.
  final Set<String> _sonsogdozBuiGeree = {};

  void _uldegdliinSonsogchdiigTokhiruulya(List<String> gereeniiIdnuud) {
    final socket = ref.read(socketServiceProvider);
    final shine = gereeniiIdnuud.where((id) => id.isNotEmpty).toSet();

    for (final id in _sonsogdozBuiGeree.difference(shine)) {
      socket.off(SocketEvents.gereeniiUldegdel(id), _uldegdelSoligdloo);
    }
    for (final id in shine.difference(_sonsogdozBuiGeree)) {
      socket.on(SocketEvents.gereeniiUldegdel(id), _uldegdelSoligdloo);
    }
    _sonsogdozBuiGeree
      ..clear()
      ..addAll(shine);
  }

  void _uldegdliinSonsogchdiigSalgaya() {
    final socket = ref.read(socketServiceProvider);
    for (final id in _sonsogdozBuiGeree) {
      socket.off(SocketEvents.gereeniiUldegdel(id), _uldegdelSoligdloo);
    }
    _sonsogdozBuiGeree.clear();
  }

  /// Менежер хэд хэдэн төлөлтийг дараалан бүртгэхэд дохио бөөгнөрч ирдэг тул
  /// богино завсраар нэгтгэнэ — эс тэгвээс гэрээ бүрийн үлдэгдлийг дахин
  /// дахин татна.
  Timer? _uldegdelSergeekhTimer;

  void _uldegdelSoligdloo(dynamic _) {
    if (!mounted) return;
    _uldegdelSergeekhTimer?.cancel();
    _uldegdelSergeekhTimer = Timer(const Duration(milliseconds: 800), () {
      if (mounted) uldegdliigSergeekh(ref);
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _onResumed();
  }

  Future<void> _onResumed() async {
    if (!mounted) return;
    final user = ref.read(currentUserProvider);
    if (user == null) return;

    final socket = ref.read(socketServiceProvider);
    await socket.ensureConnected();
    socket.joinOrgRoom(user.baiguullagiinId);
    socket.joinUserRoom(user.id);

    if (!mounted) return;
    uldegdliigSergeekh(ref);
    ref.read(notificationsProvider.notifier).load();
    ref.read(conversationsProvider.notifier).load();
  }

  /// Таб солих бүрд үлдэгдлийг дахин татна. IndexedStack дотор дэлгэцүүд
  /// амьд үлддэг тул өөрөө дахин асуухгүй. Дараалан дарахад сервер рүү
  /// давхар хүсэлт явуулахгүйн тулд богино завсар барина.
  DateTime? _suuliinSergeelt;
  void _tabSolikhod() {
    final odoo = DateTime.now();
    final suulchiin = _suuliinSergeelt;
    if (suulchiin != null && odoo.difference(suulchiin) < const Duration(seconds: 3)) {
      return;
    }
    _suuliinSergeelt = odoo;
    uldegdliigSergeekh(ref);
  }

  bool _canSee(List<String> erkhuud, String key) {
    return erkhuud.isEmpty || erkhuud.contains(key);
  }

  @override
  Widget build(BuildContext context) {
    // Гэрээний жагсаалт өөрчлөгдөх бүрд сонсогчдоо шинэчилнэ (шинэ гэрээ
    // нэмэгдэх, барилга солигдох гэх мэт).
    ref.listen<AsyncValue<List<AgreementModel>>>(agreementsProvider,
        (previous, next) {
      final jagsaalt = next.valueOrNull;
      if (jagsaalt == null || !mounted) return;
      _uldegdliinSonsogchdiigTokhiruulya(
        jagsaalt.map((a) => a.id).toList(),
      );
    });
    final gereenuud = ref.watch(agreementsProvider).valueOrNull;
    if (gereenuud != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          _uldegdliinSonsogchdiigTokhiruulya(
            gereenuud.map((a) => a.id).toList(),
          );
        }
      });
    }
    final currentIndex = ref.watch(_navIndexProvider);
    final unreadCount = ref.watch(unreadCountProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final user = ref.watch(currentUserProvider);
    final erkhuud = user?.appErkhuud ?? [];

    final showPayment = _canSee(erkhuud, 'payment');
    final showNotifications = _canSee(erkhuud, 'notifications');
    final showProfile = _canSee(erkhuud, 'profile');
    final showChat = _canSee(erkhuud, 'chat');
  final visibleTabs = <int>[0]; // home always visible
    if (showPayment) visibleTabs.add(1);
    if (showNotifications) visibleTabs.add(2);
    if (showProfile) visibleTabs.add(3);
    ref.listen<NotificationModel?>(incomingNotificationProvider, (_, next) {
      if (next == null || !mounted) return;
      uldegdliigSergeekh(ref);
      if (!ref.read(notificationsEnabledProvider)) {
        Future.microtask(() {
          if (mounted) ref.read(incomingNotificationProvider.notifier).state = null;
        });
        return;
      }
      final title = next.title.isNotEmpty ? next.title : 'Шинэ мэдэгдэл';
      final body = next.message;
      final gereeniiId = next.gereeniiId;
      final isInvoice = next.turul == 'nekhemjlekh' && gereeniiId != null && gereeniiId.isNotEmpty;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Фон нь brand өнгө тул текстийн өнгийг theme-д найдалгүй шууд
              // цагаанаар өгнө (light theme-ийн snackbar текст бараан).
              Text(title,
                  style: const TextStyle(
                      color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13)),
              if (body.isNotEmpty) ...[
                const SizedBox(height: 2),
                Text(body,
                    style: const TextStyle(color: Colors.white, fontSize: 11),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis),
              ],
            ],
          ),
          backgroundColor: AppColors.primary,
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 5),
          action: SnackBarAction(
            label: 'Харах',
            textColor: Colors.white,
            onPressed: () {
              ref.read(incomingNotificationProvider.notifier).state = null;
              if (isInvoice) {
                context.push('/agreements/$gereeniiId?tab=$kAgreementInvoiceTab');
              } else {
                ref.read(_navIndexProvider.notifier).state = 2;
              }
            },
          ),
        ),
      );
      Future.microtask(() {
        if (mounted) ref.read(incomingNotificationProvider.notifier).state = null;
      });
    });
    // Барилга солигдоход conversationsProvider шинээр үүсдэг тул тухайн барилгын чатыг ачаална.
    ref.listen<String>(selectedBarilgiinIdProvider, (prev, next) {
      if (prev != next && mounted) ref.read(conversationsProvider.notifier).load();
    });
    ref.listen<ConversationsState>(conversationsProvider, (prev, next) {
      if (!mounted) return;
      final prevCount = prev?.conversations.fold<int>(0, (s, c) => s + c.unreadCount) ?? 0;
      final nextCount = next.conversations.fold<int>(0, (s, c) => s + c.unreadCount);
      if (nextCount <= prevCount) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Таньд шинэ мессеж ирлээ',
              style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
          backgroundColor: AppColors.primary,
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 5),
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

    void onSongokh(int i) {
      ref.read(_navIndexProvider.notifier).state = visibleTabs[i];
      _tabSolikhod();
    }

    final body = Stack(
      children: [
        IndexedStack(
          index: safeScreenIndex,
          children: _screens,
        ),
        // Нэгдсэн хөвөгч товч: AI туслах + (эрхтэй бол) захиргааны чат.
        if (ref.watch(aiTuslakhIdevkhteiProvider) && safeScreenIndex < 2)
          AiTuslakhTovch(zakhirgaaniiChattai: showChat),
      ],
    );

    // Дэлгэсэн Fold / таблет дээр доод цэсний оронд хажуугийн NavigationRail.
    if (context.urgunDelgets) {
      return Scaffold(
        body: Row(
          children: [
            SafeArea(
              right: false,
              child: NavigationRail(
                selectedIndex: navBarIndex,
                onDestinationSelected: onSongokh,
                backgroundColor: isDark ? const Color(0xFF1E2A28) : AppColors.surface,
                indicatorColor: isDark ? const Color(0xFF1A3D37) : AppColors.primaryContainer,
                labelType: NavigationRailLabelType.all,
                groupAlignment: 0,
                destinations: destinations
                    .map((d) => NavigationRailDestination(
                          icon: d.icon,
                          selectedIcon: d.selectedIcon,
                          label: Text(d.label),
                        ))
                    .toList(),
              ),
            ),
            VerticalDivider(width: 1, thickness: 1, color: isDark ? Colors.white10 : Colors.black12),
            Expanded(child: body),
          ],
        ),
      );
    }

    return Scaffold(
      body: body,
      bottomNavigationBar: NavigationBar(
        selectedIndex: navBarIndex,
        onDestinationSelected: onSongokh,
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
