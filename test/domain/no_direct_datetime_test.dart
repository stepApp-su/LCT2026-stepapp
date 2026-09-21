import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

// Время берём только через GameClock: сканируем lib/ на прямые
// DateTime.now() вне game_clock.dart.
void main() {
  test('DateTime.now() не используется нигде, кроме RealClock', () {
    final offenders = <String>[];
    final direct = RegExp(r'DateTime\s*\.\s*now\s*\(');

    final files = Directory('lib')
        .listSync(recursive: true)
        .whereType<File>()
        .where((f) => f.path.endsWith('.dart'));

    for (final file in files) {
      final normalized = file.path.replaceAll(r'\', '/');
      if (normalized.endsWith('lib/domain/game_clock.dart')) continue;

      final lines = file.readAsLinesSync();
      for (var i = 0; i < lines.length; i++) {
        final line = lines[i];
        if (line.trimLeft().startsWith('//')) continue;
        if (direct.hasMatch(line)) {
          offenders.add('$normalized:${i + 1}  ${line.trim()}');
        }
      }
    }

    expect(
      offenders,
      isEmpty,
      reason: 'время только через GameClock, нашлось:\n${offenders.join('\n')}',
    );
  });
}
