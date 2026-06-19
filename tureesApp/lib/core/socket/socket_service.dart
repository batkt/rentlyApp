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

  SocketService(this._storage);

  bool get isConnected => _socket?.connected ?? false;

  Future<void> connect() async {
    if (isConnected) return;

    final token = await _storage.getToken();
    _socket = io.io(
      'https://turees.zevtabs.mn',
      io.OptionBuilder()
          .setTransports(['websocket'])
          .enableAutoConnect()
          .enableReconnection()
          .setReconnectionAttempts(5)
          .setReconnectionDelay(2000)
          .setExtraHeaders({'Authorization': 'bearer $token'})
          .build(),
    );

    _socket!.onConnect((_) {});
    _socket!.onDisconnect((_) {});
    _socket!.onConnectError((data) {});
  }

  void joinRoom(String room) {
    _socket?.emit('join', room);
  }

  void leaveRoom(String room) {
    _socket?.emit('leave', room);
  }

  void on(String event, Function(dynamic) handler) {
    _socket?.on(event, handler);
  }

  void off(String event) {
    _socket?.off(event);
  }

  void emit(String event, dynamic data) {
    _socket?.emit(event, data);
  }

  void disconnect() {
    _socket?.disconnect();
    _socket = null;
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
