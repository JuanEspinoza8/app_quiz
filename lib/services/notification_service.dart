import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/data/latest.dart' as tz;
import 'package:timezone/timezone.dart' as tz;

class NotificationService {
  static final _notifications = FlutterLocalNotificationsPlugin();

  static Future<void> init() async {
    // Sin setLocalLocation, tz.local queda en UTC y el recordatorio de las
    // 18:00 sale a las 15:00 en Argentina.
    tz.initializeTimeZones();
    await _configureLocalTimeZone();

    // Ícono que genera flutter_launcher_icons (la app no tiene ic_launcher)
    const androidInit = AndroidInitializationSettings('@mipmap/launcher_icon');

    const initSettings = InitializationSettings(android: androidInit);

    await _notifications.initialize(initSettings);

    // 🔔 Solicitar permiso en Android 13+
    await _notifications
        .resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>()
        ?.requestNotificationsPermission();
  }

  static Future<void> _configureLocalTimeZone() async {
    try {
      final timezone = await FlutterTimezone.getLocalTimezone();
      tz.setLocalLocation(tz.getLocation(timezone.identifier));
    } catch (e) {
      // Si el sistema devuelve una zona que la base de datos no conoce,
      // seguimos en UTC antes que no programar el recordatorio.
      debugPrint('No se pudo configurar la zona horaria local: $e');
    }
  }

  /// Muestra una notificación simple instantánea
  static Future<void> showNow(String title, String body) async {
    const androidDetails = AndroidNotificationDetails(
      'daily_channel_id',
      'Recordatorios diarios',
      channelDescription: 'Notificaciones del Quiz Diario',
      importance: Importance.max,
      priority: Priority.high,
    );

    await _notifications.show(
      0,
      title,
      body,
      const NotificationDetails(android: androidDetails),
    );
  }

  /// Programa una notificación diaria
  static Future<void> scheduleDaily(int hour, int minute) async {
    const androidDetails = AndroidNotificationDetails(
      'daily_channel_id',
      'Recordatorios diarios',
      channelDescription: 'Notificaciones del Quiz Diario',
      importance: Importance.max,
      priority: Priority.high,
    );

    final now = tz.TZDateTime.now(tz.local);
    var scheduled = tz.TZDateTime(tz.local, now.year, now.month, now.day, hour, minute);
    if (scheduled.isBefore(now)) {
      scheduled = scheduled.add(const Duration(days: 1));
    }

    await _notifications.zonedSchedule(
      1,
      'Quiz Diario 📚',
      'Tenés preguntas pendientes hoy, ¡no pierdas tu racha! 🔥',
      scheduled,
      const NotificationDetails(android: androidDetails),
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      uiLocalNotificationDateInterpretation:
      UILocalNotificationDateInterpretation.absoluteTime,
      matchDateTimeComponents: DateTimeComponents.time,
    );
  }
}