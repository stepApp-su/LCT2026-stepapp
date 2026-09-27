/// Магазин: витрина по стадиям, карточка товара и покупка в два шага.
/// Перед покупкой ребёнок обязан увидеть цену, категорию и влияние
/// на питомца (ТЗ 2.5.6), поэтому купить мимо окна подтверждения нельзя.
/// Продажи обратно нет: для семилетки перепродажа создаёт ложное
/// ощущение обратимости покупки.
library;

import '../models/models.dart';
import '../ru_words.dart';
import '../text_template.dart';
import 'wallet_service.dart';

/// Всё, что показывается в карточке товара. Три обязательных поля —
/// цена, категория и влияние — заполнены всегда.
final class ShopItemView {
  const ShopItemView({
    required this.item,
    required this.priceText,
    required this.categoryLabel,
    required this.categoryHint,
    required this.categoryIconId,
    required this.effectTexts,
    required this.dailyEffectTexts,
    required this.comparisonText,
    required this.isOwned,
    required this.isAffordable,
    required this.blockedText,
  });

  final ShopItem item;

  final String priceText;
  final String categoryLabel;
  final String categoryHint;
  final String categoryIconId;

  /// «Сытость +40» — человеческий вид, а не сырые числа.
  final List<String> effectTexts;

  /// «Каждый день: Настроение +2».
  final List<String> dailyEffectTexts;

  /// «Кепка — 20 монет. Это еда на 1 день и ещё 5 монет.»
  final String? comparisonText;

  final bool isOwned;
  final bool isAffordable;

  /// Почему кнопка покупки недоступна; null — покупать можно.
  final String? blockedText;

  String get id => item.id;
  String get title => item.title;
  int get price => item.price;
  ExpenseCategory get category => item.category;
}

sealed class PurchaseOutcome {
  const PurchaseOutcome();
}

/// Окно подтверждения. Пока ребёнок не нажмёт «да», ничего не списано.
final class PurchaseConfirm extends PurchaseOutcome {
  const PurchaseConfirm({
    required this.question,
    required this.view,
    required this.token,
  });

  final String question;
  final ShopItemView view;

  /// Одноразовый ключ: защищает и от покупки мимо окна, и от двойного тапа.
  final int token;
}

final class PurchaseDone extends PurchaseOutcome {
  const PurchaseDone({
    required this.item,
    required this.wallet,
    required this.transaction,
    required this.effects,
    required this.diaryText,
    required this.noteText,
  });

  final ShopItem item;
  final Wallet wallet;
  final Transaction transaction;

  /// Разовое влияние на питомца — применяет цикл дня.
  final List<StateEffect> effects;

  final String diaryText;

  /// Доп. пояснение, например про поклеенные обои.
  final String? noteText;
}

/// Покупка не состоялась, состояние не изменилось.
final class PurchaseRefused extends PurchaseOutcome {
  const PurchaseRefused(this.textRu);

  final String textRu;
}

final class PurchaseNotEnough extends PurchaseOutcome {
  const PurchaseNotEnough({
    required this.gap,
    required this.options,
    required this.confirmation,
  });

  final int gap;
  final List<NotEnoughOption> options;

  /// Окно остаётся открытым: когда монеты появятся, покупка завершается
  /// этим же подтверждением — спрашивать «купим?» второй раз не нужно.
  final PurchaseConfirm confirmation;
}

final class ShopService {
  ShopService({
    required ShopCatalog catalog,
    required WalletService wallet,
    Iterable<String> owned = const [],
    String? activeWallpaperId,
    int dayNumber = 1,
    PetStage stage = PetStage.egg,
  })  : _catalog = catalog,
        _wallet = wallet,
        _day = dayNumber,
        _stage = stage,
        _owned = {
          ...owned,
          for (final item in catalog.items)
            if (item.ownedAtStart) item.id,
        } {
    _activeWallpaperId = activeWallpaperId ?? _defaultWallpaperId();
  }

  final ShopCatalog _catalog;
  final WalletService _wallet;
  final Set<String> _owned;

  final Map<String, int> _boughtToday = {};

  int _day;
  PetStage _stage;
  String? _activeWallpaperId;
  int _tokenCounter = 0;
  int? _pendingToken;

  ShopCatalog get catalog => _catalog;
  int get dayNumber => _day;
  PetStage get stage => _stage;

  /// Купленное не теряется: список только растёт.
  Set<String> get owned => Set.unmodifiable(_owned);

  String? get activeWallpaperId => _activeWallpaperId;

  bool isOwned(String itemId) => _owned.contains(itemId);

