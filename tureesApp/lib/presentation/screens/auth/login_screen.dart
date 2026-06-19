import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_colors.dart';
import '../../../data/repositories/auth_repository.dart';
import '../../providers/auth_provider.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _phoneController = TextEditingController();
  final _passwordController = TextEditingController();

  bool _obscurePassword = true;
  bool _isCheckingPhone = false;
  bool _phoneVerified = false;
  String? _phoneError;
  List<_OrgItem> _orgs = [];
  String? _selectedOrgId;
  String _lastCheckedPhone = '';

  @override
  void dispose() {
    _phoneController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _checkPhone(String phone) async {
    if (phone.length != 8 || phone == _lastCheckedPhone) return;
    _lastCheckedPhone = phone;

    setState(() {
      _isCheckingPhone = true;
      _phoneError = null;
      _phoneVerified = false;
      _orgs = [];
      _selectedOrgId = null;
    });

    try {
      final data = await ref.read(authRepositoryProvider).verifyPhone(phone);
      if (!mounted) return;

      final exists = data['exists'] as bool? ?? false;
      if (!exists) {
        setState(() {
          _isCheckingPhone = false;
          _phoneError = 'Бүртгэлтэй хэрэглэгч олдсонгүй';
        });
        return;
      }

      final rawOrgs = (data['baiguullaguud'] as List?) ?? [];
      final orgs = rawOrgs.map((e) => _OrgItem.fromJson(e as Map<String, dynamic>)).toList();

      setState(() {
        _isCheckingPhone = false;
        _phoneVerified = true;
        _orgs = orgs;
        _selectedOrgId = orgs.length == 1 ? orgs.first.id : null;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _isCheckingPhone = false;
        _phoneError = 'Шалгах үед алдаа гарлаа';
      });
    }
  }

  Future<void> _handleLogin() async {
    if (!_formKey.currentState!.validate()) return;
    FocusScope.of(context).unfocus();

    final result = await ref.read(authStateProvider.notifier).login(
      _phoneController.text.trim(),
      _passwordController.text,
      baiguullagiinId: _selectedOrgId,
    );

    if (!mounted) return;

    switch (result) {
      case LoginResult.success:
        context.go('/home');
      case LoginResult.needsOrgSelection:
        context.push('/org-select');
      case LoginResult.error:
        break;
    }
  }

  void _resetPhone() {
    setState(() {
      _phoneController.clear();
      _passwordController.clear();
      _phoneVerified = false;
      _phoneError = null;
      _orgs = [];
      _selectedOrgId = null;
      _lastCheckedPhone = '';
    });
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authStateProvider);

    ref.listen(authStateProvider, (prev, next) {
      if (next.error != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(next.error!),
            backgroundColor: AppColors.error,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            margin: const EdgeInsets.all(16),
          ),
        );
        ref.read(authStateProvider.notifier).clearError();
      }
    });

    final showPasswordSection = _phoneVerified && (_orgs.length <= 1 || _selectedOrgId != null);
    final showOrgSelector = _phoneVerified && _orgs.length > 1 && _selectedOrgId == null;

    return Scaffold(
      backgroundColor: const Color(0xFFEDF7F5),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Form(
            key: _formKey,
            child: Column(
              children: [
                SizedBox(height: MediaQuery.sizeOf(context).height * 0.08),
                _buildHeader(),
                const SizedBox(height: 32),
                _buildCard(authState, showPasswordSection, showOrgSelector),
                const SizedBox(height: 32),
                _buildFooter(),
                const SizedBox(height: 24),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Column(
      children: [
        Container(
          width: 76,
          height: 76,
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [AppColors.primary, AppColors.primaryLight],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(22),
            boxShadow: [
              BoxShadow(
                color: AppColors.primary.withOpacity(0.35),
                blurRadius: 24,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: const Icon(Icons.apartment_rounded, color: Colors.white, size: 40),
        ),
        const SizedBox(height: 14),
        const Text(
          'Хэрэглэгчийн платформ',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: AppColors.primary,
            letterSpacing: 0.2,
          ),
        ),
      ],
    );
  }

  Widget _buildCard(AuthState authState, bool showPasswordSection, bool showOrgSelector) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(28),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.07),
            blurRadius: 30,
            offset: const Offset(0, 10),
          ),
          BoxShadow(
            color: AppColors.primary.withOpacity(0.04),
            blurRadius: 0,
            spreadRadius: 1,
          ),
        ],
      ),
      padding: const EdgeInsets.all(28),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            'Нэвтрэх',
            style: TextStyle(
              fontSize: 26,
              fontWeight: FontWeight.bold,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 6),
          const Text(
            'Та утасны дугаараа оруулан нэвтэрнэ үү.',
            style: TextStyle(
              fontSize: 13,
              color: AppColors.textSecondary,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 28),
          _buildPhoneField(),
          if (showOrgSelector) ...[
            const SizedBox(height: 16),
            _buildOrgSelector(),
          ],
          AnimatedSize(
            duration: const Duration(milliseconds: 280),
            curve: Curves.easeInOut,
            child: showPasswordSection
                ? Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const SizedBox(height: 16),
                      if (_orgs.length > 1 && _selectedOrgId != null)
                        _buildSelectedOrgChip(),
                      if (_orgs.length > 1 && _selectedOrgId != null)
                        const SizedBox(height: 12),
                      _buildPasswordField(),
                      const SizedBox(height: 24),
                      _buildLoginButton(authState),
                    ],
                  )
                : const SizedBox.shrink(),
          ),
          const SizedBox(height: 20),
          _buildDivider(),
          const SizedBox(height: 16),
          _buildResetButton(),
        ],
      ),
    );
  }

  Widget _buildPhoneField() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Утас',
          style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.textSecondary),
        ),
        const SizedBox(height: 8),
        TextFormField(
          controller: _phoneController,
          keyboardType: TextInputType.phone,
          inputFormatters: [
            FilteringTextInputFormatter.digitsOnly,
            LengthLimitingTextInputFormatter(8),
          ],
          enabled: !_phoneVerified && !_isCheckingPhone,
          style: const TextStyle(fontSize: 16, letterSpacing: 1.5, fontWeight: FontWeight.w500),
          decoration: InputDecoration(
            hintText: '12345678',
            hintStyle: const TextStyle(
              color: AppColors.textTertiary,
              letterSpacing: 0,
              fontWeight: FontWeight.normal,
            ),
            filled: true,
            fillColor: _phoneVerified
                ? const Color(0xFFE8F5F2)
                : const Color(0xFFF8FAFC),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: BorderSide.none,
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: BorderSide(
                color: _phoneVerified
                    ? AppColors.primary
                    : _phoneError != null
                        ? AppColors.error
                        : const Color(0xFFE2E8F0),
                width: 1.5,
              ),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: const BorderSide(color: AppColors.primary, width: 1.5),
            ),
            errorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: const BorderSide(color: AppColors.error, width: 1.5),
            ),
            disabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: const BorderSide(color: AppColors.primary, width: 1.5),
            ),
            prefixIcon: const Icon(Icons.phone_rounded, size: 20, color: AppColors.primary),
            suffixIcon: _isCheckingPhone
                ? const Padding(
                    padding: EdgeInsets.all(14),
                    child: SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.5,
                        color: AppColors.primary,
                      ),
                    ),
                  )
                : _phoneVerified
                    ? GestureDetector(
                        onTap: _resetPhone,
                        child: Container(
                          margin: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: AppColors.primary.withOpacity(0.1),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.close_rounded, color: AppColors.primary, size: 16),
                        ),
                      )
                    : _phoneError != null
                        ? const Padding(
                            padding: EdgeInsets.all(14),
                            child: Icon(Icons.cancel_rounded, color: AppColors.error, size: 20),
                          )
                        : null,
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
          ),
          onChanged: (val) {
            if (val.length == 8 && !_isCheckingPhone) {
              _checkPhone(val);
            } else if (val.length < 8 && (_phoneVerified || _phoneError != null)) {
              setState(() {
                _phoneVerified = false;
                _phoneError = null;
                _orgs = [];
                _selectedOrgId = null;
                _lastCheckedPhone = '';
              });
            }
          },
          validator: (v) {
            if (v == null || v.isEmpty) return 'Утасны дугаар оруулна уу';
            if (v.length < 8) return '8 оронтой дугаар оруулна уу';
            return null;
          },
        ),
        if (_phoneError != null)
          Padding(
            padding: const EdgeInsets.only(top: 6, left: 4),
            child: Row(
              children: [
                const Icon(Icons.info_outline_rounded, size: 13, color: AppColors.error),
                const SizedBox(width: 4),
                Text(
                  _phoneError!,
                  style: const TextStyle(fontSize: 12, color: AppColors.error),
                ),
              ],
            ),
          ),
      ],
    );
  }

  Widget _buildOrgSelector() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Байгууллага сонгоно уу',
          style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.textSecondary),
        ),
        const SizedBox(height: 8),
        ..._orgs.map((org) => Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: () => setState(() => _selectedOrgId = org.id),
              borderRadius: BorderRadius.circular(14),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 150),
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: _selectedOrgId == org.id
                      ? const Color(0xFFE8F5F2)
                      : const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: _selectedOrgId == org.id
                        ? AppColors.primary
                        : const Color(0xFFE2E8F0),
                    width: 1.5,
                  ),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 38,
                      height: 38,
                      decoration: BoxDecoration(
                        color: AppColors.primary.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(Icons.business_rounded, color: AppColors.primary, size: 20),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        org.ner,
                        style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.textPrimary),
                      ),
                    ),
                    AnimatedOpacity(
                      opacity: _selectedOrgId == org.id ? 1 : 0,
                      duration: const Duration(milliseconds: 150),
                      child: const Icon(Icons.check_circle_rounded, color: AppColors.primary, size: 20),
                    ),
                  ],
                ),
              ),
            ),
          ),
        )),
      ],
    );
  }

  Widget _buildSelectedOrgChip() {
    final org = _orgs.firstWhere((o) => o.id == _selectedOrgId, orElse: () => _orgs.first);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFFE8F5F2),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.primary.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          const Icon(Icons.business_rounded, size: 14, color: AppColors.primary),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              org.ner,
              style: const TextStyle(fontSize: 12, color: AppColors.primary, fontWeight: FontWeight.w600),
            ),
          ),
          GestureDetector(
            onTap: () => setState(() => _selectedOrgId = null),
            child: const Text(
              'Солих',
              style: TextStyle(fontSize: 11, color: AppColors.primary, decoration: TextDecoration.underline),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPasswordField() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Нууц үг',
          style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.textSecondary),
        ),
        const SizedBox(height: 8),
        TextFormField(
          controller: _passwordController,
          obscureText: _obscurePassword,
          autofocus: true,
          style: const TextStyle(fontSize: 16),
          decoration: InputDecoration(
            hintText: '••••••••',
            hintStyle: const TextStyle(color: AppColors.textTertiary),
            filled: true,
            fillColor: const Color(0xFFF8FAFC),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: BorderSide.none,
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: const BorderSide(color: Color(0xFFE2E8F0), width: 1.5),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: const BorderSide(color: AppColors.primary, width: 1.5),
            ),
            errorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: const BorderSide(color: AppColors.error, width: 1.5),
            ),
            prefixIcon: const Icon(Icons.lock_rounded, size: 20, color: AppColors.primary),
            suffixIcon: IconButton(
              icon: Icon(
                _obscurePassword ? Icons.visibility_rounded : Icons.visibility_off_rounded,
                size: 20,
                color: AppColors.textTertiary,
              ),
              onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
            ),
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
          ),
          onFieldSubmitted: (_) => _handleLogin(),
          validator: (v) {
            if (v == null || v.isEmpty) return 'Нууц үг оруулна уу';
            if (v.length < 4) return 'Нууц үг хэт богино байна';
            return null;
          },
        ),
      ],
    );
  }

  Widget _buildLoginButton(AuthState authState) {
    return SizedBox(
      height: 54,
      child: DecoratedBox(
        decoration: BoxDecoration(
          gradient: authState.isLoading
              ? null
              : const LinearGradient(
                  colors: [AppColors.primary, AppColors.primaryLight],
                  begin: Alignment.centerLeft,
                  end: Alignment.centerRight,
                ),
          borderRadius: BorderRadius.circular(16),
          boxShadow: authState.isLoading
              ? []
              : [
                  BoxShadow(
                    color: AppColors.primary.withOpacity(0.4),
                    blurRadius: 16,
                    offset: const Offset(0, 6),
                  ),
                ],
        ),
        child: ElevatedButton(
          onPressed: authState.isLoading ? null : _handleLogin,
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.transparent,
            shadowColor: Colors.transparent,
            foregroundColor: Colors.white,
            disabledBackgroundColor: AppColors.primaryLight,
            disabledForegroundColor: Colors.white70,
            elevation: 0,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            minimumSize: const Size(double.infinity, 54),
          ),
          child: authState.isLoading
              ? const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                    ),
                    SizedBox(width: 10),
                    Text('Уншиж байна...', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
                  ],
                )
              : const Text('Нэвтрэх', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
        ),
      ),
    );
  }

  Widget _buildDivider() {
    return Row(
      children: [
        Expanded(child: Divider(color: AppColors.divider)),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14),
          child: Text(
            'Эсвэл',
            style: TextStyle(fontSize: 12, color: AppColors.textTertiary, fontWeight: FontWeight.w500),
          ),
        ),
        Expanded(child: Divider(color: AppColors.divider)),
      ],
    );
  }

  Widget _buildResetButton() {
    return SizedBox(
      height: 52,
      child: OutlinedButton(
        onPressed: () => context.push('/reset-password'),
        style: OutlinedButton.styleFrom(
          side: const BorderSide(color: AppColors.primary, width: 1.5),
          foregroundColor: AppColors.primary,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        ),
        child: const Text(
          'Нууц үг сэргээх',
          style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
        ),
      ),
    );
  }

  Widget _buildFooter() {
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text(
              'Powered by ',
              style: TextStyle(fontSize: 12, color: AppColors.textTertiary),
            ),
            const Text(
              'ZEVTABS LLC',
              style: TextStyle(fontSize: 12, color: AppColors.primary, fontWeight: FontWeight.w700),
            ),
          ],
        ),
        const SizedBox(height: 4),
        const Text(
          'v1.0.0',
          style: TextStyle(fontSize: 11, color: AppColors.textTertiary),
        ),
      ],
    );
  }
}

class _OrgItem {
  final String id;
  final String ner;

  _OrgItem({required this.id, required this.ner});

  factory _OrgItem.fromJson(Map<String, dynamic> json) {
    return _OrgItem(
      id: json['_id']?.toString() ?? '',
      ner: json['dotoodNer']?.toString().isNotEmpty == true
          ? json['dotoodNer']!.toString()
          : json['ner']?.toString() ?? '',
    );
  }
}
