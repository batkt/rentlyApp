import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:socket_io_client/socket_io_client.dart' as io;
import '../constants/api_constants.dart';
import '../storage/secure_storage.dart';

final socketServiceProvider = Provider<SocketService>((ref) {
  final storage = ref.read(secureStorageProvider);
  return SocketService(storage);
});

class SocketService {
  io.Socket? _socket;
  final SecureStorageService _storage;

  /// Бүртгэсэн сонсогчид. [connect] нь шинэ socket instance үүсгэдэг тул
  /// (жишээ нь нэвтрэх урсгал HomeScreen-ий initState-тэй давхцахад) хуучин
  /// instance дээрх сонсогчид чимээгүй алга болдог байсан — тиймээс энд
  /// хадгалж, шинэ socket бүр дээр дахин холбоно. Мөн socket үүсээгүй байхад
  /// бүртгэсэн сонсогч ч алдагдахгүй.
  final Map<String, List<Function(dynamic)>> _sonsogchid = {};

  SocketService(this._storage);

  bool get isConnected => _socket?.connected ?? false;

  Future<void> connect() async {
    if (isConnected) return;

    final token = await _storage.getToken();
    _socket = io.io(
      ApiConstants.serverKhayag,
      io.OptionBuilder()
          .setTransports(['websocket'])
          .enableAutoConnect()
          .enableReconnection()
          .setReconnectionAttempts(5)
          .setReconnectionDelay(2000)
          .setExtraHeaders({'Authorization': 'bearer $token'})
          .build(),
    );

    _sonsogchdiigSergeeye();

    _socket!.onConnect((_) {});
    _socket!.onDisconnect((_) {});
    _socket!.onConnectError((data) {});
  }

  void _sonsogchdiigSergeeye() {
    final socket = _socket;
    if (socket == null) return;
    _sonsogchid.forEach((uzegdel, uiladluud) {
      for (final uiladel in uiladluud) {
        socket.on(uzegdel, uiladel);
      }
    });
  }

  /// Reopens a connection that dropped while the app was backgrounded (iOS
  /// suspends the socket, and reconnection attempts are capped) *without*
  /// throwing away the socket instance — every listener registered through
  /// [on] lives on that instance, so recreating it would silently stop
  /// notifications until the app was killed and relaunched.
  Future<void> ensureConnected() async {
    if (isConnected) return;
    final socket = _socket;
    if (socket != null) {
      socket.connect();
      return;
    }
    await connect();
  }

  void joinRoom(String room) {
    _socket?.emit('join', room);
  }

  void leaveRoom(String room) {
    _socket?.emit('leave', room);
  }

  void on(String event, Function(dynamic) handler) {
    _sonsogchid.putIfAbsent(event, () => []).add(handler);
    _socket?.on(event, handler);
  }

  /// Pass [handler] to remove only that listener; omit to clear all for [event].
  void off(String event, [Function(dynamic)? handler]) {
    if (handler == null) {
      _sonsogchid.remove(event);
    } else {
      _sonsogchid[event]?.remove(handler);
      if (_sonsogchid[event]?.isEmpty ?? false) _sonsogchid.remove(event);
    }
    _socket?.off(event, handler);
  }

  void emit(String event, dynamic data) {
    _socket?.emit(event, data);
  }

  void disconnect() {
    _socket?.disconnect();
    _socket = null;
    _sonsogchid.clear();
  }

  void joinOrgRoom(String orgId) {
    joinRoom(SocketEvents.orgRoom(orgId));
  }

  void joinUserRoom(String userId) {
    joinRoom(SocketEvents.userRoom(userId));
  }

  void joinQpayRoom(String orgId, String invoiceId) {
    joinRoom(SocketEvents.qpayRoom(orgId, invoiceId));
  }

  void leaveQpayRoom(String orgId, String invoiceId) {
    leaveRoom(SocketEvents.qpayRoom(orgId, invoiceId));
  }
}
