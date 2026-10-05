import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/storage/secure_storage.dart';
import '../../../core/theme/app_colors.dart';
import '../../../data/repositories/auth_repository.dart';
import '../../widgets/common/app_button.dart';
import '../../widgets/common/app_text_field.dart';
import '../../../core/utils/app_snackbar.dart';

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

  // Код дахин илгээх хүртэл үлдсэн секунд. Сервер 2 минутын завсар тавьдаг
  // (sergeekhKodAvya), товчийг мөн тэр хугацаанд идэвхгүй болгоно — эс тэгвээс
  // дараалж дарахад харилцагч руу дараалсан SMS очно.
  static const int _dakhinIlgeekhSekund = 120;
  int _uldsenSekund = 0;
  Timer? _tooluur;

  /// 95 → "1:35".
  String get _uldsenKhugatsaa =>
      '${_uldsenSekund ~/ 60}:${(_uldsenSekund % 60).toString().padLeft(2, '0')}';

  // Дуусах хугацааг утас бүрээр хадгална — хэрэглэгч дэлгэцээс гараад буцаж
  // орох, эсвэл аппаа хаагаад нээхэд ч тоолуур үргэлжилнэ.
  String _tooluuriinTulkhuur(String utas) => 'sergeekh_kod_duusakh_$utas';
  DateTime? _tooluurDuusakh;

  /// [sekund] секундын тоолуур эхлүүлж, дуусах хугацааг хадгална.
  void _tooluurEkhluuley([int sekund = _dakhinIlgeekhSekund]) {
    final duusakh = DateTime.now().add(Duration(seconds: sekund));
    ref.read(secureStorageProvider).write(
          _tooluuriinTulkhuur(_phoneController.text.trim()),
          duusakh.millisecondsSinceEpoch.toString(),
        );
    _tooluurAjilluulya(duusakh);
  }

  void _tooluurAjilluulya(DateTime duusakh) {
    _tooluur?.cancel();
    _tooluurDuusakh = duusakh;
    // Үлдсэн хугацааг дуусах цагаас тооцно — апп background-д байсан ч зөв.
    int uldsen() {
      final s = duusakh.difference(DateTime.now()).inMilliseconds / 1000;
      return s <= 0 ? 0 : s.ceil();
    }

    setState(() => _uldsenSekund = uldsen());
    if (_uldsenSekund <= 0) return;
    _tooluur = Timer.periodic(const Duration(seconds: 1), (tooluur) {
      if (!mounted) {
        tooluur.cancel();
        return;
      }
      setState(() => _uldsenSekund = uldsen());
      if (_uldsenSekund <= 0) tooluur.cancel();
    });
  }

  /// Тухайн дугаарт өмнө нь код илгээсэн бол үлдсэн хугацааг сэргээнэ.
  Future<void> _khadgalsanTooluurSergeeye() async {
    final utas = _phoneController.text.trim();
    if (utas.length < 8) {
      if (_tooluurDuusakh != null) {
        _tooluur?.cancel();
        _tooluurDuusakh = null;
        setState(() => _uldsenSekund = 0);
      }
      return;
    }
    final saved = await ref.read(secureStorageProvider).read(_tooluuriinTulkhuur(utas));
    final ms = int.tryParse(saved ?? '');
    if (!mounted || utas != _phoneController.text.trim()) return;
    if (ms == null) {
      _tooluur?.cancel();
      _tooluurDuusakh = null;
      setState(() => _uldsenSekund = 0);
      return;
    }
    _tooluurAjilluulya(DateTime.fromMillisecondsSinceEpoch(ms));
  }

  @override
  void initState() {
    super.initState();
    if (widget.initialPhone != null) {
      _phoneController.text = widget.initialPhone!;
    }
    _phoneController.addListener(_khadgalsanTooluurSergeeye);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _khadgalsanTooluurSergeeye();
    });
  }

  @override
  void dispose() {
    _tooluur?.cancel();
    _phoneController.removeListener(_khadgalsanTooluurSergeeye);
    _phoneController.dispose();
    _otpController.dispose();
    _newPasswordController.dispose();
    _confirmController.dispose();
    super.dispose();
  }

  Future<void> _sendCode() async {
    final phone = _phoneController.text.trim();
    if (phone.length < 8) {
      showAppSnackBar(context, '8 оронтой утасны дугаар оруулна уу', turul: SnackTurul.aldaa);
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
      _tooluurEkhluuley();
      if (mounted) {
        showAppSnackBar(context, 'Сэргээх код утсанд илгээлээ', turul: SnackTurul.amjilt);
      }
    } catch (e) {
      // Сервер "Дахин код авахад N секунд үлдлээ." (429) гэвэл тоолуурыг
      // серверийн үлдсэн хугацаагаар эхлүүлнэ.
      if (e is DioException && e.response?.statusCode == 429) {
        final msg = e.response?.data is Map ? '${e.response?.data['aldaa']}' : '';
        final sekund = int.tryParse(RegExp(r'\d+').firstMatch(msg)?.group(0) ?? '');
        if (mounted) _tooluurEkhluuley(sekund ?? _dakhinIlgeekhSekund);
      }
      if (mounted) {
        showAppSnackBar(context, _parseError(e), turul: SnackTurul.aldaa);
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _verifyCode() async {
    final code = _otpController.text.trim();
    if (code.length < 6) {
      showAppSnackBar(context, '6 оронтой код оруулна уу', turul: SnackTurul.aldaa);
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
        showAppSnackBar(context, _parseError(e), turul: SnackTurul.aldaa);
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _savePassword() async {
    final newPass = _newPasswordController.text;
    final confirm = _confirmController.text;
    if (newPass.isEmpty || newPass.length < 4) {
      showAppSnackBar(context, 'Хамгийн багадаа 4 тэмдэгт оруулна уу', turul: SnackTurul.aldaa);
      return;
    }
    if (newPass != confirm) {
      showAppSnackBar(context, 'Нууц үг таарахгүй байна', turul: SnackTurul.aldaa);
      return;
    }
    setState(() => _isLoading = true);
    try {
      await ref.read(authRepositoryProvider).updatePassword(_khariltsagchId, newPass, _recoveryToken);
      if (mounted) {
        showAppSnackBar(context, 'Нууц үг амжилттай солигдлоо', turul: SnackTurul.amjilt);
        context.pop();
      }
    } catch (e) {
      if (mounted) {
        showAppSnackBar(context, _parseError(e), turul: SnackTurul.aldaa);
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  String _parseError(Object e) {
    // Prefer the backend's actual message (e.g. "Мессеж илгээхэд алдаа
    // гарлаа...") over the generic fallback — the raw string-matching below
    // was matching against DioException's own toString(), which doesn't
    // include the server's response body at all.
    if (e is DioException) {
      final serverMsg = e.response?.data is Map ? e.response?.data['aldaa'] : null;
      if (serverMsg is String && serverMsg.isNotEmpty) return serverMsg;
    }
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
      body: GestureDetector(
        onTap: () => FocusScope.of(context).unfocus(),
        behavior: HitTestBehavior.opaque,
        child: Align(
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
          // Буцаж утасны алхам руу ороод дахин дарж болохгүй — мөн 2 минут хүлээнэ.
          label: _uldsenSekund > 0 ? 'Код авах ($_uldsenKhugatsaa)' : 'Код авах',
          onPressed: (_isLoading || _uldsenSekund > 0) ? null : _sendCode,
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
          onPressed: (_isLoading || _uldsenSekund > 0) ? null : _sendCode,
          child: Text(
            _uldsenSekund > 0
                ? 'Код дахин илгээх ($_uldsenKhugatsaa)'
                : 'Код дахин илгээх',
            style: const TextStyle(fontSize: 13),
          ),
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
          keyboardType: TextInputType.number,
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
          keyboardType: TextInputType.number,
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
