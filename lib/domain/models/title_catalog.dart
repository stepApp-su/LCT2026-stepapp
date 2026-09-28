import 'growth.dart';

enum DayMark {
  active,
  planMade,
  mandatoryPaid,
  onPlan,
  saved,
  savedAsPlanned,
  taskDone,
}

sealed class TitleCondition {
  const TitleCondition();

  factory TitleCondition.fromJson(Map<String, Object?> json) {
    const where = 'condition';
    final type = _read<String>(json, 'type', where);
    switch (type) {
      case 'start':
        _onlyKeys(json, const {'type'}, where);
        return const StartCondition();
      case 'days' || 'streak':
        _onlyKeys(
            json, const {'type', 'count', 'marks', 'planTolerance'}, where);
        final tolerance = json['planTolerance'];
        return DaysCondition.create(
          count: _read<int>(json, 'count', where),
          marks: [
            for (final (i, name)
                in _read<List<Object?>>(json, 'marks', where).indexed)
              _mark(name, '$where.marks[$i]')
          ],
          planTolerance: tolerance == null
              ? null
              : _tolerance(
                  _read<Map<String, Object?>>(json, 'planTolerance', where),
                  '$where.planTolerance'),
          inARow: type == 'streak',
        );
      case 'theme':
        _onlyKeys(json, const {'type', 'themeId'}, where);
        return ThemeCondition.create(
            themeId: _read<String>(json, 'themeId', where));
      case 'goals':
        _onlyKeys(json, const {'type', 'count'}, where);
        return GoalsCondition.create(count: _read<int>(json, 'count', where));
      case 'reserve':
        _onlyKeys(json, const {'type', 'count'}, where);
        return ReserveCondition.create(days: _read<int>(json, 'count', where));
      case 'careful':
        _onlyKeys(json, const {'type', 'count'}, where);
        return CarefulCondition.create(count: _read<int>(json, 'count', where));
      default:
        throw ArgumentError.value(
            type, '$where.type', 'неизвестный тип условия');
    }
  }

  Set<String> get placeholders;

  Map<String, String> get values;
}

final class StartCondition extends TitleCondition {
  const StartCondition();

  @override
  Set<String> get placeholders => const {};

  @override
  Map<String, String> get values => const {};
}

final class DaysCondition extends TitleCondition {
  const DaysCondition._({
    required this.count,
    required this.marks,
    required this.planTolerance,
    required this.inARow,
  });

  factory DaysCondition.create({
    required int count,
    required List<DayMark> marks,
    PlanTolerance? planTolerance,
    bool inARow = false,
  }) {
    _requireCount(count, 'count');
    if (marks.isEmpty) {
      throw ArgumentError.value(
          marks, 'marks', 'нужен хотя бы один признак дня');
    }
    if (marks.toSet().length != marks.length) {
      throw ArgumentError.value(marks, 'marks', 'признаки повторяются');
    }
    final needsTolerance = marks.contains(DayMark.onPlan);
    if (needsTolerance && planTolerance == null) {
      throw ArgumentError.value(
          null, 'planTolerance', 'нужен для признака «onPlan»');
    }
    if (!needsTolerance && planTolerance != null) {
      throw ArgumentError.value(planTolerance.toJson(), 'planTolerance',
          'имеет смысл только с признаком «onPlan»');
    }
    return DaysCondition._(
      count: count,
      marks: Set.unmodifiable(marks),
      planTolerance: planTolerance,
      inARow: inARow,
    );
  }

  final int count;
  final Set<DayMark> marks;
  final PlanTolerance? planTolerance;
  final bool inARow;

  @override
  Set<String> get placeholders => const {'count', 'day'};

  @override
  Map<String, String> get values => {'count': '$count'};
}

final class ThemeCondition extends TitleCondition {
  const ThemeCondition._(this.themeId);

  factory ThemeCondition.create({required String themeId}) {
    _requireText(themeId, 'themeId');
    return ThemeCondition._(themeId);
  }

