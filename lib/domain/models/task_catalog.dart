/// Каталог финансовых заданий. Тип задания определяет способ проверки,
/// всё остальное — содержание, тексты, правила — приходит из
/// assets/content/tasks.json. Новое задание = объект в JSON.
library;

import 'content_json.dart';

part 'task_games.dart';

enum TaskType {
  sort,
  coins,
  distribute,
  order,
  choice,
  basket,
  week,
  board,
  stall,
  cashier,
  pricetag,
}

enum TaskDifficulty { easy, hard }

enum TaskPool { practice, level, daily }

enum CoinsMode { pay, change }

enum TaskRuleType {
  sumAtLeast,
  sumAtMost,
  maxCoins,
  atLeast,
  atMost,
  nonDecreasingRank,
  neverNegative,
  savingsAtLeast,
  coinsAtLeast,
  exactChange,
  bestDeal,
}

final class TaskRule {
  const TaskRule({
    required this.type,
    required this.failCode,
    this.value,
    this.counterId,
  });

  final TaskRuleType type;

  /// Ключ объяснения в explanationsByReason.
  final String failCode;

  final int? value;
  final String? counterId;

  factory TaskRule.fromJson(Map<String, Object?> json) => TaskRule(
        type: TaskRuleType.values.byName(json['type'] as String),
        failCode: json['failCode'] as String,
        value: json['value'] as int?,
        counterId: json['counter'] as String?,
      );
}

final class TaskTheme {
  const TaskTheme(
      {required this.id,
      required this.title,
      required this.iconId,
      this.skill = ''});

  final String id;
  final String title;
  final String iconId;
  final String skill;

  factory TaskTheme.fromJson(Map<String, Object?> json) => TaskTheme(
        id: json['id'] as String,
        title: json['title'] as String,
        iconId: (json['iconId'] ?? '') as String,
        skill: (json['skill'] ?? '') as String,
      );
}

final class TaskMethodology {
  const TaskMethodology({required this.expectedSkill, required this.correctLogic});

  final String expectedSkill;
  final String correctLogic;

  factory TaskMethodology.fromJson(Map<String, Object?> json) => TaskMethodology(
        expectedSkill: json['expectedSkill'] as String,
        correctLogic: json['correctLogic'] as String,
      );
}

final class TaskReward {
  const TaskReward({required this.correct, required this.wrong});

  final int correct;

  /// Ребёнок не остаётся ни с чем за попытку.
  final int wrong;

  factory TaskReward.fromJson(Map<String, Object?> json) => TaskReward(
        correct: json['correct'] as int,
        wrong: (json['wrong'] ?? 0) as int,
      );
}

// --- тексты интерфейса -------------------------------------------------------

final class SortTexts {
  const SortTexts({
    required this.instruction,
    required this.notAllPlaced,
    this.bins = const {},
    this.binEmoji = const {},
  });

  final String instruction;
  final String notAllPlaced;
  final Map<String, String> bins;
  final Map<String, String> binEmoji;

  factory SortTexts.fromJson(Map<String, Object?> json) => SortTexts(
        instruction: json['instruction'] as String,
        notAllPlaced: json['notAllPlaced'] as String,
        bins: Map.unmodifiable(
            ((json['bins'] as Map?) ?? const {}).cast<String, String>()),
        binEmoji: Map.unmodifiable(
            ((json['binEmoji'] as Map?) ?? const {}).cast<String, String>()),
      );
}

final class BasketTexts {
  const BasketTexts({
    required this.instruction,
    required this.budget,
    required this.inBasket,
    required this.left,
    required this.over,
    required this.onList,
  });

  final String instruction;
  final String budget;
  final String inBasket;
  final String left;
  final String over;
  final String onList;

  factory BasketTexts.fromJson(Map<String, Object?> json) => BasketTexts(
        instruction: json['instruction'] as String,
        budget: json['budget'] as String,
        inBasket: json['inBasket'] as String,
        left: json['left'] as String,
        over: json['over'] as String,
        onList: json['onList'] as String,
      );
}

final class DistributeTexts {
  const DistributeTexts({required this.remainder});

  final String remainder;

  factory DistributeTexts.fromJson(Map<String, Object?> json) =>
      DistributeTexts(remainder: json['remainder'] as String);
}

final class CoinsTexts {
  const CoinsTexts({
    required this.denominations,
    required this.iconTemplate,
    required this.price,
    required this.paid,
    required this.onCounter,
    required this.dragHint,
  });

  final List<int> denominations;
  final String iconTemplate;
  final String price;
  final String paid;
  final String onCounter;
  final String dragHint;

  String iconFor(int denomination) =>
      iconTemplate.replaceAll('{value}', '$denomination');

