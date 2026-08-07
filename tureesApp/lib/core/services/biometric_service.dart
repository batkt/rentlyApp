import 'dart:io';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/services.dart';
import 'package:local_auth/local_auth.dart';

final biometricServiceProvider = Provider<BiometricService>((ref) {
  return BiometricService();
});

class BiometricService {
  final LocalAuthentication _auth = LocalAuthentication();

  Future<bool> get isAvailable async {
    try {
      final canCheck = await _auth.canCheckBiometrics;
      final isSupported = await _auth.isDeviceSupported();
      return canCheck || isSupported;
    } catch (_) {
      return false;
    }
  }

  /// True only when a face/fingerprint is actually enrolled.
  ///
  /// [isAvailable] is also true on a phone that merely has a passcode, and the
  /// "Face ID-ээр нэвтрэх" button then opened a passcode sheet instead —
  /// which is what made Face ID feel broken.
  Future<bool> get isEnrolled async {
    try {
      if (!await _auth.canCheckBiometrics) return false;
      final types = await _auth.getAvailableBiometrics();
      return types.isNotEmpty;
    } catch (_) {
      return false;
    }
  }

  Future<List<BiometricType>> get availableTypes async {
    try {
      return await _auth.getAvailableBiometrics();
    } catch (_) {
      return [];
    }
  }

  Future<bool> get isFaceAuth async {
    final types = await availableTypes;
    if (types.contains(BiometricType.face)) return true;
    if (types.contains(BiometricType.fingerprint)) return false;
    return Platform.isIOS; // fallback: Face ID on iOS, fingerprint on Android
  }

  Future<bool> authenticate() async {
    try {
      return await _auth.authenticate(
        localizedReason: 'Нэвтрэхийн тулд баталгаажуулна уу',
        options: const AuthenticationOptions(
          biometricOnly: false,
          stickyAuth: true,
          // Show the OS dialogs ("Set up Face ID", "Locked out") instead of
          // failing silently — a tap that did nothing was the whole complaint.
          useErrorDialogs: true,
        ),
      );
    } on PlatformException catch (e) {
      lastError = e.code;
      return false;
    } catch (_) {
      lastError = null;
      return false;
    }
  }

  /// `local_auth` error code of the last failed [authenticate], if any.
  String? lastError;

  Future<void> stopAuthentication() async {
    try {
      await _auth.stopAuthentication();
    } catch (_) {}
  }
}