  bool applyWallpaper(String itemId) {
    final item = _catalog.byId(itemId);
    if (item == null ||
        !_catalog.isSingleActive(item) ||
        !_owned.contains(itemId)) {
      return false;
    }
    _activeWallpaperId = itemId;
    return true;
  }

  int boughtToday(String itemId) => _boughtToday[itemId] ?? 0;

  String? _defaultWallpaperId() {
    for (final item in _catalog.items) {
      if (item.ownedAtStart && _catalog.isSingleActive(item)) return item.id;
    }
    return null;
  }

  /// Новый день: дневные лимиты обнуляются. Вернёт сообщение о новинке,
  /// если с этим днём в витрине что-то появилось.
  String? startDay(int dayNumber) {
    final before = _showcaseIds();
    _day = dayNumber;
    _boughtToday.clear();
    _pendingToken = null;
    return _appearedSince(before) ? _catalog.newItemByDayMessage : null;
  }

  /// Новая стадия расширяет каталог: сумма доступных соблазнов должна
  /// расти быстрее накоплений, иначе выбор перестаёт быть выбором.
  String? setStage(PetStage stage) {
    final before = _showcaseIds();
    _stage = stage;
    // Витрина изменилась — открытое подтверждение больше не актуально.
    _pendingToken = null;
    return _appearedSince(before) ? _catalog.stageUnlockMessages[stage] : null;
  }

  Set<String> _showcaseIds() => {for (final i in showcase()) i.id};

  bool _appearedSince(Set<String> before) =>
      showcase().any((i) => !before.contains(i.id));

  bool isUnlocked(ShopItem item) =>
      _stage.index >= item.minStage.index && _day >= item.minDay;

  /// Витрина: обязательное сначала, дальше по возрастанию цены.
  /// Купленные уникальные вещи остаются на полке с пометкой.
  List<ShopItem> showcase() {
    final visible = [
      for (final item in _catalog.items)
        if (item.showInShop && isUnlocked(item)) item
    ];
    visible.sort((a, b) {
      final byCategory = a.category.index.compareTo(b.category.index);
      return byCategory != 0 ? byCategory : a.price.compareTo(b.price);
    });
    return List.unmodifiable(visible);
  }

  ShopItemView view(ShopItem item) {
    final owned = _catalog.isUnique(item) && _owned.contains(item.id);
    final limitReached =
        item.maxPerDay != null && boughtToday(item.id) >= item.maxPerDay!;
    return ShopItemView(
      item: item,
      priceText: '${item.price} ${ruCoins(item.price)}',
      categoryLabel: _catalog.categoryLabel(item.category),
      categoryHint: _catalog.categoryHint(item.category),
      categoryIconId: _catalog.categoryIconId(item.category),
      effectTexts: [
        for (final e in item.effects) _effectText(_catalog.texts.effect, e)
      ],
      dailyEffectTexts: [
        for (final e in item.dailyEffects)
          _effectText(_catalog.texts.dailyEffect, e)
      ],
      comparisonText: comparisonFor(item),
      isOwned: owned,
      isAffordable: item.price <= _wallet.wallet.balance,
      blockedText: owned
          ? _catalog.texts.alreadyOwned
          : limitReached
              ? _catalog.texts.dailyLimitReached
              : null,
    );
  }

  /// Почему покупка невозможна прямо сейчас; null — можно покупать.
  /// Одна точка правды для обоих шагов: и для окна, и для списания.
  /// Витрина — не единственный вход: по id можно попросить что угодно,
  /// поэтому скрытое и бесплатное отсекаем здесь, а не фильтром показа.
  String? refusalFor(ShopItem item) {
    final texts = _catalog.texts;
    if (!item.showInShop) return texts.notInShop;
    if (item.price <= 0) return texts.notForSale;
    if (!isUnlocked(item)) return texts.notUnlocked;
    return view(item).blockedText;
  }

  ShopItemView? viewOf(String itemId) {
    final item = _catalog.byId(itemId);
    return item == null ? null : view(item);
  }

  String _effectText(String template, StateEffect effect) => fillTemplate(
        template,
        {'stat': petStatLabel(effect.stat), 'delta': '${effect.delta}'},
      );

  /// Шаг 1: открыть окно подтверждения. Кошелька не касается.
  PurchaseOutcome askToBuy(String itemId) {
    final item = _catalog.byId(itemId);
    if (item == null) return PurchaseRefused(_catalog.texts.unknownItem);
    final refusal = refusalFor(item);
    if (refusal != null) return PurchaseRefused(refusal);
    final card = view(item);

    _pendingToken = ++_tokenCounter;
    return PurchaseConfirm(
      question: fillTemplate(_catalog.texts.confirmQuestion, {
        'title': item.title,
        'titleAccusative': item.titleAccusative,
      }),
      view: card,
      token: _pendingToken!,
    );
  }

