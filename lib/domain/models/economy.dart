/// Кошелёк, цель, товар, событие, игровой день.
library;

import 'budget_plan.dart';
import 'pet.dart';
import 'transaction.dart';

/// Кошелёк. В минус не уходит.
final class Wallet {
  const Wallet._({required this.balance, required this.savings});

  factory Wallet.create({required int balance, required int savings}) {
    if (balance < 0 || savings < 0) {
      throw ArgumentError('минус запрещён: $balance/$savings');
    }
    return Wallet._(balance: balance, savings: savings);
  }

  factory Wallet.empty() => Wallet.create(balance: 0, savings: 0);

  final int balance;
  final int savings;

  Map<String, Object?> toJson() => {'balance': balance, 'savings': savings};

  factory Wallet.fromJson(Map<String, Object?> json) => Wallet.create(
      balance: json['balance'] as int, savings: json['savings'] as int);

  @override
  bool operator ==(Object other) =>
      other is Wallet && other.balance == balance && other.savings == savings;

  @override
  int get hashCode => Object.hash(balance, savings);
}

/// Мечта. Контентные поля приходят из assets/content/goals.json,
/// [saved] — снимок накопленного для профиля. Живая сумма копилки
/// одна на всё приложение и лежит в кошельке.
final class Goal {
  const Goal._({
    required this.id,
    required this.title,
    required this.titleAccusative,
    required this.titleGenitive,
    required this.price,
    required this.saved,
    required this.minGoalsReached,
    required this.rewardEffects,
    required this.iconId,
    required this.assetId,
    required this.description,
    required this.selectPhrase,
    required this.reachedText,
  });

  factory Goal.create({
    required String id,
    required String title,
    required int price,
    int saved = 0,
    String? titleAccusative,
    String? titleGenitive,
    int minGoalsReached = 0,
    List<StateEffect> rewardEffects = const [],
    String iconId = '',
    String assetId = '',
    String description = '',
    String selectPhrase = '',
    String reachedText = '',
  }) {
    if (price <= 0) {
      throw ArgumentError.value(price, 'price', 'Цена цели — целое > 0');
    }
    if (saved < 0) {
      throw ArgumentError.value(saved, 'saved', 'Накоплено не бывает < 0');
    }
    if (minGoalsReached < 0) {
      throw ArgumentError.value(
          minGoalsReached, 'minGoalsReached', 'Счётчик целей ≥ 0');
    }
    return Goal._(
      id: id,
      title: title,
      titleAccusative: (titleAccusative == null || titleAccusative.isEmpty)
          ? title
          : titleAccusative,
      titleGenitive:
          (titleGenitive == null || titleGenitive.isEmpty) ? title : titleGenitive,
      price: price,
      saved: saved,
      minGoalsReached: minGoalsReached,
      rewardEffects: List.unmodifiable(rewardEffects),
      iconId: iconId,
      assetId: assetId,
      description: description,
      selectPhrase: selectPhrase,
      reachedText: reachedText,
    );
  }

  final String id;
  final String title;

  /// «Купим самокат?», «Выбрать новую цель: мячик и скакалку?»
  final String titleAccusative;

  /// «До самоката ещё 5 дней».
  final String titleGenitive;

  final int price;
  final int saved;

  /// Большие цели открываются, когда достигнуты предыдущие: цель должна
  /// дорожать вместе с доходом, иначе выбор перестаёт быть выбором.
  final int minGoalsReached;

  /// Достигнутая цель добавляет уюта навсегда.
  final List<StateEffect> rewardEffects;

  final String iconId;
  final String assetId;
  final String description;
  final String selectPhrase;
  final String reachedText;

  int get left => price - saved < 0 ? 0 : price - saved;
  bool get isReached => saved >= price;

  Goal copyWith({int? saved}) => Goal.create(
        id: id,
        title: title,
        price: price,
        saved: saved ?? this.saved,
        titleAccusative: titleAccusative,
        titleGenitive: titleGenitive,
        minGoalsReached: minGoalsReached,
        rewardEffects: rewardEffects,
        iconId: iconId,
        assetId: assetId,
        description: description,
        selectPhrase: selectPhrase,
        reachedText: reachedText,
      );

  Map<String, Object?> toJson() => {
        'id': id,
        'title': title,
        'titleAccusative': titleAccusative,
        'titleGenitive': titleGenitive,
        'price': price,
        'saved': saved,
        'unlock': {'minGoalsReached': minGoalsReached},
        'reward': {
          'effects': [for (final e in rewardEffects) e.toJson()]
        },
        'iconId': iconId,
        'assetId': assetId,
        'description': description,
        'selectPhrase': selectPhrase,
        'reachedText': reachedText,
      };

