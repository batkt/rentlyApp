import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/app_snackbar.dart';
import '../../../data/repositories/auth_repository.dart';
import '../../widgets/common/app_button.dart';
import '../../widgets/common/app_text_field.dart';

/// Тохиргоо → "Нууц үг солих". Нэвтэрсэн хэрэглэгч SMS кодгүйгээр хуучин
/// нууц үгээ оруулж солино. Нууц үгээ мартсан бол нэвтрэх дэлгэцийн
/// сэргээх урсгалыг (ResetPasswordScreen) ашиглана.
class ChangePasswordScreen extends ConsumerStatefulWidget {
  const ChangePasswordScreen({super.key});

  @override
  ConsumerState<ChangePasswordScreen> createState() => _ChangePasswordScreenState();
}

class _ChangePasswordScreenState extends ConsumerState<ChangePasswordScreen> {
  final _khuuchinController = TextEditingController();
  final _shineController = TextEditingController();
  final _davtakhController = TextEditingController();

  bool _nuukhKhuuchin = true;
  bool _nuukhShine = true;
  bool _nuukhDavtakh = true;
  bool _isLoading = false;

  @override
  void dispose() {
    _khuuchinController.dispose();
    _shineController.dispose();
    _davtakhController.dispose();
    super.dispose();
  }

  Future<void> _khadgalya() async {
    final khuuchin = _khuuchinController.text;
    final shine = _shineController.text;
    final davtakh = _davtakhController.text;
    if (khuuchin.isEmpty) {
      showAppSnackBar(context, 'Хуучин нууц үгээ оруулна уу', turul: SnackTurul.aldaa);
      return;
    }
    if (shine.length < 4) {
      showAppSnackBar(context, 'Хамгийн багадаа 4 тэмдэгт оруулна уу', turul: SnackTurul.aldaa);
      return;
    }
    if (shine != davtakh) {
      showAppSnackBar(context, 'Шинэ нууц үг таарахгүй байна', turul: SnackTurul.aldaa);
      return;
    }
    FocusScope.of(context).unfocus();
    setState(() => _isLoading = true);
    try {
      await ref.read(authRepositoryProvider).changePassword(khuuchin, shine);
      if (mounted) {
        showAppSnackBar(context, 'Нууц үг амжилттай солигдлоо', turul: SnackTurul.amjilt);
        context.pop();
      }
    } catch (e) {
      if (mounted) showAppSnackBar(context, _aldaaUnshya(e), turul: SnackTurul.aldaa);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  String _aldaaUnshya(Object e) {
    if (e is DioException) {
      final serverMsg = e.response?.data is Map ? e.response?.data['aldaa'] : null;
      if (serverMsg is String && serverMsg.isNotEmpty) return serverMsg;
    }
    return 'Алдаа гарлаа. Дахин оролдоно уу';
  }

  Widget _nuutsUgTalbar({
    required String label,
    required TextEditingController controller,
    required bool nuukh,
    required VoidCallback onToggle,
  }) {
    return AppTextField(
      label: label,
      hint: '••••••••',
      controller: controller,
      obscureText: nuukh,
      keyboardType: TextInputType.number,
      prefixIcon: const Icon(Icons.lock_rounded, size: 18, color: AppColors.textTertiary),
      suffixIcon: IconButton(
        icon: Icon(
          nuukh ? Icons.visibility_rounded : Icons.visibility_off_rounded,
          size: 18,
          color: AppColors.textTertiary,
        ),
        onPressed: onToggle,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Нууц үг солих')),
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
                  _nuutsUgTalbar(
                    label: 'Хуучин нууц үг',
                    controller: _khuuchinController,
                    nuukh: _nuukhKhuuchin,
                    onToggle: () => setState(() => _nuukhKhuuchin = !_nuukhKhuuchin),
                  ),
                  const SizedBox(height: 16),
                  _nuutsUgTalbar(
                    label: 'Шинэ нууц үг',
                    controller: _shineController,
                    nuukh: _nuukhShine,
                    onToggle: () => setState(() => _nuukhShine = !_nuukhShine),
                  ),
                  const SizedBox(height: 16),
                  _nuutsUgTalbar(
                    label: 'Шинэ нууц үг давтах',
                    controller: _davtakhController,
                    nuukh: _nuukhDavtakh,
                    onToggle: () => setState(() => _nuukhDavtakh = !_nuukhDavtakh),
                  ),
                  const SizedBox(height: 28),
                  AppButton(
                    label: 'Хадгалах',
                    onPressed: _isLoading ? null : _khadgalya,
                    isLoading: _isLoading,
                    icon: Icons.save_rounded,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
