import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

final _clockFile = RegExp(r'lib/domain/game_clock\.dart$');
final _currentTime = RegExp(r'DateTime\s*\.\s*(now|timestamp)\b');
final _randomness = RegExp(r'\bRandom\b');

String _code(String source) => source
    .split('\n')
    .map((line) => line.replaceFirst(RegExp(r'//.*$'), ''))
    .join('\n');

List<String> _offenders(RegExp pattern, {bool skipClock = false}) => [
      for (final file in Directory('lib/domain')
          .listSync(recursive: true)
          .whereType<File>()
          .where((f) => f.path.endsWith('.dart')))
        if (!(skipClock &&
                _clockFile.hasMatch(file.path.replaceAll(r'\', '/'))) &&
            pattern.hasMatch(_code(file.readAsStringSync())))
          file.path
    ];

void main() {
  test('домен узнаёт время только через GameClock', () {
    expect(_offenders(_currentTime, skipClock: true), isEmpty);
  });

  test('в домене нет случайности: дни и события повторяются один в один', () {
    expect(_offenders(_randomness), isEmpty);
  });

  test('правило ловит любую форму обращения к текущему времени', () {
    for (final source in [
      'final t = DateTime.now();',
      'final t = DateTime.timestamp();',
      'final clock = DateTime.now;',
      'final t = DateTime\n    .now();',
    ]) {
      expect(_currentTime.hasMatch(_code(source)), isTrue, reason: source);
    }
    for (final source in [
      'final t = DateTime.parse(raw);',
      'final t = DateTime(2026, 9, 25);',
      '// DateTime.now() только в RealClock',
    ]) {
      expect(_currentTime.hasMatch(_code(source)), isFalse, reason: source);
    }
    expect(_randomness.hasMatch('final r = Random(42);'), isTrue);
    expect(_randomness.hasMatch('final r = RandomAccessFile;'), isFalse);
  });
}
