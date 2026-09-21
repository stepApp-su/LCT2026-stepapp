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

/// Мечта.
final class Goal {
  const Goal._({
    required this.id,
    required this.title,
    required this.price,
    required this.saved,
    required this.imagePath,
  });

  factory Goal.create({
    required String id,
    required String title,
    required int price,
    int saved = 0,
    String imagePath = '',
  }) {
    if (price <= 0) {
      throw ArgumentError.value(price, 'price', 'Цена цели — целое > 0');
    }
    if (saved < 0) {
      throw ArgumentError.value(saved, 'saved', 'Накоплено не бывает < 0');
    }
    return Goal._(
        id: id, title: title, price: price, saved: saved, imagePath: imagePath);
  }

  final String id;
  final String title;
  final int price;
  final int saved;

  final String imagePath;

  int get left => price - saved < 0 ? 0 : price - saved;
  bool get isReached => saved >= price;

  Goal copyWith({int? saved}) => Goal.create(
      id: id,
      title: title,
      price: price,
      saved: saved ?? this.saved,
      imagePath: imagePath);

  Map<String, Object?> toJson() => {
        'id': id,
        'title': title,
        'price': price,
        'saved': saved,
        'imagePath': imagePath,
      };

  factory Goal.fromJson(Map<String, Object?> json) => Goal.create(
        id: json['id'] as String,
        title: json['title'] as String,
        price: json['price'] as int,
        saved: json['saved'] as int,
        imagePath: (json['imagePath'] ?? '') as String,
      );

  @override
  bool operator ==(Object other) =>
      other is Goal &&
      other.id == id &&
      other.title == title &&
      other.price == price &&
      other.saved == saved &&
      other.imagePath == imagePath;

  @override
  int get hashCode => Object.hash(id, title, price, saved, imagePath);
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

/// Товар: цена, категория, влияние на питомца.
final class ShopItem {
  const ShopItem._({
    required this.id,
    required this.title,
    required this.price,
    required this.category,
    required this.effects,
  });

  factory ShopItem.create({
    required String id,
    required String title,
    required int price,
    required ExpenseCategory category,
    List<StateEffect> effects = const [],
  }) {
    if (price <= 0) {
      throw ArgumentError.value(price, 'price', 'Цена — целое > 0');
    }
    return ShopItem._(
        id: id,
        title: title,
        price: price,
        category: category,
        effects: List.unmodifiable(effects));
  }

  final String id;
  final String title;
  final int price;
  final ExpenseCategory category;
  final List<StateEffect> effects;

  Map<String, Object?> toJson() => {
        'id': id,
        'title': title,
        'price': price,
        'category': category.name,
        'effects': [for (final e in effects) e.toJson()],
      };

  factory ShopItem.fromJson(Map<String, Object?> json) => ShopItem.create(
        id: json['id'] as String,
        title: json['title'] as String,
        price: json['price'] as int,
        category: ExpenseCategory.values.byName(json['category'] as String),
        effects: [
          for (final e in (json['effects'] as List))
            StateEffect.fromJson((e as Map).cast<String, Object?>())
        ],
      );

  @override
  bool operator ==(Object other) =>
      other is ShopItem &&
      other.id == id &&
      other.title == title &&
      other.price == price &&
      other.category == category &&
      other.effects.length == effects.length;

  @override
  int get hashCode => Object.hash(id, title, price, category, effects.length);
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
  });

  factory GameDay.create({
    required int number,
    required int income,
    required BudgetPlan plan,
    List<Transaction> transactions = const [],
    DayEvent? event,
    bool isClosed = false,
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
    );
  }

  final int number;
  final int income;
  final BudgetPlan plan;
  final List<Transaction> transactions;
  final DayEvent? event;
  final bool isClosed;

  GameDay copyWith({
    BudgetPlan? plan,
    List<Transaction>? transactions,
    DayEvent? event,
    bool? isClosed,
  }) =>
      GameDay.create(
        number: number,
        income: income,
        plan: plan ?? this.plan,
        transactions: transactions ?? this.transactions,
        event: event ?? this.event,
        isClosed: isClosed ?? this.isClosed,
      );

  Map<String, Object?> toJson() => {
        'number': number,
        'income': income,
        'plan': plan.toJson(),
        'transactions': [for (final t in transactions) t.toJson()],
        'event': event?.toJson(),
        'isClosed': isClosed,
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
      );

  @override
  bool operator ==(Object other) =>
      other is GameDay &&
      other.number == number &&
      other.income == income &&
      other.plan == plan &&
      other.event == event &&
      other.isClosed == isClosed &&
      other.transactions.length == transactions.length;

  @override
  int get hashCode =>
      Object.hash(number, income, plan, event, isClosed, transactions.length);
}