  factory CoinsTexts.fromJson(Map<String, Object?> json) => CoinsTexts(
        denominations: List.unmodifiable(
            [for (final d in (json['denominations'] as List)) d as int]),
        iconTemplate: json['iconTemplate'] as String,
        price: json['price'] as String,
        paid: json['paid'] as String,
        onCounter: json['onCounter'] as String,
        dragHint: json['dragHint'] as String,
      );
}

final class OrderTexts {
  const OrderTexts({required this.swapHint, required this.placedRight});

  final String swapHint;
  final String placedRight;

  factory OrderTexts.fromJson(Map<String, Object?> json) => OrderTexts(
        swapHint: json['swapHint'] as String,
        placedRight: json['placedRight'] as String,
      );
}

final class WeekTexts {
  const WeekTexts({
    required this.day,
    required this.wallet,
    required this.savings,
    required this.eventGap,
    required this.goal,
  });

  final String day;
  final String wallet;
  final String savings;
  final String eventGap;
  final String goal;

  factory WeekTexts.fromJson(Map<String, Object?> json) => WeekTexts(
        day: json['day'] as String,
        wallet: json['wallet'] as String,
        savings: json['savings'] as String,
        eventGap: json['eventGap'] as String,
        goal: json['goal'] as String,
      );
}

final class TaskTexts {
  const TaskTexts({
    required this.check,
    required this.tryAgain,
    required this.next,
    required this.hintButton,
    required this.sort,
    required this.basket,
    required this.distribute,
    required this.coins,
    required this.order,
    required this.week,
    required this.board,
    required this.stall,
    required this.cashier,
    required this.pricetag,
    required this.hints,
  });

  final String check;
  final String tryAgain;
  final String next;
  final String hintButton;
  final SortTexts sort;
  final BasketTexts basket;
  final DistributeTexts distribute;
  final CoinsTexts coins;
  final OrderTexts order;
  final WeekTexts week;
  final TextGroup board;
  final TextGroup stall;
  final TextGroup cashier;
  final TextGroup pricetag;
  final TextGroup hints;

  static Map<String, Object?> _group(Map<String, Object?> json, String key) =>
      (json[key] as Map).cast<String, Object?>();

  factory TaskTexts.fromJson(Map<String, Object?> json) => TaskTexts(
        check: json['check'] as String,
        tryAgain: json['tryAgain'] as String,
        next: json['next'] as String,
        hintButton: json['hintButton'] as String,
        sort: SortTexts.fromJson(_group(json, 'sort')),
        basket: BasketTexts.fromJson(_group(json, 'basket')),
        distribute: DistributeTexts.fromJson(_group(json, 'distribute')),
        coins: CoinsTexts.fromJson(_group(json, 'coins')),
        order: OrderTexts.fromJson(_group(json, 'order')),
        week: WeekTexts.fromJson(_group(json, 'week')),
        board: TextGroup.fromJson(json['board'], 'texts.board', TextGroup.boardKeys),
        stall: TextGroup.fromJson(json['stall'], 'texts.stall', TextGroup.stallKeys),
        cashier: TextGroup.fromJson(
            json['cashier'], 'texts.cashier', TextGroup.cashierKeys),
        pricetag: TextGroup.fromJson(
            json['pricetag'], 'texts.pricetag', TextGroup.pricetagKeys),
        hints: TextGroup.fromJson(json['hints'], 'texts.hints', TextGroup.hintKeys),
      );
}

// --- содержание вариантов ----------------------------------------------------

sealed class TaskPayload {
  const TaskPayload();

  List<TaskRule> get rules => const [];
}

final class SortCard {
  const SortCard({
    required this.id,
    required this.label,
    required this.iconId,
    required this.bin,
    required this.why,
  });

  final String id;
  final String label;
  final String iconId;
  final String bin;

  /// Подсказка на карточке — объясняет, а не констатирует.
  final String why;

  factory SortCard.fromJson(Map<String, Object?> json) => SortCard(
        id: json['id'] as String,
        label: json['label'] as String,
        iconId: (json['iconId'] ?? '') as String,
        bin: json['bin'] as String,
        why: json['why'] as String,
      );
}

final class SortPayload extends TaskPayload {
  const SortPayload({required this.bins, required this.cards});

  final List<String> bins;
  final List<SortCard> cards;

  List<SortCard> cardsOf(String bin) =>
      List.unmodifiable([for (final c in cards) if (c.bin == bin) c]);
}

final class CoinsPayload extends TaskPayload {
  const CoinsPayload({
    required this.mode,
    required this.price,
    required this.paid,
    required this.wallet,
    required this.rules,
  });

  final CoinsMode mode;
  final int price;

  /// Сколько дал покупатель — только для режима сдачи.
  final int? paid;

  /// Номинал -> сколько таких монет доступно.
  final Map<int, int> wallet;

  @override
  final List<TaskRule> rules;

  int get expected => mode == CoinsMode.pay ? price : (paid ?? 0) - price;

  int get walletTotal {
    var sum = 0;
    wallet.forEach((denomination, count) => sum += denomination * count);
    return sum;
  }
}

