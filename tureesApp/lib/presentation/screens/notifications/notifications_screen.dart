import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/formatters.dart';
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
      ref.read(tasksProvider.notifier).load();
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
            Tab(text: 'Хүсэлт'),
            Tab(text: 'Дуудлага'),
          ],
        ),
        actions: [
          IconButton(
            icon: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(color: context.appInputFill, borderRadius: BorderRadius.circular(10)),
              child: Icon(Icons.add_rounded, size: 20, color: context.appTextSecondary),
            ),
            onPressed: () {
              if (_tabController.index == 2) {
                _showNewDuudlagaDialog(context);
              } else {
                _showNewTaskDialog(context);
              }
            },
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _NotificationsTab(),
          _TasksTab(onAddTask: () => _showNewTaskDialog(context)),
          _DuudlagaTab(onAddDuudlaga: () => _showNewDuudlagaDialog(context)),
        ],
      ),
    );
  }

  void _showNewTaskDialog(BuildContext context) {
    final titleCtrl = TextEditingController();
    final descCtrl = TextEditingController();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        decoration: BoxDecoration(
          color: ctx.appSurface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        ),
        padding: EdgeInsets.fromLTRB(24, 24, 24, MediaQuery.of(ctx).viewInsets.bottom + 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text('Шинэ хүсэлт', style: Theme.of(ctx).textTheme.headlineSmall),
                const Spacer(),
                IconButton(onPressed: () => Navigator.pop(ctx), icon: const Icon(Icons.close_rounded)),
              ],
            ),
            const SizedBox(height: 16),
            TextField(
              controller: titleCtrl,
              decoration: const InputDecoration(labelText: 'Гарчиг', hintText: 'Хүсэлтийн гарчиг...'),
              textCapitalization: TextCapitalization.sentences,
            ),
            const SizedBox(height: 12),
            TextField(
              controller: descCtrl,
              maxLines: 3,
              decoration: const InputDecoration(labelText: 'Дэлгэрэнгүй', hintText: 'Хүсэлтийн дэлгэрэнгүй мэдээлэл...'),
              textCapitalization: TextCapitalization.sentences,
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () async {
                  if (titleCtrl.text.trim().isEmpty) return;
                  Navigator.pop(ctx);
                  final title = titleCtrl.text.trim();
                  final desc = descCtrl.text.trim();
                  await ref.read(tasksProvider.notifier).submitTask(title, desc);
                  if (!mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Хүсэлт амжилттай илгээгдлээ')),
                  );
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: const Text('Илгээх', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showNewDuudlagaDialog(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _DuudlagaFormSheet(
        onSubmitted: () {
          ref.read(duudlagaProvider.notifier).load();
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Дуудлага амжилттай илгээгдлээ')),
            );
          }
        },
      ),
    );
  }
}

// ─── Дуудлага form sheet ────────────────────────────────────────────────────

class _DuudlagaFormSheet extends ConsumerStatefulWidget {
  final VoidCallback? onSubmitted;

  const _DuudlagaFormSheet({this.onSubmitted});

  @override
  ConsumerState<_DuudlagaFormSheet> createState() => _DuudlagaFormSheetState();
}

class _DuudlagaFormSheetState extends ConsumerState<_DuudlagaFormSheet> {
  final _titleCtrl = TextEditingController();
  final _msgCtrl = TextEditingController();
  String _selectedTurul = '';
  bool _isDropdownOpen = false;
  bool _submitted = false;
  bool _loading = false;

