import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_colors.dart';
import '../../../data/repositories/auth_repository.dart';
import '../../providers/auth_provider.dart';
import '../../widgets/common/app_button.dart';
import '../../widgets/common/app_text_field.dart';

class ResetPasswordScreen extends ConsumerStatefulWidget {
  const ResetPasswordScreen({super.key});

  @override
  ConsumerState<ResetPasswordScreen> createState() => _ResetPasswordScreenState();
}

class _ResetPasswordScreenState extends ConsumerState<ResetPasswordScreen> {
  final _formKey = GlobalKey<FormState>();
  final _newPasswordController = TextEditingController();
  final _confirmController = TextEditingController();
  bool _obscure1 = true;
  bool _obscure2 = true;
  bool _isLoading = false;

  @override
  void dispose() {
    _newPasswordController.dispose();
    _confirmController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    final user = ref.read(currentUserProvider);
    final phone = user?.primaryPhone ?? '';
    if (phone.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Утасны дугаар олдсонгүй'), backgroundColor: AppColors.error),
      );
      return;
    }
    setState(() => _isLoading = true);
    try {
      await ref.read(authRepositoryProvider).resetPassword(
        phone: phone,
        newPassword: _newPasswordController.text,
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Нууц үг амжилттай солигдлоо')),
        );
        context.pop();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Алдаа гарлаа'), backgroundColor: AppColors.error),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Нууц үг солих'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => context.pop(),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 8),
              Text(
                'Шинэ нууц үгээ оруулна уу',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              const SizedBox(height: 32),
              AppTextField(
                label: 'Шинэ нууц үг',
                hint: '••••••••',
                controller: _newPasswordController,
                obscureText: _obscure1,
                prefixIcon: const Icon(Icons.lock_rounded, size: 18, color: AppColors.textTertiary),
                suffixIcon: IconButton(
                  icon: Icon(
                    _obscure1 ? Icons.visibility_rounded : Icons.visibility_off_rounded,
                    size: 18,
                    color: AppColors.textTertiary,
                  ),
                  onPressed: () => setState(() => _obscure1 = !_obscure1),
                ),
                validator: (v) {
                  if (v == null || v.isEmpty) return 'Нууц үг оруулна уу';
                  if (v.length < 4) return 'Хамгийн багадаа 4 тэмдэгт';
                  return null;
                },
              ),
              const SizedBox(height: 16),
              AppTextField(
                label: 'Нууц үг давтах',
                hint: '••••••••',
                controller: _confirmController,
                obscureText: _obscure2,
                prefixIcon: const Icon(Icons.lock_rounded, size: 18, color: AppColors.textTertiary),
                suffixIcon: IconButton(
                  icon: Icon(
                    _obscure2 ? Icons.visibility_rounded : Icons.visibility_off_rounded,
                    size: 18,
                    color: AppColors.textTertiary,
                  ),
                  onPressed: () => setState(() => _obscure2 = !_obscure2),
                ),
                validator: (v) {
                  if (v != _newPasswordController.text) return 'Нууц үг таарахгүй байна';
                  return null;
                },
              ),
              const SizedBox(height: 32),
              AppButton(
                label: 'Хадгалах',
                onPressed: _isLoading ? null : _submit,
                isLoading: _isLoading,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
