import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/formatters.dart';
import '../../../data/models/duudlaga_model.dart';
import '../../providers/duudlaga_provider.dart';
import '../../widgets/common/app_loading.dart';

class DuudlagaScreen extends ConsumerStatefulWidget {
  const DuudlagaScreen({super.key});

  @override
  ConsumerState<DuudlagaScreen> createState() => _DuudlagaScreenState();
}

class _DuudlagaScreenState extends ConsumerState<DuudlagaScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final state = ref.read(duudlagaProvider);
      if (state.items.isEmpty && !state.isLoading) {
        ref.read(duudlagaProvider.notifier).load();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final duudlagaState = ref.watch(duudlagaProvider);

    return Scaffold(
      backgroundColor: context.appBackground,
      appBar: AppBar(
        title: const Text('Дуудлага'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            onPressed: () => ref.read(duudlagaProvider.notifier).load(refresh: true),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showCreateSheet(context),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add_rounded),
        label: const Text('Шинэ дуудлага', style: TextStyle(fontWeight: FontWeight.w700)),
        elevation: 4,
      ),
      body: RefreshIndicator(
        color: AppColors.primary,
        onRefresh: () => ref.read(duudlagaProvider.notifier).load(refresh: true),
        child: Builder(builder: (context) {
          if (duudlagaState.isLoading && duudlagaState.items.isEmpty) {
            return const ShimmerList(itemCount: 5);
          }

          if (duudlagaState.error != null && duudlagaState.items.isEmpty) {
            return AppErrorWidget(
              message: duudlagaState.error!,
              onRetry: () => ref.read(duudlagaProvider.notifier).load(refresh: true),
            );
          }

          if (duudlagaState.items.isEmpty) {
            return const AppEmpty(
              icon: Icons.campaign_outlined,
              message: 'Дуудлага байхгүй байна',
              subMessage: 'Шинэ дуудлага үүсгэхийн тулд + товчийг дарна уу',
            );
          }

          return ListView.separated(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
            itemCount: duudlagaState.items.length,
            separatorBuilder: (_, __) => const SizedBox(height: 10),
            itemBuilder: (context, index) {
              final item = duudlagaState.items[index];
              return _DuudlagaCard(
                duudlaga: item,
                onCancel: item.isActive
                    ? () => _confirmCancel(context, item)
                    : null,
              );
            },
          );
        }),
      ),
    );
  }

  void _showCreateSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _CreateDuudlagaSheet(
        onCreated: () => ref.read(duudlagaProvider.notifier).load(refresh: true),
      ),
    );
  }

  Future<void> _confirmCancel(BuildContext context, DuudlagaModel item) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Дуудлага цуцлах'),
        content: Text('"${item.title}" дуудлагыг цуцлах уу?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Болих')),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(backgroundColor: AppColors.error),
            child: const Text('Цуцлах'),
          ),
        ],
      ),
    );
    if (confirm == true) {
      await ref.read(duudlagaProvider.notifier).cancel(item.id);
    }
  }
}

class _DuudlagaCard extends StatelessWidget {
  final DuudlagaModel duudlaga;
  final VoidCallback? onCancel;

  const _DuudlagaCard({required this.duudlaga, this.onCancel});

