import 'dart:typed_data';

import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:timezone/data/latest_all.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;
import 'package:wakelock_plus/wakelock_plus.dart';

import '../todo/domain/todo_item.dart';

@pragma('vm:entry-point')
void notificationTapBackground(NotificationResponse response) {
  // Intentionally left blank for background tap support.
}

class ReminderService {
  static const String _channelId = 'todo_alarm_channel';
  static const String _channelName = 'Todo提醒';
  static const String _channelDescription = '待办事项到点提醒';

  final FlutterLocalNotificationsPlugin _plugin = FlutterLocalNotificationsPlugin();

  bool _initialized = false;

  Future<void> initialize() async {
    if (_initialized) {
      return;
    }

    tz_data.initializeTimeZones();
    try {
      tz.setLocalLocation(tz.getLocation('Asia/Shanghai'));
    } catch (_) {
      tz.setLocalLocation(tz.UTC);
    }

    const android = AndroidInitializationSettings('ic_notification');
    const ios = DarwinInitializationSettings();

    await _plugin.initialize(
      const InitializationSettings(android: android, iOS: ios),
      onDidReceiveNotificationResponse: _onNotificationTap,
      onDidReceiveBackgroundNotificationResponse: notificationTapBackground,
    );

    await _createChannel();
    await requestPermissions();

    _initialized = true;
  }

  Future<void> requestPermissions() async {
    await Permission.notification.request();

    final android = _plugin.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
    await android?.requestNotificationsPermission();
    await android?.requestExactAlarmsPermission();

    final ios =
        _plugin.resolvePlatformSpecificImplementation<IOSFlutterLocalNotificationsPlugin>();
    await ios?.requestPermissions(alert: true, badge: true, sound: true);
  }

  Future<void> scheduleTodoReminder(TodoItem todo) async {
    await initialize();

    if (todo.id == null) {
      return;
    }

    final due = tz.TZDateTime.from(todo.dueAt, tz.local);
    if (due.isBefore(tz.TZDateTime.now(tz.local))) {
      return;
    }

    final android = AndroidNotificationDetails(
      _channelId,
      _channelName,
      channelDescription: _channelDescription,
      icon: 'ic_notification',
      importance: Importance.max,
      priority: Priority.high,
      category: AndroidNotificationCategory.alarm,
      fullScreenIntent: true,
      visibility: NotificationVisibility.public,
      vibrationPattern: Int64List.fromList(<int>[0, 500, 250, 700]),
      enableVibration: true,
      ticker: '待办提醒',
    );

    const ios = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
      interruptionLevel: InterruptionLevel.timeSensitive,
    );

    await _plugin.zonedSchedule(
      todo.id!,
      '待办时间到了',
      todo.title,
      due,
      NotificationDetails(android: android, iOS: ios),
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      payload: todo.id.toString(),
    );
  }

  Future<void> cancelTodoReminder(int todoId) async {
    await _plugin.cancel(todoId);
  }

  Future<void> _createChannel() async {
    final android = _plugin.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();

    await android?.createNotificationChannel(
      const AndroidNotificationChannel(
        _channelId,
        _channelName,
        description: _channelDescription,
        importance: Importance.max,
      ),
    );
  }

  void _onNotificationTap(NotificationResponse response) {
    // Keep screen awake briefly after user taps a reminder for better visibility.
    WakelockPlus.enable();
    Future<void>.delayed(const Duration(seconds: 15), WakelockPlus.disable);
  }
}
