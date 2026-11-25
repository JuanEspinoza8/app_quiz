import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/data/latest.dart' as tz;
import 'package:timezone/timezone.dart' as tz;

class NotificationService {
  static final _notifications = FlutterLocalNotificationsPlugin();

  /// Cuántos días por adelantado se programan. Se reprograman cada vez que
  /// se abre la app; si alguien no la abre en dos semanas, dejan de llegar.
  static const reminderDays = 14;
  static const _firstReminderId = 100;

  static const _details = NotificationDetails(
    android: AndroidNotificationDetails(
      'daily_channel_id',
      'Recordatorios diarios',
      channelDescription: 'Notificaciones del Quiz Diario',
      importance: Importance.max,
      priority: Priority.high,
    ),
  );

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

  /// Horarios de los próximos recordatorios, a la hora elegida. El primero
  /// es hoy salvo que ya se haya cumplido la meta o ya haya pasado la hora.
  static List<DateTime> reminderTimes(
    DateTime now,
    int hour,
    int minute, {
    required bool goalMetToday,
    int days = reminderDays,
  }) {
    final todayAtTime = DateTime(now.year, now.month, now.day, hour, minute);
    final startsToday = !goalMetToday && todayAtTime.isAfter(now);
    final firstDay = startsToday ? now.day : now.day + 1;
    return [for (var i = 0; i < days; i++) DateTime(now.year, now.month, firstDay + i, hour, minute)];
  }

  /// Programa un aviso por día para los próximos [reminderDays] días.
  ///
  /// No se usa un aviso que se repite solo (matchDateTimeComponents): el
  /// plugin calcula su primera fecha desde "ahora" e ignora la que se le
  /// pasa, así que no se podría saltear el día en que ya se cumplió la meta.
  static Future<void> scheduleReminders({
    required int hour,
    required int minute,
    required bool goalMetToday,
  }) async {
    // Borra también el aviso repetido de la versión anterior (id 1).
    await _notifications.cancelAll();

    final now = tz.TZDateTime.now(tz.local);
    final times = reminderTimes(
      DateTime(now.year, now.month, now.day, now.hour, now.minute, now.second),
      hour,
      minute,
      goalMetToday: goalMetToday,
    );
    for (var i = 0; i < times.length; i++) {
      final t = times[i];
      await _notifications.zonedSchedule(
        _firstReminderId + i,
        'Quiz Diario 📚',
        'Te faltan preguntas para tu meta de hoy. ¡No pierdas tu racha! 🔥',
        tz.TZDateTime(tz.local, t.year, t.month, t.day, t.hour, t.minute),
        _details,
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
        uiLocalNotificationDateInterpretation: UILocalNotificationDateInterpretation.absoluteTime,
      );
    }
  }
}