  factory Goal.fromJson(Map<String, Object?> json) {
    final unlock = (json['unlock'] as Map?)?.cast<String, Object?>() ?? const {};
    final reward = (json['reward'] as Map?)?.cast<String, Object?>() ?? const {};
    return Goal.create(
      id: json['id'] as String,
      title: json['title'] as String,
      titleAccusative: json['titleAccusative'] as String?,
      titleGenitive: json['titleGenitive'] as String?,
      price: json['price'] as int,
      saved: (json['saved'] ?? 0) as int,
      minGoalsReached: (unlock['minGoalsReached'] ?? 0) as int,
      rewardEffects: [
        for (final e in (reward['effects'] as List? ?? const []))
          StateEffect.fromJson((e as Map).cast<String, Object?>())
      ],
      iconId: (json['iconId'] ?? '') as String,
      assetId: (json['assetId'] ?? '') as String,
      description: (json['description'] ?? '') as String,
      selectPhrase: (json['selectPhrase'] ?? '') as String,
      reachedText: (json['reachedText'] ?? '') as String,
    );
  }

  @override
  bool operator ==(Object other) =>
      other is Goal &&
      other.id == id &&
      other.title == title &&
      other.titleAccusative == titleAccusative &&
      other.titleGenitive == titleGenitive &&
      other.price == price &&
      other.saved == saved &&
      other.minGoalsReached == minGoalsReached &&
      other.rewardEffects.length == rewardEffects.length &&
      other.iconId == iconId &&
      other.assetId == assetId;

  @override
  int get hashCode => Object.hash(id, title, titleAccusative, titleGenitive,
      price, saved, minGoalsReached, rewardEffects.length, iconId, assetId);
}

/// Влияние товара на шкалу питомца.
final class StateEffect {
  const StateEffect({required this.stat, required this.delta});

  final PetStat stat;
  final int delta;

  Map<String, Object?> toJson() => {'stat': stat.name, 'delta': delta};

  factory StateEffect.fromJson(Map<String, Object?> json) => StateEffect(
        stat: PetStat.values.byName(json['stat'] as String),
        delta: json['delta'] as int,
      );

  @override
  bool operator ==(Object other) =>
      other is StateEffect && other.stat == stat && other.delta == delta;

  @override
  int get hashCode => Object.hash(stat, delta);
}

/// Вид предмета. Уникальность вида задаётся каталогом, а не предметом.
enum ShopItemKind { consumable, toy, accessory, furniture, wallpaper }

/// Товар: цена, категория, влияние на питомца.
final class ShopItem {
  const ShopItem._({
    required this.id,
    required this.title,
    required this.titleAccusative,
    required this.price,
    required this.category,
    required this.kind,
    required this.group,
    required this.effects,
    required this.dailyEffects,
    required this.maxPerDay,
    required this.minStage,
    required this.minDay,
    required this.slot,
    required this.roomId,
    required this.iconId,
    required this.assetId,
    required this.animation,
    required this.description,
    required this.diaryText,
    required this.showInShop,
    required this.ownedAtStart,
  });

  factory ShopItem.create({
    required String id,
    required String title,
    required int price,
    required ExpenseCategory category,
    String? titleAccusative,
    ShopItemKind kind = ShopItemKind.consumable,
    String group = '',
    List<StateEffect> effects = const [],
    List<StateEffect> dailyEffects = const [],
    int? maxPerDay,
    PetStage minStage = PetStage.egg,
    int minDay = 1,
    String slot = '',
    String roomId = '',
    String iconId = '',
    String assetId = '',
    String animation = '',
    String description = '',
    String diaryText = '',
    bool showInShop = true,
    bool ownedAtStart = false,
  }) {
    if (price < 0) {
      throw ArgumentError.value(price, 'price', 'Цена — целое ≥ 0');
    }
    if (maxPerDay != null && maxPerDay < 1) {
      throw ArgumentError.value(maxPerDay, 'maxPerDay', 'Лимит за день ≥ 1');
    }
    if (minDay < 1) {
      throw ArgumentError.value(minDay, 'minDay', 'Дни нумеруются с 1');
    }
    return ShopItem._(
      id: id,
      title: title,
      titleAccusative:
          (titleAccusative == null || titleAccusative.isEmpty)
              ? title
              : titleAccusative,
      price: price,
      category: category,
      kind: kind,
      group: group,
      effects: List.unmodifiable(effects),
      dailyEffects: List.unmodifiable(dailyEffects),
      maxPerDay: maxPerDay,
      minStage: minStage,
      minDay: minDay,
      slot: slot,
      roomId: roomId,
      iconId: iconId,
      assetId: assetId,
      animation: animation,
      description: description,
      diaryText: diaryText,
      showInShop: showInShop,
      ownedAtStart: ownedAtStart,
    );
  }

