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

    test('игровые и экранные эффекты на месте', () {
      const extra = [
        'snap', 'round_win', 'miss', 'not_enough', 'dice', 'level_done',
        'goal_select', 'equip', 'knock', 'page_turn', 'egg_crack',
        'stat_up', 'stat_down', 'bubble', 'tally', 'cozy_up', 'ui_tick',
        'retry', 'tap',
      ];
      for (final event in extra) {
        expect(scheme.events[event], isNotNull, reason: event);
      }
    });

    test('каждый файл схемы существует в assets', () {
      for (final file in scheme.allFiles) {
        expect(File('assets/audio/$file').existsSync(), isTrue, reason: file);
      }
    });

    test('у каждого питомца свой голосок', () {
      final characters = (_phrases()['characters'] as Map).keys.toSet();
      expect(scheme.pets.keys.toSet(), characters);
      final all = <String>[];
      for (final files in scheme.pets.values) {
        all.addAll(files);
      }
      expect(all.toSet().length, all.length);
    });

    test('в звуке нет синтетики: только mp3', () {
      for (final file in scheme.allFiles) {
        expect(file, endsWith('.mp3'), reason: file);
      }
    });

    test('без события нет схемы', () {
      final broken = _raw();
      ((broken['events'] as Map)).remove('coin');
      expect(() => SoundScheme.fromJson(broken), throwsArgumentError);
    });

    test('фоновые темы на месте и файлы существуют', () {
      for (final name in const ['main', 'calm']) {
        expect(scheme.music[name], isNotNull, reason: name);
      }
      expect(service.musicFor('main', musicOn: true),
          'assets/audio/music/main_theme.mp3');
      expect(service.musicFor('main', musicOn: false), isNull);
      expect(() => service.musicFor('night', musicOn: true),
          throwsArgumentError);
    });

    test('питомец без голоска не принимается', () {
      final broken = _raw();
      (broken['pets'] as Map)['fox'] = <String>[];
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
          'assets/audio/sfx/coin.mp3');
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

    test('голосок своего вида, варианты чередуются', () {
      final first = service.petSound('puppy', turn: 0, soundOn: true);
      final second = service.petSound('puppy', turn: 1, soundOn: true);
      expect(first, startsWith('assets/audio/pets/puppy_'));
      expect(second, startsWith('assets/audio/pets/puppy_'));
      expect(first, isNot(second));
      expect(service.petSound('puppy', turn: 2, soundOn: true), first);
    });

    test('незнакомый вид и выключенный звук — тишина', () {
      expect(service.petSound('unicorn', turn: 0, soundOn: true), isNull);
      expect(service.petSound('fox', turn: 0, soundOn: false), isNull);
    });
  });
}
