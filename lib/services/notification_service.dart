import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest.dart' as tz;
import 'package:timezone/timezone.dart' as tz;

class NotificationService {
  static final _notifications = FlutterLocalNotificationsPlugin();

  static Future<void> init() async {
    // Inicializa zona horaria
    tz.initializeTimeZones();

    // Configuración inicial
    const androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');
    const initSettings = InitializationSettings(android: androidInit);

    await _notifications.initialize(initSettings);

    // 🔔 Solicitar permiso en Android 13+
    await _notifications
        .resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>()
        ?.requestNotificationsPermission();
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
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle, // 👈 cambio clave
      uiLocalNotificationDateInterpretation:
      UILocalNotificationDateInterpretation.absoluteTime,
      matchDateTimeComponents: DateTimeComponents.time,
    );

  }

}
