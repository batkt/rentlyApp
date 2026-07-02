import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/formatters.dart';
import '../../../data/models/notification_model.dart';
import '../../providers/auth_provider.dart';
import '../../providers/notification_provider.dart';
import '../../widgets/cards/notification_card.dart';
import '../../widgets/common/app_loading.dart';

class NotificationsScreen extends ConsumerStatefulWidget {
  const NotificationsScreen({super.key});

  @override
  ConsumerState<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends ConsumerState<NotificationsScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(notificationsProvider.notifier).load();
      ref.read(duudlagaProvider.notifier).load();
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Мэдэгдэл & Хүсэлт'),
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: AppColors.primary,
          labelColor: AppColors.primary,
          unselectedLabelColor: context.appTextTertiary,
          tabs: const [
            Tab(text: 'Мэдэгдэл'),
            Tab(text: 'Шаардлага'),
            Tab(text: 'Дуудлага'),
          ],
        ),
        actions: [
          IconButton(
            tooltip: 'Бүгдийг уншсан болгох',
            icon: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(color: context.appInputFill, borderRadius: BorderRadius.circular(10)),
              child: Icon(Icons.done_all_rounded, size: 20, color: context.appTextSecondary),
            ),
            onPressed: () => ref.read(notificationsProvider.notifier).markAllRead(),
          ),
          const SizedBox(width: 4),
          IconButton(
            icon: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(color: context.appInputFill, borderRadius: BorderRadius.circular(10)),
              child: Icon(Icons.add_rounded, size: 20, color: context.appTextSecondary),
            ),
            onPressed: () => _showNewRequestSheet(
              context,
              initialTurul: _tabController.index == 2 ? 'duudlaga' : 'sanal',
            ),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 720),
          child: TabBarView(
            controller: _tabController,
            children: [
              _NotificationsTab(),
              _RequestsTab(onAddRequest: () => _showNewRequestSheet(context, initialTurul: 'sanal')),
              _DuudlagaTab(onAddDuudlaga: () => _showNewRequestSheet(context, initialTurul: 'duudlaga')),
            ],
          ),
        ),
      ),
    );
  }

  void _showNewRequestSheet(BuildContext context, {required String initialTurul}) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      constraints: BoxConstraints(
        maxWidth: MediaQuery.sizeOf(context).width > 600 ? 560 : double.infinity,
      ),
      builder: (ctx) => _RequestFormSheet(
        initialTurul: initialTurul,
        onSubmitted: (turul) {
          if (turul == 'duudlaga') {
            ref.read(duudlagaProvider.notifier).load();
          }
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text(turul == 'duudlaga' ? 'Дуудлага амжилттай илгээгдлээ' : 'Хүсэлт амжилттай илгээгдлээ')),
            );
          }
        },
      ),
    );
  }
}

class _ReadOnlyField extends StatelessWidget {
  final IconData icon;
  final String value;

  const _ReadOnlyField({required this.icon, required this.value});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        SizedBox(
          width: 32,
          child: Icon(icon, size: 18, color: context.appTextTertiary),
        ),
        Expanded(
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: context.appInputFill,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: context.appDivider),
            ),
            child: Text(
              value.isNotEmpty ? value : '—',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(color: context.appTextSecondary),
            ),
          ),
        ),
      ],
    );
  }
}

// ─── Tab widgets ────────────────────────────────────────────────────────────

class _NotificationsTab extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(notificationsProvider);
    final items = state.notifications
        .where((n) => n.category == NotifCategory.medegdel)
        .toList();

    if (state.isLoading && state.notifications.isEmpty) {
      return const ShimmerList(itemCount: 5, itemHeight: 80);
    }
    if (state.error != null && state.notifications.isEmpty) {
      return AppErrorWidget(
        message: 'Мэдэгдэлүүд ачаалахад алдаа гарлаа',
        onRetry: () => ref.read(notificationsProvider.notifier).load(),
      );
    }
    if (items.isEmpty) {
      return RefreshIndicator(
        color: AppColors.primary,
        onRefresh: () async => ref.read(notificationsProvider.notifier).load(),
        child: ListView(
          children: const [
            SizedBox(height: 120),
            AppEmpty(icon: Icons.notifications_none_rounded, message: 'Мэдэгдэл байхгүй байна'),
          ],
        ),
      );
    }

    return RefreshIndicator(
      color: AppColors.primary,
      onRefresh: () async => ref.read(notificationsProvider.notifier).load(),
      child: ListView.builder(
        padding: const EdgeInsets.symmetric(vertical: 8),
        itemCount: items.length,
        itemBuilder: (context, index) => NotificationCard(
          notification: items[index],
          onTap: () {
            if (items[index].isUnread) {
              ref.read(notificationsProvider.notifier).markRead(items[index].id);
            }
          },
        ),
      ),
    );
  }
}

