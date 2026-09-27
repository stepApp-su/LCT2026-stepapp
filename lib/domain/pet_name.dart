import 'stop_words.dart';

const int petNameMaxLength = 12;

const List<String> _blockedRoots = [
  'хуй',
  'хуе',
  'хуя',
  'хуи',
  'пизд',
  'ебал',
  'ебан',
  'ебат',
  'ебуч',
  'ебла',
  'уеб',
  'выеб',
  'наеб',
  'заеб',
  'бля',
  'сука',
  'суки',
  'сучк',
  'мудак',
  'мудил',
  'пидор',
  'пидр',
  'гандон',
  'говн',
  'дерьм',
  'жопа',
  'жопу',
  'шлюх',
  'залуп',
  'дроч',
  'срака',
  'дебил',
  'идиот',
  'кретин',
  'урод',
  'дурак',
  'тупиц',
  'fuck',
  'shit',
  'bitch',
  'dick',
];

const Map<String, String> _lookalikes = {
  'a': 'а',
  'b': 'в',
  'c': 'с',
  'e': 'е',
  'h': 'н',
  'k': 'к',
  'm': 'м',
  'o': 'о',
  'p': 'р',
  't': 'т',
  'x': 'х',
  'y': 'у',
  'ё': 'е',
  '0': 'о',
  '3': 'з',
};

final RegExp _allowed = RegExp(r'^[A-Za-zА-Яа-яЁё0-9 \-]+$');
final RegExp _letter = RegExp(r'[A-Za-zА-Яа-яЁё]');
final RegExp _spaces = RegExp(r'\s+');

String normalizePetName(String raw) => raw.trim().replaceAll(_spaces, ' ');

String _squash(String text) =>
    text.toLowerCase().replaceAll(RegExp(r'[\s\-]'), '');

String _cyrillic(String text) =>
    [for (final char in text.split('')) _lookalikes[char] ?? char].join();

bool _blocked(String name) {
  final plain = _squash(name).replaceAll('ё', 'е');
  final mixed = _cyrillic(_squash(name));
  for (final root in _blockedRoots) {
    final cyrRoot = _cyrillic(root);
    if (plain.contains(root) || mixed.contains(cyrRoot)) return true;
  }
  return findStopWords(name).isNotEmpty;
}

String? petNameProblem(String raw) {
  final name = normalizePetName(raw);
  if (name.isEmpty) return 'Придумай питомцу имя';
  if (name.length > petNameMaxLength) {
    return 'Имя не длиннее $petNameMaxLength букв';
  }
  if (!_allowed.hasMatch(name)) return 'Можно только буквы, цифры и пробел';
  if (!_letter.hasMatch(name)) return 'Нужна хотя бы одна буква';
  if (_blocked(name)) return 'Давай придумаем другое, доброе имя';
  return null;
}
