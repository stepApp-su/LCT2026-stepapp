/// Единая рамка компетенций: справочник, на который ссылается контент.
library;

enum CompetenceComponent { knowledge, skills, attitudes }

enum CompetenceLevel { base, advanced }

final class CompetenceSource {
  const CompetenceSource({
    required this.title,
    required this.section,
    required this.approved,
    required this.url,
  });

  final String title;
  final String section;
  final String approved;
  final String url;

  factory CompetenceSource.fromJson(Map<String, Object?> json) =>
      CompetenceSource(
        title: (json['title'] ?? '') as String,
        section: (json['section'] ?? '') as String,
        approved: (json['approved'] ?? '') as String,
        url: (json['url'] ?? '') as String,
      );
}

final class Competence {
  const Competence({
    required this.id,
    required this.area,
    required this.topic,
    required this.component,
    required this.level,
    required this.text,
    required this.forAdult,
  });

  final String id;
  final String area;
  final String topic;
  final CompetenceComponent component;
  final CompetenceLevel level;

  /// Формулировка из рамки — для документации.
  final String text;

  /// Та же мысль словами для раздела взрослого.
  final String forAdult;

  factory Competence.fromJson(Map<String, Object?> json) => Competence(
        id: json['id'] as String,
        area: (json['area'] ?? '') as String,
        topic: (json['topic'] ?? '') as String,
        component:
            CompetenceComponent.values.byName(json['component'] as String),
        level: CompetenceLevel.values.byName(json['level'] as String),
        text: json['text'] as String,
        forAdult: (json['forAdult'] ?? '') as String,
      );
}

final class CompetenceCatalog {
  const CompetenceCatalog._({
    required this.schemaVersion,
    required this.source,
    required this.components,
    required this.levels,
    required this.competences,
  });

  factory CompetenceCatalog.create({
    int schemaVersion = 1,
    required CompetenceSource source,
    Map<CompetenceComponent, String> components = const {},
    Map<CompetenceLevel, String> levels = const {},
    required List<Competence> competences,
  }) {
    final ids = <String>{};
    for (final competence in competences) {
      if (!ids.add(competence.id)) {
        throw ArgumentError.value(competence.id, 'id', 'повторяется в рамке');
      }
      if (competence.text.isEmpty) {
        throw ArgumentError.value(competence.id, 'text', 'пустая формулировка');
      }
    }
    return CompetenceCatalog._(
      schemaVersion: schemaVersion,
      source: source,
      components: Map.unmodifiable(components),
      levels: Map.unmodifiable(levels),
      competences: List.unmodifiable(competences),
    );
  }

  factory CompetenceCatalog.fromJson(Map<String, Object?> json) =>
      CompetenceCatalog.create(
        schemaVersion: (json['schemaVersion'] ?? 1) as int,
        source: CompetenceSource.fromJson(
            ((json['source'] as Map?) ?? const {}).cast<String, Object?>()),
        components: {
          for (final e in ((json['components'] as Map?) ?? const {}).entries)
            CompetenceComponent.values.byName(e.key as String): e.value as String
        },
        levels: {
          for (final e in ((json['levels'] as Map?) ?? const {}).entries)
            CompetenceLevel.values.byName(e.key as String): e.value as String
        },
        competences: [
          for (final raw in (json['competences'] as List))
            Competence.fromJson((raw as Map).cast<String, Object?>())
        ],
      );

  final int schemaVersion;
  final CompetenceSource source;
  final Map<CompetenceComponent, String> components;
  final Map<CompetenceLevel, String> levels;
  final List<Competence> competences;

  Competence? byId(String id) {
    for (final competence in competences) {
      if (competence.id == id) return competence;
    }
    return null;
  }

  List<Competence> byArea(String area) => List.unmodifiable(
      [for (final c in competences) if (c.area == area) c]);
}