  final String id;
  final String title;

  /// Винительный падеж для вопроса «Купим кепку?».
  final String titleAccusative;

  final int price;
  final ExpenseCategory category;
  final ShopItemKind kind;

  /// Группа для витрины: food, snack, toy, accessory, furniture, wallpaper.
  final String group;

  /// Разовое влияние в момент покупки.
  final List<StateEffect> effects;

  /// Влияние, которое вещь даёт каждый день, пока лежит в комнате.
  final List<StateEffect> dailyEffects;

  /// Сколько раз за день можно купить; null — без ограничения.
  final int? maxPerDay;

  /// Каталог расширяется по стадиям и дням: запас монет не должен
  /// убирать необходимость выбора.
  final PetStage minStage;
  final int minDay;

  /// Слот аксессуара (head, neck, body, back, paw, eyes).
  final String slot;
  final String roomId;

  final String iconId;
  final String assetId;
  final String animation;
  final String description;

  /// Запись в дневнике и объяснение в журнале операций.
  final String diaryText;

  final bool showInShop;
  final bool ownedAtStart;

  Map<String, Object?> toJson() => {
        'id': id,
        'title': title,
        'titleAccusative': titleAccusative,
        'price': price,
        'category': category.name,
        'kind': kind.name,
        'group': group,
        'effects': [for (final e in effects) e.toJson()],
        'dailyEffects': [for (final e in dailyEffects) e.toJson()],
        if (maxPerDay != null) 'maxPerDay': maxPerDay,
        'unlock': {'minStage': minStage.name, 'minDay': minDay},
        'slot': slot,
        'roomId': roomId,
        'iconId': iconId,
        'assetId': assetId,
        'animation': animation,
        'description': description,
        'diaryText': diaryText,
        'showInShop': showInShop,
        'ownedAtStart': ownedAtStart,
      };

  factory ShopItem.fromJson(Map<String, Object?> json) {
    final unlock =
        (json['unlock'] as Map?)?.cast<String, Object?>() ?? const {};
    return ShopItem.create(
      id: json['id'] as String,
      title: json['title'] as String,
      titleAccusative: json['titleAccusative'] as String?,
      price: json['price'] as int,
      category: ExpenseCategory.values.byName(json['category'] as String),
      kind: ShopItemKind.values
          .byName((json['kind'] ?? ShopItemKind.consumable.name) as String),
      group: (json['group'] ?? '') as String,
      effects: _effectsFromJson(json['effects']),
      dailyEffects: _effectsFromJson(json['dailyEffects']),
      maxPerDay: json['maxPerDay'] as int?,
      minStage: PetStage.values
          .byName((unlock['minStage'] ?? PetStage.egg.name) as String),
      minDay: (unlock['minDay'] ?? 1) as int,
      slot: (json['slot'] ?? '') as String,
      roomId: (json['roomId'] ?? '') as String,
      iconId: (json['iconId'] ?? '') as String,
      assetId: (json['assetId'] ?? '') as String,
      animation: (json['animation'] ?? '') as String,
      description: (json['description'] ?? '') as String,
      diaryText: (json['diaryText'] ?? '') as String,
      showInShop: (json['showInShop'] ?? true) as bool,
      ownedAtStart: (json['ownedAtStart'] ?? false) as bool,
    );
  }

  static List<StateEffect> _effectsFromJson(Object? raw) => [
        for (final e in (raw as List? ?? const []))
          StateEffect.fromJson((e as Map).cast<String, Object?>())
      ];

  @override
  bool operator ==(Object other) =>
      other is ShopItem &&
      other.id == id &&
      other.title == title &&
      other.titleAccusative == titleAccusative &&
      other.price == price &&
      other.category == category &&
      other.kind == kind &&
      other.maxPerDay == maxPerDay &&
      other.minStage == minStage &&
      other.minDay == minDay &&
      other.effects.length == effects.length &&
      other.dailyEffects.length == dailyEffects.length;

