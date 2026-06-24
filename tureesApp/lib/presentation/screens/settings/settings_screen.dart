import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_colors.dart';
import '../../providers/auth_provider.dart';
import '../../providers/theme_provider.dart';
import '../../widgets/common/app_button.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(currentUserProvider);
    final isDark = ref.watch(themeModeProvider) == ThemeMode.dark;

    return Scaffold(
      appBar: AppBar(title: const Text('Профайл')),
      body: Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 600),
          child: SingleChildScrollView(
            child: Column(
              children: [
                _buildProfileHeader(context, user?.fullName ?? 'Хэрэглэгч', user?.primaryPhone ?? ''),
                const SizedBox(height: 16),
                _buildUserInfoCard(context, user),
                const SizedBox(height: 16),
                _buildSettingsSection(context, ref, isDark),
                const SizedBox(height: 16),
                _buildLogoutSection(context, ref),
                const SizedBox(height: 32),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildProfileHeader(BuildContext context, String name, String phone) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: context.appCardBg,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: context.appDivider),
        ),
        child: Row(
          children: [
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                color: AppColors.primaryContainer,
                shape: BoxShape.circle,
              ),
              child: Center(
                child: Text(
                  name.isNotEmpty ? name[0].toUpperCase() : 'Х',
                  style: const TextStyle(
                    color: AppColors.primary,
                    fontSize: 24,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    name,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    phone,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(color: context.appTextTertiary),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildUserInfoCard(BuildContext context, dynamic user) {
    if (user == null) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Container(
        decoration: BoxDecoration(
          color: context.appCardBg,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: context.appDivider),
        ),
        child: Column(
          children: [
            _InfoRow(icon: Icons.person_rounded, label: 'Нэр', value: user.fullName),
            const Divider(height: 1),
            _InfoRow(
              icon: Icons.phone_rounded,
              label: 'Утас',
              value: user.utas.isNotEmpty ? user.utas.first : '-',
            ),
            if (user.register?.isNotEmpty == true) ...[
              const Divider(height: 1),
              _InfoRow(icon: Icons.badge_rounded, label: 'Регистр', value: user.register!),
            ],
            if (user.mail?.isNotEmpty == true) ...[
              const Divider(height: 1),
              _InfoRow(icon: Icons.mail_rounded, label: 'И-мэйл', value: user.mail!),
            ],
            
          ],
        ),
      ),
    );
  }

  String _roleLabel(String? role) {
    switch (role) {
      case 'oршин суугч':
      case 'suugch':
        return 'Оршин суугч';
      case 'tureeslegch':
      case 'tenant':
        return 'Түрээслэгч';
      default:
        return role ?? 'Хэрэглэгч';
    }
  }

  Widget _buildSettingsSection(BuildContext context, WidgetRef ref, bool isDark) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Container(
        decoration: BoxDecoration(
          color: context.appCardBg,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: context.appDivider),
        ),
        child: Column(
          children: [
            _SettingsItem(
              icon: Icons.lock_rounded,
              label: 'Нууц үг солих',
              onTap: () => context.push('/reset-password'),
            ),
            const Divider(height: 1),
            _SettingsItem(
              icon: Icons.notifications_rounded,
              label: 'Мэдэгдлийн тохиргоо',
              onTap: () {},
            ),
            const Divider(height: 1),
            ListTile(
              leading: const Icon(Icons.dark_mode_rounded, size: 20, color: AppColors.primary),
              title: const Text('Dark Mode'),
              trailing: Switch.adaptive(
                value: isDark,
                activeThumbColor: AppColors.primary,
                activeTrackColor: AppColors.primaryContainer,
                onChanged: (_) => ref.read(themeModeProvider.notifier).toggle(),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLogoutSection(BuildContext context, WidgetRef ref) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: AppButton(
        label: 'Гарах',
        variant: ButtonVariant.danger,
        icon: Icons.logout_rounded,
        onPressed: () => _confirmLogout(context, ref),
      ),
    );
  }

  void _confirmLogout(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Гарахыг баталгаажуулах'),
        content: const Text('Та системээс гарахдаа итгэлтэй байна уу?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Болих'),
          ),
          FilledButton(
            onPressed: () async {
              Navigator.pop(ctx);
              await ref.read(authStateProvider.notifier).logout();
              if (context.mounted) context.go('/login');
            },
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.error,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: const Text('Гарах'),
          ),
        ],
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _InfoRow({required this.icon, required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return ListTile(
      dense: true,
      leading: Icon(icon, size: 18, color: AppColors.primary),
      title: Text(label, style: Theme.of(context).textTheme.bodySmall?.copyWith(color: context.appTextTertiary)),
      trailing: Text(value, style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w500)),
    );
  }
}

class _SettingsItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _SettingsItem({required this.icon, required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return ListTile(
      onTap: onTap,
      leading: Icon(icon, size: 20, color: AppColors.primary),
      title: Text(label, style: Theme.of(context).textTheme.titleSmall),
      trailing: Icon(Icons.chevron_right_rounded, size: 20, color: context.appTextTertiary),
    );
  }
}
