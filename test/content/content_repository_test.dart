import 'dart:convert';
import 'dart:io';

import 'package:finni/content/content_repository.dart';
import 'package:finni/domain/models/models.dart';
import 'package:finni/domain/services/task_engine.dart';
import 'package:finni/domain/stop_words.dart';
import 'package:flutter_test/flutter_test.dart';

Map<String, Object?> _raw(String file) =>
    (jsonDecode(File('assets/content/$file').readAsStringSync()) as Map)
        .cast<String, Object?>();

ContentRepository _repository({
  Map<String, Map<String, Object?> Function(Map<String, Object?> json)> patch =
      const {},
  Map<String, String> replace = const {},
  void Function(ContentIssue issue)? onIssue,
}) =>
    ContentRepository(
      (file) async {
        final text = replace[file];
        if (text != null) return text;
        final change = patch[file];
        if (change == null) return File('assets/content/$file').readAsString();
        return jsonEncode(change(_raw(file)));
      },
      onIssue: onIssue,
    );

List<Map<String, Object?>> _records(Map<String, Object?> json, String key) => [
      for (final item in json[key] as List) (item as Map).cast<String, Object?>(),
    ];

Map<String, Object?> _copy(Object? json) =>
    (jsonDecode(jsonEncode(json)) as Map).cast<String, Object?>();

List<String> _childTexts(Object? node, [String key = '']) {
  if (key == 'forAdult' || key == 'rules') return const [];
  if (node is String) return [node];
  if (node is List) return [for (final v in node) ..._childTexts(v)];
  if (node is Map) {
    return [
      for (final e in node.entries) ..._childTexts(e.value, '${e.key}'),
    ];
  }
  return const [];
}

