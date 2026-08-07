import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/models/mashin_model.dart';
import '../../data/repositories/mashin_repository.dart';
import 'auth_provider.dart';

export '../../data/repositories/mashin_repository.dart' show mashinRepositoryProvider;

/// Organisations that keep their own vehicle registry — the web app hides the
/// Машин бүртгэл card for them (`MASHIN_BURTGEL_HADGALTAI_BAIGUULLAGUUD` in
/// `app/(dashboard)/settings/page.tsx`), so the app hides it too.
const _mashinBurtgelHadgaltaiBaiguullaguud = <String>{
  '63c0f31efe522048bf02086d',
};

final mashinBurtgelKharuulakhProvider = Provider<bool>((ref) {
  final user = ref.watch(currentUserProvider);
  if (user == null) return false;
  return !_mashinBurtgelHadgaltaiBaiguullaguud.contains(user.baiguullagiinId);
});

final mashinuudProvider = FutureProvider<List<MashinModel>>((ref) async {
  final user = ref.watch(currentUserProvider);
  if (user == null) return [];
  final register = user.register ?? '';
  if (register.isEmpty) return [];
  return ref.read(mashinRepositoryProvider).getMashinuud(
        baiguullagiinId: user.baiguullagiinId,
        register: register,
      );
});
