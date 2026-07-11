import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

class NotificationService {
  static final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
      FlutterLocalNotificationsPlugin();

  static Future<void> init() async {
    const AndroidInitializationSettings initializationSettingsAndroid =
        AndroidInitializationSettings('@mipmap/ic_launcher');

    const InitializationSettings initializationSettings = InitializationSettings(
      android: initializationSettingsAndroid,
    );

    try {
      await flutterLocalNotificationsPlugin.initialize(initializationSettings);
      await checkAndRequestPermissions();
    } catch (e) {
      debugPrint('Notification init error: $e');
    }
  }

  static Future<bool> checkAndRequestPermissions() async {
    try {
      final AndroidFlutterLocalNotificationsPlugin? androidImplementation =
          flutterLocalNotificationsPlugin.resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin>();

      if (androidImplementation != null) {
        final bool? granted = await androidImplementation.requestNotificationsPermission();
        return granted ?? false;
      }
    } catch (e) {
      debugPrint('Permission request error: $e');
    }
    return false;
  }

  static Future<void> showNotification(String title, String body) async {
    const AndroidNotificationDetails androidPlatformChannelSpecifics =
        AndroidNotificationDetails(
      'it_park_notifications_channel',
      'IT Park Xabarlari',
      channelDescription: 'IT Park xabarlari va bildirishnomalari',
      importance: Importance.max,
      priority: Priority.high,
      showWhen: true,
    );
    const NotificationDetails platformChannelSpecifics = NotificationDetails(
      android: androidPlatformChannelSpecifics,
    );
    try {
      await flutterLocalNotificationsPlugin.show(
        DateTime.now().millisecondsSinceEpoch % 100000,
        title,
        body,
        platformChannelSpecifics,
      );
    } catch (e) {
      debugPrint('Show notification error: $e');
    }
  }
}
