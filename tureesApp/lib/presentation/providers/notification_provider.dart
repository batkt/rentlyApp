import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/socket/socket_service.dart';
import '../../data/models/notification_model.dart';
import '../../data/models/task_model.dart';
import '../../data/repositories/notification_repository.dart';
import 'auth_provider.dart';

/// Latest notification received via socket — home screen listens to show a banner.
final incomingNotificationProvider = StateProvider<NotificationModel?>((ref) => null);

final notificationsProvider = StateNotifierProvider<NotificationsNotifier, NotificationsState>((ref) {
  final user = ref.watch(currentUserProvider);
  return NotificationsNotifier(
    ref.read(notificationRepositoryProvider),
    ref,
    ref.read(socketServiceProvider),
    user?.id,
  );
});

final unreadCountProvider = Provider<int>((ref) {
  // Only count medegdel category — pending requests have tuluv==0 as their approval
  // status (not a "read" state), so including them inflates the badge incorrectly.
  return ref.watch(notificationsProvider).notifications
      .where((n) => n.isUnread && n.category == NotifCategory.medegdel)
      .length;
});

final tasksProvider = StateNotifierProvider<TasksNotifier, TasksState>((ref) {
  return TasksNotifier(ref.read(notificationRepositoryProvider), ref);
});

class NotificationsState {
  final bool isLoading;
  final List<NotificationModel> notifications;
  final String? error;

  const NotificationsState({
    this.isLoading = false,
    this.notifications = const [],
    this.error,
  });

  NotificationsState copyWith({
    bool? isLoading,
    List<NotificationModel>? notifications,
    String? error,
  }) => NotificationsState(
    isLoading: isLoading ?? this.isLoading,
    notifications: notifications ?? this.notifications,
    error: error,
  );
}

class NotificationsNotifier extends StateNotifier<NotificationsState> {
  final NotificationRepository _repo;
  final Ref _ref;
  final SocketService _socket;
  final String? _userId;

  NotificationsNotifier(this._repo, this._ref, this._socket, this._userId)
      : super(const NotificationsState()) {
    if (_userId != null) {
      _socket.on('khariltsagch$_userId', _onSocketNotification);
    }
  }

  void _onSocketNotification(dynamic data) {
    if (data is! Map) return;
    try {
      final notif = NotificationModel.fromJson(Map<String, dynamic>.from(data as Map));
      if (notif.id.isEmpty) return;
      final alreadyExists = state.notifications.any((n) => n.id == notif.id);
      if (!alreadyExists) {
        state = state.copyWith(notifications: [notif, ...state.notifications]);
        _ref.read(incomingNotificationProvider.notifier).state = notif;
      }
    } catch (_) {}
  }

  @override
  void dispose() {
    if (_userId != null) {
      _socket.off('khariltsagch$_userId', _onSocketNotification);
    }
    super.dispose();
  }