class _RequestsTab extends ConsumerStatefulWidget {
  final VoidCallback? onAddRequest;

  const _RequestsTab({this.onAddRequest});

  @override
  ConsumerState<_RequestsTab> createState() => _RequestsTabState();
}

class _RequestsTabState extends ConsumerState<_RequestsTab> {
  // null = Бүгд (all)
  String? _turulFilter;

  static const _turulOptions = ['Санал хүсэлт', 'Шаардлага', 'Гомдол'];

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(notificationsProvider);
    final allItems = state.notifications
        .where((n) => n.category == NotifCategory.request)
        .toList();
    final items = _turulFilter == null
        ? allItems
        : allItems.where((n) => n.requestTypeLabel == _turulFilter).toList();

    if (state.isLoading && state.notifications.isEmpty) {
      return const ShimmerList(itemCount: 4, itemHeight: 80);
    }
    if (state.error != null && state.notifications.isEmpty) {
      return AppErrorWidget(
        message: 'Хүсэлтүүд ачаалахад алдаа гарлаа',
        onRetry: () => ref.read(notificationsProvider.notifier).load(),
      );
    }
    if (allItems.isEmpty) {
      return RefreshIndicator(
        color: AppColors.primary,
        onRefresh: () async => ref.read(notificationsProvider.notifier).load(),
        child: ListView(
          children: [
            const SizedBox(height: 80),
            AppEmpty(
              icon: Icons.forum_outlined,
              message: 'Хүсэлт байхгүй байна',
              subMessage: 'Санал хүсэлт, гомдол илгээхийн тулд + товчийг дарна уу',
              onAction: widget.onAddRequest,
              actionLabel: 'Хүсэлт илгээх',
            ),
          ],
        ),
      );
    }

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 6),
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _TurulFilterChip(
                  label: 'Бүгд',
                  selected: _turulFilter == null,
                  onTap: () => setState(() => _turulFilter = null),
                ),
                for (final t in _turulOptions) ...[
                  const SizedBox(width: 8),
                  _TurulFilterChip(
                    label: t,
                    selected: _turulFilter == t,
                    onTap: () => setState(() => _turulFilter = t),
                  ),
                ],
              ],
            ),
          ),
        ),
        Expanded(
          child: items.isEmpty
              ? RefreshIndicator(
                  color: AppColors.primary,
                  onRefresh: () async => ref.read(notificationsProvider.notifier).load(),
                  child: ListView(
                    children: [
                      const SizedBox(height: 80),
                      AppEmpty(icon: Icons.forum_outlined, message: 'Хүсэлт байхгүй байна'),
                    ],
                  ),
                )
              : RefreshIndicator(
                  color: AppColors.primary,
                  onRefresh: () async => ref.read(notificationsProvider.notifier).load(),
                  child: ListView.builder(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    itemCount: items.length,
                    itemBuilder: (context, index) => _RequestCard(
                      notification: items[index],
                    ),
                  ),
                ),
        ),
      ],
    );
  }
}

class _TurulFilterChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _TurulFilterChip({required this.label, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: selected ? AppColors.primary : context.appInputFill,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: selected ? AppColors.primary : context.appDivider),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: selected ? Colors.white : context.appTextSecondary,
          ),
        ),
      ),
    );
  }
}

/// Status label + colour for a request/notification, based on `tuluv`.
/// 0 = pending, 1 = approved/resolved, -1 = declined, else awaiting action.
({String label, Color color}) notifStatus(int tuluv) {
  switch (tuluv) {
    case 1:
      return (label: 'Зөвшөөрөгдсөн', color: AppColors.success);
    case -1:
      return (label: 'Татгалзсан', color: AppColors.error);
    case 2:
      return (label: 'Зөвшөөрөх', color: AppColors.info);
    default:
      return (label: 'Хүлээгдэж байгаа', color: AppColors.warning);
  }
}

class _RequestCard extends StatelessWidget {
  final NotificationModel notification;

  const _RequestCard({required this.notification});

