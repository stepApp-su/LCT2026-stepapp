import 'dart:convert';

import '../domain/models/models.dart';

final class ContentIssue {
  const ContentIssue({
    required this.file,
    required this.message,
    this.recordId,
    this.fatal = false,
  });

  final String file;
  final String? recordId;
  final String message;
  final bool fatal;

  @override
  String toString() {
    final where = recordId == null ? file : '$file [$recordId]';
    return fatal ? '$where: $message (файл не загружен)' : '$where: $message';
  }
}

final class ContentLoadException implements Exception {
  const ContentLoadException(this.issues);

  final List<ContentIssue> issues;

  @override
  String toString() =>
      'Контент не загрузился: ${issues.where((i) => i.fatal).join('; ')}';
}

typedef ContentReader = Future<String> Function(String file);

final class ContentBundle {
  const ContentBundle({
    required this.competences,
    required this.shop,
    required this.economy,
    required this.goals,
    required this.tasks,
    required this.events,
    required this.titles,
    required this.glossary,
    required this.rooms,
    required this.phrases,
    required this.summaries,
    required this.levels,
    this.coach = CoachCatalog.empty,
    required this.issues,
  });

  final CompetenceCatalog competences;
  final ShopCatalog shop;
  final EconomyConfig economy;
  final GoalCatalog goals;
  final TaskCatalog tasks;
  final EventCatalog events;
  final TitleCatalog titles;
  final GlossaryCatalog glossary;
  final RoomCatalog rooms;
  final PhraseCatalog phrases;
  final SummaryTexts summaries;
  final LevelCatalog levels;
  final CoachCatalog coach;
  final List<ContentIssue> issues;

  bool get isClean => issues.isEmpty;
}

final class ContentRepository {
  ContentRepository(this.read, {this.onIssue});

  final ContentReader read;
  final void Function(ContentIssue issue)? onIssue;

  static const String competencesFile = 'competences.json';
  static const String shopFile = 'shop.json';
  static const String economyFile = 'economy.json';
  static const String goalsFile = 'goals.json';
  static const String tasksFile = 'tasks.json';
  static const String eventsFile = 'events.json';
  static const String titlesFile = 'titles.json';
  static const String glossaryFile = 'glossary.json';
  static const String roomsFile = 'rooms.json';
  static const String phrasesFile = 'phrases.json';
  static const String summariesFile = 'summaries.json';
  static const String levelsFile = 'levels.json';
  static const String coachFile = 'coach.json';

  static const List<String> files = [
    competencesFile,
    shopFile,
    economyFile,
    goalsFile,
    tasksFile,
    eventsFile,
    titlesFile,
    glossaryFile,
    roomsFile,
    phrasesFile,
    summariesFile,
    levelsFile,
    coachFile,
  ];

