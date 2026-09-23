import 'dart:convert';
import 'dart:io';

import 'package:finni/domain/game_clock.dart';
import 'package:finni/domain/models/models.dart';
import 'package:finni/domain/services/phrase_service.dart';
import 'package:finni/domain/stop_words.dart';
import 'package:flutter_test/flutter_test.dart';

Map<String, Object?> _raw() =>
    (jsonDecode(File('assets/content/phrases.json').readAsStringSync()) as Map)
        .cast<String, Object?>();

Map<String, Object?> _phraseJson(Map<String, Object?> raw, String id) =>
    ((raw['phrases'] as List).firstWhere((p) => (p as Map)['id'] == id) as Map)
        .cast<String, Object?>();

List<String> _strings(Object? node) {
  if (node is String) return [node];
  if (node is List) return [for (final v in node) ..._strings(v)];
  if (node is Map) return [for (final v in node.values) ..._strings(v)];
  return const [];
}

void main() {
  final catalog = PhraseCatalog.fromJson(_raw());

  PhraseService service({String character = 'fox', DemoClock? clock}) =>
      PhraseService(
        catalog: catalog,
        clock: clock ?? DemoClock(),
        character: character,
      );

  group('банк реплик', () {
    test('четыре характера, реплик хватает на все случаи', () {
      expect(catalog.characters.keys,
          containsAll(['fox', 'robot', 'puppy', 'dragon']));
      expect(catalog.phrases.length, greaterThanOrEqualTo(80));
    });

    test('каждая категория и каждый триггер чем-то закрыты', () {
      for (final category in catalog.categories.keys) {
        expect(catalog.byCategory(category), isNotEmpty, reason: category);
      }
      for (final trigger in catalog.triggers.keys) {
        expect(catalog.byTrigger(trigger), isNotEmpty, reason: trigger);
      }
    });

    test('ни одна реплика не длиннее десяти слов', () {
      for (final phrase in catalog.phrases) {
        for (final entry in phrase.templates.entries) {
          expect(phraseWordCount(entry.value),
              lessThanOrEqualTo(catalog.rules.maxWords),
              reason: '${phrase.id}/${entry.key}: ${entry.value}');
        }
      }
    });

    test('характер меняет подачу, а не подставляемые числа', () {
      for (final phrase in catalog.phrases) {
        final sets =
            phrase.templates.values.map(phrasePlaceholders).toList();
        for (final set in sets) {
          expect(set, sets.first, reason: phrase.id);
        }
      }
    });

    test('озвученные реплики обходятся без чисел', () {
      for (final phrase in catalog.phrases) {
        if (phrase.tts) {
          expect(phrase.placeholders, isEmpty, reason: phrase.id);
        }
      }
    });

    test('каждое подставляемое число объявлено триггером', () {
      for (final phrase in catalog.phrases) {
        final declared = catalog.triggers[phrase.trigger]!.placeholders;
        for (final placeholder in phrase.valuePlaceholders) {
          expect(declared, contains(placeholder), reason: phrase.id);
        }
      }
    });

    test('у кнопки есть и текст, и маршрут', () {
      for (final phrase in catalog.phrases) {
        final action = phrase.action;
        if (action != null) {
          expect(action.label, isNotEmpty, reason: phrase.id);
          expect(action.route, isNotEmpty, reason: phrase.id);
        }
      }
    });
  });

  test('стоп-лист не встречается ни в одной реплике', () {
    final offenders = <String>[];
    for (final text in _strings(_raw())) {
      final found = findStopWords(text);
      if (found.isNotEmpty) offenders.add('$found -> $text');
    }
    expect(offenders, isEmpty, reason: offenders.join('\n'));
  });

  group('каталог ловит битый банк', () {
    test('реплика длиннее лимита', () {
      final broken = _raw();
      (_phraseJson(broken, 'greeting_default')['templates'] as Map)['fox'] =
          'Раз два три четыре пять шесть семь восемь девять десять одиннадцать';
      expect(() => PhraseCatalog.fromJson(broken), throwsArgumentError);
    });

    test('характер поменял набор чисел', () {
      final broken = _raw();
      (_phraseJson(broken, 'not_enough_money')['templates'] as Map)['puppy'] =
          'Не хватает немного. Ничего, подождём вместе!';
      expect(() => PhraseCatalog.fromJson(broken), throwsArgumentError);
    });

    test('озвучка с подставляемым числом', () {
      final broken = _raw();
      final templates = _phraseJson(broken, 'greeting_default')['templates'] as Map;
      for (final key in templates.keys.toList()) {
        templates[key] = 'Привет! До {goalGenitive} совсем чуть-чуть!';
      }
      expect(() => PhraseCatalog.fromJson(broken), throwsArgumentError);
    });

    test('число, которого триггер не передаёт', () {
      final broken = _raw();
      final phrase = _phraseJson(broken, 'greeting_default');
      phrase['tts'] = false;
      final templates = phrase['templates'] as Map;
      for (final key in templates.keys.toList()) {
        templates[key] = 'Привет! Не хватает {gap}!';
      }
      expect(() => PhraseCatalog.fromJson(broken), throwsArgumentError);
    });

    test('нет варианта для одного из характеров', () {
      final broken = _raw();
      (_phraseJson(broken, 'greeting_default')['templates'] as Map)
          .remove('puppy');
      expect(() => PhraseCatalog.fromJson(broken), throwsArgumentError);
    });

    test('ссылка на несуществующий триггер', () {
      final broken = _raw();
      _phraseJson(broken, 'greeting_default')['trigger'] = 'no_such_trigger';
      expect(() => PhraseCatalog.fromJson(broken), throwsArgumentError);
    });
  });

  group('выбор реплики', () {
    test('без фактов срабатывает безусловная', () {
      expect(service().say('app_open')!.id, 'greeting_default');
    });

    test('условие поднимает более уместную реплику', () {
      expect(service().say('app_open', facts: {'timeOfDay': 'morning'})!.id,
          'greeting_morning');
      expect(service().say('app_open', facts: {'statLow': 'satiety'})!.id,
          'greeting_low_satiety');
    });

    test('условие «не меньше» сравнивает, а не проверяет равенство', () {
      final line = service().say('app_open', facts: {'goalProgress': 80});
      expect(line!.id, 'greeting_goal_close');
      expect(service().say('app_open', facts: {'goalProgress': 40})!.id,
          'greeting_default');
    });

    test('условие-список ловит любой из вариантов', () {
      for (final group in ['water_light', 'cleaning']) {
        expect(service().say('purchase_done', facts: {'itemGroup': group})!.id,
            'purchase_care');
      }
      expect(service().say('purchase_done', facts: {'itemGroup': 'snack'})!.id,
          'purchase_snack');
    });

    test('диапазон в условии', () {
      final idleTask = catalog.byId('idle_task')!;
      expect(idleTask.condition.matches({'tasksLeftToday': 2}), isTrue);
      expect(idleTask.condition.matches({'tasksLeftToday': 0}), isFalse);
      expect(idleTask.condition.matches(const {}), isFalse);
    });

    test('на неизвестный триггер питомец молчит, а не падает', () {
      expect(service().say('no_such_trigger'), isNull);
    });

    test('реплика не повторяется подряд', () {
      final pet = service();
      final first = pet.say('task_wrong', facts: {'attempt': 2})!.id;
      final second = pet.say('task_wrong', facts: {'attempt': 2})!.id;
      expect(first, 'task_wrong_again');
      expect(second, isNot(first));
      expect(pet.say('task_wrong', facts: {'attempt': 2})!.id, first);
    });

    test('кулдаун держит реплику до срока', () {
      final clock = DemoClock();
      final pet = service(clock: clock);

      expect(pet.say('shop_open')!.id, 'shop_open_hint');
      expect(pet.say('shop_open'), isNull);
      expect(pet.isOnCooldown('shop_open_hint'), isTrue);

      clock.advance(const Duration(seconds: 301));
      expect(pet.isOnCooldown('shop_open_hint'), isFalse);
      expect(pet.say('shop_open')!.id, 'shop_open_hint');
    });

    test('предпросмотр ничего не отмечает', () {
      final pet = service();
      final preview = pet.preview('shop_open')!;
      expect(preview.id, 'shop_open_hint');
      expect(pet.lastShownId, isNull);
      expect(pet.isOnCooldown('shop_open_hint'), isFalse);
      expect(pet.say('shop_open')!.id, 'shop_open_hint');
    });

    test('forget возвращает питомца в исходное состояние', () {
      final pet = service();
      pet.say('shop_open');
      pet.forget();
      expect(pet.lastShownId, isNull);
      expect(pet.say('shop_open')!.id, 'shop_open_hint');
    });
  });

  group('текст реплики', () {
    test('числа подставляются и слова согласуются', () {
      final pet = service();
      expect(pet.say('day_started', values: {'income': 1})!.textRu,
          'Новый день — и 1 монета! Есть идея!');
      pet.forget();
      expect(pet.say('day_started', values: {'income': 2})!.textRu,
          contains('2 монеты'));
      pet.forget();
      expect(pet.say('day_started', values: {'income': 40})!.textRu,
          contains('40 монет'));
    });

    test('дни тоже согласуются', () {
      final line = service().say('day_summary',
          facts: {'savingStreak': 5}, values: {'days': 5})!;
      expect(line.textRu, contains('5 дней'));
    });

    test('забытое число — ошибка разработчика, а не пустая реплика', () {
      expect(() => service().say('day_started'), throwsArgumentError);
    });

    test('характер меняет слова, но не повод', () {
      final fox = service().say('goal_reached')!;
      final puppy = service(character: 'puppy').say('goal_reached')!;
      expect(fox.id, puppy.id);
      expect(fox.emotion, PhraseEmotion.celebrate);
      expect(fox.textRu, isNot(puppy.textRu));
      expect(puppy.textRu, contains('Гав'));
    });

    test('смена характера на лету', () {
      final pet = service();
      final before = pet.say('goal_reached')!.textRu;
      pet.forget();
      pet.switchCharacter('dragon');
      expect(pet.say('goal_reached')!.textRu, isNot(before));
      expect(() => pet.switchCharacter('unicorn'), throwsArgumentError);
    });

    test('кнопка доезжает до реплики', () {
      final line = service().say('purchase_not_enough', values: {'gap': 15})!;
      expect(line.textRu, 'Ой! Не хватает 15 монет. Есть идея — придумаем?');
      expect(line.action!.route, 'not_enough_options');
      expect(line.tts, isFalse);
    });

    test('реплику можно взять по id, минуя выбор', () {
      expect(service().lineOf('praise_goal_reached')!.emotion,
          PhraseEmotion.celebrate);
      expect(service().lineOf('no_such'), isNull);
    });
  });
}