void main() {
  group('настоящий контент', () {
    late ContentBundle bundle;

    setUpAll(() async {
      bundle = await _repository().load();
    });

    test('все файлы грузятся без единого замечания', () {
      expect(bundle.issues, isEmpty, reason: bundle.issues.join('\n'));
      expect(bundle.isClean, isTrue);
    });

    test('каждый каталог не пустой', () {
      expect(bundle.competences.competences, isNotEmpty);
      expect(bundle.shop.items, isNotEmpty);
      expect(bundle.goals.goals, isNotEmpty);
      expect(bundle.tasks.tasks, isNotEmpty);
      expect(bundle.events.events, isNotEmpty);
      expect(bundle.titles.titles, isNotEmpty);
      expect(bundle.glossary.terms, isNotEmpty);
      expect(bundle.rooms.rooms, isNotEmpty);
      expect(bundle.phrases.phrases, isNotEmpty);
      expect(bundle.summaries.overall, isNotEmpty);
    });

    test('в каждом файле id записей уникальны', () {
      final lists = {
        'competences.json': 'competences',
        'shop.json': 'items',
        'goals.json': 'goals',
        'tasks.json': 'tasks',
        'events.json': 'events',
        'titles.json': 'titles',
        'glossary.json': 'terms',
        'rooms.json': 'rooms',
        'phrases.json': 'phrases',
      };
      for (final entry in lists.entries) {
        final ids = [for (final r in _records(_raw(entry.key), entry.value)) r['id']];
        expect(ids.toSet().length, ids.length, reason: entry.key);
      }
    });

    test('ссылки на компетенции разрешаются', () {
      final known = {for (final c in bundle.competences.competences) c.id};
      expect(known, containsAll(bundle.tasks.competenceIds()));
      expect(known, containsAll(bundle.goals.competenceIds));
      expect(known, containsAll(bundle.events.competenceIds));
      expect(known, containsAll(bundle.titles.titles.map((t) => t.competenceId)));
      expect(known, containsAll(bundle.glossary.competenceIds));
    });

    test('звания ссылаются на существующие темы', () {
      final themeIds = {for (final t in bundle.tasks.themes) t.id};
      for (final title in bundle.titles.titles) {
        final condition = title.condition;
        if (condition is ThemeCondition) {
          expect(themeIds, contains(condition.themeId), reason: title.id);
        }
      }
      expect(bundle.titles.problems, isEmpty);
    });

    test('комната ждёт только то, что есть в магазине и целях', () {
      final shopIds = {for (final i in bundle.shop.items) i.id};
      final goalIds = {for (final g in bundle.goals.goals) g.id};
      for (final room in bundle.rooms.rooms) {
        expect(shopIds, contains(room.defaultWallpaperId), reason: room.id);
        for (final spot in room.spots) {
          final known = spot.type == RoomSpotType.goal ? goalIds : shopIds;
          expect(known, containsAll(spot.accepts), reason: '${room.id}/${spot.id}');
        }
      }
    });

    test('события меняют цены только существующих товаров', () {
      for (final event in bundle.events.events) {
        for (final delta in event.priceDeltas) {
          expect(bundle.shop.byId(delta.itemId), isNotNull, reason: event.id);
        }
      }
      for (final id in bundle.events.events.map((e) => e.id)) {
        expect(bundle.events.byId(id), isNotNull);
      }
      for (final id in bundle.events.settings.sequence) {
        expect(bundle.events.byId(id), isNotNull, reason: id);
      }
    });

    test('в каждом событии есть вариант без траты', () {
      for (final event in bundle.events.events) {
        expect(event.options.any((o) => o.isFree), isTrue, reason: event.id);
      }
    });

    test('нет пустых текстов ни в одном файле', () {
      for (final file in ContentRepository.files) {
        for (final text in _childTexts(_raw(file))) {
          expect(text.trim(), isNotEmpty, reason: file);
        }
      }
    });

    test('в новых текстах для ребёнка нет слов из стоп-листа', () {
      for (final file in const [
        'events.json',
        'glossary.json',
        'rooms.json',
        'summaries.json',
        'titles.json',
      ]) {
        for (final text in _childTexts(_raw(file))) {
          expect(findStopWords(text), isEmpty, reason: '$file: $text');
        }
      }
    });

    test('параметры экономики приходят из economy.json', () {
      final params = bundle.economy.params;
      final raw = _raw('economy.json');
      expect(params.day.income, (raw['day'] as Map)['income']);
      expect(params.plan.step, (raw['plan'] as Map)['step']);
      expect(params.plan.directions.keys,
          containsAll(PlanRules.requiredDirections));
      expect(params.tasks.repeatReward, (raw['tasks'] as Map)['repeatReward']);
      expect(params.cooldownsMinutes['petChore'], isNotNull);
    });

    test('события приходят по предсказуемому расписанию раз в 2–3 дня', () {
      final days = bundle.economy.params.events.eventDaysUpTo(15);
      expect(days, [3, 5, 8, 10, 13, 15]);
      for (var i = 1; i < days.length; i++) {
        expect(days[i] - days[i - 1], inInclusiveRange(2, 3));
      }
      expect(bundle.economy.params.events.eventDaysUpTo(15), days);
    });

    test('уровни уюта не заканчиваются', () {
      final levels = bundle.economy.params.cozyLevels;
      expect(levels.levelFor(0).level, 1);
      expect(levels.levelFor(30).level, 2);
      expect(levels.levelFor(209).level, 4);
      expect(levels.levelFor(210).level, 5);
      expect(levels.levelFor(310).level, 6);
      expect(levels.levelFor(310).title, contains('1'));
    });

    test('словарик ищет по началу слова', () {
      expect(bundle.glossary.search('копил').map((t) => t.id), contains('savings'));
      expect(bundle.glossary.search(''), bundle.glossary.terms);
    });

    test('в итогах дня причины очков совпадают с факторами роста', () {
      expect(bundle.summaries.pointReasons.keys, GrowthFactor.values);
      expect(bundle.summaries.missedReasons.keys, GrowthFactor.values);
      expect(bundle.summaries.tomorrow.any((t) => t.isDefault), isTrue);
    });
  });

  group('новое задание добавляется одной записью в JSON', () {
    test('задание из JSON грузится и решается движком без правки кода', () async {
      final bundle = await _repository(patch: {
        'tasks.json': (json) {
          final tasks = _records(json, 'tasks');
          final clone = _copy(tasks.firstWhere((t) => t['id'] == 'payments_sort_needs'));
          clone['id'] = 'payments_sort_school';
          clone['title'] = 'Собираемся в школу';
          clone['order'] = 99;
          final easy = (clone['variants'] as Map)['easy'] as Map;
          easy['cards'] = [
            {'id': 'pen', 'label': 'Ручка', 'iconId': 'icon_card_pen', 'bin': 'mandatory', 'why': 'Ручкой пишут на уроке.'},
            {'id': 'sticker', 'label': 'Наклейка', 'iconId': 'icon_card_stickers', 'bin': 'optional', 'why': 'Наклейка для радости.'},
          ];
          return {...json, 'tasks': [...tasks, clone]};
        },
      }).load();

      expect(bundle.issues, isEmpty, reason: bundle.issues.join('\n'));
      final task = bundle.tasks.byId('payments_sort_school');
      expect(task, isNotNull);
      expect(bundle.tasks.tasks.last.id, 'payments_sort_school');

      final engine = TaskEngine(
          catalog: bundle.tasks, rewards: bundle.economy.params.tasks);
      final session = engine.start('payments_sort_school', TaskDifficulty.easy);
      final feedback = session.submit(
          const SortAnswer({'pen': 'mandatory', 'sticker': 'optional'}));
      expect(feedback.isCorrect, isTrue);
      expect(feedback.completion!.coins, task!.reward.correct);
    });
  });

  group('битый контент пропускается, а не роняет приложение', () {
    test('задание без объяснения выбрасывается, остальные на месте', () async {
      final issues = <ContentIssue>[];
      final bundle = await _repository(
        onIssue: issues.add,
        patch: {
          'tasks.json': (json) {
            final tasks = _records(json, 'tasks');
            final broken = _copy(tasks.first);
            ((broken['variants'] as Map)['easy'] as Map).remove('explanationCorrect');
            return {...json, 'tasks': [broken, ...tasks.skip(1)]};
          },
        },
      ).load();

      final all = _records(_raw('tasks.json'), 'tasks');
      expect(bundle.tasks.byId('${all.first['id']}'), isNull);
      expect(bundle.tasks.tasks.length, all.length - 1);
      expect(bundle.issues.single.file, 'tasks.json');
      expect(bundle.issues.single.recordId, all.first['id']);
      expect(bundle.issues.single.fatal, isFalse);
      expect(issues, bundle.issues);
    });

    test('задание со ссылкой на несуществующую компетенцию выбрасывается', () async {
      final bundle = await _repository(patch: {
        'tasks.json': (json) {
          final tasks = _records(json, 'tasks');
          final broken = _copy(tasks.last);
          broken['id'] = 'orphan';
          broken['competenceIds'] = {
            'easy': ['nobody_knows'],
            'hard': ['nobody_knows'],
          };
          return {...json, 'tasks': [...tasks, broken]};
        },
      }).load();

      expect(bundle.tasks.byId('orphan'), isNull);
      expect(bundle.issues.single.recordId, 'orphan');
      expect(bundle.issues.single.message, contains('nobody_knows'));
    });

    test('задание в несуществующей теме выбрасывается при сборке каталога', () async {
      final bundle = await _repository(patch: {
        'tasks.json': (json) {
          final tasks = _records(json, 'tasks');
          final broken = _copy(tasks.first);
          broken['id'] = 'lost';
          broken['themeId'] = 'space';
          return {...json, 'tasks': [...tasks, broken]};
        },
      }).load();

      expect(bundle.tasks.byId('lost'), isNull);
      expect(bundle.issues.single.recordId, 'lost');
      expect(bundle.tasks.tasks.length, _records(_raw('tasks.json'), 'tasks').length);
    });

    test('повтор id: остаётся первая запись', () async {
      final bundle = await _repository(patch: {
        'shop.json': (json) {
          final items = _records(json, 'items');
          final twin = _copy(items[1]);
          twin['title'] = 'Двойник';
          return {...json, 'items': [...items, twin]};
        },
      }).load();

      final id = '${_records(_raw('shop.json'), 'items')[1]['id']}';
      expect(bundle.shop.byId(id)!.title, isNot('Двойник'));
      expect(bundle.issues.single.message, contains('повторяется'));
    });

    test('запись-не-объект и запись с пустым текстом пропускаются', () async {
      final bundle = await _repository(patch: {
        'glossary.json': (json) {
          final terms = _records(json, 'terms');
          final empty = _copy(terms.first)
            ..['id'] = 'blank'
            ..['definition'] = '   ';
          return {...json, 'terms': [42, ...terms, empty]};
        },
      }).load();

      expect(bundle.glossary.terms.length, _records(_raw('glossary.json'), 'terms').length);
      expect(bundle.glossary.byId('blank'), isNull);
      expect(bundle.issues.map((i) => i.recordId), ['#1', 'blank']);
    });

    test('событие с чужим товаром выбрасывается и уходит из очереди', () async {
      final bundle = await _repository(patch: {
        'events.json': (json) {
          final events = _records(json, 'events');
          final priceUp = events.firstWhere((e) => e['id'] == 'price_up');
          priceUp['priceDeltas'] = [
            {'itemId': 'caviar', 'delta': 5, 'days': 1},
          ];
          return {...json, 'events': events};
        },
      }).load();

      expect(bundle.events.byId('price_up'), isNull);
      expect(bundle.events.settings.sequence, isNot(contains('price_up')));
      expect(bundle.issues.map((i) => i.recordId), containsAll(['price_up', 'sequence']));
    });

    test('реплика про несуществующее событие выбрасывается', () async {
      final bundle = await _repository(patch: {
        'phrases.json': (json) {
          final phrases = _records(json, 'phrases');
          final broken = _copy(phrases.firstWhere((p) => p['id'] == 'event_rain'));
          broken['id'] = 'event_snow';
          broken['condition'] = {'eventId': 'snow'};
          return {...json, 'phrases': [...phrases, broken]};
        },
      }).load();

      expect(bundle.phrases.byId('event_snow'), isNull);
      expect(bundle.issues.single.recordId, 'event_snow');
    });

    test('ошибку, которую видит только каталог, находим поиском записи', () async {
      final bundle = await _repository(patch: {
        'phrases.json': (json) {
          final phrases = _records(json, 'phrases');
          final long = _copy(phrases.first);
          long['id'] = 'too_long';
          long['templates'] = {
            for (final character in (json['characters'] as Map).keys)
              character: 'Раз два три четыре пять шесть семь восемь девять десять одиннадцать',
          };
          return {...json, 'phrases': [...phrases, long]};
        },
      }).load();

      expect(bundle.phrases.byId('too_long'), isNull);
      expect(bundle.phrases.phrases.length, _records(_raw('phrases.json'), 'phrases').length);
      expect(bundle.issues.single.recordId, 'too_long');
    });

    test('место в комнате для несуществующего товара: комната пропускается', () async {
      final bundle = await _repository(patch: {
        'rooms.json': (json) {
          final rooms = _records(json, 'rooms');
          final bedroom = rooms.firstWhere((r) => r['id'] == 'bedroom');
          final spots = [for (final s in bedroom['spots'] as List) (s as Map).cast<String, Object?>()];
          spots.firstWhere((s) => s['id'] == 'bed')['accepts'] = ['golden_bed'];
          bedroom['spots'] = spots;
          return {...json, 'rooms': rooms};
        },
      }).load();

      expect(bundle.rooms.byId('bedroom'), isNull);
      expect(bundle.rooms.byId('main'), isNotNull);
      expect(bundle.issues.single.message, contains('golden_bed'));
    });

    test('обязательная потребность питомца без товара выбрасывается', () async {
      final bundle = await _repository(patch: {
        'economy.json': (json) {
          final pet = (json['pet'] as Map).cast<String, Object?>();
          final needs = [...pet['needs'] as List, {
            'itemId': 'unicorn',
            'missedEffects': [
              {'stat': 'mood', 'delta': -5},
            ],
            'missedReason': 'Сегодня без единорога',
          }];
          return {...json, 'pet': {...pet, 'needs': needs}};
        },
      }).load();

      expect(bundle.economy.pet.needFor('unicorn'), isNull);
      expect(bundle.issues.single.recordId, 'unicorn');
    });

    test('нечитаемый файл — понятная ошибка вместо падения', () async {
      final repository = _repository(replace: {'glossary.json': '{ не json'});
      await expectLater(
        repository.load(),
        throwsA(isA<ContentLoadException>().having(
            (e) => e.issues.where((i) => i.fatal).map((i) => i.file),
            'fatal files',
            ['glossary.json'])),
      );
    });

    test('без списка записей файл не загружается, а не падает молча', () async {
      final repository = _repository(patch: {
        'titles.json': (json) => {...json}..remove('titles'),
      });
      await expectLater(repository.load(), throwsA(isA<ContentLoadException>()));
    });
  });
}