  Future<ContentBundle> load() async {
    final session = _Session(read, onIssue);

    final competences = await session.file(
      competencesFile,
      recordsPath: const ['competences'],
      check: (record, root) => Competence.fromJson(record),
      build: CompetenceCatalog.fromJson,
    );
    final competenceIds = {for (final c in competences.competences) c.id};

    List<String> unknownCompetences(Iterable<String> ids) => [
          for (final id in ids)
            if (!competenceIds.contains(id)) 'нет компетенции «$id»',
        ];

    final shop = await session.file(
      shopFile,
      recordsPath: const ['items'],
      check: (record, root) => ShopItem.fromJson(record),
      build: ShopCatalog.fromJson,
    );
    final shopIds = {for (final item in shop.items) item.id};
    final shopGroups = {for (final item in shop.items) item.group};

    final economy = await session.file(
      economyFile,
      recordsPath: const ['pet', 'needs'],
      idKey: 'itemId',
      references: (record) {
        final item = shop.byId('${record['itemId']}');
        if (item == null) return ['нет товара «${record['itemId']}»'];
        if (item.category != ExpenseCategory.mandatory) {
          return ['«${item.id}» не обязательная покупка'];
        }
        return const [];
      },
      build: EconomyConfig.fromJson,
    );
    final planDirections = economy.params.plan.directions.keys.toSet();

    final goals = await session.file(
      goalsFile,
      recordsPath: const ['goals'],
      check: (record, root) => Goal.fromJson(record),
      sanitize: (root) => session.filterStrings(
        goalsFile,
        root,
        'competenceIds',
        (id) => competenceIds.contains(id),
        'нет компетенции',
      ),
      build: GoalCatalog.fromJson,
    );
    final goalIds = {for (final goal in goals.goals) goal.id};

    final tasks = await session.file(
      tasksFile,
      recordsPath: const ['tasks'],
      check: (record, root) => TaskCatalog.validateTask(
        TaskDef.fromJson(record),
        TaskTexts.fromJson(jsonMap(root['texts'], 'texts')),
      ),
      references: (record) => [
        ...unknownCompetences(_taskCompetenceIds(record)),
        if (record['counterSource'] == 'plan.directions')
          for (final id in _taskCounterIds(record))
            if (!planDirections.contains(id)) 'нет направления плана «$id»',
      ],
      build: TaskCatalog.fromJson,
    );
    final themeIds = {for (final theme in tasks.themes) theme.id};

    final events = await session.file(
      eventsFile,
      recordsPath: const ['events'],
      check: (record, root) => GameEventDef.fromJson(record),
      references: (record) => [
        ...unknownCompetences(_strings(record['competenceIds'])),
        for (final delta in _maps(record['priceDeltas']))
          if (!shopIds.contains(delta['itemId'])) 'нет товара «${delta['itemId']}»',
      ],
      sanitize: (root) {
        final kept = {for (final event in _maps(root['events'])) event['id']};
        final settings = jsonMap(root['settings'], 'settings');
        return {
          ...root,
          'settings': session.filterStrings(
            eventsFile,
            settings,
            'sequence',
            kept.contains,
            'в очереди событие, которого нет',
          ),
        };
      },
      build: EventCatalog.fromJson,
    );
    final eventIds = {for (final event in events.events) event.id};

    final titles = await session.file(
      titlesFile,
      recordsPath: const ['titles'],
      check: (record, root) => TitleDef.fromJson(record),
      references: (record) {
        final condition = record['condition'];
        final themeId = condition is Map ? condition['themeId'] : null;
        return [
          ...unknownCompetences([if (record['competenceId'] is String) record['competenceId'] as String]),
          if (themeId != null && !themeIds.contains(themeId)) 'нет темы заданий «$themeId»',
        ];
      },
      build: TitleCatalog.fromJson,
    );

    final glossary = await session.file(
      glossaryFile,
      recordsPath: const ['terms'],
      check: (record, root) => GlossaryTerm.fromJson(record),
      references: (record) =>
          unknownCompetences([if (record['competenceId'] is String) record['competenceId'] as String]),
      build: GlossaryCatalog.fromJson,
    );

    final rooms = await session.file(
      roomsFile,
      recordsPath: const ['rooms'],
      check: (record, root) => RoomDef.fromJson(record),
      references: (record) {
        final problems = <String>[];
        final wallpaper = shop.byId('${record['defaultWallpaperId']}');
        if (wallpaper == null || wallpaper.kind != ShopItemKind.wallpaper) {
          problems.add('нет обоев «${record['defaultWallpaperId']}»');
        }
        for (final spot in _maps(record['spots'])) {
          final known = spot['type'] == 'goal' ? goalIds : shopIds;
          for (final id in _strings(spot['accepts'])) {
            if (!known.contains(id)) {
              problems.add('место «${spot['id']}» ждёт то, чего нет: «$id»');
            }
          }
          final kind = spot['acceptsKind'];
          if (kind != null && !ShopItemKind.values.any((k) => k.name == kind)) {
            problems.add('нет вида товаров «$kind»');
          }
        }
        return problems;
      },
      build: RoomCatalog.fromJson,
    );

    final phrases = await session.file(
      phrasesFile,
      recordsPath: const ['phrases'],
      check: (record, root) => PhraseDef.fromJson(record),
      references: (record) {
        final condition = record['condition'];
        if (condition is! Map) return const [];
        final problems = <String>[];
        final itemId = condition['itemId'];
        if (itemId != null && !shopIds.contains(itemId)) {
          problems.add('нет товара «$itemId»');
        }
        final eventId = condition['eventId'];
        if (eventId != null && !eventIds.contains(eventId)) {
          problems.add('нет события «$eventId»');
        }
        final taskType = condition['taskType'];
        if (taskType is String &&
            !TaskType.values.any((t) => t.name == taskType.toLowerCase())) {
          problems.add('нет типа заданий «$taskType»');
        }
        for (final group in _strings(condition['itemGroup'])) {
          if (!shopGroups.contains(group)) problems.add('нет группы товаров «$group»');
        }
        final kind = condition['itemKind'];
        if (kind != null && !ShopItemKind.values.any((k) => k.name == kind)) {
          problems.add('нет вида товаров «$kind»');
        }
        return problems;
      },
      build: PhraseCatalog.fromJson,
    );

    final summaries = await session.file(
      summariesFile,
      build: SummaryTexts.fromJson,
    );

    final levels = await session.file(
      levelsFile,
      recordsPath: const ['unlocks'],
      idKey: 'taskId',
      check: (record, root) => LevelUnlock.fromJson(record),
      references: (record) => [
        if (tasks.byId('${record['taskId']}') == null)
          'нет задания «${record['taskId']}»',
      ],
      build: LevelCatalog.fromJson,
    );

    final coach = await session.file(
      coachFile,
      recordsPath: const ['tours'],
      check: (record, root) => CoachTour.fromJson(record),
      build: CoachCatalog.fromJson,
    );

    return ContentBundle(
      competences: competences,
      shop: shop,
      economy: economy,
      goals: goals,
      tasks: tasks,
      events: events,
      titles: titles,
      glossary: glossary,
      rooms: rooms,
      phrases: phrases,
      summaries: summaries,
      levels: levels,
      coach: coach,
      issues: List.unmodifiable(session.issues),
    );
  }