final class CounterSpec {
  const CounterSpec({
    required this.id,
    required this.label,
    required this.iconId,
    required this.step,
    required this.unitValue,
    required this.min,
    required this.max,
  });

  final String id;
  final String label;
  final String iconId;
  final int step;

  /// Сколько монет стоит одна единица счётчика: у дней это 15, у монет 1.
  final int unitValue;

  final int min;
  final int? max;

  factory CounterSpec.fromJson(Map<String, Object?> json) => CounterSpec(
        id: json['id'] as String,
        label: (json['label'] ?? '') as String,
        iconId: (json['iconId'] ?? '') as String,
        step: (json['step'] ?? 1) as int,
        unitValue: (json['unitValue'] ?? 1) as int,
        min: (json['min'] ?? 0) as int,
        max: json['max'] as int?,
      );
}

final class DistributePayload extends TaskPayload {
  const DistributePayload({
    required this.pool,
    required this.target,
    required this.counterSource,
    required this.counters,
    required this.preview,
    required this.rules,
  });

  /// Сколько монет раздаём. null — задание не про раздачу пула (счёт дней).
  final int? pool;

  /// Сумма, до которой нужно дойти.
  final int? target;

  /// Откуда брать названия счётчиков, если они не заданы в задании.
  final String? counterSource;

  final List<CounterSpec> counters;
  final String? preview;

  @override
  final List<TaskRule> rules;

  CounterSpec? counter(String id) {
    for (final counter in counters) {
      if (counter.id == id) return counter;
    }
    return null;
  }
}

final class OrderItem {
  const OrderItem({
    required this.id,
    required this.label,
    required this.iconId,
    required this.rank,
    required this.why,
  });

  final String id;
  final String label;
  final String iconId;

  /// Одинаковый ранг — карточки взаимозаменяемы.
  final int rank;

  final String why;

  factory OrderItem.fromJson(Map<String, Object?> json) => OrderItem(
        id: json['id'] as String,
        label: json['label'] as String,
        iconId: (json['iconId'] ?? '') as String,
        rank: json['rank'] as int,
        why: json['why'] as String,
      );
}

final class OrderPayload extends TaskPayload {
  const OrderPayload({required this.items, required this.rules});

  final List<OrderItem> items;

  @override
  final List<TaskRule> rules;
}

final class ChoiceOption {
  const ChoiceOption({
    required this.id,
    required this.label,
    required this.isCorrect,
    required this.explanation,
  });

  final String id;
  final String label;
  final bool isCorrect;

  /// Объяснение показывается при любом выборе.
  final String explanation;

  factory ChoiceOption.fromJson(Map<String, Object?> json) => ChoiceOption(
        id: json['id'] as String,
        label: json['label'] as String,
        isCorrect: json['isCorrect'] as bool,
        explanation: json['explanation'] as String,
      );
}

final class ChoicePayload extends TaskPayload {
  const ChoicePayload({required this.question, required this.options});

  final String question;
  final List<ChoiceOption> options;
}

final class BasketProduct {
  const BasketProduct({
    required this.id,
    required this.label,
    required this.iconId,
    required this.price,
    required this.onList,
  });

  final String id;
  final String label;
  final String iconId;
  final int price;
  final bool onList;

  factory BasketProduct.fromJson(Map<String, Object?> json) => BasketProduct(
        id: json['id'] as String,
        label: json['label'] as String,
        iconId: (json['iconId'] ?? '') as String,
        price: json['price'] as int,
        onList: (json['onList'] ?? false) as bool,
      );
}

final class BasketPayload extends TaskPayload {
  const BasketPayload({required this.budget, required this.products});

  final int budget;
  final List<BasketProduct> products;

  List<BasketProduct> get fromList =>
      List.unmodifiable([for (final p in products) if (p.onList) p]);

  int get listCost {
    var sum = 0;
    for (final product in products) {
      if (product.onList) sum += product.price;
    }
    return sum;
  }
}

final class WeekEvent {
  const WeekEvent({
    required this.day,
    required this.label,
    required this.iconId,
    required this.cost,
  });

  final int day;
  final String label;
  final String iconId;
  final int cost;

  factory WeekEvent.fromJson(Map<String, Object?> json) => WeekEvent(
        day: json['day'] as int,
        label: json['label'] as String,
        iconId: (json['iconId'] ?? '') as String,
        cost: json['cost'] as int,
      );
}

final class WeekPayload extends TaskPayload {
  const WeekPayload({
    required this.days,
    required this.dailyIncome,
    required this.step,
    required this.maxSavePerDay,
    required this.target,
    required this.events,
    required this.rules,
  });

  final int days;
  final int dailyIncome;
  final int step;
  final int maxSavePerDay;
  final int target;
  final List<WeekEvent> events;

  @override
  final List<TaskRule> rules;

