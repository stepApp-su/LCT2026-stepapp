Map<String, Object?> jsonMap(Object? raw, String field) {
  if (raw is Map) return raw.cast<String, Object?>();
  throw ArgumentError.value(raw, field, 'ожидался объект');
}

List<Object?> jsonList(Object? raw, String field) {
  if (raw is List) return raw;
  throw ArgumentError.value(raw, field, 'ожидался список');
}

List<Map<String, Object?>> jsonMaps(Object? raw, String field) => [
      for (final item in jsonList(raw, field)) jsonMap(item, '$field[]'),
    ];

String jsonText(Object? raw, String field) {
  if (raw is String && raw.trim().isNotEmpty) return raw;
  throw ArgumentError.value(raw, field, 'нужен непустой текст');
}

String? jsonTextOrNull(Object? raw, String field) =>
    raw == null ? null : jsonText(raw, field);

int jsonInt(Object? raw, String field, {int? min, int? max}) {
  if (raw is! int) {
    throw ArgumentError.value(raw, field, 'нужно целое число');
  }
  if (min != null && raw < min) {
    throw ArgumentError.value(raw, field, 'не меньше $min');
  }
  if (max != null && raw > max) {
    throw ArgumentError.value(raw, field, 'не больше $max');
  }
  return raw;
}

double jsonNum(Object? raw, String field, {double? min, double? max}) {
  if (raw is! num) {
    throw ArgumentError.value(raw, field, 'нужно число');
  }
  final value = raw.toDouble();
  if (min != null && value < min) {
    throw ArgumentError.value(raw, field, 'не меньше $min');
  }
  if (max != null && value > max) {
    throw ArgumentError.value(raw, field, 'не больше $max');
  }
  return value;
}

bool jsonBool(Object? raw, String field) {
  if (raw is bool) return raw;
  throw ArgumentError.value(raw, field, 'нужно true или false');
}

List<String> jsonStrings(Object? raw, String field) => List.unmodifiable([
      for (final item in jsonList(raw, field)) jsonText(item, '$field[]'),
    ]);

List<int> jsonInts(Object? raw, String field, {int? min}) => List.unmodifiable([
      for (final item in jsonList(raw, field)) jsonInt(item, '$field[]', min: min),
    ]);

Map<String, String> jsonTexts(
  Object? raw,
  String field, {
  Set<String> required = const {},
}) {
  final map = jsonMap(raw, field);
  final texts = <String, String>{
    for (final entry in map.entries)
      if (entry.value is! Map) entry.key: jsonText(entry.value, '$field.${entry.key}'),
  };
  for (final key in required) {
    if (!texts.containsKey(key)) {
      throw ArgumentError.value(field, key, 'нет обязательного текста');
    }
  }
  return Map.unmodifiable(texts);
}

T jsonEnum<T extends Enum>(List<T> values, Object? raw, String field) {
  final name = jsonText(raw, field);
  for (final value in values) {
    if (value.name == name) return value;
  }
  throw ArgumentError.value(raw, field, 'неизвестное значение');
}

void requireUniqueIds(Iterable<String> ids, String field) {
  final seen = <String>{};
  for (final id in ids) {
    if (!seen.add(id)) {
      throw ArgumentError.value(id, field, 'повторяется');
    }
  }
}