  static Iterable<String> _taskCompetenceIds(Map<String, Object?> record) {
    final byDifficulty = record['competenceIds'];
    if (byDifficulty is! Map) return const [];
    return [for (final ids in byDifficulty.values) ..._strings(ids)];
  }

  static Iterable<String> _taskCounterIds(Map<String, Object?> record) {
    final variants = [
      if (record['variants'] case final Map map) ...map.values,
      if (record['levelVariants'] case final Map map) ...map.values,
      if (record['dailyVariants'] case final Object daily) daily,
    ];
    return {
      for (final entry in variants)
        for (final variant in entry is List ? entry : [entry])
          if (variant is Map)
            for (final counter in _maps(variant['counters']))
              if (counter['id'] is String) counter['id'] as String,
    };
  }
}

List<String> _strings(Object? raw) {
  if (raw is String) return [raw];
  if (raw is! List) return const [];
  return [for (final item in raw) if (item is String) item];
}

List<Map<String, Object?>> _maps(Object? raw) {
  if (raw is! List) return const [];
  return [for (final item in raw) if (item is Map) item.cast<String, Object?>()];
}

String? _emptyTextPath(Object? node, String path) {
  if (node is String) return node.trim().isEmpty ? path : null;
  if (node is List) {
    for (var i = 0; i < node.length; i++) {
      final found = _emptyTextPath(node[i], '$path[$i]');
      if (found != null) return found;
    }
  }
  if (node is Map) {
    for (final entry in node.entries) {
      final found =
          _emptyTextPath(entry.value, path.isEmpty ? '${entry.key}' : '$path.${entry.key}');
      if (found != null) return found;
    }
  }
  return null;
}

final class _Session {
  _Session(this.read, this.onIssue);

  final ContentReader read;
  final void Function(ContentIssue issue)? onIssue;
  final List<ContentIssue> issues = [];

  void report(ContentIssue issue) {
    issues.add(issue);
    onIssue?.call(issue);
  }

  ContentLoadException _fatal(String file, String message) {
    report(ContentIssue(file: file, message: message, fatal: true));
    return ContentLoadException(List.unmodifiable(issues));
  }

  Map<String, Object?> filterStrings(
    String file,
    Map<String, Object?> node,
    String key,
    bool Function(String value) keep,
    String message,
  ) {
    final raw = node[key];
    if (raw is! List) return node;
    final kept = <Object?>[];
    for (final value in raw) {
      if (value is String && keep(value)) {
        kept.add(value);
      } else {
        report(ContentIssue(file: file, recordId: key, message: '$message: «$value»'));
      }
    }
    return {...node, key: kept};
  }