  @override
  Widget build(BuildContext context) {
    final statusColor = _statusColor(duudlaga.tuluv);
    final statusBg = statusColor.withOpacity(0.1);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: context.appCardBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: context.appDivider),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: AppColors.primary.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.campaign_rounded, color: AppColors.primary, size: 22),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      duudlaga.title,
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      duudlaga.createdAt != null ? AppFormatters.dateTime(duudlaga.createdAt) : '',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: statusBg,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 6,
                      height: 6,
                      decoration: BoxDecoration(
                        color: statusColor,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 5),
                    Text(
                      duudlaga.statusText,
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: statusColor,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (duudlaga.message.isNotEmpty) ...[
            const SizedBox(height: 10),
            Text(
              duudlaga.message,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(height: 1.5),
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
            ),
          ],
          if (duudlaga.tailbar != null && duudlaga.isCancelled) ...[
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: context.appErrorLight,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                'Шалтгаан: ${duudlaga.tailbar}',
                style: const TextStyle(fontSize: 11, color: AppColors.error),
              ),
            ),
          ],
          if (onCancel != null) ...[
            const SizedBox(height: 12),
            const Divider(height: 1),
            const SizedBox(height: 10),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton.icon(
                onPressed: onCancel,
                icon: const Icon(Icons.cancel_outlined, size: 16),
                label: const Text('Цуцлах', style: TextStyle(fontSize: 13)),
                style: TextButton.styleFrom(
                  foregroundColor: AppColors.error,
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Color _statusColor(int tuluv) {
    switch (tuluv) {
      case 0: return const Color(0xFF2563EB);
      case 1: return AppColors.success;
      case -1: return AppColors.error;
      default: return AppColors.textTertiary;
    }
  }
}

class _CreateDuudlagaSheet extends ConsumerStatefulWidget {
  final VoidCallback onCreated;

  const _CreateDuudlagaSheet({required this.onCreated});

  @override
  ConsumerState<_CreateDuudlagaSheet> createState() => _CreateDuudlagaSheetState();
}

class _CreateDuudlagaSheetState extends ConsumerState<_CreateDuudlagaSheet> {
  final _titleController = TextEditingController();
  final _messageController = TextEditingController();

  final _titles = [
    'Засвар',
    'Цахилгаан',
    'Ус',
    'Халаалт',
    'Лифт',
    'Цэвэрлэгээ',
    'Аюулгүй байдал',
    'Бусад',
  ];

  @override
  void dispose() {
    _titleController.dispose();
    _messageController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_titleController.text.isEmpty || _messageController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Гарчиг болон мессеж оруулна уу'), backgroundColor: AppColors.error),
      );
      return;
    }
    FocusScope.of(context).unfocus();
    final success = await ref.read(duudlagaProvider.notifier).create(
      title: _titleController.text.trim(),
      message: _messageController.text.trim(),
    );
    if (!mounted) return;
    if (success) {
      widget.onCreated();
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Дуудлага амжилттай илгээгдлээ!'),
          backgroundColor: AppColors.success,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          margin: const EdgeInsets.all(16),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final duudlagaState = ref.watch(duudlagaProvider);

    return Container(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E2A28) : Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
      ),
      padding: EdgeInsets.fromLTRB(24, 16, 24, MediaQuery.of(context).viewInsets.bottom + 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF2D3B39) : AppColors.divider,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 20),
          Text(
            'Шинэ дуудлага үүсгэх',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 4),
          Text(
            'Засвар, гэмтэл, шаардлагаа бидэнд мэдэгдэнэ үү.',
            style: Theme.of(context).textTheme.bodySmall,
          ),
          const SizedBox(height: 20),
          Text(
            'Гарчиг',
            style: Theme.of(context).textTheme.labelMedium?.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _titles.map((t) {
              final selected = _titleController.text == t;
              return GestureDetector(
                onTap: () => setState(() => _titleController.text = t),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 150),
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  decoration: BoxDecoration(
                    color: selected ? AppColors.primary : (isDark ? const Color(0xFF111918) : const Color(0xFFF1F5F9)),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: selected ? AppColors.primary : (isDark ? const Color(0xFF2D3B39) : AppColors.divider),
                    ),
                  ),
                  child: Text(
                    t,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: selected ? Colors.white : context.appTextSecondary,
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
          if (_titleController.text == 'Бусад') ...[
            const SizedBox(height: 10),
            TextField(
              controller: _titleController,
              decoration: InputDecoration(
                hintText: 'Өөр гарчиг оруулах...',
                filled: true,
                fillColor: isDark ? const Color(0xFF111918) : const Color(0xFFF8FAFC),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
                contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              ),
            ),
          ],
          const SizedBox(height: 16),
          Text(
            'Дэлгэрэнгүй мэдээлэл',
            style: Theme.of(context).textTheme.labelMedium?.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _messageController,
            maxLines: 4,
            decoration: InputDecoration(
              hintText: 'Асуудлын тайлбарыг оруулна уу...',
              filled: true,
              fillColor: isDark ? const Color(0xFF111918) : const Color(0xFFF8FAFC),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: isDark ? const Color(0xFF2D3B39) : AppColors.divider),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: AppColors.primary, width: 1.5),
              ),
              contentPadding: const EdgeInsets.all(14),
            ),
          ),
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            height: 52,
            child: ElevatedButton(
              onPressed: duudlagaState.isCreating ? null : _submit,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                elevation: 0,
              ),
              child: duudlagaState.isCreating
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white),
                    )
                  : const Text('Илгээх', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
            ),
          ),
        ],
      ),
    );
  }
}
