import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/network/dio_client.dart';
import '../../core/constants/api_constants.dart';
import '../models/notification_model.dart';
import '../models/task_model.dart';

final notificationRepositoryProvider = Provider<NotificationRepository>((ref) {
  return NotificationRepository(ref.read(dioClientProvider));
});

class NotificationRepository {
  final DioClient _client;

  NotificationRepository(this._client);

  Future<List<NotificationModel>> getNotifications({
    required String khariltsagchiinId,
    int page = 1,
    int pageSize = 30,
  }) async {
    final query = {'khariltsagchiinId': khariltsagchiinId};
    final res = await _client.get(ApiConstants.notifications, queryParameters: {
      'query': jsonEncode(query),
      'khuudasniiDugaar': page,
      'khuudasniiKhemjee': pageSize,
    });
    final list = (res.data['jagsaalt'] as List?) ?? [];
    return list.map((e) => NotificationModel.fromJson(e)).toList();
  }

  Future<void> markNotificationRead(String notificationId) async {
    await _client.put('${ApiConstants.notifications}/$notificationId', data: {'tuluv': 1});
  }

  Future<List<TaskModel>> getTasks({
    required String khariltsagchiinId,
    int page = 1,
    int pageSize = 20,
  }) async {
    final query = {'khariltsagchiinId': khariltsagchiinId};
    final res = await _client.get(ApiConstants.tasks, queryParameters: {
      'query': jsonEncode(query),
      'khuudasniiDugaar': page,
      'khuudasniiKhemjee': pageSize,
    });
    final list = (res.data['jagsaalt'] as List?) ?? [];
    return list.map((e) => TaskModel.fromJson(e)).toList();
  }

  Future<void> submitTask({
    required String title,
    required String description,
    required String baiguullagiinId,
    required String barilgiinId,
    required String khariltsagchiinId,
    required String khariltsagchiinNer,
  }) async {
    await _client.post(ApiConstants.submitTask, data: {
      'title': title,
      'description': description,
      'baiguullagiinId': baiguullagiinId,
      'barilgiinId': barilgiinId,
      'khariltsagchiinId': khariltsagchiinId,
      'khariltsagchiinNer': khariltsagchiinNer,
      'turul': 'daalgavar',
    });
  }

  Future<List<Map<String, dynamic>>> getDuudlaga({
    required String khariltsagchiinId,
    int page = 1,
    int pageSize = 20,
  }) async {
    final res = await _client.get(ApiConstants.notifications, queryParameters: {
      'query': '{"khariltsagchiinId":"$khariltsagchiinId","turul":"duudlaga"}',
      'khuudasniiDugaar': page,
      'khuudasniiKhemjee': pageSize,
    });
    final list = (res.data['jagsaalt'] as List?) ?? [];
    return list.cast<Map<String, dynamic>>();
  }

  Future<void> submitDuudlaga({
    required String baiguullagiinId,
    required String barilgiinId,
    required String khariltsagchiinId,
    required String khariltsagchiinNer,
    required String title,
    required String message,
    String duudlagiinTurul = '',
    String khariltsagchiinUtas = '',
    String khariltsagchiinRegister = '',
  }) async {
    await _client.post(ApiConstants.duudlagaKhadgalya, data: {
      'baiguullagiinId': baiguullagiinId,
      'barilgiinId': barilgiinId,
      'khariltsagchiinId': khariltsagchiinId,
      'khariltsagchiinNer': khariltsagchiinNer,
      'khariltsagchiinUtas': khariltsagchiinUtas,
      'khariltsagchiinRegister': khariltsagchiinRegister,
      'title': title,
      'message': message,
      'turul': 'duudlaga',
      'duudlagiinTurul': duudlagiinTurul.isNotEmpty ? duudlagiinTurul : 'Бусад',
      'tukhainBaaziinKholbolt': 'default',
    });
  }
}
