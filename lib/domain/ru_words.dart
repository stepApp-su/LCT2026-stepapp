/// Русские словоформы для текстов, которые читает ребёнок.
/// Числительные и названия шкал — язык, а не контент, поэтому живут в коде.
library;

import 'models/pet.dart';

/// Форма слова при числе: 1 монета, 2 монеты, 5 монет.
String ruPlural(int n, String one, String few, String many) {
  final hundreds = n.abs() % 100;
  if (hundreds >= 11 && hundreds <= 14) return many;
  return switch (n.abs() % 10) {
    1 => one,
    2 || 3 || 4 => few,
    _ => many,
  };
}

String ruCoins(int n) => ruPlural(n, 'монета', 'монеты', 'монет');

String ruDays(int n) => ruPlural(n, 'день', 'дня', 'дней');

final _pluralToken = RegExp(r'(\d+)(\s*)\{(coin|day)\}');

/// «{income} {coin}» после подстановки числа превращается в «40 монет».
/// Токен без числа перед ним остаётся как есть — это видно на ревью.
String fillPlurals(String text) =>
    text.replaceAllMapped(_pluralToken, (m) {
      final n = int.parse(m.group(1)!);
      final word = m.group(3) == 'coin' ? ruCoins(n) : ruDays(n);
      return '${m.group(1)}${m.group(2)}$word';
    });

const Map<PetStat, String> petStatLabels = {
  PetStat.satiety: 'Сытость',
  PetStat.care: 'Уход',
  PetStat.mood: 'Настроение',
  PetStat.cozy: 'Уют',
};

String petStatLabel(PetStat stat) => petStatLabels[stat] ?? stat.name;