  @override
  Widget build(BuildContext context) {
    // Шаардлага and Гомдол are flagged red; Санал хүсэлт stays blue.
    final label = notification.requestTypeLabel;
    final accent = (label == 'Гомдол' || label == 'Шаардлага')
        ? AppColors.error
        : AppColors.info;
    final status = notifStatus(notification.tuluv);

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 5),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: context.appCardBg,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: context.appDivider),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: accent.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  label,
                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: accent),
                ),
              ),
              const Spacer(),
              if (notification.createdAt != null)
                Text(AppFormatters.dateTime(notification.createdAt),
                    style: Theme.of(context).textTheme.labelSmall),
            ],
          ),
          if (notification.message.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(notification.message, style: Theme.of(context).textTheme.bodyMedium),
          ],
          const SizedBox(height: 8),
          _StatusPill(status: status),
        ],
      ),
    );
  }
}

class _StatusPill extends StatelessWidget {
  final ({String label, Color color}) status;

  const _StatusPill({required this.status});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: status.color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 6,
            height: 6,
            decoration: BoxDecoration(color: status.color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 5),
          Text(status.label,
              style: TextStyle(fontSize: 11, color: status.color, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}

/// Bottom sheet to submit a Санал хүсэлт / Гомдол, mirroring the web opinion page.
class _RequestFormSheet extends ConsumerStatefulWidget {
  final String initialTurul;
  final void Function(String turul)? onSubmitted;

  const _RequestFormSheet({this.initialTurul = 'sanal', this.onSubmitted});

  @override
  ConsumerState<_RequestFormSheet> createState() => _RequestFormSheetState();
}

class _RequestFormSheetState extends ConsumerState<_RequestFormSheet> {
  final _msgCtrl = TextEditingController();
  final _duudlagaTitleCtrl = TextEditingController();
  late String _turul = widget.initialTurul;
  String _duudlagaSubTurul = '';
  bool _isDropdownOpen = false;
  bool _loading = false;

  static const _duudlagaTurulOptions = [
    'Сантехник', 'Цахилгаан', 'Халаалтын систем', 'Агааржуулалт', 'Лифт засвар',
    'Ус', 'Усны даралт', 'Усны чанар', 'Усны хоолой', 'Бохир ус',
    'Ханын засвар', 'Шалны засвар', 'Тааз засвар', 'Цонх засвар', 'Хаалганы засвар',
    'Галын аюулгүй байдал', 'Аюулгүй байдлын систем', 'Дуу чимээ', 'Гэрэлтүүлэг',
    'Цэвэрлэгээ', 'Хогийн менежмент', 'Халдвар хамгаалалт', 'Интернет', 'Кабелийн ТВ',
    'Утасны холбоо', 'Лифт', 'Паркинг', 'Хамгаалалт', 'Удирдлагын асуудал',
    'Санхүүгийн асуудал', 'Бусад',
  ];

  @override
  void dispose() {
    _msgCtrl.dispose();
    _duudlagaTitleCtrl.dispose();
    super.dispose();
  }

  bool get _isDuudlaga => _turul == 'duudlaga';

  Future<void> _submit() async {
    if (_msgCtrl.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Тайлбар оруулна уу')),
      );
      return;
    }
    if (_isDuudlaga && (_duudlagaSubTurul.isEmpty || _duudlagaTitleCtrl.text.trim().isEmpty)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Бүх талбарыг бөглөнө үү')),
      );
      return;
    }
    setState(() => _loading = true);
    try {
      if (_isDuudlaga) {
        final user = ref.read(currentUserProvider);
        await ref.read(duudlagaProvider.notifier).submit(
              title: _duudlagaTitleCtrl.text.trim(),
              message: _msgCtrl.text.trim(),
              duudlagiinTurul: _duudlagaSubTurul,
              khariltsagchiinUtas: user?.primaryPhone ?? '',
              khariltsagchiinRegister: user?.register ?? '',
            );
      } else {
        await ref.read(notificationsProvider.notifier).submitRequest(
              message: _msgCtrl.text.trim(),
              turul: _turul,
            );
      }
      if (!mounted) return;
      Navigator.pop(context);
      widget.onSubmitted?.call(_turul);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Алдаа: $e'), backgroundColor: AppColors.error),
        );
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(currentUserProvider);
    return Container(
      decoration: BoxDecoration(
        color: context.appSurface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: EdgeInsets.fromLTRB(24, 20, 24, MediaQuery.of(context).viewInsets.bottom + 24),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text('Шинэ хүсэлт', style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700)),
                const Spacer(),
                IconButton(onPressed: () => Navigator.pop(context), icon: const Icon(Icons.close_rounded)),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                _TurulChoice(
                  label: 'Санал хүсэлт',
                  selected: _turul == 'sanal',
                  color: AppColors.info,
                  onTap: () => setState(() => _turul = 'sanal'),
                ),
                const SizedBox(width: 8),
                _TurulChoice(
                  label: 'Гомдол',
                  selected: _turul == 'gomdol',
                  color: AppColors.warning,
                  onTap: () => setState(() => _turul = 'gomdol'),
                ),
                const SizedBox(width: 8),
                _TurulChoice(
                  label: 'Дуудлага',
                  selected: _isDuudlaga,
                  color: AppColors.primary,
                  onTap: () => setState(() => _turul = 'duudlaga'),
                ),
              ],
            ),
            const SizedBox(height: 16),
            if (_isDuudlaga) ...[
              _buildDuudlagaTypeDropdown(context),
              const SizedBox(height: 12),
              TextField(
                controller: _duudlagaTitleCtrl,
                maxLength: 40,
                textCapitalization: TextCapitalization.sentences,
                onChanged: (_) => setState(() {}),
                decoration: InputDecoration(
                  labelText: 'Гарчиг',
                  hintText: 'Дуудлагын гарчиг...',
                  counterText: '${_duudlagaTitleCtrl.text.length}/40',
                ),
              ),
              const SizedBox(height: 12),
            ],
            TextField(
              controller: _msgCtrl,
              maxLines: _isDuudlaga ? 3 : 4,
              textCapitalization: TextCapitalization.sentences,
              decoration: InputDecoration(
                labelText: 'Тайлбар',
                hintText: _turul == 'gomdol'
                    ? 'Гомдлын тайлбар...'
                    : _isDuudlaga
                        ? 'Дэлгэрэнгүй тайлбар...'
                        : 'Санал хүсэлт...',
              ),
            ),
            if (_isDuudlaga) ...[
              const SizedBox(height: 12),
              _ReadOnlyField(icon: Icons.person_rounded, value: user?.fullName ?? ''),
              const SizedBox(height: 8),
              _ReadOnlyField(icon: Icons.phone_rounded, value: user?.primaryPhone ?? ''),
              if ((user?.register?.isNotEmpty ?? false)) ...[
                const SizedBox(height: 8),
                _ReadOnlyField(icon: Icons.badge_rounded, value: user?.register ?? ''),
              ],
            ],
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: _loading ? null : _submit,
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: _loading
                    ? const SizedBox(
                        width: 20, height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                      )
                    : const Text('Илгээх', style: TextStyle(fontWeight: FontWeight.w600)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDuudlagaTypeDropdown(BuildContext context) {
    return Column(
      children: [
        GestureDetector(
          onTap: () => setState(() => _isDropdownOpen = !_isDropdownOpen),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            decoration: BoxDecoration(
              border: Border.all(color: _isDropdownOpen ? AppColors.primary : context.appDivider, width: _isDropdownOpen ? 1.5 : 1),
              borderRadius: BorderRadius.circular(12),
              color: context.appInputFill,
            ),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    _duudlagaSubTurul.isEmpty ? 'Төрөл сонгох' : _duudlagaSubTurul,
                    style: TextStyle(color: _duudlagaSubTurul.isEmpty ? context.appTextTertiary : context.appTextPrimary),
                  ),
                ),
                Icon(
                  _isDropdownOpen ? Icons.keyboard_arrow_up_rounded : Icons.keyboard_arrow_down_rounded,
                  color: context.appTextTertiary,
                ),
              ],
            ),
          ),
        ),
        if (_isDropdownOpen)
          Container(
            constraints: const BoxConstraints(maxHeight: 200),
            decoration: BoxDecoration(
              border: Border.all(color: AppColors.primary.withOpacity(0.4)),
              borderRadius: BorderRadius.circular(12),
              color: context.appSurface,
              boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 8)],
            ),
            child: ListView.builder(
              shrinkWrap: true,
              itemCount: _duudlagaTurulOptions.length,
              itemBuilder: (_, i) => InkWell(
                onTap: () => setState(() {
                  _duudlagaSubTurul = _duudlagaTurulOptions[i];
                  _isDropdownOpen = false;
                }),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  decoration: BoxDecoration(
                    color: _duudlagaSubTurul == _duudlagaTurulOptions[i] ? context.appPrimaryContainer : Colors.transparent,
                    border: i < _duudlagaTurulOptions.length - 1
                        ? Border(bottom: BorderSide(color: context.appDivider))
                        : null,
                  ),
                  child: Text(
                    _duudlagaTurulOptions[i],
                    style: TextStyle(
                      color: _duudlagaSubTurul == _duudlagaTurulOptions[i] ? AppColors.primary : context.appTextPrimary,
                      fontWeight: _duudlagaSubTurul == _duudlagaTurulOptions[i] ? FontWeight.w600 : FontWeight.normal,
                    ),
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}

class _TurulChoice extends StatelessWidget {
  final String label;
  final bool selected;
  final Color color;
  final VoidCallback onTap;

  const _TurulChoice({required this.label, required this.selected, required this.color, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: selected ? color : context.appInputFill,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: selected ? color : context.appDivider),
          ),
          child: Text(
            label,
            style: TextStyle(
              fontWeight: FontWeight.w600,
              color: selected ? Colors.white : context.appTextSecondary,
            ),
          ),
        ),
      ),
    );
  }
}