  WeekEvent? eventOn(int day) {
    for (final event in events) {
      if (event.day == day) return event;
    }
    return null;
  }

  int get eventsCost {
    var sum = 0;
    for (final event in events) {
      sum += event.cost;
    }
    return sum;
  }
}

// --- задание -----------------------------------------------------------------

final class TaskVariant {
  const TaskVariant({
    required this.difficulty,
    required this.intro,
    required this.hint,
    required this.competenceIds,
    required this.explanationCorrect,
    required this.explanationWrong,
    required this.explanationsByReason,
    required this.payload,
  });

  final TaskDifficulty difficulty;
  final String intro;
  final String hint;
  final List<String> competenceIds;

  /// Объяснение показывается и при верном ответе тоже.
  final String explanationCorrect;
  final String explanationWrong;

  /// failCode правила -> что сказать. Точнее общего explanationWrong.
  final Map<String, String> explanationsByReason;

  final TaskPayload payload;

  String explanationFor(String? failCode) =>
      failCode == null ? explanationCorrect
          : (explanationsByReason[failCode] ?? explanationWrong);

  List<TaskRule> get rules => payload.rules;
}

final class TaskDef {
  const TaskDef({
    required this.id,
    required this.themeId,
    required this.type,
    required this.order,
    required this.title,
    required this.iconId,
    required this.reward,
    required this.allOptionsValid,
    required this.methodology,
    required this.variantSets,
    this.levelSets = const {},
    this.dailyVariants = const [],
  });

  final String id;
  final String themeId;
  final TaskType type;
  final int order;
  final String title;
  final String iconId;
  final TaskReward reward;

  /// Задание без единственно верного ответа: любой выбор допустим.
  final bool allOptionsValid;

  final TaskMethodology methodology;
  final Map<TaskDifficulty, List<TaskVariant>> variantSets;
  final Map<TaskDifficulty, List<TaskVariant>> levelSets;
  final List<TaskVariant> dailyVariants;

  List<TaskVariant> get allVariants => [
        for (final list in variantSets.values) ...list,
        for (final list in levelSets.values) ...list,
        ...dailyVariants,
      ];

  List<TaskVariant> variantsIn(TaskPool pool, TaskDifficulty difficulty) {
    final own = switch (pool) {
      TaskPool.practice => variantsOf(difficulty),
      TaskPool.level => levelSets[difficulty] ?? const <TaskVariant>[],
      TaskPool.daily => dailyVariants,
    };
    return own.isNotEmpty ? own : variantsOf(difficulty);
  }

  bool hasOwn(TaskPool pool, TaskDifficulty difficulty) => switch (pool) {
        TaskPool.practice => true,
        TaskPool.level => (levelSets[difficulty] ?? const []).isNotEmpty,
        TaskPool.daily => dailyVariants.isNotEmpty,
      };

  String keyIn(TaskPool pool, TaskDifficulty difficulty, int index) {
    final at = index % variantsIn(pool, difficulty).length;
    if (!hasOwn(pool, difficulty)) return variantKey(difficulty, at);
    return switch (pool) {
      TaskPool.practice => variantKey(difficulty, at),
      TaskPool.level => '$id/level/${difficulty.name}/$at',
      TaskPool.daily => '$id/daily/$at',
    };
  }

  Map<TaskDifficulty, TaskVariant> get variants => {
        for (final entry in variantSets.entries)
          if (entry.value.isNotEmpty) entry.key: entry.value.first
      };

  List<TaskVariant> variantsOf(TaskDifficulty difficulty) =>
      variantSets[difficulty] ?? variantSets.values.first;

  int get variantCount =>
      variantSets.values.fold(0, (sum, list) => sum + list.length);

  TaskVariant variant(TaskDifficulty difficulty, [int index = 0]) {
    final list = variantsOf(difficulty);
    return list[index % list.length];
  }

  String variantKey(TaskDifficulty difficulty, int index) =>
      '$id/${difficulty.name}/${index % variantsOf(difficulty).length}';

  List<String> get variantKeys => [
        for (final entry in variantSets.entries)
          for (var i = 0; i < entry.value.length; i++)
            '$id/${entry.key.name}/$i'
      ];

