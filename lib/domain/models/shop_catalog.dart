/// Каталог магазина целиком: категории, виды, тексты, правила сравнения цен
/// и позиции. Всё приходит из assets/content/shop.json — в коде нет ни цен,
/// ни названий, ни формулировок.
library;

import 'economy.dart';
import 'pet.dart';
import 'transaction.dart';

final class ShopCategoryInfo {
  const ShopCategoryInfo({
    required this.label,
    required this.hint,
    required this.iconId,
  });

  final String label;
  final String hint;

  /// Категорию всегда сопровождает иконка: цвет не может быть
  /// единственным способом её показать.
  final String iconId;

  factory ShopCategoryInfo.fromJson(Map<String, Object?> json) =>
      ShopCategoryInfo(
        label: json['label'] as String,
        hint: (json['hint'] ?? '') as String,
        iconId: (json['iconId'] ?? '') as String,
      );
}

final class ShopKindInfo {
  const ShopKindInfo({
    required this.label,
    required this.unique,
    required this.singleActive,
  });

  final String label;

  /// Уникальное покупается один раз и остаётся навсегда.
  final bool unique;

  /// Активным может быть только одно (обои).
  final bool singleActive;

  factory ShopKindInfo.fromJson(Map<String, Object?> json) => ShopKindInfo(
        label: json['label'] as String,
        unique: (json['unique'] ?? false) as bool,
        singleActive: (json['singleActive'] ?? false) as bool,
      );
}

final class ShopTexts {
  const ShopTexts({
    required this.effect,
    required this.dailyEffect,
    required this.confirmQuestion,
    required this.alreadyOwned,
    required this.dailyLimitReached,
    required this.wallpaperApplied,
    this.unknownItem = 'Такого товара нет',
    this.notInShop = 'Этого нет в магазине',
    this.notUnlocked = 'Этот товар пока не появился в магазине',
    this.notForSale = 'Это не продаётся',
    this.needsConfirmation = 'Сначала спросим: купим?',
  });

  final String effect;
  final String dailyEffect;
  final String confirmQuestion;
  final String alreadyOwned;
  final String dailyLimitReached;
  final String wallpaperApplied;

  /// Отказы. Лежат в JSON вместе с остальными текстами: ребёнок их видит,
  /// значит формулировку должен уметь править не только программист.
  final String unknownItem;
  final String notInShop;
  final String notUnlocked;
  final String notForSale;
  final String needsConfirmation;

  factory ShopTexts.fromJson(Map<String, Object?> json) {
    String text(String key, String fallback) =>
        (json[key] as String?) ?? fallback;
    return ShopTexts(
      effect: json['effect'] as String,
      dailyEffect: json['dailyEffect'] as String,
      confirmQuestion: json['confirmQuestion'] as String,
      alreadyOwned: json['alreadyOwned'] as String,
      dailyLimitReached: json['dailyLimitReached'] as String,
      wallpaperApplied: json['wallpaperApplied'] as String,
      unknownItem: text('unknownItem', 'Такого товара нет'),
      notInShop: text('notInShop', 'Этого нет в магазине'),
      notUnlocked:
          text('notUnlocked', 'Этот товар пока не появился в магазине'),
      notForSale: text('notForSale', 'Это не продаётся'),
      needsConfirmation: text('needsConfirmation', 'Сначала спросим: купим?'),
    );
  }
}

/// Понятный эквивалент цены: «еда на день», «все обязательные покупки».
final class PriceAnchor {
  const PriceAnchor({
    required this.id,
    required this.itemIds,
    required this.phrase,
    required this.maxMultiplier,
  });

  final String id;
  final List<String> itemIds;
  final String phrase;

  /// Дальше этого множителя сравнение перестаёт быть понятным:
  /// «еда на 12 дней» ребёнку уже ничего не объясняет.
  final int maxMultiplier;

  factory PriceAnchor.fromJson(String id, Map<String, Object?> json) =>
      PriceAnchor(
        id: (json['id'] ?? id) as String,
        itemIds: (json['itemIds'] as List).cast<String>(),
        phrase: json['phrase'] as String,
        maxMultiplier: (json['maxMultiplier'] ?? 1) as int,
      );
}

