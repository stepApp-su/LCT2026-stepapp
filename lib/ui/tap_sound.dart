/// Глобальный звук нажатия: тема и жесты дёргают tap(), контроллер
/// подключает проигрывание. Частые срабатывания гасятся, чтобы одно
/// нажатие не щёлкало дважды.
abstract final class TapSound {
  static void Function()? _play;
  static final Stopwatch _since = Stopwatch()..start();
  static int _last = -1000;

  static void attach(void Function()? play) => _play = play;

  static void tap() {
    final now = _since.elapsedMilliseconds;
    if (now - _last < 90) return;
    _last = now;
    _play?.call();
  }
}