  factory TaskDef.fromJson(Map<String, Object?> json) {
    final type = TaskType.values.byName((json['type'] as String).toLowerCase());
    final bins = [
      for (final bin in (json['bins'] as List? ?? const [])) bin as String
    ];
    final competences =
        ((json['competenceIds'] as Map?) ?? const {}).cast<String, Object?>();

    List<TaskVariant> parse(Object? raw, TaskDifficulty difficulty) =>
        List<TaskVariant>.unmodifiable([
          for (final item in switch (raw) {
            null => const <Object?>[],
            final List<Object?> list => list,
            final other => [other],
          })
            _variantFromJson(
              difficulty,
              (item as Map).cast<String, Object?>(),
              type: type,
              mode: json['mode'] as String?,
              bins: bins,
              counterSource: json['counterSource'] as String?,
              competenceIds: [
                for (final id
                    in (competences[difficulty.name] as List? ?? const []))
                  id as String
              ],
            )
        ]);

    Map<TaskDifficulty, List<TaskVariant>> sets(Object? raw) {
      final map = ((raw as Map?) ?? const {}).cast<String, Object?>();
      return Map.unmodifiable({
        for (final difficulty in TaskDifficulty.values)
          if (map[difficulty.name] != null)
            difficulty: parse(map[difficulty.name], difficulty)
      });
    }

    return TaskDef(
      id: json['id'] as String,
      themeId: json['themeId'] as String,
      type: type,
      order: (json['order'] ?? 0) as int,
      title: json['title'] as String,
      iconId: (json['iconId'] ?? '') as String,
      reward: TaskReward.fromJson(
          ((json['reward'] as Map?) ?? const {'correct': 0}).cast<String, Object?>()),
      allOptionsValid: (json['allOptionsValid'] ?? false) as bool,
      methodology: TaskMethodology.fromJson(
          (json['methodology'] as Map).cast<String, Object?>()),
      variantSets: sets(json['variants']),
      levelSets: sets(json['levelVariants']),
      dailyVariants: parse(json['dailyVariants'], TaskDifficulty.hard),
    );
  }

}

TaskVariant _variantFromJson(
  TaskDifficulty difficulty,
  Map<String, Object?> json, {
  required TaskType type,
  required String? mode,
  required List<String> bins,
  required String? counterSource,
  required List<String> competenceIds,
}) {
  List<TaskRule> rules() => List.unmodifiable([
        for (final raw in (json['rules'] as List? ?? const []))
          TaskRule.fromJson((raw as Map).cast<String, Object?>())
      ]);

  List<T> list<T>(String key, T Function(Map<String, Object?>) fromJson) =>
      List.unmodifiable([
        for (final raw in (json[key] as List? ?? const []))
          fromJson((raw as Map).cast<String, Object?>())
      ]);

  final payload = switch (type) {
    TaskType.sort => SortPayload(
        bins: List.unmodifiable(bins),
        cards: list('cards', SortCard.fromJson),
      ),
    TaskType.coins => CoinsPayload(
        mode: CoinsMode.values.byName(mode ?? CoinsMode.pay.name),
        price: json['price'] as int,
        paid: json['paid'] as int?,
        wallet: Map.unmodifiable({
          for (final e in ((json['wallet'] as Map?) ?? const {}).entries)
            int.parse(e.key as String): e.value as int
        }),
        rules: rules(),
      ),
    TaskType.distribute => DistributePayload(
        pool: json['pool'] as int?,
        target: json['target'] as int?,
        counterSource: counterSource,
        counters: list('counters', CounterSpec.fromJson),
        preview: json['preview'] as String?,
        rules: rules(),
      ),
    TaskType.order => OrderPayload(
        items: list('items', OrderItem.fromJson),
        rules: rules(),
      ),
    TaskType.choice => ChoicePayload(
        question: (json['question'] ?? '') as String,
        options: list('options', ChoiceOption.fromJson),
      ),
    TaskType.basket => BasketPayload(
        budget: json['budget'] as int,
        products: list('products', BasketProduct.fromJson),
      ),
    TaskType.week => WeekPayload(
        days: json['days'] as int,
        dailyIncome: json['dailyIncome'] as int,
        step: (json['step'] ?? 1) as int,
        maxSavePerDay: (json['maxSavePerDay'] ?? json['dailyIncome']) as int,
        target: json['target'] as int,
        events: list('events', WeekEvent.fromJson),
        rules: rules(),
      ),
    TaskType.board => BoardPayload(
        startCoins: jsonInt(json['startCoins'], 'startCoins', min: 0),
        step: jsonInt(json['step'] ?? 5, 'step', min: 1),
        target: jsonInt(json['target'], 'target', min: 1),
        dice: jsonInts(json['dice'], 'dice', min: 1),
        cells: list('cells', BoardCell.fromJson),
        rules: rules(),
      ),
    TaskType.stall => StallPayload(
        startCoins: jsonInt(json['startCoins'], 'startCoins', min: 0),
        costPerPortion: jsonInt(json['costPerPortion'], 'costPerPortion', min: 1),
        portionStep: jsonInt(json['portionStep'] ?? 1, 'portionStep', min: 1),
        maxPortions: jsonInt(json['maxPortions'], 'maxPortions', min: 1),
        prices: jsonInts(json['prices'], 'prices', min: 1),
        days: list('days', StallDay.fromJson),
        target: jsonInt(json['target'], 'target', min: 1),
        rules: rules(),
      ),
    TaskType.pricetag => PriceTagPayload(
        rounds: list('rounds', PriceRound.fromJson),
        rules: rules(),
      ),
    TaskType.cashier => CashierPayload(
        customers: list('customers', CashierCustomer.fromJson),
        showTotal: (json['showTotal'] ?? true) as bool,
        denominations: jsonInts(json['denominations'], 'denominations', min: 1),
        rules: rules(),
      ),
  };

  return TaskVariant(
    difficulty: difficulty,
    intro: json['intro'] as String,
    hint: (json['hint'] ?? '') as String,
    competenceIds: List.unmodifiable(competenceIds),
    explanationCorrect: json['explanationCorrect'] as String,
    explanationWrong: json['explanationWrong'] as String,
    explanationsByReason: Map.unmodifiable({
      for (final e in ((json['explanationsByReason'] as Map?) ?? const {}).entries)
        e.key as String: e.value as String
    }),
    payload: payload,
  );
}

