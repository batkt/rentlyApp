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
    customerTin: user.customerTin,
    gereeniiIdnuud: user.gereeniiIdnuud,
    barilgiinId: selectedBarilgiinId.isNotEmpty ? selectedBarilgiinId : null,
    pageSize: 999999,
  );
  if (agreements.isEmpty) return agreements;

  // Үлдэгдлийг `uldegdelBodyo`-оос ШУУД тооцуулна — tureesShine-ий
  // useGereeniiUldegdel-тэй ижил эх сурвалж.
  //
  // Өмнө нь сүүлийн нэхэмжлэхийн `medeelel.niitUldegdel`-ийг уншдаг байсан.
  // Тэр нь нэхэмжлэх үүсгэх мөчид хөлдөөж бичсэн тоо тул менежер turees
  // дээр төлбөр бүртгэх/дүн засахад апп дээр хэзээ ч шинэчлэгддэггүй,
  // зөвхөн ШИНЭ нэхэмжлэх үүсэхэд л өөрчлөгддөг байв. QPay төлөлт мөн
  // үүнээс болж үлдэгдлийг бууруулж харагдахгүй байсан.
  //
  // getUldegdel нь ognoo-д өнөөдрийн огноог өгдөг ба backend түүнийг сарын
  // эцэс болгож тайрдаг — веб дээрх bulkUldegdelBodyo-гийн анхны цонхтой
  // яг ижил. getNiitUldegdel дээр нь алдангийг нэмнэ.
  //
  // Сөрөг утгыг 0 болгож дарахгүй: илүү төлсөн үед түрээслэгч өөрийн
  // кредитээ харах ёстой. AppFormatters.balance сөрөг дүнг "-X₮" гэж,
  // balanceColor ногооноор зөв үзүүлдэг.
  final results = await Future.wait(agreements.map((a) async {
    try {
      final niitUldegdel = await repo.getNiitUldegdel(
        a.gereeniiDugaar,
        a.barilgiinId,
      );
      return a.copyWith(uldegdel: niitUldegdel);
    } catch (_) {
      return a;
    }
  }));
  return results;
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

/// One нэхэмжлэх together with the contract it belongs to.
typedef NekhemjlekhBichlegT = ({
  AgreementModel agreement,
  Map<String, dynamic> invoice,
  DateTime? ognoo,
});

/// Every contract's invoices in one list, newest first. A tenant with a dozen
/// contracts had to open each one separately to see what was billed.
final bukhNekhemjlekhProvider = FutureProvider<List<NekhemjlekhBichlegT>>((ref) async {
  final agreements = await ref.watch(agreementsProvider.future);
  if (agreements.isEmpty) return [];
  final repo = ref.read(agreementRepositoryProvider);

  final perAgreement = await Future.wait(agreements.map((agreement) async {
    try {
      final list = await repo.getInvoiceHistory(agreement.id);
      return list.map((inv) {
        final raw = (inv['nekhemjlekhiinOgnoo'] ?? inv['createdAt'])?.toString();
        return (
          agreement: agreement,
          invoice: inv,
          ognoo: raw == null ? null : DateTime.tryParse(raw),
        );
      }).toList();
    } catch (_) {
      // One unreachable contract must not blank out the whole list.
      return <NekhemjlekhBichlegT>[];
    }
  }));

  final bukh = perAgreement.expand((e) => e).toList();
  bukh.sort((a, b) {
    final ad = a.ognoo, bd = b.ognoo;
    if (ad == null && bd == null) return 0;
    if (ad == null) return 1;
    if (bd == null) return -1;
    return bd.compareTo(ad);
  });
  return bukh;
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

  // Contracts linked from the dashboard are authoritative — the buildings
  // they live in are exactly the ones this user should be able to switch to.
  if (user.gereeniiIdnuud.isNotEmpty) {
    final linked = await repo.getAgreements(
      register: '',
      gereeniiIdnuud: user.gereeniiIdnuud,
      pageSize: 999999,
    );
    return linked.map((a) => a.barilgiinId).where((id) => id.isNotEmpty).toSet();
  }

  // Fetch agreements by phone number (primaryPhone) as requested: "check by utasniiDugaar"
  final all = await repo.getAgreements(
    register: user.primaryPhone.isNotEmpty ? user.primaryPhone : (user.register ?? ''),
    customerTin: user.customerTin,
    pageSize: 999999,
  );
  final allByReg = await repo.getAgreements(
    register: user.register ?? '',
    customerTin: user.customerTin,
    pageSize: 999999,
  );
  final combined = {...all, ...allByReg};
  return combined.map((a) => a.barilgiinId).where((id) => id.isNotEmpty).toSet();
});

// Mutable state for zurguud (files) of the currently opened agreement
final agreementZurguudProvider = StateProvider.family<List<dynamic>, String>((ref, agreementId) => []);