enum PriceRuleType { exactMultiple, withRemainder, lessThan }

final class PriceRule {
  const PriceRule({
    required this.type,
    required this.anchorIds,
    required this.template,
  });

  final PriceRuleType type;
  final List<String> anchorIds;
  final String template;

  factory PriceRule.fromJson(Map<String, Object?> json) => PriceRule(
        type: PriceRuleType.values.byName(json['type'] as String),
        anchorIds: json['anchors'] != null
            ? (json['anchors'] as List).cast<String>()
            : [json['anchor'] as String],
        template: json['template'] as String,
      );
}

final class PriceComparison {
  const PriceComparison._({
    required this.applyToCategories,
    required this.anchors,
    required this.rules,
  });

  factory PriceComparison.fromJson(Map<String, Object?> json) {
    final anchors = <String, PriceAnchor>{};
    for (final raw in (json['anchors'] as List? ?? const [])) {
      final map = (raw as Map).cast<String, Object?>();
      final id = map['id'] as String;
      anchors[id] = PriceAnchor.fromJson(id, map);
    }
    return PriceComparison._(
      applyToCategories: {
        for (final c in (json['applyToCategories'] as List? ?? const []))
          ExpenseCategory.values.byName(c as String)
      },
      anchors: Map.unmodifiable(anchors),
      rules: List.unmodifiable([
        for (final raw in (json['rules'] as List? ?? const []))
          PriceRule.fromJson((raw as Map).cast<String, Object?>())
      ]),
    );
  }

  static const PriceComparison none = PriceComparison._(
    applyToCategories: {},
    anchors: {},
    rules: [],
  );

  final Set<ExpenseCategory> applyToCategories;
  final Map<String, PriceAnchor> anchors;
  final List<PriceRule> rules;

  PriceAnchor? anchor(String id) => anchors[id];
}

final class ShopCatalog {
  const ShopCatalog._({
    required this.schemaVersion,
    required this.categories,
    required this.kinds,
    required this.stageUnlockMessages,
    required this.newItemByDayMessage,
    required this.texts,
    required this.priceComparison,
    required this.items,
  });

  factory ShopCatalog.create({
    int schemaVersion = 1,
    required Map<ExpenseCategory, ShopCategoryInfo> categories,
    required Map<ShopItemKind, ShopKindInfo> kinds,
    Map<PetStage, String> stageUnlockMessages = const {},
    String newItemByDayMessage = '',
    required ShopTexts texts,
    PriceComparison priceComparison = PriceComparison.none,
    required List<ShopItem> items,
  }) {
    final ids = <String>{};
    for (final item in items) {
      if (!ids.add(item.id)) {
        throw ArgumentError.value(item.id, 'id', 'повторяется в каталоге');
      }
      if (!categories.containsKey(item.category)) {
        throw ArgumentError.value(
            item.category.name, 'category', 'нет в описании категорий');
      }
      if (!kinds.containsKey(item.kind)) {
        throw ArgumentError.value(item.kind.name, 'kind', 'нет в описании видов');
      }
    }
    _validateComparison(priceComparison, items, categories.keys.toSet());
    return ShopCatalog._(
      schemaVersion: schemaVersion,
      categories: Map.unmodifiable(categories),
      kinds: Map.unmodifiable(kinds),
      stageUnlockMessages: Map.unmodifiable(stageUnlockMessages),
      newItemByDayMessage: newItemByDayMessage,
      texts: texts,
      priceComparison: priceComparison,
      items: List.unmodifiable(items),
    );
  }