class _DuudlagaTab extends ConsumerWidget {
  final VoidCallback? onAddDuudlaga;

  const _DuudlagaTab({this.onAddDuudlaga});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(duudlagaProvider);

    if (state.isLoading && state.duudlagaList.isEmpty) {
      return const ShimmerList(itemCount: 4, itemHeight: 80);
    }
    if (state.error != null && state.duudlagaList.isEmpty) {
      return AppErrorWidget(
        message: 'Дуудлагууд ачаалахад алдаа гарлаа',
        onRetry: () => ref.read(duudlagaProvider.notifier).load(),
      );
    }
    if (state.duudlagaList.isEmpty) {
      return AppEmpty(
        icon: Icons.phone_outlined,
        message: 'Дуудлага байхгүй байна',
        subMessage: 'Шинэ дуудлага үүсгэхийн тулд + товчийг дарна уу',
        onAction: onAddDuudlaga,
        actionLabel: 'Дуудлага үүсгэх',
      );
    }

    return RefreshIndicator(
      color: AppColors.primary,
      onRefresh: () async => ref.read(duudlagaProvider.notifier).load(),
      child: ListView.builder(
        padding: const EdgeInsets.symmetric(vertical: 8),
        itemCount: state.duudlagaList.length,
        itemBuilder: (context, index) => _DuudlagaCard(data: state.duudlagaList[index]),
      ),
    );
  }
}