final class TaskCatalog {
  const TaskCatalog._({
    required this.schemaVersion,
    required this.themes,
    required this.texts,
    required this.tasks,
    required this.tutorials,
    required this.taskTutorials,
  });

  factory TaskCatalog.create({
    int schemaVersion = 1,
    required List<TaskTheme> themes,
    required TaskTexts texts,
    required List<TaskDef> tasks,
    Map<TaskType, List<TutorialStep>> tutorials = const {},
    Map<String, List<TutorialStep>> taskTutorials = const {},
  }) {
    for (final entry in taskTutorials.entries) {
      if (entry.value.isEmpty) {
        throw ArgumentError.value(entry.key, 'taskTutorials', 'обучение без шагов');
      }
      if (!tasks.any((task) => task.id == entry.key)) {
        throw ArgumentError.value(entry.key, 'taskTutorials', 'нет такого задания');
      }
    }
    for (final entry in tutorials.entries) {
      if (entry.value.isEmpty) {
        throw ArgumentError.value(entry.key.name, 'tutorials', 'обучение без шагов');
      }
    }
    if (themes.isEmpty) throw ArgumentError('нет ни одной темы');
    if (tasks.isEmpty) throw ArgumentError('нет ни одного задания');

    final themeIds = <String>{};
    for (final theme in themes) {
      if (!themeIds.add(theme.id)) {
        throw ArgumentError.value(theme.id, 'themeId', 'повторяется');
      }
    }

    final taskIds = <String>{};
    for (final task in tasks) {
      if (!taskIds.add(task.id)) {
        throw ArgumentError.value(task.id, 'id', 'повторяется');
      }
      if (!themeIds.contains(task.themeId)) {
        throw ArgumentError.value(task.themeId, 'themeId',
            'задание «${task.id}» ссылается на несуществующую тему');
      }
      validateTask(task, texts);
    }

    return TaskCatalog._(
      schemaVersion: schemaVersion,
      themes: List.unmodifiable(themes),
      texts: texts,
      tasks: List.unmodifiable([...tasks]..sort((a, b) => a.order.compareTo(b.order))),
      tutorials: Map.unmodifiable(tutorials),
      taskTutorials: Map.unmodifiable(taskTutorials),
    );
  }

  static void validateTask(TaskDef task, TaskTexts texts) {
    if (task.reward.correct <= 0 ||
        task.reward.wrong <= 0 ||
        task.reward.wrong > task.reward.correct) {
      throw ArgumentError.value(task.id, 'reward',
          'награда за попытку от 1 и не больше награды за верный ответ');
    }
    for (final difficulty in TaskDifficulty.values) {
      final list = task.variantSets[difficulty];
      if (list == null || list.isEmpty) {
        throw ArgumentError.value(
            task.id, 'variants', 'нет варианта «${difficulty.name}»');
      }
      for (final variant in list) {
        _validateVariant(task, variant, texts);
      }
    }
    for (final list in task.levelSets.values) {
      for (final variant in list) {
        _validateVariant(task, variant, texts);
      }
    }
    for (final variant in task.dailyVariants) {
      _validateVariant(task, variant, texts);
    }
  }

