/// Стоп-лист: формулировки, которых не должно быть ни в одном тексте
/// для ребёнка. Вина, стыд и оценка личности вместо объяснения.
library;

const List<String> kStopWords = [
  'неправильн',
  'неверн',
  'ошиб',
  'стыд',
  'жаль',
  'подвёл',
  'подвел',
  'проигра',
  'не справ',
  'плохо',
  'слишком много',
  'глуп',
  'ленив',
  'виноват',
  'зря',
  'я голоден',
  'мне плохо',
];

List<String> findStopWords(String text) {
  final lower = text.toLowerCase();
  return [
    for (final word in kStopWords)
      if (lower.contains(word)) word
  ];
}
