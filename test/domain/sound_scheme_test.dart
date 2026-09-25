import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:finni/domain/models/models.dart';
import 'package:finni/domain/services/sound_service.dart';

Map<String, Object?> _raw() =>
    (jsonDecode(File('assets/content/sounds.json').readAsStringSync()) as Map)
        .cast<String, Object?>();

Map<String, Object?> _phrases() =>
    (jsonDecode(File('assets/content/phrases.json').readAsStringSync()) as Map)
        .cast<String, Object?>();

void main() {
  final scheme = SoundScheme.fromJson(_raw());
  final service = SoundService(scheme: scheme);

  group('схема', () {
    test('все обязательные события озвучены', () {
      for (final event in SoundScheme.requiredEvents) {
        expect(scheme.events[event], isNotNull, reason: event);
      }
    });

    test('каждый файл схемы существует в assets', () {
      for (final file in scheme.allFiles) {
        expect(File('assets/audio/$file').existsSync(), isTrue, reason: file);
      }
    });

    test('у каждого питомца свой набор бормотания', () {
      final characters = (_phrases()['characters'] as Map).keys.toSet();
      expect(scheme.babble.keys.toSet(), characters);
      final all = <String>[];
      for (final files in scheme.babble.values) {
        all.addAll(files);
      }
      expect(all.toSet().length, all.length);
    });

    test('без события нет схемы', () {
      final broken = _raw();
      ((broken['events'] as Map)).remove('coin');
      expect(() => SoundScheme.fromJson(broken), throwsArgumentError);
    });

    test('питомец без сэмплов не принимается', () {
      final broken = _raw();
      (broken['babble'] as Map)['fox'] = ['babble/fox/fox_1.wav'];
      expect(() => SoundScheme.fromJson(broken), throwsArgumentError);
    });
  });

  group('озвучка реплик', () {
    test('каждый файл озвучки — настоящая tts-реплика с текстом', () {
      final phrases = {
        for (final p in (_phrases()['phrases'] as List))
          (p as Map)['id'] as String: p
      };
      for (final entry in scheme.voice.entries) {
        for (final phraseId in entry.value.keys) {
          final phrase = phrases[phraseId];
          expect(phrase, isNotNull, reason: phraseId);
          expect(phrase!['tts'], isTrue, reason: phraseId);
          final text =
              ((phrase['templates'] as Map)[entry.key] as String).trim();
          expect(text, isNotEmpty, reason: phraseId);
        }
      }
    });

    test('каждая tts-реплика лисёнка записана', () {
      final ttsIds = [
        for (final p in (_phrases()['phrases'] as List))
          if ((p as Map)['tts'] == true) p['id'] as String
      ];
      for (final id in ttsIds) {
        expect(scheme.voice['fox']![id], isNotNull, reason: id);
      }
    });
  });

  group('выбор звука', () {
    test('событие даёт путь к ассету, выключенный звук — тишину', () {
      expect(service.forEvent('coin', soundOn: true),
          'assets/audio/sfx/coin.wav');
      expect(service.forEvent('coin', soundOn: false), isNull);
      expect(() => service.forEvent('boom', soundOn: true),
          throwsArgumentError);
    });

    test('реплика с записью озвучивается, без записи — null', () {
      expect(
          service.voiceFor('greeting_default', species: 'fox', soundOn: true),
          'assets/audio/voice/greeting_default.mp3');
      expect(
          service.voiceFor('greeting_default',
              species: 'robot', soundOn: true),
          isNull);
      expect(
          service.voiceFor('greeting_default', species: 'fox', soundOn: false),
          isNull);
    });

    test('бормотание: по сэмплу на слог, в тембре питомца', () {
      final chain = service.babbleFor('Привет! Как дела?',
          species: 'puppy', seed: 5, soundOn: true);
      expect(chain.length, 5);
      for (final path in chain) {
        expect(path, startsWith('assets/audio/babble/puppy/'));
      }
    });

    test('длинная реплика не бормочет дольше лимита', () {
      final chain = service.babbleFor(
          'Очень длинная реплика про планирование бюджета и накопления на мечту',
          species: 'fox',
          seed: 1,
          soundOn: true);
      expect(chain.length, scheme.babbleMaxSyllables);
    });

    test('один сид — одна и та же цепочка', () {
      List<String> chain() => service.babbleFor('Привет, дружок!',
          species: 'dragon', seed: 42, soundOn: true);
      expect(chain(), chain());
    });

    test('выключенный звук — пустое бормотание', () {
      expect(
          service.babbleFor('Привет', species: 'fox', seed: 1, soundOn: false),
          isEmpty);
    });
  });
}
