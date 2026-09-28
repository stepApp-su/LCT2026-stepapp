enum PetAppearance {
  moni('fox', 'Мони', 'Лисёнок', 'moni'),
  pix('robot', 'Пикс', 'Робокотёнок', 'pix'),
  tyapa('puppy', 'Тяпа', 'Щенок', 'tyapa'),
  bumba('dragon', 'Бумба', 'Дракончик', 'bumba');

  const PetAppearance(this.character, this.name, this.label, this.folder);
  final String character, name, label, folder;
  String get assets => 'assets/pets/$folder';
  String get egg => '$assets/egg.png';

  static PetAppearance restore(Object? character) => values
      .firstWhere((pet) => pet.character == character, orElse: () => moni);
}