  Future<T> file<T>(
    String name, {
    required T Function(Map<String, Object?> json) build,
    List<String> recordsPath = const [],
    String idKey = 'id',
    void Function(Map<String, Object?> record, Map<String, Object?> root)? check,
    List<String> Function(Map<String, Object?> record)? references,
    Map<String, Object?> Function(Map<String, Object?> root)? sanitize,
  }) async {
    Map<String, Object?> root;
    try {
      root = jsonMap(jsonDecode(await read(name)), name);
    } catch (error) {
      throw _fatal(name, 'файл не читается: $error');
    }

    List<Object?> records = const [];
    if (recordsPath.isNotEmpty) {
      Object? raw;
      try {
        raw = _at(root, recordsPath);
      } catch (_) {
        raw = null;
      }
      if (raw is! List) {
        throw _fatal(name, 'нет списка ${recordsPath.join('.')}');
      }
      records = _validRecords(name, root, raw, idKey, check, references);
      root = _replaceAt(root, recordsPath, records);
    }

    final emptyPath = _emptyTextPath(root, '');
    if (emptyPath != null) {
      report(ContentIssue(file: name, message: 'пустой текст в поле $emptyPath'));
    }

    if (sanitize != null) root = sanitize(root);
    return _buildIsolating(name, root, recordsPath, records, idKey, build);
  }

  List<Object?> _validRecords(
    String file,
    Map<String, Object?> root,
    List<Object?> raw,
    String idKey,
    void Function(Map<String, Object?> record, Map<String, Object?> root)? check,
    List<String> Function(Map<String, Object?> record)? references,
  ) {
    final kept = <Object?>[];
    final ids = <String>{};
    for (var i = 0; i < raw.length; i++) {
      final item = raw[i];
      if (item is! Map) {
        report(ContentIssue(file: file, recordId: '#${i + 1}', message: 'запись не объект'));
        continue;
      }
      final record = item.cast<String, Object?>();
      final rawId = record[idKey];
      final id = rawId is String && rawId.trim().isNotEmpty ? rawId : null;
      final label = id ?? '#${i + 1}';
      final problem = _problem(record, root, id, ids, idKey, check, references);
      if (problem != null) {
        report(ContentIssue(file: file, recordId: label, message: problem));
        continue;
      }
      ids.add(id!);
      kept.add(record);
    }
    return kept;
  }

  String? _problem(
    Map<String, Object?> record,
    Map<String, Object?> root,
    String? id,
    Set<String> ids,
    String idKey,
    void Function(Map<String, Object?> record, Map<String, Object?> root)? check,
    List<String> Function(Map<String, Object?> record)? references,
  ) {
    if (id == null) return 'нет $idKey';
    if (ids.contains(id)) return '$idKey повторяется';
    final emptyPath = _emptyTextPath(record, '');
    if (emptyPath != null) return 'пустой текст в поле $emptyPath';
    if (check != null) {
      try {
        check(record, root);
      } catch (error) {
        return '$error';
      }
    }
    if (references != null) {
      final List<String> problems;
      try {
        problems = references(record);
      } catch (error) {
        return '$error';
      }
      if (problems.isNotEmpty) return problems.join('; ');
    }
    return null;
  }

  T _buildIsolating<T>(
    String file,
    Map<String, Object?> root,
    List<String> recordsPath,
    List<Object?> records,
    String idKey,
    T Function(Map<String, Object?> json) build,
  ) {
    try {
      return build(root);
    } catch (error) {
      if (recordsPath.isNotEmpty) {
        for (var i = 0; i < records.length; i++) {
          final without = [...records]..removeAt(i);
          try {
            final result = build(_replaceAt(root, recordsPath, without));
            final record = records[i];
            report(ContentIssue(
              file: file,
              recordId: record is Map ? '${record[idKey]}' : '#${i + 1}',
              message: '$error',
            ));
            return result;
          } catch (_) {
            continue;
          }
        }
      }
      throw _fatal(file, '$error');
    }
  }
}

Object? _at(Map<String, Object?> root, List<String> path) {
  Object? node = root;
  for (final key in path) {
    node = jsonMap(node, key)[key];
  }
  return node;
}

Map<String, Object?> _replaceAt(
  Map<String, Object?> node,
  List<String> path,
  Object? value,
) {
  final copy = Map<String, Object?>.of(node);
  final key = path.first;
  copy[key] = path.length == 1
      ? value
      : _replaceAt(jsonMap(node[key], key), path.sublist(1), value);
  return copy;
}