  /// Шаг 2: покупка. Только по свежему подтверждению из [askToBuy]
  /// и только один раз — повторный вызов ничего не спишет.
  PurchaseOutcome confirm(
    PurchaseConfirm confirmation, {
    required DateTime at,
    bool hasUnusedTasksToday = false,
  }) {
    if (_pendingToken == null || confirmation.token != _pendingToken) {
      return PurchaseRefused(_catalog.texts.needsConfirmation);
    }
    final item = confirmation.view.item;
    final refusal = refusalFor(item);
    if (refusal != null) {
      _pendingToken = null;
      return PurchaseRefused(refusal);
    }

    final outcome = _wallet.spend(
      amount: item.price,
      itemId: item.id,
      category: item.category,
      reasonText: item.diaryText,
      at: at,
      dayNumber: _day,
      hasUnusedTasksToday: hasUnusedTasksToday,
      catalog: _alternativesTo(item),
    );
    switch (outcome) {
      // Окно подтверждения остаётся открытым: ребёнок выбирает из вариантов.
      case WalletNotEnough(:final gap, :final options):
        return PurchaseNotEnough(
            gap: gap, options: options, confirmation: confirmation);
      case WalletOk(:final wallet, :final transaction):
        _pendingToken = null;
        _boughtToday.update(item.id, (n) => n + 1, ifAbsent: () => 1);
        if (_catalog.isUnique(item)) _owned.add(item.id);
        String? note;
        if (_catalog.isSingleActive(item)) {
          _activeWallpaperId = item.id;
          note = _catalog.texts.wallpaperApplied;
        }
        return PurchaseDone(
          item: item,
          wallet: wallet,
          transaction: transaction,
          effects: item.effects,
          diaryText: item.diaryText,
          noteText: note,
        );
    }
  }

  /// Что вещи в комнате дают каждый день — применяет цикл дня (A-07).
  List<StateEffect> dailyEffectsOfOwned() => [
        for (final item in _catalog.items)
          if (_owned.contains(item.id)) ...item.dailyEffects
      ];

  List<ShopItem> _alternativesTo(ShopItem item) => [
        for (final other in showcase())
          if (other.id != item.id &&
              other.category == item.category &&
              (item.category == ExpenseCategory.optional ||
                  other.group == item.group) &&
              refusalFor(other) == null)
            other
      ];

  /// Понятный эквивалент цены. Работает только для той категории,
  /// которую разрешает каталог, и только пока сравнение остаётся понятным.
  String? comparisonFor(ShopItem item) {
    final comparison = _catalog.priceComparison;
    if (!comparison.applyToCategories.contains(item.category)) return null;
    for (final rule in comparison.rules) {
      for (final anchorId in rule.anchorIds) {
        final anchor = comparison.anchor(anchorId);
        if (anchor == null) continue;
        final sum = _anchorSum(anchor);
        if (sum <= 0) continue;
        final text = _applyRule(rule, anchor, sum, item);
        if (text != null) return text;
      }
    }
    return null;
  }

  int _anchorSum(PriceAnchor anchor) {
    var sum = 0;
    for (final id in anchor.itemIds) {
      sum += _catalog.byId(id)?.price ?? 0;
    }
    return sum;
  }

  String? _applyRule(
      PriceRule rule, PriceAnchor anchor, int sum, ShopItem item) {
    final price = item.price;
    switch (rule.type) {
      case PriceRuleType.exactMultiple:
        if (price % sum != 0) return null;
        final n = price ~/ sum;
        if (n < 1 || n > anchor.maxMultiplier) return null;
        return _fillComparison(rule.template, anchor, item, n: n);
      case PriceRuleType.withRemainder:
        final n = price ~/ sum;
        final rest = price % sum;
        if (n < 1 || n > anchor.maxMultiplier || rest == 0) return null;
        return _fillComparison(rule.template, anchor, item, n: n, rest: rest);
      case PriceRuleType.lessThan:
        if (price >= sum) return null;
        return _fillComparison(rule.template, anchor, item);
    }
  }

  String _fillComparison(
    String template,
    PriceAnchor anchor,
    ShopItem item, {
    int n = 0,
    int rest = 0,
  }) {
    final values = {
      'title': item.title,
      'titleAccusative': item.titleAccusative,
      'price': '${item.price}',
      'coin': ruCoins(item.price),
      'n': '$n',
      'day': ruDays(n),
      'rest': '$rest',
      'restCoin': ruCoins(rest),
    };
    return fillTemplate(template, {
      ...values,
      'anchorPhrase': fillTemplate(anchor.phrase, values),
    });
  }
}