  static void _validateVariant(
      TaskDef task, TaskVariant variant, TaskTexts texts) {
    final where = '${task.id}/${variant.difficulty.name}';
    if (variant.intro.isEmpty ||
        variant.explanationCorrect.isEmpty ||
        variant.explanationWrong.isEmpty) {
      throw ArgumentError.value(where, 'texts', 'пустое объяснение');
    }
    if (variant.competenceIds.isEmpty) {
      throw ArgumentError.value(where, 'competenceIds', 'не указана компетенция');
    }
    for (final rule in variant.rules) {
      if (!variant.explanationsByReason.containsKey(rule.failCode)) {
        throw ArgumentError.value(
            rule.failCode, where, 'нет объяснения для этого исхода');
      }
    }

    switch (variant.payload) {
      case SortPayload(:final bins, :final cards):
        if (bins.isEmpty) {
          throw ArgumentError.value(where, 'bins', 'не заданы корзины');
        }
        for (final card in cards) {
          if (!bins.contains(card.bin)) {
            throw ArgumentError.value(card.bin, where, 'такой корзины нет');
          }
        }
        for (final bin in bins) {
          if (!cards.any((c) => c.bin == bin)) {
            throw ArgumentError.value(bin, where, 'корзина осталась пустой');
          }
        }
      case CoinsPayload payload:
        for (final denomination in payload.wallet.keys) {
          if (!texts.coins.denominations.contains(denomination)) {
            throw ArgumentError.value(
                denomination, where, 'нет такого номинала монет');
          }
        }
        if (payload.mode == CoinsMode.change && payload.paid == null) {
          throw ArgumentError.value(where, 'paid', 'не сказано, сколько дали');
        }
        if (payload.expected <= 0) {
          throw ArgumentError.value(
              payload.expected, where, 'нечего выкладывать на прилавок');
        }
        if (payload.walletTotal < payload.expected) {
          throw ArgumentError.value(where, 'wallet', 'монет заведомо не хватит');
        }
      case DistributePayload payload:
        if (payload.counters.isEmpty) {
          throw ArgumentError.value(where, 'counters', 'нет счётчиков');
        }
        for (final counter in payload.counters) {
          if (counter.step <= 0 || counter.unitValue <= 0) {
            throw ArgumentError.value(counter.id, where, 'шаг и цена единицы > 0');
          }
        }
        for (final rule in payload.rules) {
          final id = rule.counterId;
          if (id != null && payload.counter(id) == null) {
            throw ArgumentError.value(id, where, 'правило ссылается на счётчик, которого нет');
          }
        }
      case OrderPayload(:final items):
        if (items.length < 2) {
          throw ArgumentError.value(where, 'items', 'нечего расставлять');
        }
        final ranks = {for (final item in items) item.rank}.toList()..sort();
        for (var i = 0; i < ranks.length; i++) {
          if (ranks[i] != i + 1) {
            throw ArgumentError.value(ranks, where, 'ранги идут с пропуском');
          }
        }
      case ChoicePayload(:final question, :final options):
        if (question.isEmpty) {
          throw ArgumentError.value(where, 'question', 'нет вопроса');
        }
        if (options.length < 2) {
          throw ArgumentError.value(where, 'options', 'меньше двух вариантов');
        }
        if (!options.any((o) => o.isCorrect)) {
          throw ArgumentError.value(where, 'options', 'нет ни одного верного');
        }
        if (task.allOptionsValid && options.any((o) => !o.isCorrect)) {
          throw ArgumentError.value(
              where, 'options', 'задание без неверных ответов, а неверный есть');
        }
        for (final option in options) {
          if (option.explanation.isEmpty) {
            throw ArgumentError.value(option.id, where, 'вариант без объяснения');
          }
        }
      case BasketPayload payload:
        if (payload.fromList.isEmpty) {
          throw ArgumentError.value(where, 'products', 'список покупок пуст');
        }
        if (payload.listCost > payload.budget) {
          throw ArgumentError.value(
              where, 'budget', 'список дороже бюджета, задание нерешаемо');
        }
        if (!payload.products.any((p) => !p.onList)) {
          throw ArgumentError.value(where, 'products', 'нет ни одного соблазна');
        }
      case WeekPayload payload:
        if (payload.days < 1 || payload.step < 1) {
          throw ArgumentError.value(where, 'week', 'дней и шаг должно быть > 0');
        }
        for (final event in payload.events) {
          if (event.day < 1 || event.day > payload.days) {
            throw ArgumentError.value(event.day, where, 'событие вне недели');
          }
        }
        final free = payload.days * payload.dailyIncome - payload.eventsCost;
        if (free < payload.target) {
          throw ArgumentError.value(
              where, 'target', 'дохода не хватит на события и цель');
        }
      case BoardPayload payload:
        final cells = payload.cells;
        if (cells.length < 3 ||
            cells.first.kind != BoardCellKind.start ||
            cells.last.kind != BoardCellKind.finish) {
          throw ArgumentError.value(where, 'cells', 'поле от старта до финиша');
        }
        for (var i = 1; i < cells.length - 1; i++) {
          final kind = cells[i].kind;
          if (kind == BoardCellKind.start || kind == BoardCellKind.finish) {
            throw ArgumentError.value(i, where, 'старт и финиш только по краям');
          }
          if ((kind == BoardCellKind.income ||
                  kind == BoardCellKind.expense ||
                  kind == BoardCellKind.temptation) &&
              cells[i].amount <= 0) {
            throw ArgumentError.value(i, where, 'у клетки нет суммы');
          }
        }
        for (final roll in payload.dice) {
          if (roll < 1 || roll > 6) {
            throw ArgumentError.value(roll, where, 'на кубике от 1 до 6');
          }
        }
        if (payload.dice.fold(0, (a, b) => a + b) < cells.length - 1) {
          throw ArgumentError.value(where, 'dice', 'до финиша не дойти');
        }
        if (!payload.solvable) {
          throw ArgumentError.value(where, 'board', 'цель недостижима');
        }
      case StallPayload payload:
        if (payload.days.isEmpty || payload.prices.isEmpty) {
          throw ArgumentError.value(where, 'stall', 'нет дней или цен');
        }
        for (final day in payload.days) {
          for (final price in payload.prices) {
            if (!day.demand.containsKey(price)) {
              throw ArgumentError.value(price, '$where/${day.id}', 'нет спроса для цены');
            }
          }
        }
        if (!payload.solvable) {
          throw ArgumentError.value(where, 'stall', 'цель недостижима');
        }
      case PriceTagPayload payload:
        if (payload.rounds.isEmpty) {
          throw ArgumentError.value(where, 'rounds', 'нет ни одной задачи');
        }
        final roundIds = <String>{};
        for (final round in payload.rounds) {
          if (!roundIds.add(round.id)) {
            throw ArgumentError.value(round.id, where, 'задача повторяется');
          }
          if (round.offers.length < 2) {
            throw ArgumentError.value(round.id, where, 'нужно хотя бы два варианта');
          }
          final offerIds = {for (final offer in round.offers) offer.id};
          if (offerIds.length != round.offers.length) {
            throw ArgumentError.value(round.id, where, 'варианты повторяются');
          }
          final fitting = [for (final offer in round.offers) if (offer.fits) offer];
          if (fitting.isEmpty) {
            throw ArgumentError.value(round.id, where, 'ни один вариант не подходит');
          }
          final cheapest = fitting.map((o) => o.pay).reduce((a, b) => a < b ? a : b);
          if (fitting.where((o) => o.pay == cheapest).length != 1) {
            throw ArgumentError.value(round.id, where, 'выгодных вариантов несколько');
          }
        }
      case CashierPayload payload:
        if (payload.customers.isEmpty || payload.denominations.isEmpty) {
          throw ArgumentError.value(where, 'cashier', 'нет покупателей или монет');
        }
        final ids = <String>{};
        for (final customer in payload.customers) {
          if (!ids.add(customer.id)) {
            throw ArgumentError.value(customer.id, where, 'покупатель повторяется');
          }
          if (customer.items.isEmpty) {
            throw ArgumentError.value(customer.id, where, 'покупатель без покупок');
          }
          if (customer.change <= 0 || !payload.canMake(customer.change)) {
            throw ArgumentError.value(customer.id, where, 'сдачу не собрать');
          }
        }
    }
  }