  @override
  int get hashCode => Object.hash(id, title, price, category, kind, maxPerDay,
      minStage, minDay, effects.length, dailyEffects.length);
}

/// Случайное событие дня (дождик — нужен зонт).
final class DayEvent {
  const DayEvent._({
    required this.id,
    required this.title,
    required this.cost,
    required this.resolved,
  });

  factory DayEvent.create({
    required String id,
    required String title,
    required int cost,
    bool resolved = false,
  }) {
    if (cost < 0) {
      throw ArgumentError.value(cost, 'cost', 'Стоимость события ≥ 0');
    }
    return DayEvent._(id: id, title: title, cost: cost, resolved: resolved);
  }

  final String id;
  final String title;
  final int cost;

  /// Оплатили или отказались — оба варианта ок.
  final bool resolved;

  DayEvent resolve() =>
      DayEvent.create(id: id, title: title, cost: cost, resolved: true);

  Map<String, Object?> toJson() =>
      {'id': id, 'title': title, 'cost': cost, 'resolved': resolved};

  factory DayEvent.fromJson(Map<String, Object?> json) => DayEvent.create(
        id: json['id'] as String,
        title: json['title'] as String,
        cost: json['cost'] as int,
        resolved: json['resolved'] as bool,
      );

  @override
  bool operator ==(Object other) =>
      other is DayEvent &&
      other.id == id &&
      other.title == title &&
      other.cost == cost &&
      other.resolved == resolved;

  @override
  int get hashCode => Object.hash(id, title, cost, resolved);
}

/// Игровой день. Закрывается действием ребёнка, не календарём.
final class GameDay {
  const GameDay._({
    required this.number,
    required this.income,
    required this.plan,
    required this.transactions,
    required this.event,
    required this.isClosed,
    required this.planConfirmed,
  });

  factory GameDay.create({
    required int number,
    required int income,
    required BudgetPlan plan,
    List<Transaction> transactions = const [],
    DayEvent? event,
    bool isClosed = false,
    bool planConfirmed = false,
  }) {
    if (number < 1) {
      throw ArgumentError.value(number, 'number', 'Дни нумеруются с 1');
    }
    if (income < 0) {
      throw ArgumentError.value(income, 'income', 'Доход дня ≥ 0');
    }
    return GameDay._(
      number: number,
      income: income,
      plan: plan,
      transactions: List.unmodifiable(transactions),
      event: event,
      isClosed: isClosed,
      planConfirmed: planConfirmed,
    );
  }

  final int number;
  final int income;
  final BudgetPlan plan;
  final List<Transaction> transactions;
  final DayEvent? event;
  final bool isClosed;
  final bool planConfirmed;

  GameDay copyWith({
    BudgetPlan? plan,
    List<Transaction>? transactions,
    DayEvent? event,
    bool? isClosed,
    bool? planConfirmed,
  }) =>
      GameDay.create(
        number: number,
        income: income,
        plan: plan ?? this.plan,
        transactions: transactions ?? this.transactions,
        event: event ?? this.event,
        isClosed: isClosed ?? this.isClosed,
        planConfirmed: planConfirmed ?? this.planConfirmed,
      );

  Map<String, Object?> toJson() => {
        'number': number,
        'income': income,
        'plan': plan.toJson(),
        'transactions': [for (final t in transactions) t.toJson()],
        'event': event?.toJson(),
        'isClosed': isClosed,
        'planConfirmed': planConfirmed,
      };

  factory GameDay.fromJson(Map<String, Object?> json) => GameDay.create(
        number: json['number'] as int,
        income: json['income'] as int,
        plan: BudgetPlan.fromJson(
            (json['plan'] as Map).cast<String, Object?>()),
        transactions: [
          for (final t in (json['transactions'] as List))
            Transaction.fromJson((t as Map).cast<String, Object?>())
        ],
        event: json['event'] == null
            ? null
            : DayEvent.fromJson((json['event'] as Map).cast<String, Object?>()),
        isClosed: json['isClosed'] as bool,
        planConfirmed: (json['planConfirmed'] ?? false) as bool,
      );

  @override
  bool operator ==(Object other) =>
      other is GameDay &&
      other.number == number &&
      other.income == income &&
      other.plan == plan &&
      other.event == event &&
      other.isClosed == isClosed &&
      other.planConfirmed == planConfirmed &&
      other.transactions.length == transactions.length;

  @override
  int get hashCode => Object.hash(
      number, income, plan, event, isClosed, planConfirmed, transactions.length);
}
