import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Local notifications: asks permission on first launch and shows admin broadcasts.
class Notifier {
  Notifier._();
  static final Notifier instance = Notifier._();

  final _plugin = FlutterLocalNotificationsPlugin();
  bool _ready = false;
  bool enabled = true;
  int _id = 0;

  Future<void> init() async {
    try {
      await _plugin.initialize(
        const InitializationSettings(android: AndroidInitializationSettings('@mipmap/ic_launcher')),
      );
      final p = await SharedPreferences.getInstance();
      enabled = p.getBool('notifs') ?? true;
      _ready = true;
    } catch (_) {}
  }

  /// Shows the system permission prompt (Android 13+).
  Future<bool> requestPermission() async {
    if (!_ready) return false;
    final android = _plugin.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
    final ok = await android?.requestNotificationsPermission() ?? false;
    return ok;
  }

  Future<void> setEnabled(bool v) async {
    enabled = v;
    final p = await SharedPreferences.getInstance();
    await p.setBool('notifs', v);
    if (v) await requestPermission();
  }

  Future<void> show(String title, String body) async {
    if (!_ready || !enabled) return;
    try {
      await _plugin.show(
        _id++,
        title,
        body,
        const NotificationDetails(
          android: AndroidNotificationDetails(
            'clover_updates',
            'Clover updates',
            channelDescription: 'News, new episodes and announcements',
            importance: Importance.high,
            priority: Priority.high,
          ),
        ),
      );
    } catch (_) {}
  }
}