  final String themeId;

  @override
  Set<String> get placeholders => const {'theme'};

  @override
  Map<String, String> get values => const {};
}

final class GoalsCondition extends TitleCondition {
  const GoalsCondition._(this.count);

  factory GoalsCondition.create({required int count}) {
    _requireCount(count, 'count');
    return GoalsCondition._(count);
  }

  final int count;

  @override
  Set<String> get placeholders => const {'count'};

  @override
  Map<String, String> get values => {'count': '$count'};
}

final class CarefulCondition extends TitleCondition {
  const CarefulCondition._(this.count);

  factory CarefulCondition.create({required int count}) {
    _requireCount(count, 'count');
    return CarefulCondition._(count);
  }

  final int count;

  @override
  Set<String> get placeholders => const {'count'};

  @override
  Map<String, String> get values => {'count': '$count'};
}

final class ReserveCondition extends TitleCondition {
  const ReserveCondition._(this.days);

  factory ReserveCondition.create({required int days}) {
    _requireCount(days, 'count');
    return ReserveCondition._(days);
  }

  final int days;

  @override
  Set<String> get placeholders => const {'count', 'day'};

  @override
  Map<String, String> get values => {'count': '$days'};
}

final class TitleDef {
  const TitleDef._({
    required this.id,
    required this.title,
    required this.description,
    required this.iconId,
    required this.competenceId,
    required this.attributeId,
    required this.condition,
  });

  factory TitleDef.create({
    required String id,
    required String title,
    required String description,
    required String iconId,
    required String competenceId,
    String attributeId = '',
    required TitleCondition condition,
  }) {
    if (id.trim().isEmpty || id.contains(RegExp(r'\s'))) {
      throw ArgumentError.value(id, 'id', 'непустой, без пробелов');
    }
    _requireText(title, 'title');
    _requireText(iconId, 'iconId');
    _requireText(competenceId, 'competenceId');
    _requireDescription(description, condition);
    return TitleDef._(
      id: id,
      title: title,
      description: description,
      iconId: iconId,
      competenceId: competenceId,
      attributeId: attributeId,
      condition: condition,
    );
  }

  factory TitleDef.fromJson(Map<String, Object?> json) {
    _onlyKeys(json, _keys);
    return TitleDef.create(
      id: _read<String>(json, 'id'),
      title: _read<String>(json, 'title'),
      description: _read<String>(json, 'description'),
      iconId: _read<String>(json, 'iconId'),
      competenceId: _read<String>(json, 'competenceId'),
      attributeId:
          json['attributeId'] == null ? '' : _read<String>(json, 'attributeId'),
      condition: TitleCondition.fromJson(
          _read<Map<String, Object?>>(json, 'condition')),
    );
  }

  static const _keys = {
    'id',
    'title',
    'description',
    'iconId',
    'competenceId',
    'attributeId',
    'condition',
  };

  final String id;
  final String title;
  final String description;
  final String iconId;
  final String competenceId;
  final String attributeId;
  final TitleCondition condition;
}

final class TitleTexts {
  const TitleTexts._({required this.earned});

  factory TitleTexts.create({required String earned}) {
    _requireText(earned, 'earned');
    if (!earned.contains('{title}')) {
      throw ArgumentError.value(earned, 'earned', 'нужен {title}');
    }
    return TitleTexts._(earned: earned);
  }

  factory TitleTexts.fromJson(Map<String, Object?> json) {
    _onlyKeys(json, const {'earned'}, 'texts');
    return TitleTexts.create(earned: _read<String>(json, 'earned', 'texts'));
  }

  final String earned;
}

final class TitleCatalog {
  const TitleCatalog._({
    required this.schemaVersion,
    required this.texts,
    required this.titles,
    required this.problems,
  });

