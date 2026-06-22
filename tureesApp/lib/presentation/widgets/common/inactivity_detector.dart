import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../providers/auth_provider.dart';

/// Logs the user out after [timeout] of no interaction. Any touch resets the
/// countdown; the timer is a no-op while unauthenticated (e.g. on /login).
class InactivityDetector extends ConsumerStatefulWidget {
  final Widget child;
  final Duration timeout;

  const InactivityDetector({
    super.key,
    required this.child,
    this.timeout = const Duration(minutes: 15),
  });

  @override
  ConsumerState<InactivityDetector> createState() => _InactivityDetectorState();
}

class _InactivityDetectorState extends ConsumerState<InactivityDetector> {
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _reset();
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _reset([_]) {
    _timer?.cancel();
    _timer = Timer(widget.timeout, _onTimeout);
  }

  void _onTimeout() {
    if (ref.read(authStateProvider).isAuthenticated) {
      ref.read(authStateProvider.notifier).logout();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Listener(
      behavior: HitTestBehavior.translucent,
      onPointerDown: _reset,
      onPointerMove: _reset,
      onPointerSignal: _reset,
      child: widget.child,
    );
  }
}
