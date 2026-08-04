import 'dart:io';
import 'package:android_alarm_manager_plus/android_alarm_manager_plus.dart';
import 'package:daily_you/main.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:permission_handler/permission_handler.dart';

class NotificationManager {
  static final NotificationManager instance = NotificationManager._init();

  NotificationManager._init();

  static FlutterLocalNotificationsPlugin? _notifications;
  FlutterLocalNotificationsPlugin get notifications => _notifications!;

  bool justLaunched = true;

  Future<void> init() async {
    _notifications = FlutterLocalNotificationsPlugin();
    await _notifications!.initialize(
        settings: const InitializationSettings(
            android: AndroidInitializationSettings('@drawable/ic_notification'),
            linux:
                LinuxInitializationSettings(defaultActionName: 'Log Today')));
  }

  Future<bool> hasNotificationPermission() async {
    if (!Platform.isAndroid) return false;

    final granted = await _notifications!
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()!
        .requestNotificationsPermission();
    if (granted != true) return false;

    return requestAlarmPermission();
  }

  Future<bool> requestAlarmPermission() async {
    final androidInfo = await DeviceInfoPlugin().androidInfo;
    // Exact alarms require a dedicated permission on Android 12+
    if (androidInfo.version.sdkInt < 31) return true;

    final status = await Permission.scheduleExactAlarm.status;
    if (status.isGranted) return true;
    return (await Permission.scheduleExactAlarm.request()).isGranted;
  }

  Future<void> dismissReminderNotification() async {
    await notifications.cancel(id: 0);
  }

  Future<void> dismissOnThisDayNotification() async {
    await notifications.cancel(id: 1);
  }

  Future<void> stopDailyReminders() async {
    await AndroidAlarmManager.cancel(0);
    await dismissReminderNotification();
  }

  Future<void> startScheduledDailyReminders() async {
    await setAlarm(firstSet: true);
  }

  Future<void> stopOnThisDayNotifications() async {
    await AndroidAlarmManager.cancel(1);
    await dismissOnThisDayNotification();
  }

  Future<void> startOnThisDayNotifications() async {
    await setOnThisDayAlarm(firstSet: true);
  }
}
