import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/models/agreement_model.dart';
import '../../data/repositories/agreement_repository.dart';
import 'auth_provider.dart';

final agreementFilterProvider = StateProvider<int?>((ref) => 1);

final agreementsProvider = FutureProvider<List<AgreementModel>>((ref) async {
  final user = ref.watch(currentUserProvider);
  if (user == null) return [];
  final filter = ref.watch(agreementFilterProvider);
  final repo = ref.read(agreementRepositoryProvider);
  final agreements = await repo.getAgreements(register: user.register ?? '', tuluv: filter);

  // Fetch real-time uldegdel from /uldegdelBodyo for each agreement in parallel
  final updated = await Future.wait(
    agreements.map((a) async {
      try {
        final data = await repo.getUldegdel(a.gereeniiDugaar, a.barilgiinId);
        final uldegdel = (data['uldegdel'] as num?)?.toDouble() ?? a.uldegdel;
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
