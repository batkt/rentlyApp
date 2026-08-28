import 'dart:io' show Platform;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../core/services/push_notification_service.dart';
import '../../../core/theme/app_colors.dart';
import '../../providers/auth_provider.dart';
import '../../providers/mashin_provider.dart';
import '../../providers/notification_provider.dart';
import '../../providers/theme_provider.dart';
import '../../widgets/common/app_button.dart';
import '../home/home_screen.dart' show chatVisibleProvider;

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen>
    with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Хэрэглэгч утасны тохиргооноос мэдэгдлээ асаагаад буцаж ирэхэд
    // анхааруулга нь өөрөө алга болох ёстой.
    if (state == AppLifecycleState.resumed) {
      ref.invalidate(medegdelUnturaasanProvider);
    }
  }

  @override
  Widget build(BuildContext context) {
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
                _buildNemeltKhereglegchid(context, ref),
                _buildMedegdelAnkhaaruulga(context, ref),
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

  /// Users the tenant added from the web portal (appKhariltsagch). Hidden when
  /// there are none, so a tenant who never added anyone sees no extra clutter.
  Widget _buildNemeltKhereglegchid(BuildContext context, WidgetRef ref) {
    final khereglegchid = ref.watch(nemeltKhereglegchidProvider);

    return khereglegchid.maybeWhen(
      orElse: () => const SizedBox.shrink(),
      data: (jagsaalt) {
        if (jagsaalt.isEmpty) return const SizedBox.shrink();
        return Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          child: Container(
            decoration: BoxDecoration(
              color: context.appCardBg,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: context.appDivider),
            ),
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
                  child: Row(
                    children: [
                      const Icon(Icons.group_rounded, size: 20, color: AppColors.primary),
                      const SizedBox(width: 10),
                      Text(
                        'Нэмэлт хэрэглэгч',
                        style: Theme.of(context).textTheme.titleSmall?.copyWith(
                              fontWeight: FontWeight.w700,
                              color: context.appTextPrimary,
                            ),
                      ),
                      const Spacer(),
                      Text(
                        '${jagsaalt.length}',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: context.appTextTertiary,
                            ),
                      ),
                    ],
                  ),
                ),
                for (final khereglegch in jagsaalt) ...[
                  const Divider(height: 1),
                  ListTile(
                    leading: CircleAvatar(
                      radius: 18,
                      backgroundColor: context.appPrimaryContainer,
                      child: Text(
                        khereglegch.ner.isNotEmpty ? khereglegch.ner[0] : '?',
                        style: const TextStyle(
                          color: AppColors.primary,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    title: Text(
                      khereglegch.fullName.isNotEmpty ? khereglegch.fullName : 'Нэргүй',
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        color: context.appTextPrimary,
                      ),
                    ),
                    subtitle: Text(
                      [
                        if (khereglegch.primaryPhone.isNotEmpty) khereglegch.primaryPhone,
                        if (khereglegch.gereeniiIdnuud.isNotEmpty)
                          '${khereglegch.gereeniiIdnuud.length} гэрээ',
                        if (khereglegch.appErkhuud.isNotEmpty)
                          '${khereglegch.appErkhuud.length} эрх',
                      ].join(' · '),
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }

  /// Утасны тохиргоон дээр мэдэгдэл унтраалттай үед анхааруулна.
  ///
  /// Апп доторх «Мэдэгдэл харах» унтраалга нь зөвхөн апп нээлттэй үеийн
  /// мэдэгдлийг л удирддаг — түгжигдсэн дэлгэц дээрх мэдэгдлийг үйлдлийн
  /// систем шийддэг. Тиймээс тэндээс унтраасныг апп доторх тохиргооноос
  /// мэдэх аргагүй бөгөөд хэрэглэгч мэдэгдэл ирэхгүйг шалтгаангүй гэж боддог.
  Widget _buildMedegdelAnkhaaruulga(BuildContext context, WidgetRef ref) {
    final unturaasan = ref.watch(medegdelUnturaasanProvider);

    return unturaasan.maybeWhen(
      orElse: () => const SizedBox.shrink(),
      data: (unturaalttai) {
        if (!unturaalttai) return const SizedBox.shrink();
        return Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          child: Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: context.appWarningLight,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.warning.withOpacity(0.4)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.notifications_off_rounded,
                        size: 20, color: AppColors.warning),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'Мэдэгдэл унтраалттай байна',
                        style: Theme.of(context)
                            .textTheme
                            .titleSmall
                            ?.copyWith(
                              fontWeight: FontWeight.w700,
                              color: AppColors.warning,
                            ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  'Утасныхаа тохиргоон дээр энэ аппын мэдэгдлийг хаасан байна. '
                  'Нэхэмжлэх, төлбөрийн мэдэгдэл танд ирэхгүй.',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: context.appTextSecondary,
                      ),
                ),
                const SizedBox(height: 10),
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton.icon(
                    onPressed: () => _medegdliigAsaaya(ref),
                    icon: const Icon(Icons.settings_rounded, size: 16),
                    label: const Text('Асаах'),
                    style: TextButton.styleFrom(
                      foregroundColor: AppColors.warning,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 6),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  /// Эхлээд системийн зөвшөөрлийг дахин асууна (Android 13+ дээр цонх гарна).
  /// Бүрмөсөн татгалзсан эсвэл iOS дээр бол энэ юу ч хийхгүй тул утасны
  /// тохиргоог нь нээж өгнө.
  Future<void> _medegdliigAsaaya(WidgetRef ref) async {
    await PushNotificationService.instance.zuvshuuruliigDakhinAsuuya();
    ref.invalidate(medegdelUnturaasanProvider);

    final khevleer = await ref.read(medegdelUnturaasanProvider.future);
    if (!khevleer) return;

    // iOS дээр `app-settings:` нь аппын тохиргоог шууд нээнэ. `canLaunchUrl`
    // энэ схем дээр найдваргүй хариу өгдөг тул шууд оролдоод, бүтэхгүй бол
    // анхааруулга нь хэвээр үлдэнэ — хэрэглэгч гараар нээх боломжтой.
    if (Platform.isIOS) {
      try {
        await launchUrl(Uri.parse('app-settings:'));
      } catch (_) {}
    }
  }

  Widget _buildSettingsSection(BuildContext context, WidgetRef ref, bool isDark) {
    final chatVisible = ref.watch(chatVisibleProvider);
    final notifEnabled = ref.watch(notificationsEnabledProvider);
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
            if (ref.watch(mashinBurtgelKharuulakhProvider)) ...[
              _SettingsItem(
                icon: Icons.directions_car_rounded,
                label: 'Машин бүртгэл',
                onTap: () => context.push('/mashin'),
              ),
              const Divider(height: 1),
            ],
            ListTile(
              leading: const Icon(Icons.notifications_rounded, size: 20, color: AppColors.primary),
              title: const Text('Мэдэгдэл харах'),
              trailing: Switch.adaptive(
                value: notifEnabled,
                activeThumbColor: AppColors.primary,
                activeTrackColor: AppColors.primaryContainer,
                onChanged: (v) => ref.read(notificationsEnabledProvider.notifier).set(v),
              ),
            ),
            const Divider(height: 1),
            ListTile(
              leading: const Icon(Icons.chat_bubble_rounded, size: 20, color: AppColors.primary),
              title: const Text('Чат харуулах'),
              trailing: Switch.adaptive(
                value: chatVisible,
                activeThumbColor: AppColors.primary,
                activeTrackColor: AppColors.primaryContainer,
                onChanged: (v) => ref.read(chatVisibleProvider.notifier).state = v,
              ),
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
        onPressed: () async {
          final confirmed = await showDialog<bool>(
            context: context,
            builder: (ctx) => AlertDialog(
              title: const Text('Гарах уу?'),
              content: const Text('Системээс гарахдаа итгэлтэй байна уу?'),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx, false),
                  child: const Text('Болих'),
                ),
                TextButton(
                  onPressed: () => Navigator.pop(ctx, true),
                  style: TextButton.styleFrom(foregroundColor: AppColors.error),
                  child: const Text('Гарах'),
                ),
              ],
            ),
          );
          if (confirmed != true) return;
          await ref.read(authStateProvider.notifier).logout();
          if (context.mounted) context.go('/login');
        },
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
