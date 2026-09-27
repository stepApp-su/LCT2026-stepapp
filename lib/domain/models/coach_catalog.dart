import 'content_json.dart';
import 'task_catalog.dart';

final class CoachTour {
  const CoachTour._({
    required this.id,
    required this.steps,
    required this.covers,
    required this.chain,
    this.title,
    this.requires,
  });

  factory CoachTour.fromJson(Map<String, Object?> json) {
    final id = jsonText(json['id'], 'tours.id');
    final steps = [
      for (final raw in jsonMaps(json['steps'], 'tours.$id.steps')) TutorialStep.fromJson(raw),
    ];
    if (steps.isEmpty) throw ArgumentError.value(id, 'tours.steps', 'обучение без шагов');
    return CoachTour._(
      id: id,
      steps: List.unmodifiable(steps),
      covers: jsonStrings(json['covers'] ?? const <Object?>[], 'tours.$id.covers'),
      chain: jsonStrings(json['chain'] ?? const <Object?>[], 'tours.$id.chain'),
      title: jsonTextOrNull(json['title'], 'tours.$id.title'),
      requires: jsonTextOrNull(json['requires'], 'tours.$id.requires'),
    );
  }

  final String id;
  final List<TutorialStep> steps;
  final List<String> covers;
  final List<String> chain;
  final String? title;
  final String? requires;

  List<String> seenAfter({required bool finished}) =>
      [id, ...covers, if (!finished) ...chain];
}

final class CoachTexts {
  const CoachTexts({
    required this.next,
    required this.done,
    required this.skip,
    required this.later,
    required this.tap,
    required this.step,
  });

  factory CoachTexts.fromJson(Map<String, Object?> json) => CoachTexts(
        next: jsonText(json['next'], 'texts.next'),
        done: jsonText(json['done'], 'texts.done'),
        skip: jsonText(json['skip'], 'texts.skip'),
        later: jsonText(json['later'], 'texts.later'),
        tap: jsonText(json['tap'], 'texts.tap'),
        step: jsonText(json['step'], 'texts.step'),
      );

  static const fallback = CoachTexts(
    next: 'Дальше',
    done: 'Понятно!',
    skip: 'Пропустить',
    later: 'Потом',
    tap: 'Нажми на подсвеченное',
    step: '{n} из {total}',
  );

  final String next;
  final String done;
  final String skip;
  final String later;
  final String tap;
  final String step;
}

final class CoachCatalog {
  const CoachCatalog({
    required this.texts,
    required this.tours,
    required this.gameFirst,
    required this.gameLast,
  });

  factory CoachCatalog.fromJson(Map<String, Object?> json) {
    final tours = [
      for (final raw in jsonMaps(json['tours'], 'tours')) CoachTour.fromJson(raw),
    ];
    requireUniqueIds(tours.map((t) => t.id), 'tours');
    List<TutorialStep> steps(String key) => List.unmodifiable([
          for (final raw in jsonMaps(json[key] ?? const <Object?>[], key))
            TutorialStep.fromJson(raw),
        ]);
    return CoachCatalog(
      texts: CoachTexts.fromJson(jsonMap(json['texts'], 'texts')),
      tours: {for (final tour in tours) tour.id: tour},
      gameFirst: steps('gameFirst'),
      gameLast: steps('gameLast'),
    );
  }

  static const empty = CoachCatalog(
    texts: CoachTexts.fallback,
    tours: {},
    gameFirst: [],
    gameLast: [],
  );

  final CoachTexts texts;
  final Map<String, CoachTour> tours;
  final List<TutorialStep> gameFirst;
  final List<TutorialStep> gameLast;

  CoachTour? tour(String id) => tours[id];

  Iterable<TutorialStep> get allSteps => [
        for (final tour in tours.values) ...tour.steps,
        ...gameFirst,
        ...gameLast,
      ];
}
