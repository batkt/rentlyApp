import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/services/biometric_service.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/storage/secure_storage.dart';
import '../../../data/repositories/auth_repository.dart';
import '../../providers/auth_provider.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen>
    with SingleTickerProviderStateMixin {
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

  bool _canUseBiometric = false;
  bool _isBiometricLoading = false;
  bool _isFaceAuth = false;
  String _savedPhone = '';
  bool _biometricEnabled = false;
  bool _hasSavedToken = false;
  bool _showBiometricLoginButton = false;

  late AnimationController _fadeController;
  late Animation<double> _fadeAnim;

  @override
  void initState() {
    super.initState();
    _fadeController = AnimationController(vsync: this, duration: const Duration(milliseconds: 600));
    _fadeAnim = CurvedAnimation(parent: _fadeController, curve: Curves.easeOut);
    _fadeController.forward();
    _initBiometric();
  }

  Future<void> _initBiometric() async {
    final bio = ref.read(biometricServiceProvider);
    final storage = ref.read(secureStorageProvider);
    final available = await bio.isAvailable;
    final enabled = await storage.isBiometricEnabled();
    final hasToken = await storage.isLoggedIn();
    final savedPhone = await storage.read('utas');
    final faceAuth = available ? await bio.isFaceAuth : false;
    if (!mounted) return;
    setState(() {
      _savedPhone = savedPhone ?? '';
      _biometricEnabled = enabled && available;
      _hasSavedToken = hasToken;
      _canUseBiometric = available && hasToken;
      _isFaceAuth = faceAuth;
    });
    // Auto-trigger biometric if previously enabled and token exists
    if (available && enabled && hasToken) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _doBiometricLogin());
    }
  }

  Future<void> _doBiometricLogin() async {
    setState(() => _isBiometricLoading = true);
    final success = await ref.read(authStateProvider.notifier).loginWithBiometric();
    if (!mounted) return;
    setState(() => _isBiometricLoading = false);
    if (success) context.go('/home');
  }

  @override
  void dispose() {
    _phoneController.dispose();
    _passwordController.dispose();
    _fadeController.dispose();
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
        // Show biometric icon next to login button if this phone has biometric set up
        _showBiometricLoginButton = _biometricEnabled && _hasSavedToken && phone == _savedPhone;
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

    if (result == LoginResult.success) {
      // Save the selected org's buildings so the dashboard can show a selector
      final org = _orgs.isEmpty
          ? null
          : (_selectedOrgId != null
              ? _orgs.firstWhere((o) => o.id == _selectedOrgId, orElse: () => _orgs.first)
              : _orgs.first);
      if (org != null && org.barilguud.isNotEmpty) {
        final json = jsonEncode(org.barilguud.map((b) => {'id': b.id, 'ner': b.ner}).toList());
        await ref.read(secureStorageProvider).saveBuildings(json);
        await ref.read(authStateProvider.notifier).reloadBarilguud();
      }
      await _offerBiometricSetup();
      if (mounted) context.go('/home');
    } else if (result == LoginResult.needsOrgSelection) {
      context.push('/org-select');
    }
  }

  Future<void> _offerBiometricSetup() async {
    final bio = ref.read(biometricServiceProvider);
    final storage = ref.read(secureStorageProvider);
    final available = await bio.isAvailable;
    final alreadyEnabled = await storage.isBiometricEnabled();
    if (!available || alreadyEnabled || !mounted) return;

    final face = await ref.read(biometricServiceProvider).isFaceAuth;
    final icon = face ? Icons.face_rounded : Icons.fingerprint_rounded;
    final label = face ? 'Face ID' : 'Хурууны хээ';
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Icon(icon, color: AppColors.primary),
            const SizedBox(width: 10),
            Expanded(child: Text('$label идэвхжүүлэх')),
          ],
        ),
        content: Text('Дараагаас $label / хурууны хээгээр хурдан нэвтрэх үү?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Үгүй')),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Тийм'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    // Confirm with an actual face/fingerprint scan before enabling.
    final ok = await bio.authenticate();
    if (!ok) return;
    await ref.read(authStateProvider.notifier).enableBiometric();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('$label амжилттай идэвхжлээ'),
        backgroundColor: AppColors.success,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.all(16),
      ),
    );
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
      _showBiometricLoginButton = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final authState = ref.watch(authStateProvider);

    ref.listen(authStateProvider, (_, next) {
      if (next.error != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(next.error!),
            backgroundColor: AppColors.error,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            margin: const EdgeInsets.all(16),
          ),
        );
        ref.read(authStateProvider.notifier).clearError();
      }
    });

    final showPasswordSection = _phoneVerified && (_orgs.length <= 1 || _selectedOrgId != null);
    final showOrgSelector = _phoneVerified && _orgs.length > 1 && _selectedOrgId == null;

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF0D1514) : const Color(0xFFEDF7F5),
      body: GestureDetector(
        onTap: () => FocusScope.of(context).unfocus(),
        behavior: HitTestBehavior.opaque,
        child: SafeArea(
        child: FadeTransition(
          opacity: _fadeAnim,
          child: Align(
            alignment: Alignment.topCenter,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 520),
              child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Form(
              key: _formKey,
              child: Column(
                children: [
                  SizedBox(height: MediaQuery.sizeOf(context).height * 0.07),
                  _buildHeader(isDark),
                  const SizedBox(height: 28),
                  _buildCard(context, isDark, authState, showPasswordSection, showOrgSelector),
                  if (_canUseBiometric && !_showBiometricLoginButton) ...[
                    const SizedBox(height: 20),
                    _buildBiometricButton(isDark),
                  ],
                  const SizedBox(height: 24),
                  _buildFooter(isDark),
                  const SizedBox(height: 24),
                ],
              ),
            ),
          ),
            ),
          ),
        ),
        ),
      ),
    );
  }

  Widget _buildHeader(bool isDark) {
    return Column(
      children: [
        Container(
          width: 80,
          height: 80,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(24),
            boxShadow: [
              BoxShadow(
                color: AppColors.primary.withOpacity(0.35),
                blurRadius: 28,
                offset: const Offset(0, 12),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(24),
            child: Image.asset(
              'assets/images/rently.png',
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => Container(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    colors: [AppColors.primary, AppColors.primaryLight],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                ),
                child: const Icon(Icons.apartment_rounded, color: Colors.white, size: 42),
              ),
            ),
          ),
        ),
        const SizedBox(height: 16),
        Text(
          'Rently',
          style: TextStyle(
            fontSize: 28,
            fontWeight: FontWeight.w800,
            color: isDark ? Colors.white : AppColors.primary,
            letterSpacing: -0.5,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          'Түрээсийн удирдлагын систем',
          style: TextStyle(
            fontSize: 13,
            color: isDark ? const Color(0xFF94A3B8) : AppColors.textSecondary,
          ),
        ),
      ],
    );
  }

  Widget _buildCard(BuildContext context, bool isDark, AuthState authState,
      bool showPasswordSection, bool showOrgSelector) {
    return Container(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1A2826) : Colors.white,
        borderRadius: BorderRadius.circular(28),
        border: isDark ? Border.all(color: const Color(0xFF2D3B39)) : null,
        boxShadow: isDark
            ? []
            : [
                BoxShadow(
                  color: Colors.black.withOpacity(0.07),
                  blurRadius: 30,
                  offset: const Offset(0, 10),
                ),
              ],
      ),
      padding: const EdgeInsets.all(28),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Нэвтрэх',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.w800,
              color: isDark ? Colors.white : AppColors.textPrimary,
              letterSpacing: -0.3,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Утасны дугаараа оруулан нэвтэрнэ үү.',
            style: TextStyle(
              fontSize: 13,
              color: isDark ? const Color(0xFF64748B) : AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 28),
          _buildPhoneField(isDark),
          if (showOrgSelector) ...[
            const SizedBox(height: 16),
            _buildOrgSelector(isDark),
          ],
          AnimatedSize(
            duration: const Duration(milliseconds: 280),
            curve: Curves.easeInOut,
            child: showPasswordSection
                ? Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const SizedBox(height: 16),
                      if (_orgs.length > 1 && _selectedOrgId != null) ...[
                        _buildSelectedOrgChip(isDark),
                        const SizedBox(height: 12),
                      ],
                      _buildPasswordField(isDark),
                      const SizedBox(height: 24),
                      Row(
                        children: [
                          Expanded(child: _buildLoginButton(authState)),
                          if (_showBiometricLoginButton) ...[
                            const SizedBox(width: 10),
                            _buildBiometricIconButton(isDark),
                          ],
                        ],
                      ),
                    ],
                  )
                : const SizedBox.shrink(),
          ),
          const SizedBox(height: 20),
          _buildDivider(isDark),
          const SizedBox(height: 16),
          _buildResetButton(isDark),
        ],
      ),
    );
  }

  Widget _buildPhoneField(bool isDark) {
    final bg = isDark ? const Color(0xFF111918) : const Color(0xFFF8FAFC);
    final verifiedBg = isDark ? const Color(0xFF1A3D37) : const Color(0xFFE8F5F2);
    final enabledBorder = isDark ? const Color(0xFF2D3B39) : const Color(0xFFE2E8F0);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Утасны дугаар',
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: isDark ? const Color(0xFF94A3B8) : AppColors.textSecondary,
          ),
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
          style: TextStyle(
            fontSize: 16,
            letterSpacing: 2,
            fontWeight: FontWeight.w600,
            color: isDark ? Colors.white : AppColors.textPrimary,
          ),
          decoration: InputDecoration(
            hintText: '1234 5678',
            hintStyle: TextStyle(
              color: isDark ? const Color(0xFF475569) : AppColors.textTertiary,
              letterSpacing: 0,
              fontWeight: FontWeight.normal,
            ),
            filled: true,
            fillColor: _phoneVerified ? verifiedBg : bg,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: BorderSide(
                color: _phoneVerified ? AppColors.primary : _phoneError != null ? AppColors.error : enabledBorder,
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
                      child: CircularProgressIndicator(strokeWidth: 2.5, color: AppColors.primary),
                    ),
                  )
                : _phoneVerified
                    ? GestureDetector(
                        onTap: _resetPhone,
                        child: Container(
                          margin: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: AppColors.primary.withOpacity(0.12),
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
                Text(_phoneError!, style: const TextStyle(fontSize: 12, color: AppColors.error)),
              ],
            ),
          ),
      ],
    );
  }

  Widget _buildOrgSelector(bool isDark) {
    final bg = isDark ? const Color(0xFF111918) : const Color(0xFFF8FAFC);
    final selectedBg = isDark ? const Color(0xFF1A3D37) : const Color(0xFFE8F5F2);
    final border = isDark ? const Color(0xFF2D3B39) : const Color(0xFFE2E8F0);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Байгууллага сонгоно уу',
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: isDark ? const Color(0xFF94A3B8) : AppColors.textSecondary,
          ),
        ),
        const SizedBox(height: 8),
        ..._orgs.map((org) => Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: InkWell(
            onTap: () => setState(() => _selectedOrgId = org.id),
            borderRadius: BorderRadius.circular(14),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: _selectedOrgId == org.id ? selectedBg : bg,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: _selectedOrgId == org.id ? AppColors.primary : border,
                  width: 1.5,
                ),
              ),
              child: Row(
                children: [
                  Container(
                    width: 38,
                    height: 38,
                    decoration: BoxDecoration(
                      color: AppColors.primary.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.business_rounded, color: AppColors.primary, size: 20),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      org.ner,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: isDark ? Colors.white : AppColors.textPrimary,
                      ),
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
        )),
      ],
    );
  }

  Widget _buildSelectedOrgChip(bool isDark) {
    final org = _orgs.firstWhere((o) => o.id == _selectedOrgId, orElse: () => _orgs.first);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1A3D37) : const Color(0xFFE8F5F2),
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

  Widget _buildPasswordField(bool isDark) {
    final bg = isDark ? const Color(0xFF111918) : const Color(0xFFF8FAFC);
    final border = isDark ? const Color(0xFF2D3B39) : const Color(0xFFE2E8F0);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Нууц үг',
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: isDark ? const Color(0xFF94A3B8) : AppColors.textSecondary,
          ),
        ),
        const SizedBox(height: 8),
        TextFormField(
          controller: _passwordController,
          obscureText: _obscurePassword,
          autofocus: true,
          style: TextStyle(
            fontSize: 16,
            color: isDark ? Colors.white : AppColors.textPrimary,
          ),
          decoration: InputDecoration(
            hintText: '••••••••',
            hintStyle: TextStyle(
              color: isDark ? const Color(0xFF475569) : AppColors.textTertiary,
            ),
            filled: true,
            fillColor: bg,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: BorderSide(color: border, width: 1.5),
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
                color: isDark ? const Color(0xFF64748B) : AppColors.textTertiary,
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
                  colors: [AppColors.primaryDark, AppColors.primary, AppColors.primaryLight],
                  begin: Alignment.centerLeft,
                  end: Alignment.centerRight,
                ),
          color: authState.isLoading ? AppColors.primaryLight : null,
          borderRadius: BorderRadius.circular(16),
          boxShadow: authState.isLoading
              ? []
              : [
                  BoxShadow(
                    color: AppColors.primary.withOpacity(0.4),
                    blurRadius: 18,
                    offset: const Offset(0, 7),
                  ),
                ],
        ),
        child: ElevatedButton(
          onPressed: authState.isLoading ? null : _handleLogin,
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.transparent,
            shadowColor: Colors.transparent,
            foregroundColor: Colors.white,
            disabledBackgroundColor: Colors.transparent,
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
                    Text('Нэвтэрч байна...', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
                  ],
                )
              : const Text('Нэвтрэх', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
        ),
      ),
    );
  }

  // Square icon button shown next to the login button when biometric is available.
  Widget _buildBiometricIconButton(bool isDark) {
    final icon = _isFaceAuth ? Icons.face_rounded : Icons.fingerprint_rounded;
    return SizedBox(
      width: 54,
      height: 54,
      child: GestureDetector(
        onTap: _isBiometricLoading ? null : _handleBiometricLoginInstead,
        child: Container(
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF1A2826) : Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.primary, width: 1.5),
            boxShadow: isDark
                ? []
                : [BoxShadow(color: Colors.black.withOpacity(0.06), blurRadius: 10, offset: const Offset(0, 4))],
          ),
          child: _isBiometricLoading
              ? const Center(
                  child: SizedBox(
                    width: 20, height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2.5, color: AppColors.primary),
                  ),
                )
              : Icon(icon, color: AppColors.primary, size: 28),
        ),
      ),
    );
  }

  Future<void> _handleBiometricLoginInstead() async {
    setState(() => _isBiometricLoading = true);
    final success = await ref.read(authStateProvider.notifier).loginWithBiometric();
    if (!mounted) return;
    setState(() => _isBiometricLoading = false);
    if (success) {
      context.go('/home');
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(_isFaceAuth
              ? 'Face ID амжилтгүй. Нууц үгийг оруулна уу.'
              : 'Хурууны хээ амжилтгүй. Нууц үгийг оруулна уу.'),
          backgroundColor: AppColors.warning,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          margin: const EdgeInsets.all(16),
        ),
      );
    }
  }

  Widget _buildBiometricButton(bool isDark) {
    final icon = _isFaceAuth ? Icons.face_rounded : Icons.fingerprint_rounded;
    final label = _isFaceAuth ? 'Face ID-ээр нэвтрэх' : 'Хурууны хээгээр нэвтрэх';

    return Column(
      children: [
        Row(
          children: [
            Expanded(child: Divider(color: isDark ? const Color(0xFF2D3B39) : AppColors.divider)),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14),
              child: Text(
                'Эсвэл',
                style: TextStyle(
                  fontSize: 12,
                  color: isDark ? const Color(0xFF475569) : AppColors.textTertiary,
                ),
              ),
            ),
            Expanded(child: Divider(color: isDark ? const Color(0xFF2D3B39) : AppColors.divider)),
          ],
        ),
        const SizedBox(height: 16),
        GestureDetector(
          onTap: _isBiometricLoading ? null : _doBiometricLogin,
          child: Container(
            height: 56,
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF1A2826) : Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.primary.withOpacity(0.4), width: 1.5),
              boxShadow: isDark
                  ? []
                  : [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.05),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ],
            ),
            child: _isBiometricLoading
                ? const Center(
                    child: SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(strokeWidth: 2.5, color: AppColors.primary),
                    ),
                  )
                : Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(icon, color: AppColors.primary, size: 26),
                      const SizedBox(width: 10),
                      Text(
                        label,
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: AppColors.primary,
                        ),
                      ),
                    ],
                  ),
          ),
        ),
      ],
    );
  }

  Widget _buildDivider(bool isDark) {
    return Row(
      children: [
        Expanded(child: Divider(color: isDark ? const Color(0xFF2D3B39) : AppColors.divider)),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14),
          child: Text(
            'Эсвэл',
            style: TextStyle(
              fontSize: 12,
              color: isDark ? const Color(0xFF475569) : AppColors.textTertiary,
            ),
          ),
        ),
        Expanded(child: Divider(color: isDark ? const Color(0xFF2D3B39) : AppColors.divider)),
      ],
    );
  }

  Widget _buildResetButton(bool isDark) {
    return SizedBox(
      height: 52,
      child: OutlinedButton(
        onPressed: () {
          final phone = _phoneController.text.trim();
          if (phone.isEmpty) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Утасны дугаараа оруулна уу'),
                backgroundColor: AppColors.warning,
              ),
            );
            return;
          }
          context.push('/reset-password', extra: phone);
        },
        style: OutlinedButton.styleFrom(
          side: BorderSide(
            color: isDark ? const Color(0xFF2D3B39) : AppColors.primary,
            width: 1.5,
          ),
          foregroundColor: AppColors.primary,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        ),
        child: const Text('Нууц үг сэргээх', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
      ),
    );
  }

  Widget _buildFooter(bool isDark) {
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              'Powered by ',
              style: TextStyle(
                fontSize: 12,
                color: isDark ? const Color(0xFF475569) : AppColors.textTertiary,
              ),
            ),
            Text(
              'ZEVTABS LLC',
              style: TextStyle(
                fontSize: 12,
                color: isDark ? AppColors.primaryLight : AppColors.primary,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          'v3.0.0',
          style: TextStyle(
            fontSize: 11,
            color: isDark ? const Color(0xFF334155) : AppColors.textTertiary,
          ),
        ),
      ],
    );
  }
}

class _OrgItem {
  final String id;
  final String ner;
  final List<({String id, String ner})> barilguud;

  _OrgItem({required this.id, required this.ner, this.barilguud = const []});

  factory _OrgItem.fromJson(Map<String, dynamic> json) {
    final rawBarilguud = json['barilguud'] as List? ?? [];
    return _OrgItem(
      id: json['_id']?.toString() ?? '',
      ner: json['dotoodNer']?.toString().isNotEmpty == true
          ? json['dotoodNer']!.toString()
          : json['ner']?.toString() ?? '',
      barilguud: rawBarilguud
          .map((b) => (id: b['_id']?.toString() ?? '', ner: b['ner']?.toString() ?? ''))
          .where((b) => b.id.isNotEmpty)
          .toList(),
    );
  }
}
