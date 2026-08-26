import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/dio_client.dart';
import '../../../core/socket/socket_service.dart';
import '../../../core/theme/app_colors.dart';
import '../../../data/models/user_model.dart';
import '../../../routing/app_router.dart';
import '../../providers/auth_provider.dart';

/// Watches whether the signed-in account still has the right to use the app
/// and ends the session with a warning when it does not.
///
/// A tenant can delete (or deactivate) an additional app user from the web
/// portal, but the phone holding that session only ever read a locally stored
/// JWT — `tokenShalgakh` checks the signature, not whether the account is
/// still there, so every ordinary request keeps answering 200 and the user
/// stayed signed in indefinitely.
///
/// This lives above the router in [TureesApp] so it applies on every screen.
/// The earlier version of this check lived in HomeScreen, which meant it was
/// torn down whenever a sub-route (гэрээ, төлбөр, чат …) was pushed on top,
/// and its dialog was built from HomeScreen's own context — the sign-out
/// redirect removed that route on the next frame, so the warning flashed and
/// vanished. Here the dialog is shown against [tureesNavKey] *before* the
/// session is dropped.
class ErkhKhamgaalagch extends ConsumerStatefulWidget {
  final Widget child;

  /// Safety net for the moments the socket cannot cover — the event was
  /// emitted while the phone was offline, or the connection is down.
  final Duration davtamj;

  const ErkhKhamgaalagch({
    super.key,
    required this.child,
    this.davtamj = const Duration(seconds: 60),
  });

  @override
  ConsumerState<ErkhKhamgaalagch> createState() => _ErkhKhamgaalagchState();
}

class _ErkhKhamgaalagchState extends ConsumerState<ErkhKhamgaalagch>
    with WidgetsBindingObserver {
  Timer? _tseag;
  /// Held rather than re-read in [dispose] — `ref` is unusable by then.
  SocketService? _sokhet;
  String? _uzegdel;
  Function(dynamic)? _uiladel;
  bool _medegdejBaina = false;
  bool _shalgaj = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    // `checkAuth` has already run in main(), so a user is normally in place by
    // the first frame — ref.listen only fires on later changes.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _khereglegchidTokhiruulya(ref.read(currentUserProvider));
    });
  }

  @override
  void dispose() {
    _tseag?.cancel();
    _sonsogchiigSalgaya();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed) return;
    final user = ref.read(currentUserProvider);
    if (user == null) return;
    // The socket sleeps while the app is backgrounded, so an account deleted
    // in the meantime is only visible by asking the server again.
    _sokhetiigSergeeye(user);
    _shalgaya();
  }

  void _khereglegchidTokhiruulya(UserModel? user) {
    _sonsogchiigSalgaya();
    _tseag?.cancel();
    _tseag = null;
    if (user == null || user.id.isEmpty) return;

    final socket = ref.read(socketServiceProvider);
    _sokhet = socket;
    _uzegdel = 'khariltsagchUstlaa${user.id}';
    _uiladel = (_) => _erkhUstsan();
    socket.on(_uzegdel!, _uiladel!);

    _tseag = Timer.periodic(widget.davtamj, (_) => _shalgaya());
    _shalgaya();
  }

  void _sonsogchiigSalgaya() {
    if (_uzegdel == null || _uiladel == null) return;
    _sokhet?.off(_uzegdel!, _uiladel!);
    _uzegdel = null;
    _uiladel = null;
  }

  Future<void> _sokhetiigSergeeye(UserModel user) async {
    final socket = ref.read(socketServiceProvider);
    await socket.ensureConnected();
    if (!mounted) return;
    socket.joinOrgRoom(user.baiguullagiinId);
    socket.joinUserRoom(user.id);
  }

  Future<void> _shalgaya() async {
    if (_medegdejBaina || _shalgaj) return;
    if (!ref.read(authStateProvider).isAuthenticated) return;
    _shalgaj = true;
    try {
      final ustsan =
          await ref.read(authStateProvider.notifier).erkhUstsanEsekhShalgaya();
      if (ustsan) await _erkhUstsan();
    } finally {
      _shalgaj = false;
    }
  }

  /// Warns, then ends the session. The order matters: [AuthNotifier.logout]
  /// flips the router to /login on the next frame, which would take the dialog
  /// with it.
  Future<void> _erkhUstsan() async {
    if (_medegdejBaina) return;
    if (!ref.read(authStateProvider).isAuthenticated) return;
    _medegdejBaina = true;
    _tseag?.cancel();
    _tseag = null;
    // Read before awaiting the dialog: `ref` is unusable if this widget goes
    // away while it is open.
    final auth = ref.read(authStateProvider.notifier);
    try {
      final ctx = tureesNavKey.currentContext;
      if (ctx != null) {
        await showDialog<void>(
          context: ctx,
          barrierDismissible: false,
          builder: (dialogCtx) => AlertDialog(
            icon: const Icon(
              Icons.no_accounts_rounded,
              color: AppColors.error,
              size: 40,
            ),
            title: const Text('Таны эрх устгагдсан байна'),
            content: const Text(
              'Таны аппликейшн ашиглах эрхийг цуцалсан байна. '
              'Дэлгэрэнгүй мэдээллийг менежерээсээ авна уу.',
              textAlign: TextAlign.center,
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogCtx),
                child: const Text('Ойлголоо'),
              ),
            ],
          ),
        );
      }
    } finally {
      // Runs even if the dialog could not be built — the session must end
      // either way.
      await auth.logout();
      _medegdejBaina = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<UserModel?>(currentUserProvider, (umnukh, odoo) {
      if (umnukh?.id == odoo?.id) return;
      _khereglegchidTokhiruulya(odoo);
    });

    // Any token-backed request answering 401 means the same thing.
    ref.listen<bool>(erkhTsutslagdsanProvider, (_, tsutslagdsan) {
      if (!tsutslagdsan) return;
      ref.read(erkhTsutslagdsanProvider.notifier).state = false;
      _erkhUstsan();
    });

    return widget.child;
  }
}
