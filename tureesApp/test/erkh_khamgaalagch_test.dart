import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:Rently/core/network/dio_client.dart';
import 'package:Rently/core/socket/socket_service.dart';
import 'package:Rently/core/storage/secure_storage.dart';
import 'package:Rently/data/models/user_model.dart';
import 'package:Rently/data/repositories/auth_repository.dart';
import 'package:Rently/presentation/providers/auth_provider.dart';
import 'package:Rently/presentation/widgets/common/erkh_khamgaalagch.dart';
import 'package:Rently/routing/app_router.dart';

/// A tenant deleting an additional app user from the web portal has to end
/// that user's session. It never did: the token stayed on the phone and
/// `tokenShalgakh` only checks the signature, so the app kept working until
/// the user signed out by hand and hit "Бүртгэлтэй хэрэглэгч олдсонгүй".
void main() {
  const khereglegch = UserModel(
    id: 'kh1',
    ner: 'Болд',
    ovog: 'Дорж',
    utas: ['99119911'],
    baiguullagiinId: 'b1',
    barilgiinId: 'br1',
    zochinTurul: 'turees',
  );

  late _KhuurmagStorage storage;
  late _KhuurmagRepo repo;
  late _KhuurmagSocket socket;

  setUp(() {
    storage = _KhuurmagStorage();
    repo = _KhuurmagRepo(storage, khereglegch);
    socket = _KhuurmagSocket(storage);
  });

  Future<ProviderContainer> pumpKhamgaalagch(WidgetTester tester) async {
    final container = ProviderContainer(overrides: [
      secureStorageProvider.overrideWithValue(storage),
      authRepositoryProvider.overrideWithValue(repo),
      socketServiceProvider.overrideWithValue(socket),
    ]);
    addTearDown(container.dispose);
    await container.read(authStateProvider.notifier).checkAuth();
    expect(container.read(authStateProvider).isAuthenticated, isTrue);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          navigatorKey: tureesNavKey,
          builder: (_, child) => ErkhKhamgaalagch(child: child!),
          home: const Scaffold(body: Text('нүүр')),
        ),
      ),
    );
    await tester.pumpAndSettle();
    return container;
  }

  final ankhaaruulga = find.text('Таны эрх устгагдсан байна');

  testWidgets('Сокетоор устгасан мэдэгдэл ирэхэд анхааруулга гарч, гаргана',
      (tester) async {
    final container = await pumpKhamgaalagch(tester);
    expect(ankhaaruulga, findsNothing, reason: 'эрх нь бүрэн байхад юу ч гарахгүй');

    socket.duudya('khariltsagchUstlaa${khereglegch.id}');
    await tester.pumpAndSettle();

    expect(ankhaaruulga, findsOneWidget);
    expect(container.read(authStateProvider).isAuthenticated, isTrue,
        reason: 'анхааруулгыг уншиж амжтал сессийг таслахгүй');

    await tester.tap(find.text('Ойлголоо'));
    await tester.pumpAndSettle();

    expect(container.read(authStateProvider).isAuthenticated, isFalse);
    expect(storage.tsevrsen, isTrue, reason: 'хадгалсан токен устах ёстой');
    expect(socket.salsan, isTrue);
  });

  testWidgets('Сокет ажиллаагүй ч сервер шалгалт хэрэглэгчийг гаргана',
      (tester) async {
    repo.tuluv = KhereglegchiinTuluv.ustsan;
    final container = await pumpKhamgaalagch(tester);

    expect(ankhaaruulga, findsOneWidget);

    await tester.tap(find.text('Ойлголоо'));
    await tester.pumpAndSettle();
    expect(container.read(authStateProvider).isAuthenticated, isFalse);
  });

  testWidgets('Токен 401 буцаахад ч гаргана', (tester) async {
    final container = await pumpKhamgaalagch(tester);

    container.read(erkhTsutslagdsanProvider.notifier).state = true;
    await tester.pumpAndSettle();

    expect(ankhaaruulga, findsOneWidget);
    await tester.tap(find.text('Ойлголоо'));
    await tester.pumpAndSettle();
    expect(container.read(authStateProvider).isAuthenticated, isFalse);
  });

  testWidgets('Сүлжээ тасарсан үед хэрэглэгчийг гаргахгүй', (tester) async {
    repo.tuluv = KhereglegchiinTuluv.todorkhoigui;
    final container = await pumpKhamgaalagch(tester);

    expect(ankhaaruulga, findsNothing);
    expect(container.read(authStateProvider).isAuthenticated, isTrue);
  });
}

class _KhuurmagStorage extends SecureStorageService {
  bool tsevrsen = false;

  @override
  Future<bool> isLoggedIn() async => !tsevrsen;

  @override
  Future<String?> getToken() async => tsevrsen ? null : 'token';

  @override
  Future<void> clearAll() async => tsevrsen = true;

  @override
  Future<String?> getBuildings() async => null;

  @override
  Future<void> saveBuildings(String json) async {}

  @override
  Future<void> write(String key, String value) async {}

  @override
  Future<String?> read(String key) async => null;
}

class _KhuurmagRepo extends AuthRepository {
  _KhuurmagRepo(SecureStorageService storage, this._khereglegch)
      : super(DioClient(storage));

  final UserModel _khereglegch;
  KhereglegchiinTuluv tuluv = KhereglegchiinTuluv.baina;

  @override
  Future<UserModel?> getUserByToken() async => _khereglegch;

  @override
  Future<KhereglegchiinTuluv> khereglegchShalgaya() async => tuluv;

  @override
  Future<List<({String id, String ner})>> getBarilguud(String orgId) async => [];

  @override
  Future<void> saveFcmToken(String khariltsagchId, String fcmToken) async {}
}

class _KhuurmagSocket extends SocketService {
  _KhuurmagSocket(SecureStorageService storage) : super(storage);

  final Map<String, List<Function(dynamic)>> sonsogchid = {};
  bool salsan = false;

  @override
  bool get isConnected => !salsan;

  @override
  Future<void> connect() async {}

  @override
  Future<void> ensureConnected() async {}

  @override
  void on(String event, Function(dynamic) handler) =>
      sonsogchid.putIfAbsent(event, () => []).add(handler);

  @override
  void off(String event, [Function(dynamic)? handler]) {
    if (handler == null) {
      sonsogchid.remove(event);
    } else {
      sonsogchid[event]?.remove(handler);
    }
  }

  @override
  void joinRoom(String room) {}

  @override
  void leaveRoom(String room) {}

  @override
  void disconnect() {
    salsan = true;
    sonsogchid.clear();
  }

  void duudya(String event) {
    for (final handler in [...?sonsogchid[event]]) {
      handler(null);
    }
  }
}
