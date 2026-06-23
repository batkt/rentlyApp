import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_colors.dart';
import '../../../data/repositories/auth_repository.dart';
import '../../widgets/common/app_button.dart';
import '../../widgets/common/app_text_field.dart';

enum _Step { phone, otp, password }

class ResetPasswordScreen extends ConsumerStatefulWidget {
  final String? initialPhone;

  const ResetPasswordScreen({super.key, this.initialPhone});

  @override
  ConsumerState<ResetPasswordScreen> createState() => _ResetPasswordScreenState();
}

class _ResetPasswordScreenState extends ConsumerState<ResetPasswordScreen> {
  _Step _step = _Step.phone;

  final _phoneController = TextEditingController();
  final _otpController = TextEditingController();
  final _newPasswordController = TextEditingController();
  final _confirmController = TextEditingController();

  bool _obscure1 = true;
  bool _obscure2 = true;
  bool _isLoading = false;

  // Persisted between steps
  String _khariltsagchId = '';
  String _recoveryToken = '';

  @override
  void initState() {
    super.initState();
    if (widget.initialPhone != null) {
      _phoneController.text = widget.initialPhone!;
    }
  }

  @override
  void dispose() {
    _phoneController.dispose();
    _otpController.dispose();
    _newPasswordController.dispose();
    _confirmController.dispose();
    super.dispose();
  }

  Future<void> _sendCode() async {
    final phone = _phoneController.text.trim();
    if (phone.length < 8) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('8 оронтой утасны дугаар оруулна уу'), backgroundColor: AppColors.error),
      );
      return;
    }
    setState(() => _isLoading = true);
    try {
      final id = await ref.read(authRepositoryProvider).sendRecoveryCode(phone);
      if (id.isEmpty) throw Exception('Хэрэглэгч олдсонгүй');
      setState(() {
        _khariltsagchId = id;
        _step = _Step.otp;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Сэргээх код утсанд илгээлээ'),
            backgroundColor: AppColors.success,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(_parseError(e)),
            backgroundColor: AppColors.error,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _verifyCode() async {
    final code = _otpController.text.trim();
    if (code.length < 6) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('6 оронтой код оруулна уу'), backgroundColor: AppColors.error),
      );
      return;
    }
    setState(() => _isLoading = true);
    try {
      final token = await ref.read(authRepositoryProvider).verifyRecoveryCode(_khariltsagchId, code);
      if (token.isEmpty) throw Exception('Код буруу байна');
      setState(() {
        _recoveryToken = token;
        _step = _Step.password;
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(_parseError(e)),
            backgroundColor: AppColors.error,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _savePassword() async {
    final newPass = _newPasswordController.text;
    final confirm = _confirmController.text;
    if (newPass.isEmpty || newPass.length < 4) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Хамгийн багадаа 4 тэмдэгт оруулна уу'), backgroundColor: AppColors.error),
      );
      return;
    }
    if (newPass != confirm) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Нууц үг таарахгүй байна'), backgroundColor: AppColors.error),
      );
      return;
    }
    setState(() => _isLoading = true);
    try {
      await ref.read(authRepositoryProvider).updatePassword(_khariltsagchId, newPass, _recoveryToken);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Нууц үг амжилттай солигдлоо'), backgroundColor: AppColors.success),
        );
        context.pop();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(_parseError(e)), backgroundColor: AppColors.error),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  String _parseError(Object e) {
    final msg = e.toString();
    if (msg.contains('Тохиргоо')) return 'SMS тохиргоо хийгдээгүй байна';
    if (msg.contains('олдсонгүй') || msg.contains('404')) return 'Бүртгэлтэй харилцагч олдсонгүй';
    if (msg.contains('буруу') || msg.contains('401')) return 'Код буруу байна';
    return 'Алдаа гарлаа. Дахин оролдоно уу';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Нууц үг сэргээх'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () {
            if (_step == _Step.otp) {
              setState(() => _step = _Step.phone);
            } else if (_step == _Step.password) {
              setState(() => _step = _Step.otp);
            } else {
              context.pop();
            }
          },
        ),
      ),
      body: Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 520),
          child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _StepIndicator(step: _step),
            const SizedBox(height: 28),
            if (_step == _Step.phone) _buildPhoneStep(),
            if (_step == _Step.otp) _buildOtpStep(),
            if (_step == _Step.password) _buildPasswordStep(),
          ],
        ),
          ),
        ),
      ),
    );
  }

  Widget _buildPhoneStep() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Утасны дугаараа оруулна уу',
          style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 6),
        Text(
          'Бүртгэлтэй утасны дугаарт сэргээх код илгээнэ',
          style: Theme.of(context).textTheme.bodyMedium,
        ),
        const SizedBox(height: 24),
        AppTextField(
          label: 'Утасны дугаар',
          hint: '1234 5678',
          controller: _phoneController,
          keyboardType: TextInputType.phone,
          enabled: widget.initialPhone == null,
          inputFormatters: [
            FilteringTextInputFormatter.digitsOnly,
            LengthLimitingTextInputFormatter(8),
          ],
          prefixIcon: const Icon(Icons.phone_rounded, size: 18, color: AppColors.textTertiary),
          suffixIcon: widget.initialPhone != null
              ? const Icon(Icons.lock_rounded, size: 16, color: AppColors.textTertiary)
              : null,
        ),
        const SizedBox(height: 28),
        AppButton(
          label: 'Код авах',
          onPressed: _isLoading ? null : _sendCode,
          isLoading: _isLoading,
          icon: Icons.send_rounded,
        ),
      ],
    );
  }

  Widget _buildOtpStep() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Сэргээх код',
          style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 6),
        Text(
          '${_phoneController.text} дугаарт илгээсэн 6 оронтой кодыг оруулна уу',
          style: Theme.of(context).textTheme.bodyMedium,
        ),
        const SizedBox(height: 24),
        AppTextField(
          label: 'Сэргээх код',
          hint: '○ ○ ○ ○ ○ ○',
          controller: _otpController,
          keyboardType: TextInputType.number,
          inputFormatters: [
            FilteringTextInputFormatter.digitsOnly,
            LengthLimitingTextInputFormatter(6),
          ],
          prefixIcon: const Icon(Icons.lock_open_rounded, size: 18, color: AppColors.textTertiary),
        ),
        const SizedBox(height: 12),
        TextButton(
          onPressed: _isLoading ? null : _sendCode,
          child: const Text('Код дахин илгээх', style: TextStyle(fontSize: 13)),
        ),
        const SizedBox(height: 16),
        AppButton(
          label: 'Баталгаажуулах',
          onPressed: _isLoading ? null : _verifyCode,
          isLoading: _isLoading,
          icon: Icons.check_rounded,
        ),
      ],
    );
  }

  Widget _buildPasswordStep() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Шинэ нууц үг',
          style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 6),
        Text(
          'Шинэ нууц үгээ оруулна уу',
          style: Theme.of(context).textTheme.bodyMedium,
        ),
        const SizedBox(height: 24),
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
        ),
        const SizedBox(height: 28),
        AppButton(
          label: 'Хадгалах',
          onPressed: _isLoading ? null : _savePassword,
          isLoading: _isLoading,
          icon: Icons.save_rounded,
        ),
      ],
    );
  }
}

