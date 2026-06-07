import 'package:flutter_local_notifications/flutter_local_notifications.dart';

class NotificationService {
  static final NotificationService _instance = NotificationService._();
  factory NotificationService() => _instance;
  NotificationService._();

  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();
  bool _initialized = false;

  Future<void> initialize() async {
    if (_initialized) return;

    const androidSettings =
        AndroidInitializationSettings('@mipmap/ic_launcher');
    const initSettings = InitializationSettings(android: androidSettings);

    await _plugin.initialize(initSettings);
    _initialized = true;
  }

  Future<void> showExerciseStartedNotification(String exerciseType) async {
    await initialize();
    await _plugin.show(
      1,
      'Exercise Started',
      'Complete your $exerciseType to unlock the app',
      const NotificationDetails(
        android: AndroidNotificationDetails(
          'exercise_channel',
          'Exercise Notifications',
          channelDescription: 'Notifications for exercise sessions',
          importance: Importance.high,
          priority: Priority.high,
        ),
      ),
    );
  }

  Future<void> showExerciseCompletedNotification(String appName) async {
    await initialize();
    await _plugin.show(
      2,
      'Exercise Completed!',
      '$appName is unlocked for 5 minutes',
      const NotificationDetails(
        android: AndroidNotificationDetails(
          'exercise_channel',
          'Exercise Notifications',
          channelDescription: 'Notifications for exercise sessions',
          importance: Importance.high,
          priority: Priority.high,
        ),
      ),
    );
  }
}
