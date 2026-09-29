enum PetAppearance {
  moni('fox', 'Мони', 'Лисёнок', 'moni'),
  pix('robot', 'Пикс', 'Робокотёнок', 'pix'),
  tyapa('puppy', 'Тяпа', 'Щенок', 'tyapa'),
  bumba('dragon', 'Бумба', 'Дракончик', 'bumba'),
  puf('rabbit', 'Пуф', 'Зайчонок', 'puf'),
  roni('raccoon', 'Рони', 'Енот', 'roni'),
  tori('red_panda', 'Тори', 'Красная панда', 'tori'),
  busya('bear', 'Буся', 'Медвежонок', 'busya'),
  leo('lion', 'Лео', 'Львёнок', 'leo');

  const PetAppearance(this.character, this.name, this.label, this.folder);
  final String character, name, label, folder;
  String get assets => 'assets/pets/$folder';
  bool get unifiedHead => index >= puf.index;
  String get egg => '$assets/${unifiedHead ? 'body' : 'egg'}.png';

  static PetAppearance restore(Object? character) => values
      .firstWhere((pet) => pet.character == character, orElse: () => moni);
}
