import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/models/agreement_model.dart';
import '../../data/repositories/agreement_repository.dart';
import 'auth_provider.dart';

// null = Бүгд (all), 1 = Идэвхтэй (active). Applied client-side so the
// header stats and list stay consistent across filter switches.
final agreementFilterProvider = StateProvider<int?>((ref) => 1);

final agreementsProvider = FutureProvider<List<AgreementModel>>((ref) async {
  final user = ref.watch(currentUserProvider);
  if (user == null) return [];
  final selectedBarilgiinId = ref.watch(selectedBarilgiinIdProvider);
  final repo = ref.read(agreementRepositoryProvider);
  final agreements = await repo.getAgreements(
    register: user.register ?? '',
    barilgiinId: selectedBarilgiinId.isNotEmpty ? selectedBarilgiinId : null,
    pageSize: 999999,
  );

  // Fetch the real outstanding balance per agreement via /uldegdelBodyo.
  final updated = await Future.wait(
    agreements.map((a) async {
      try {
        final uldegdel = await repo.getNiitUldegdel(a.gereeniiDugaar, a.barilgiinId);
        return a.copyWith(uldegdel: uldegdel);
      } catch (_) {
        return a;
      }
    }),
  );
  return updated;
});

final selectedAgreementProvider = StateProvider<AgreementModel?>((ref) => null);

final agreementDetailProvider = FutureProvider.family<AgreementModel?, String>((ref, id) async {
  final repo = ref.read(agreementRepositoryProvider);
  return repo.getAgreementById(id);
});

final agreementBalanceProvider = FutureProvider.family<Map<String, dynamic>, String>((ref, gereeniiDugaar) async {
  final user = ref.watch(currentUserProvider);
  if (user == null) return {};
  final repo = ref.read(agreementRepositoryProvider);
  return repo.getBalance(gereeniiDugaar, user.barilgiinId);
});

final invoiceHistoryProvider = FutureProvider.family<List<Map<String, dynamic>>, String>((ref, gereeniiId) async {
  final repo = ref.read(agreementRepositoryProvider);
  return repo.getInvoiceHistory(gereeniiId);
});

final uldegdelProvider = FutureProvider.family<Map<String, dynamic>, ({String gereeniiDugaar, String barilgiinId})>((ref, args) async {
  final repo = ref.read(agreementRepositoryProvider);
  return repo.getUldegdel(args.gereeniiDugaar, args.barilgiinId);
});

typedef NiitUldegdelArgs = ({String gereeniiDugaar, String barilgiinId});

final niitUldegdelProvider = FutureProvider.family<double, NiitUldegdelArgs>((ref, args) async {
  final repo = ref.read(agreementRepositoryProvider);
  return repo.getNiitUldegdel(args.gereeniiDugaar, args.barilgiinId);
});

final transactionHistoryProvider =
    FutureProvider.family<List<Map<String, dynamic>>, String>((ref, gereeniiId) async {
  final repo = ref.read(agreementRepositoryProvider);
  return repo.getTransactionHistory(gereeniiId);
});

/// Set of barilgiinIds that have at least one agreement for the current user.
/// Used to filter the building picker so only buildings with contracts are shown.
final barilguudWithAgreementsProvider = FutureProvider<Set<String>>((ref) async {
  final user = ref.watch(currentUserProvider);
  if (user == null) return {};
  final repo = ref.read(agreementRepositoryProvider);
  final all = await repo.getAgreements(
    register: user.register ?? '',
    pageSize: 999999,
  );
  return all.map((a) => a.barilgiinId).where((id) => id.isNotEmpty).toSet();
});

// Mutable state for zurguud (files) of the currently opened agreement
final agreementZurguudProvider = StateProvider.family<List<dynamic>, String>((ref, agreementId) => []);
