/// Подстановка чисел в шаблоны из JSON. Тексты для ребёнка не генерируются,
/// а собираются из заготовок — так их можно править, не трогая код.
library;

final _placeholder = RegExp(r'\{(\w+)\}');

/// Незнакомый плейсхолдер остаётся как есть: лучше увидеть «{days}»
/// в тексте на ревью, чем молча потерять число.
String fillTemplate(String template, Map<String, String> values) =>
    template.replaceAllMapped(
        _placeholder, (m) => values[m.group(1)] ?? m.group(0)!);