  static const _turulOptions = [
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
    _titleCtrl.dispose();
    _msgCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_selectedTurul.isEmpty || _titleCtrl.text.trim().isEmpty || _msgCtrl.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Бүх талбарыг бөглөнө үү')),
      );
      return;
    }
    final user = ref.read(currentUserProvider);
    setState(() => _loading = true);
    try {
      await ref.read(duudlagaProvider.notifier).submit(
        title: _titleCtrl.text.trim(),
        message: _msgCtrl.text.trim(),
        duudlagiinTurul: _selectedTurul,
        khariltsagchiinUtas: user?.primaryPhone ?? '',
        khariltsagchiinRegister: user?.register ?? '',
      );
      setState(() => _submitted = true);
      widget.onSubmitted?.call();
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
      padding: EdgeInsets.fromLTRB(24, 0, 24, MediaQuery.of(context).viewInsets.bottom + 24),
      child: _submitted ? _buildSuccess() : _buildForm(context, user),
    );
  }

  Widget _buildSuccess() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const SizedBox(height: 32),
        Container(
          width: 64,
          height: 64,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(color: AppColors.success, width: 2),
          ),
          child: const Icon(Icons.check_rounded, size: 32, color: AppColors.success),
        ),
        const SizedBox(height: 16),
        Text(
          'Дуудлага амжилттай бүртгэгдлээ.',
          style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 8),
        Text(
          'Хариуцсан менежер болон ажилтнууд\nтантай эргэн холбогдох болно.',
          style: Theme.of(context).textTheme.bodyMedium,
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 24),
        SizedBox(
          width: double.infinity,
          child: FilledButton(
            onPressed: () => Navigator.pop(context),
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.success,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: const Text('Хаах'),
          ),
        ),
        const SizedBox(height: 8),
      ],
    );
  }

  Widget _buildForm(BuildContext context, dynamic user) {
    return SingleChildScrollView(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 48,
              height: 5,
              margin: const EdgeInsets.symmetric(vertical: 12),
              decoration: BoxDecoration(color: context.appDivider, borderRadius: BorderRadius.circular(4)),
            ),
          ),
          Row(
            children: [
              Text('Дуудлага үүсгэх', style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700)),
              const Spacer(),
              IconButton(onPressed: () => Navigator.pop(context), icon: const Icon(Icons.close_rounded)),
            ],
          ),
          const SizedBox(height: 12),
          _buildTypeDropdown(context),
          const SizedBox(height: 12),
          TextField(
            controller: _titleCtrl,
            maxLength: 40,
            textCapitalization: TextCapitalization.sentences,
            onChanged: (_) => setState(() {}),
            decoration: InputDecoration(
              labelText: 'Гарчиг',
              hintText: 'Дуудлагын гарчиг...',
              counterText: '${_titleCtrl.text.length}/40',
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _msgCtrl,
            maxLines: 3,
            maxLength: 150,
            textCapitalization: TextCapitalization.sentences,
            onChanged: (_) => setState(() {}),
            decoration: InputDecoration(
              labelText: 'Тайлбар',
              hintText: 'Дэлгэрэнгүй тайлбар...',
              counterText: '${_msgCtrl.text.length}/150',
            ),
          ),
          const SizedBox(height: 12),
          _ReadOnlyField(label: 'Нэр', value: user?.fullName ?? ''),
          const SizedBox(height: 8),
          _ReadOnlyField(label: 'Утас', value: user?.primaryPhone ?? ''),
          if ((user?.register?.isNotEmpty ?? false)) ...[
            const SizedBox(height: 8),
            _ReadOnlyField(label: 'Регистр', value: user?.register ?? ''),
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
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                    )
                  : const Text('Илгээх', style: TextStyle(fontWeight: FontWeight.w600)),
            ),
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }

  Widget _buildTypeDropdown(BuildContext context) {
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
                    _selectedTurul.isEmpty ? 'Төрөл сонгох' : _selectedTurul,
                    style: TextStyle(color: _selectedTurul.isEmpty ? context.appTextTertiary : context.appTextPrimary),
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
              itemCount: _turulOptions.length,
              itemBuilder: (_, i) => InkWell(
                onTap: () => setState(() {
                  _selectedTurul = _turulOptions[i];
                  _isDropdownOpen = false;
                }),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  decoration: BoxDecoration(
                    color: _selectedTurul == _turulOptions[i] ? context.appPrimaryContainer : Colors.transparent,
                    border: i < _turulOptions.length - 1
                        ? Border(bottom: BorderSide(color: context.appDivider))
                        : null,
                  ),
                  child: Text(
                    _turulOptions[i],
                    style: TextStyle(
                      color: _selectedTurul == _turulOptions[i] ? AppColors.primary : context.appTextPrimary,
                      fontWeight: _selectedTurul == _turulOptions[i] ? FontWeight.w600 : FontWeight.normal,
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

class _ReadOnlyField extends StatelessWidget {
  final String label;
  final String value;

  const _ReadOnlyField({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        SizedBox(
          width: 72,
          child: Text(
            label,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(color: context.appTextTertiary),
          ),
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

    if (state.isLoading && state.notifications.isEmpty) {
      return const ShimmerList(itemCount: 5, itemHeight: 80);
    }
    if (state.error != null && state.notifications.isEmpty) {
      return AppErrorWidget(
        message: 'Мэдэгдэлүүд ачаалахад алдаа гарлаа',
        onRetry: () => ref.read(notificationsProvider.notifier).load(),
      );
    }
    if (state.notifications.isEmpty) {
      return const AppEmpty(icon: Icons.notifications_none_rounded, message: 'Мэдэгдэл байхгүй байна');
    }

    return RefreshIndicator(
      color: AppColors.primary,
      onRefresh: () async => ref.read(notificationsProvider.notifier).load(),
      child: ListView.builder(
        padding: const EdgeInsets.symmetric(vertical: 8),
        itemCount: state.notifications.length,
        itemBuilder: (context, index) => NotificationCard(
          notification: state.notifications[index],
          onTap: () {
            if (state.notifications[index].isUnread) {
              ref.read(notificationsProvider.notifier).markRead(state.notifications[index].id);
            }
          },
        ),
      ),
    );
  }
}

class _TasksTab extends ConsumerWidget {
  final VoidCallback? onAddTask;

  const _TasksTab({this.onAddTask});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(tasksProvider);

    if (state.isLoading && state.tasks.isEmpty) {
      return const ShimmerList(itemCount: 4, itemHeight: 80);
    }
    if (state.error != null && state.tasks.isEmpty) {
      return AppErrorWidget(
        message: 'Хүсэлтүүд ачаалахад алдаа гарлаа',
        onRetry: () => ref.read(tasksProvider.notifier).load(),
      );
    }
    if (state.tasks.isEmpty) {
      return AppEmpty(
        icon: Icons.build_outlined,
        message: 'Хүсэлт байхгүй байна',
        subMessage: 'Засвар үйлчилгээний хүсэлт илгээхийн тулд + товчийг дарна уу',
        onAction: onAddTask,
        actionLabel: 'Хүсэлт илгээх',
      );
    }

    return RefreshIndicator(
      color: AppColors.primary,
      onRefresh: () async => ref.read(tasksProvider.notifier).load(),
      child: ListView.builder(
        padding: const EdgeInsets.symmetric(vertical: 8),
        itemCount: state.tasks.length,
        itemBuilder: (context, index) => TaskCard(task: state.tasks[index]),
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
