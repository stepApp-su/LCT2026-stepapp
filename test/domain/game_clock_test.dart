import 'package:flutter_test/flutter_test.dart';
import 'package:finni/domain/game_clock.dart';

void main() {
  group('DemoClock', () {
    test('пять суток проходят подряд без ожиданий', () {
      final clock = DemoClock(start: DateTime(2026, 9, 16, 10));
      var lastLogin = clock.now();
      var loginBonuses = 0;

      for (var day = 0; day < 5; day++) {
        if (clock.isNewCalendarDay(lastLogin)) {
          loginBonuses++;
          lastLogin = clock.now();
        }
        clock.advanceDay();
      }

      expect(loginBonuses, 5);
      expect(clock.now().difference(DateTime(2026, 9, 16, 10)).inDays, 5);
    });

    test('кулдауны нулевые', () {
      final clock = DemoClock();
      expect(clock.cooldownMs('petChores'), 0);
      expect(clock.cooldownMs('dailyTask'), 0);
      expect(clock.cooldownMs('что угодно'), 0);
    });

    test('advance сдвигает время', () {
      final clock = DemoClock(start: DateTime(2026, 1, 1, 9));
      clock.advance(const Duration(hours: 3, minutes: 30));
      expect(clock.now(), DateTime(2026, 1, 1, 12, 30));
    });
  });

  group('RealClock', () {
    test('now отдаёт реальное время', () {
      final clock = RealClock();
      final before = DateTime.now();
      final got = clock.now();
      final after = DateTime.now();
      expect(got.isBefore(before), isFalse);
      expect(got.isAfter(after), isFalse);
    });

    test('кулдауны из конфига, неизвестный ключ — 0', () {
      final clock = RealClock(cooldowns: {
        'petChores': const Duration(hours: 3),
      });
      expect(clock.cooldownMs('petChores'), 3 * 60 * 60 * 1000);
      expect(clock.cooldownMs('неизвестный'), 0);
    });

    test('перевод часов назад не даёт повторный бонус', () {
      final clock = RealClock();
      final lastLoginInFuture = clock.now().add(const Duration(days: 1));
      expect(clock.isNewCalendarDay(lastLoginInFuture), isFalse);
    });

    test('сегодня — не новый день, вчера — новый', () {
      final clock = RealClock();
      final now = clock.now();
      expect(clock.isNewCalendarDay(now), isFalse);
      expect(clock.isNewCalendarDay(now.subtract(const Duration(days: 1))),
          isTrue);
    });

    test('неделя без входа = просто новые сутки, один бонус', () {
      final clock = RealClock();
      final weekAgo = clock.now().subtract(const Duration(days: 7));
      expect(clock.isNewCalendarDay(weekAgo), isTrue);
    });
  });
}