  factory TaskCatalog.fromJson(Map<String, Object?> json) => TaskCatalog.create(
        schemaVersion: (json['schemaVersion'] ?? 1) as int,
        themes: [
          for (final raw in (json['themes'] as List))
            TaskTheme.fromJson((raw as Map).cast<String, Object?>())
        ],
        texts: TaskTexts.fromJson((json['texts'] as Map).cast<String, Object?>()),
        tasks: [
          for (final raw in (json['tasks'] as List))
            TaskDef.fromJson((raw as Map).cast<String, Object?>())
        ],
        tutorials: {
          for (final entry in jsonMap(json['tutorials'] ?? const {}, 'tutorials').entries)
            jsonEnum(TaskType.values, entry.key.toLowerCase(), 'tutorials'): [
              for (final raw in jsonMaps(entry.value, 'tutorials.${entry.key}'))
                TutorialStep.fromJson(raw),
            ],
        },
        taskTutorials: {
          for (final entry
              in jsonMap(json['taskTutorials'] ?? const {}, 'taskTutorials').entries)
            entry.key: [
              for (final raw in jsonMaps(entry.value, 'taskTutorials.${entry.key}'))
                TutorialStep.fromJson(raw),
            ],
        },
      );

  final Map<TaskType, List<TutorialStep>> tutorials;
  final Map<String, List<TutorialStep>> taskTutorials;

  List<TutorialStep> tutorialFor(TaskDef task) =>
      taskTutorials[task.id] ?? tutorials[task.type] ?? const [];

  final int schemaVersion;
  final List<TaskTheme> themes;
  final TaskTexts texts;
  final List<TaskDef> tasks;

  TaskDef? byId(String id) {
    for (final task in tasks) {
      if (task.id == id) return task;
    }
    return null;
  }

  TaskTheme? theme(String id) {
    for (final theme in themes) {
      if (theme.id == id) return theme;
    }
    return null;
  }

  List<TaskDef> byTheme(String themeId) =>
      List.unmodifiable([for (final t in tasks) if (t.themeId == themeId) t]);

  List<TaskDef> byType(TaskType type) =>
      List.unmodifiable([for (final t in tasks) if (t.type == type) t]);

  Set<String> competenceIds() => {
        for (final task in tasks)
          for (final variant in task.allVariants) ...variant.competenceIds
      };
}