  factory TitleCatalog.create({
    int schemaVersion = 1,
    required TitleTexts texts,
    required List<TitleDef> titles,
    List<String> problems = const [],
  }) {
    if (schemaVersion < 1) {
      throw ArgumentError.value(schemaVersion, 'schemaVersion', '≥ 1');
    }
    final ids = <String>{};
    for (final title in titles) {
      if (!ids.add(title.id)) {
        throw ArgumentError.value(title.id, 'id', 'повторяется');
      }
    }
    return TitleCatalog._(
      schemaVersion: schemaVersion,
      texts: texts,
      titles: List.unmodifiable(titles),
      problems: List.unmodifiable(problems),
    );
  }

  factory TitleCatalog.fromJson(Map<String, Object?> json) {
    final titles = <TitleDef>[];
    final problems = <String>[];
    final ids = <String>{};
    for (final (i, raw) in _read<List<Object?>>(json, 'titles').indexed) {
      final id = raw is Map ? raw['id'] : null;
      final where = id is String ? 'titles[$i] «$id»' : 'titles[$i]';
      try {
        if (raw is! Map<String, Object?>) {
          throw ArgumentError.value(raw, 'запись', 'ожидался объект');
        }
        final title = TitleDef.fromJson(raw);
        if (!ids.add(title.id)) {
          throw ArgumentError.value(title.id, 'id', 'повторяется');
        }
        titles.add(title);
      } on ArgumentError catch (error) {
        problems.add('$where: $error');
      }
    }
    return TitleCatalog.create(
      schemaVersion: _read<int>(json, 'schemaVersion'),
      texts: TitleTexts.fromJson(_read<Map<String, Object?>>(json, 'texts')),
      titles: titles,
      problems: problems,
    );
  }

  final int schemaVersion;
  final TitleTexts texts;
  final List<TitleDef> titles;
  final List<String> problems;

  TitleDef? byId(String id) {
    for (final title in titles) {
      if (title.id == id) return title;
    }
    return null;
  }
}

final _placeholder = RegExp(r'\{(\w+)\}');

T _read<T>(Map<String, Object?> json, String key, [String where = '']) {
  final value = json[key];
  if (value is! T) {
    final name = where.isEmpty ? key : '$where.$key';
    throw ArgumentError.value(value, name, 'ожидалось значение типа $T');
  }
  return value;
}

void _onlyKeys(
  Map<String, Object?> json,
  Set<String> allowed, [
  String where = 'запись',
]) {
  for (final key in json.keys) {
    if (!allowed.contains(key)) {
      throw ArgumentError.value(key, where, 'неизвестное поле');
    }
  }
}

DayMark _mark(Object? name, String where) {
  final mark = name is String ? DayMark.values.asNameMap()[name] : null;
  if (mark == null) {
    throw ArgumentError.value(name, where, 'неизвестный признак дня');
  }
  return mark;
}

PlanTolerance _tolerance(Map<String, Object?> json, String where) {
  _onlyKeys(json, const {'percent', 'atLeast', 'roundUp'}, where);
  return PlanTolerance.create(
    percent: _read<int>(json, 'percent', where),
    atLeast: _read<int>(json, 'atLeast', where),
    roundUp: json['roundUp'] == null || _read<bool>(json, 'roundUp', where),
  );
}

void _requireText(String text, String name) {
  if (text.trim().isEmpty) {
    throw ArgumentError.value(text, name, 'текст не может быть пустым');
  }
}

void _requireCount(int count, String name) {
  if (count < 1) throw ArgumentError.value(count, name, '≥ 1');
}

void _requireDescription(String description, TitleCondition condition) {
  _requireText(description, 'description');
  for (final match in _placeholder.allMatches(description)) {
    final name = match.group(1)!;
    if (!condition.placeholders.contains(name)) {
      throw ArgumentError.value(
          description, 'description', 'в этом условии нет {$name}');
    }
  }
  final days = '{day}'.allMatches(description).length;
  if (days != '{count} {day}'.allMatches(description).length) {
    throw ArgumentError.value(
        description, 'description', '{day} ставится сразу после «{count} »');
  }
}