  factory ShopCatalog.fromJson(Map<String, Object?> json) =>
      ShopCatalog.create(
        schemaVersion: (json['schemaVersion'] ?? 1) as int,
        categories: {
          for (final e in (json['categories'] as Map).entries)
            ExpenseCategory.values.byName(e.key as String):
                ShopCategoryInfo.fromJson((e.value as Map).cast<String, Object?>())
        },
        kinds: {
          for (final e in (json['kinds'] as Map).entries)
            ShopItemKind.values.byName(e.key as String):
                ShopKindInfo.fromJson((e.value as Map).cast<String, Object?>())
        },
        stageUnlockMessages: {
          for (final e
              in ((json['stageUnlockMessages'] as Map?) ?? const {}).entries)
            PetStage.values.byName(e.key as String): e.value as String
        },
        newItemByDayMessage: (json['newItemByDayMessage'] ?? '') as String,
        texts: ShopTexts.fromJson((json['texts'] as Map).cast<String, Object?>()),
        priceComparison: json['priceComparison'] == null
            ? PriceComparison.none
            : PriceComparison.fromJson(
                (json['priceComparison'] as Map).cast<String, Object?>()),
        items: [
          for (final raw in (json['items'] as List))
            ShopItem.fromJson((raw as Map).cast<String, Object?>())
        ],
      );

  final int schemaVersion;
  final Map<ExpenseCategory, ShopCategoryInfo> categories;
  final Map<ShopItemKind, ShopKindInfo> kinds;
  final Map<PetStage, String> stageUnlockMessages;
  final String newItemByDayMessage;
  final ShopTexts texts;
  final PriceComparison priceComparison;
  final List<ShopItem> items;

  /// Битая ссылка в правилах сравнения цен молча отключала бы сравнение
  /// целиком, поэтому ловим её при загрузке каталога, а не в проде.
  static void _validateComparison(
    PriceComparison comparison,
    List<ShopItem> items,
    Set<ExpenseCategory> knownCategories,
  ) {
    final prices = {for (final item in items) item.id: item.price};
    for (final category in comparison.applyToCategories) {
      if (!knownCategories.contains(category)) {
        throw ArgumentError.value(category.name, 'applyToCategories',
            'нет в описании категорий');
      }
    }
    for (final anchor in comparison.anchors.values) {
      if (anchor.itemIds.isEmpty) {
        throw ArgumentError.value(anchor.id, 'anchor', 'пустой список товаров');
      }
      if (anchor.maxMultiplier < 1) {
        throw ArgumentError.value(
            anchor.maxMultiplier, 'maxMultiplier', 'множитель ≥ 1');
      }
      var sum = 0;
      for (final id in anchor.itemIds) {
        final price = prices[id];
        if (price == null) {
          throw ArgumentError.value(
              id, 'anchor «${anchor.id}»', 'такого товара нет в каталоге');
        }
        sum += price;
      }
      if (sum <= 0) {
        throw ArgumentError.value(
            anchor.id, 'anchor', 'сравнивать с бесплатным нельзя');
      }
    }
    for (final rule in comparison.rules) {
      if (rule.anchorIds.isEmpty) {
        throw ArgumentError.value(
            rule.type.name, 'rule', 'правилу нужен хотя бы один якорь');
      }
      for (final id in rule.anchorIds) {
        if (!comparison.anchors.containsKey(id)) {
          throw ArgumentError.value(
              id, 'rule «${rule.type.name}»', 'такого якоря нет');
        }
      }
    }
  }

  ShopItem? byId(String id) {
    for (final item in items) {
      if (item.id == id) return item;
    }
    return null;
  }

  bool isUnique(ShopItem item) => kinds[item.kind]?.unique ?? false;

  bool isSingleActive(ShopItem item) =>
      kinds[item.kind]?.singleActive ?? false;

  String categoryLabel(ExpenseCategory category) =>
      categories[category]?.label ?? category.name;

  String categoryHint(ExpenseCategory category) =>
      categories[category]?.hint ?? '';

  String categoryIconId(ExpenseCategory category) =>
      categories[category]?.iconId ?? '';

  /// Сколько стоят все обязательные покупки дня — нужно планировщику (A-03).
  int get mandatoryCost {
    var sum = 0;
    for (final item in items) {
      if (item.category == ExpenseCategory.mandatory) sum += item.price;
    }
    return sum;
  }
}
