import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/storage/secure_storage.dart';

/// Нүүр хуудсан дээрх «AI туслах» хөвөгч товч харагдах эсэх.
///
/// Товчийг доош чирж устгахад унтарна; Профайл → «AI туслах» унтраалгаар
/// буцааж асаана. Аппын бусад тохиргоотой адил secure storage-д хадгална.
class AiTuslakhIdevkhteiNotifier extends StateNotifier<bool> {
  static const _key = 'chatbot_enabled';

  final SecureStorageService _storage;

  AiTuslakhIdevkhteiNotifier(this._storage) : super(true) {
    _load();
  }

  Future<void> _load() async {
    try {
      final saved = await _storage.read(_key);
      if (saved != null && mounted) state = saved == 'true';
    } catch (_) {}
  }

  Future<void> set(bool idevkhtei) async {
    state = idevkhtei;
    try {
      await _storage.write(_key, idevkhtei.toString());
    } catch (_) {}
  }
}

final aiTuslakhIdevkhteiProvider =
    StateNotifierProvider<AiTuslakhIdevkhteiNotifier, bool>((ref) {
  return AiTuslakhIdevkhteiNotifier(ref.read(secureStorageProvider));
});

/// Хөвөгч товчийн хадгалсан байрлал. Үнэмлэхүй X-ийн оронд аль ирмэгт
/// наалдсаныг хадгална — Fold эвхэх/дэлгэх үед дэлгэцийн өргөн өөрчлөгдсөн
/// ч товч дэлгэцээс гадуур гарахгүй.
class AiTuslakhBairshil {
  final bool baruunTald;
  final double y;
  const AiTuslakhBairshil({required this.baruunTald, required this.y});
}

class AiTuslakhBairshilKhadgalagch {
  static const _baruunKey = 'chatbot_baruun_tald';
  static const _yKey = 'chatbot_pos_y';

  final SecureStorageService _storage;
  AiTuslakhBairshilKhadgalagch(this._storage);

  Future<AiTuslakhBairshil?> unshikh() async {
    try {
      final baruun = await _storage.read(_baruunKey);
      final y = double.tryParse(await _storage.read(_yKey) ?? '');
      if (baruun == null || y == null) return null;
      return AiTuslakhBairshil(baruunTald: baruun == 'true', y: y);
    } catch (_) {
      return null;
    }
  }

  Future<void> khadgalakh(AiTuslakhBairshil b) async {
    try {
      await Future.wait([
        _storage.write(_baruunKey, b.baruunTald.toString()),
        _storage.write(_yKey, b.y.toString()),
      ]);
    } catch (_) {}
  }
}

final aiTuslakhBairshilProvider = Provider<AiTuslakhBairshilKhadgalagch>((ref) {
  return AiTuslakhBairshilKhadgalagch(ref.read(secureStorageProvider));
});
