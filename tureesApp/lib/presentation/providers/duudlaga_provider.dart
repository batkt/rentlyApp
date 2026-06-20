import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/models/duudlaga_model.dart';
import '../../data/repositories/duudlaga_repository.dart';
import 'auth_provider.dart';

class DuudlagaState {
  final List<DuudlagaModel> items;
  final bool isLoading;
  final bool isCreating;
  final String? error;
  final int page;
  final bool hasMore;

  const DuudlagaState({
    this.items = const [],
    this.isLoading = false,
    this.isCreating = false,
    this.error,
    this.page = 1,
    this.hasMore = true,
  });

  DuudlagaState copyWith({
    List<DuudlagaModel>? items,
    bool? isLoading,
    bool? isCreating,
    String? error,
    int? page,
    bool? hasMore,
  }) {
    return DuudlagaState(
      items: items ?? this.items,
      isLoading: isLoading ?? this.isLoading,
      isCreating: isCreating ?? this.isCreating,
      error: error,
      page: page ?? this.page,
      hasMore: hasMore ?? this.hasMore,
    );
  }
}

class DuudlagaNotifier extends StateNotifier<DuudlagaState> {
  final DuudlagaRepository _repo;
  final Ref _ref;

  DuudlagaNotifier(this._repo, this._ref) : super(const DuudlagaState());

  Future<void> load({bool refresh = false}) async {
    final user = _ref.read(currentUserProvider);
    if (user == null) return;

    final page = refresh ? 1 : state.page;
    if (state.isLoading) return;

    state = state.copyWith(isLoading: true, error: null);
    try {
      final items = await _repo.getDuudlagaList(
        baiguullagiinId: user.baiguullagiinId,
        khariltsagchiinId: user.id,
        barilgiinId: user.barilgiinId,
        page: page,
      );
      state = state.copyWith(
        isLoading: false,
        items: refresh ? items : [...state.items, ...items],
        page: page + 1,
        hasMore: items.length >= 20,
      );
    } catch (e) {
      state = state.copyWith(isLoading: false, error: 'Дуудлагын жагсаалт ачаалахад алдаа гарлаа');
    }
  }

  Future<bool> create({
    required String title,
    required String message,
    String? gereeniiDugaar,
    String? talbainDugaar,
  }) async {
    final user = _ref.read(currentUserProvider);
    if (user == null) return false;

    state = state.copyWith(isCreating: true, error: null);
    try {
      final duudlaga = await _repo.createDuudlaga(
        baiguullagiinId: user.baiguullagiinId,
        khariltsagchiinId: user.id,
        barilgiinId: user.barilgiinId,
        khariltsagchiinNer: user.fullName,
        khariltsagchiinUtas: user.utas.isNotEmpty ? user.utas.first : '',
        title: title,
        message: message,
        khariltsagchiinGereeniiDugaar: gereeniiDugaar,
        khariltsagchiinTalbainDugaar: talbainDugaar,
        khariltsagchiinRegister: user.register,
      );
      state = state.copyWith(
        isCreating: false,
        items: [duudlaga, ...state.items],
      );
      return true;
    } catch (_) {
      state = state.copyWith(isCreating: false, error: 'Дуудлага үүсгэхэд алдаа гарлаа');
      return false;
    }
  }

  Future<void> cancel(String id, {String? reason}) async {
    try {
      await _repo.updateStatus(id, -1, tailbar: reason ?? 'Хэрэглэгч цуцлав');
      state = state.copyWith(
        items: state.items.map((d) => d.id == id ? d.copyWith(tuluv: -1, tailbar: reason) : d).toList(),
      );
    } catch (_) {
      state = state.copyWith(error: 'Цуцлахад алдаа гарлаа');
    }
  }
}

final duudlagaProvider = StateNotifierProvider<DuudlagaNotifier, DuudlagaState>((ref) {
  return DuudlagaNotifier(ref.read(duudlagaRepositoryProvider), ref);
});