  Future<void> load() async {
    final user = _ref.read(currentUserProvider);
    if (user == null) return;
    state = state.copyWith(isLoading: true, error: null);
    try {
      final list = await _repo.getNotifications(khariltsagchiinId: user.id);
      final ovog = user.ovog;
      final ner = user.ner;
      final processed = list.map((n) {
        var msg = n.message;
        if (msg.contains('<ovog>') || msg.contains('<ner>')) {
          msg = msg.replaceAll('<ovog>', ovog).replaceAll('<ner>', ner);
        }
        if (msg == n.message) return n;
        return NotificationModel(
          id: n.id, title: n.title, message: msg,
          khariltsagchiinId: n.khariltsagchiinId,
          baiguullagiinId: n.baiguullagiinId,
          tuluv: n.tuluv, turul: n.turul,
          duudlagiinTurul: n.duudlagiinTurul,
          createdAt: n.createdAt,
        );
      }).toList();
      state = state.copyWith(isLoading: false, notifications: processed);
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  Future<void> submitRequest({required String message, String turul = 'sanal'}) async {
    final user = _ref.read(currentUserProvider);
    if (user == null) return;
    await _repo.submitSanal(
      baiguullagiinId: user.baiguullagiinId,
      barilgiinId: user.barilgiinId,
      khariltsagchiinId: user.id,
      khariltsagchiinNer: user.fullName,
      message: message,
      turul: turul,
    );
    await load();
  }

  Future<void> markRead(String id) async {
    await _repo.markNotificationRead(id);
    state = state.copyWith(
      notifications: state.notifications.map((n) {
        if (n.id == id) {
          return NotificationModel(
            id: n.id, title: n.title, message: n.message,
            khariltsagchiinId: n.khariltsagchiinId, baiguullagiinId: n.baiguullagiinId,
            tuluv: 1, turul: n.turul, duudlagiinTurul: n.duudlagiinTurul,
            createdAt: n.createdAt,
          );
        }
        return n;
      }).toList(),
    );
  }

  Future<void> markAllRead() async {
    final unreadMedegdel = state.notifications
        .where((n) => n.isUnread && n.category == NotifCategory.medegdel)
        .toList();
    if (unreadMedegdel.isEmpty) return;
    await Future.wait(unreadMedegdel.map((n) => _repo.markNotificationRead(n.id)));
    state = state.copyWith(
      notifications: state.notifications.map((n) => (n.isUnread && n.category == NotifCategory.medegdel)
          ? NotificationModel(
              id: n.id, title: n.title, message: n.message,
              khariltsagchiinId: n.khariltsagchiinId, baiguullagiinId: n.baiguullagiinId,
              tuluv: 1, turul: n.turul, duudlagiinTurul: n.duudlagiinTurul,
              createdAt: n.createdAt,
            )
          : n).toList(),
    );
  }
}

class TasksState {
  final bool isLoading;
  final List<TaskModel> tasks;
  final String? error;

  const TasksState({
    this.isLoading = false,
    this.tasks = const [],
    this.error,
  });

  TasksState copyWith({
    bool? isLoading,
    List<TaskModel>? tasks,
    String? error,
  }) => TasksState(
    isLoading: isLoading ?? this.isLoading,
    tasks: tasks ?? this.tasks,
    error: error,
  );
}

class TasksNotifier extends StateNotifier<TasksState> {
  final NotificationRepository _repo;
  final Ref _ref;

  TasksNotifier(this._repo, this._ref) : super(const TasksState());

  Future<void> load() async {
    final user = _ref.read(currentUserProvider);
    if (user == null) return;
    state = state.copyWith(isLoading: true, error: null);
    try {
      final list = await _repo.getTasks(khariltsagchiinId: user.id);
      state = state.copyWith(isLoading: false, tasks: list);
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  Future<void> submitTask(String title, String description) async {
    final user = _ref.read(currentUserProvider);
    if (user == null) return;
    await _repo.submitTask(
      title: title,
      description: description,
      baiguullagiinId: user.baiguullagiinId,
      barilgiinId: user.barilgiinId,
      khariltsagchiinId: user.id,
      khariltsagchiinNer: user.fullName,
    );
    await load();
  }
}

class DuudlagaState {
  final bool isLoading;
  final List<Map<String, dynamic>> duudlagaList;
  final String? error;

  const DuudlagaState({
    this.isLoading = false,
    this.duudlagaList = const [],
    this.error,
  });

  DuudlagaState copyWith({
    bool? isLoading,
    List<Map<String, dynamic>>? duudlagaList,
    String? error,
  }) => DuudlagaState(
    isLoading: isLoading ?? this.isLoading,
    duudlagaList: duudlagaList ?? this.duudlagaList,
    error: error,
  );
}

class DuudlagaNotifier extends StateNotifier<DuudlagaState> {
  final NotificationRepository _repo;
  final Ref _ref;

  DuudlagaNotifier(this._repo, this._ref) : super(const DuudlagaState());

  Future<void> load() async {
    final user = _ref.read(currentUserProvider);
    if (user == null) return;
    state = state.copyWith(isLoading: true, error: null);
    try {
      final list = await _repo.getDuudlaga(khariltsagchiinId: user.id);
      state = state.copyWith(isLoading: false, duudlagaList: list);
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  Future<void> submit({
    required String title,
    required String message,
    String duudlagiinTurul = '',
    String khariltsagchiinUtas = '',
    String khariltsagchiinRegister = '',
  }) async {
    final user = _ref.read(currentUserProvider);
    if (user == null) return;
    await _repo.submitDuudlaga(
      baiguullagiinId: user.baiguullagiinId,
      barilgiinId: user.barilgiinId,
      khariltsagchiinId: user.id,
      khariltsagchiinNer: user.fullName,
      title: title,
      message: message,
      duudlagiinTurul: duudlagiinTurul,
      khariltsagchiinUtas: khariltsagchiinUtas,
      khariltsagchiinRegister: khariltsagchiinRegister,
    );
    await load();
  }
}

final duudlagaProvider = StateNotifierProvider<DuudlagaNotifier, DuudlagaState>((ref) {
  return DuudlagaNotifier(ref.read(notificationRepositoryProvider), ref);
});