class _StepIndicator extends StatelessWidget {
  final _Step step;

  const _StepIndicator({required this.step});

  @override
  Widget build(BuildContext context) {
    final steps = ['Утас', 'Код', 'Нууц үг'];
    final current = step.index;

    return Row(
      children: List.generate(steps.length, (i) {
        final isActive = i == current;
        final isDone = i < current;
        return Expanded(
          child: Row(
            children: [
              Expanded(
                child: Column(
                  children: [
                    Container(
                      width: 32,
                      height: 32,
                      margin: const EdgeInsets.symmetric(horizontal: 4),
                      decoration: BoxDecoration(
                        color: isDone
                            ? AppColors.success
                            : isActive
                                ? AppColors.primary
                                : AppColors.inputFill,
                        shape: BoxShape.circle,
                        border: isActive ? Border.all(color: AppColors.primary, width: 2) : null,
                      ),
                      child: Center(
                        child: isDone
                            ? const Icon(Icons.check_rounded, size: 16, color: Colors.white)
                            : Text(
                                '${i + 1}',
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w700,
                                  color: isActive ? Colors.white : AppColors.textTertiary,
                                ),
                              ),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      steps[i],
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: isActive ? FontWeight.w700 : FontWeight.normal,
                        color: isActive ? AppColors.primary : AppColors.textTertiary,
                      ),
                    ),
                  ],
                ),
              ),
              if (i < steps.length - 1)
                Expanded(
                  child: Container(
                    height: 2,
                    margin: const EdgeInsets.only(bottom: 20),
                    color: i < current ? AppColors.success : AppColors.divider,
                  ),
                ),
            ],
          ),
        );
      }),
    );
  }
}
