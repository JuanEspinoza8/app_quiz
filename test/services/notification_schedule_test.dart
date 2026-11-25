import 'package:flutter_test/flutter_test.dart';
import 'package:quiz_daily/services/notification_service.dart';

void main() {
  group('NotificationService.reminderTimes', () {
    test('si no cumplió la meta y la hora no pasó, el primer aviso es hoy', () {
      final times = NotificationService.reminderTimes(DateTime(2026, 11, 19, 10), 18, 30, goalMetToday: false);

      expect(times.first, DateTime(2026, 11, 19, 18, 30));
      expect(times[1], DateTime(2026, 11, 20, 18, 30));
    });

    test('si ya cumplió la meta, hoy no avisa: el primero es mañana', () {
      final times = NotificationService.reminderTimes(DateTime(2026, 11, 19, 10), 18, 30, goalMetToday: true);

      expect(times.first, DateTime(2026, 11, 20, 18, 30));
    });

    test('si la hora ya pasó, el primero es mañana', () {
      final times = NotificationService.reminderTimes(DateTime(2026, 11, 19, 18, 30), 18, 30, goalMetToday: false);

      expect(times.first, DateTime(2026, 11, 20, 18, 30));
    });

    test('son 14 avisos en días seguidos a la hora elegida, aunque cambie el mes o el año', () {
      final times = NotificationService.reminderTimes(DateTime(2026, 12, 25, 8), 7, 0, goalMetToday: false);

      expect(times, hasLength(NotificationService.reminderDays));
      expect(times.every((t) => t.hour == 7 && t.minute == 0), isTrue);
      for (var i = 1; i < times.length; i++) {
        expect(DateTime.utc(times[i].year, times[i].month, times[i].day)
            .difference(DateTime.utc(times[i - 1].year, times[i - 1].month, times[i - 1].day))
            .inDays, 1);
      }
      expect(times.first, DateTime(2026, 12, 26, 7));
      expect(times.last, DateTime(2027, 1, 8, 7));
    });
  });
}
