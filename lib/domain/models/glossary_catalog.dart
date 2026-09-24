import 'content_json.dart';

final class GlossaryTerm {
  const GlossaryTerm._({
    required this.id,
    required this.term,
    required this.iconId,
    required this.competenceId,
    required this.definition,
    required this.inGame,
  });

  factory GlossaryTerm.fromJson(Map<String, Object?> json) => GlossaryTerm._(
        id: jsonText(json['id'], 'id'),
        term: jsonText(json['term'], 'term'),
        iconId: jsonText(json['iconId'], 'iconId'),
        competenceId: jsonText(json['competenceId'], 'competenceId'),
        definition: jsonText(json['definition'], 'definition'),
        inGame: jsonText(json['inGame'], 'inGame'),
      );

  final String id;
  final String term;
  final String iconId;
  final String competenceId;
  final String definition;
  final String inGame;
}

final class GlossaryCatalog {
  const GlossaryCatalog._({
    required this.schemaVersion,
    required this.texts,
    required this.terms,
  });

  static const Set<String> requiredTexts = {'header', 'intro', 'inGame', 'search'};

  factory GlossaryCatalog.create({
    int schemaVersion = 1,
    required Map<String, String> texts,
    required List<GlossaryTerm> terms,
  }) {
    if (terms.isEmpty) throw ArgumentError('словарик пуст');
    requireUniqueIds(terms.map((t) => t.id), 'terms.id');
    for (final key in requiredTexts) {
      if (!texts.containsKey(key)) {
        throw ArgumentError.value(key, 'texts', 'нет обязательного текста');
      }
    }
    return GlossaryCatalog._(
      schemaVersion: schemaVersion,
      texts: Map.unmodifiable(texts),
      terms: List.unmodifiable(terms),
    );
  }

  factory GlossaryCatalog.fromJson(Map<String, Object?> json) =>
      GlossaryCatalog.create(
        schemaVersion: jsonInt(json['schemaVersion'] ?? 1, 'schemaVersion', min: 1),
        texts: jsonTexts(json['texts'], 'texts', required: requiredTexts),
        terms: [
          for (final raw in jsonMaps(json['terms'], 'terms'))
            GlossaryTerm.fromJson(raw),
        ],
      );

  final int schemaVersion;
  final Map<String, String> texts;
  final List<GlossaryTerm> terms;

  GlossaryTerm? byId(String id) {
    for (final term in terms) {
      if (term.id == id) return term;
    }
    return null;
  }

  List<GlossaryTerm> search(String query) {
    final needle = query.trim().toLowerCase();
    if (needle.isEmpty) return terms;
    return List.unmodifiable([
      for (final term in terms)
        if (term.term.toLowerCase().contains(needle)) term,
    ]);
  }

  Set<String> get competenceIds => {for (final term in terms) term.competenceId};
}