class _DuudlagaCard extends StatelessWidget {
  final Map<String, dynamic> data;

  const _DuudlagaCard({required this.data});

  Color _statusColor(int tuluv) {
    switch (tuluv) {
      case 1: return AppColors.success;
      case -1: return AppColors.error;
      default: return AppColors.info;
    }
  }

  Color _statusBg(BuildContext context, int tuluv) {
    switch (tuluv) {
      case 1: return context.appSuccessLight;
      case -1: return context.appErrorLight;
      default: return context.appInfoLight;
    }
  }

  String _statusLabel(int tuluv) {
    switch (tuluv) {
      case 1: return 'Дууссан';
      case -1: return 'Цуцлагдсан';
      default: return 'Идэвхтэй';
    }
  }

  @override
  Widget build(BuildContext context) {
    final tuluv = (data['tuluv'] as num?)?.toInt() ?? 0;
    final title = data['title']?.toString() ?? 'Дуудлага';
    final message = data['message']?.toString() ?? '';
    final turul = data['duudlagiinTurul']?.toString() ?? '';
    final createdAt = data['createdAt']?.toString();

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 5),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: context.appCardBg,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: context.appDivider),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: _statusBg(context, tuluv),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(Icons.phone_rounded, size: 20, color: _statusColor(tuluv)),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(title, style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600)),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(color: _statusBg(context, tuluv), borderRadius: BorderRadius.circular(20)),
                      child: Text(_statusLabel(tuluv), style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: _statusColor(tuluv))),
                    ),
                  ],
                ),
                if (turul.isNotEmpty) ...[
                  const SizedBox(height: 3),
                  Text(turul, style: Theme.of(context).textTheme.bodySmall?.copyWith(color: AppColors.primary, fontWeight: FontWeight.w500)),
                ],
                if (message.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(message, style: Theme.of(context).textTheme.bodySmall, maxLines: 2, overflow: TextOverflow.ellipsis),
                ],
                if (createdAt != null) ...[
                  const SizedBox(height: 6),
                  Text(AppFormatters.dateTime(createdAt), style: Theme.of(context).textTheme.labelSmall),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}
