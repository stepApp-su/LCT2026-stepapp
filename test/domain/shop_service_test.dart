import 'dart:convert';
import 'dart:io';

import 'package:finni/domain/models/models.dart';
import 'package:finni/domain/services/shop_service.dart';
import 'package:finni/domain/services/wallet_service.dart';
import 'package:flutter_test/flutter_test.dart';

final _at = DateTime(2026, 9, 21, 12);

ShopCatalog _catalog() => ShopCatalog.fromJson(
      (jsonDecode(File('assets/content/shop.json').readAsStringSync()) as Map)
          .cast<String, Object?>(),
    );

ShopService _shop(
  ShopCatalog catalog, {
  int balance = 100,
  int day = 1,
  PetStage stage = PetStage.adult,
}) =>
    ShopService(
      catalog: catalog,
      wallet: WalletService(initial: Wallet.create(balance: balance, savings: 0)),
      dayNumber: day,
      stage: stage,
    );

/// Каталог из трёх позиций: нужен, чтобы проверить отказы, которых
/// в настоящем shop.json нет — скрытую и бесплатную позицию.
ShopCatalog _tinyCatalog() => ShopCatalog.create(
      categories: const {
        ExpenseCategory.mandatory:
            ShopCategoryInfo(label: 'Обязательное', hint: '', iconId: 'i_m'),
        ExpenseCategory.optional:
            ShopCategoryInfo(label: 'Желаемое', hint: '', iconId: 'i_o'),
      },
      kinds: const {
        ShopItemKind.consumable:
            ShopKindInfo(label: '', unique: false, singleActive: false),
        ShopItemKind.toy:
            ShopKindInfo(label: '', unique: true, singleActive: false),
      },
      texts: const ShopTexts(
        effect: '{stat} +{delta}',
        dailyEffect: '{stat} +{delta}',
        confirmQuestion: 'Купим {titleAccusative}?',
        alreadyOwned: 'Уже есть у тебя',
        dailyLimitReached: 'На сегодня хватит',
        wallpaperApplied: '',
      ),
      items: [
        ShopItem.create(
            id: 'bread',
            title: 'Хлеб',
            price: 10,
            category: ExpenseCategory.mandatory),
        ShopItem.create(
            id: 'secret',
            title: 'Служебная вещь',
            price: 10,
            category: ExpenseCategory.optional,
            kind: ShopItemKind.toy,
            showInShop: false),
        ShopItem.create(
            id: 'gift',
            title: 'Подарок на старте',
            price: 0,
            category: ExpenseCategory.optional,
            kind: ShopItemKind.toy),
      ],
    );

PurchaseOutcome _buy(ShopService shop, String id,
    {bool hasUnusedTasksToday = false}) {
  final asked = shop.askToBuy(id);
  if (asked is! PurchaseConfirm) return asked;
  return shop.confirm(asked,
      at: _at, hasUnusedTasksToday: hasUnusedTasksToday);
}

void main() {
  final catalog = _catalog();

  group('каталог', () {
    test('позиций больше минимума, обе категории представлены', () {
      final mandatory = catalog.items
          .where((i) => i.category == ExpenseCategory.mandatory)
          .toList();
      final optional = catalog.items
          .where((i) => i.category == ExpenseCategory.optional)
          .toList();
      expect(catalog.items.length, greaterThanOrEqualTo(15));
      expect(mandatory.length, greaterThanOrEqualTo(3));
      expect(optional.length, greaterThanOrEqualTo(12));
    });

    test('у каждой позиции есть цена, категория, иконка и описание', () {
      for (final item in catalog.items) {
        expect(item.price, greaterThanOrEqualTo(0), reason: item.id);
        expect(catalog.categories.containsKey(item.category), isTrue,
            reason: item.id);
        expect(item.iconId, isNotEmpty, reason: item.id);
        expect(item.description, isNotEmpty, reason: item.id);
        expect(item.diaryText, isNotEmpty, reason: item.id);
      }
    });

    test('битая ссылка в сравнении цен ловится при загрузке', () {
      Map<String, Object?> broken() =>
          (jsonDecode(File('assets/content/shop.json').readAsStringSync())
                  as Map)
              .cast<String, Object?>();

      final noItem = broken();
      ((noItem['priceComparison'] as Map)['anchors'] as List).first['itemIds'] =
          ['no_such_item'];
      expect(() => ShopCatalog.fromJson(noItem), throwsArgumentError);

      final noAnchor = broken();
      ((noAnchor['priceComparison'] as Map)['rules'] as List).first['anchors'] =
          ['no_such_anchor'];
      expect(() => ShopCatalog.fromJson(noAnchor), throwsArgumentError);
    });

    test('обязательные позиции влияют на сытость и уход', () {
      final food = catalog.byId('food')!;
      expect(food.category, ExpenseCategory.mandatory);
      expect(food.effects.single.stat, PetStat.satiety);
      expect(food.effects.single.delta, 40);
      expect(catalog.mandatoryCost, 25);
    });
  });

  group('карточка товара', () {
    test('цена, категория и влияние — все три поля', () {
      final view = _shop(catalog).viewOf('food')!;
      expect(view.priceText, '15 монет');
      expect(view.categoryLabel, 'Обязательное');
      expect(view.categoryIconId, isNotEmpty);
      expect(view.effectTexts, ['Сытость +40']);
    });

    test('влияние в человеческом виде, а не числами', () {
      final view = _shop(catalog).viewOf('apple')!;
      expect(view.effectTexts, ['Сытость +10', 'Настроение +4']);
    });

    test('ежедневное влияние подписано отдельно', () {
      final view = _shop(catalog).viewOf('bouncy_ball')!;
      expect(view.effectTexts, ['Настроение +10']);
      expect(view.dailyEffectTexts, ['Каждый день: Настроение +2']);
    });
  });

  group('сравнение с понятным эквивалентом', () {
    late ShopService shop;
    setUp(() => shop = _shop(catalog));

    test('ровно столько же, сколько еда на день', () {
      expect(shop.viewOf('bouncy_ball')!.comparisonText,
          'Попрыгунчик — 15 монет. Это столько же, сколько еда на 1 день.');
    });

    test('ровно столько же, сколько все обязательные покупки', () {
      expect(shop.viewOf('glasses')!.comparisonText,
          'Очки — 25 монет. Это столько же, сколько все обязательные покупки на 1 день.');
    });

    test('с остатком', () {
      expect(shop.viewOf('cap')!.comparisonText,
          'Кепка — 20 монет. Это еда на 1 день и ещё 5 монет.');
    });

    test('дешевле дневной еды', () {
      expect(shop.viewOf('apple')!.comparisonText,
          'Яблоко — 8 монет. Это дешевле, чем еда на один день.');
    });

    test('обязательным покупкам сравнение не приписываем', () {
      expect(shop.viewOf('food')!.comparisonText, isNull);
    });

    test('множественное число согласовано', () {
      expect(shop.viewOf('raincoat')!.comparisonText, contains('еда на 2 дня'));
      expect(shop.viewOf('balloon')!.comparisonText,
          contains('вода и свет на 2 дня'));
    });
  });

  group('покупка', () {
    test('списывает ровно цену и пишет объяснение в журнал', () {
      final wallet =
          WalletService(initial: Wallet.create(balance: 40, savings: 0));
      final shop = ShopService(
          catalog: catalog, wallet: wallet, stage: PetStage.adult);

      final done = _buy(shop, 'food') as PurchaseDone;
      expect(done.wallet.balance, 25);
      expect(wallet.journal.single.amount, 15);
      expect(wallet.journal.single.category, ExpenseCategory.mandatory);
      expect(wallet.journal.single.reasonText, 'Купили еду на день.');
      expect(done.effects.single.delta, 40);
    });

    test('без подтверждения покупка не проходит', () {
      final wallet =
          WalletService(initial: Wallet.create(balance: 100, savings: 0));
      final shop = ShopService(
          catalog: catalog, wallet: wallet, stage: PetStage.adult);
      final confirmation = shop.askToBuy('cap') as PurchaseConfirm;

      final forged = PurchaseConfirm(
          question: confirmation.question,
          view: confirmation.view,
          token: confirmation.token + 1);
      expect(shop.confirm(forged, at: _at), isA<PurchaseRefused>());
      expect(shop.isOwned('cap'), isFalse);
      expect(wallet.wallet.balance, 100);
      expect(wallet.journal, isEmpty);
    });

    test('повторное подтверждение не списывает второй раз', () {
      final wallet =
          WalletService(initial: Wallet.create(balance: 100, savings: 0));
      final shop = ShopService(
          catalog: catalog, wallet: wallet, stage: PetStage.adult);

      final confirmation = shop.askToBuy('cap') as PurchaseConfirm;
      expect(shop.confirm(confirmation, at: _at), isA<PurchaseDone>());
      expect(shop.confirm(confirmation, at: _at), isA<PurchaseRefused>());
      expect(wallet.wallet.balance, 80);
      expect(wallet.journal.length, 1);
    });

    test('вопрос подтверждения — в винительном падеже', () {
      final shop = _shop(catalog);
      expect((shop.askToBuy('cap') as PurchaseConfirm).question,
          'Купим кепку?');
    });
  });

  group('уникальность и владение', () {
    test('уникальный предмет не купить дважды', () {
      final wallet =
          WalletService(initial: Wallet.create(balance: 100, savings: 0));
      final shop = ShopService(
          catalog: catalog, wallet: wallet, stage: PetStage.adult);

      expect(_buy(shop, 'cap'), isA<PurchaseDone>());
      final second = _buy(shop, 'cap');
      expect(second, isA<PurchaseRefused>());
      expect((second as PurchaseRefused).textRu, 'Уже есть у тебя');
      expect(wallet.wallet.balance, 80);
    });

    test('купленное не теряется при смене дня и стадии', () {
      final shop = _shop(catalog, stage: PetStage.baby);
      _buy(shop, 'bow');
      shop.startDay(5);
      shop.setStage(PetStage.teen);
      expect(shop.isOwned('bow'), isTrue);
    });

    test('список владения снаружи не поменять', () {
      final shop = _shop(catalog);
      expect(() => shop.owned.add('cap'), throwsUnsupportedError);
    });

    test('расходники покупаются повторно, но не чаще лимита за день', () {
      final wallet =
          WalletService(initial: Wallet.create(balance: 100, savings: 0));
      final shop = ShopService(
          catalog: catalog, wallet: wallet, stage: PetStage.adult);

      expect(_buy(shop, 'treat'), isA<PurchaseDone>());
      expect(_buy(shop, 'treat'), isA<PurchaseDone>());
      final third = _buy(shop, 'treat');
      expect(third, isA<PurchaseRefused>());
      expect((third as PurchaseRefused).textRu,
          'На сегодня хватит. Завтра можно снова!');
      expect(wallet.wallet.balance, 90);

      shop.startDay(2);
      expect(_buy(shop, 'treat'), isA<PurchaseDone>());
    });

    test('обои: активными остаются последние, старые никуда не деваются', () {
      final shop = _shop(catalog, balance: 100, day: 12);
      expect(shop.activeWallpaperId, 'wp_plain');

      final done = _buy(shop, 'wp_dots') as PurchaseDone;
      expect(shop.activeWallpaperId, 'wp_dots');
      expect(done.noteText, 'Обои поменяли! Старые никуда не делись.');
      expect(shop.isOwned('wp_plain'), isTrue);
    });

    test('игрушки в комнате радуют каждый день', () {
      final shop = _shop(catalog);
      _buy(shop, 'bouncy_ball');
      _buy(shop, 'puzzle');
      expect(shop.dailyEffectsOfOwned().map((e) => e.delta), [2, 2]);
    });
  });

  group('покупать можно только то, что продаётся', () {
    test('скрытую позицию по id не купить', () {
      final shop = _shop(catalog, day: 15);
      final refused = shop.askToBuy('wp_plain');
      expect(refused, isA<PurchaseRefused>());
      expect((refused as PurchaseRefused).textRu, 'Этого нет в магазине');
    });

    test('скрытая позиция не спасается тем, что её ещё нет у тебя', () {
      final wallet =
          WalletService(initial: Wallet.create(balance: 100, savings: 0));
      final shop = ShopService(catalog: _tinyCatalog(), wallet: wallet);

      expect(shop.isOwned('secret'), isFalse);
      expect((_buy(shop, 'secret') as PurchaseRefused).textRu,
          'Этого нет в магазине');
      expect(wallet.journal, isEmpty);
      expect(wallet.wallet.balance, 100);
    });

    test('бесплатную позицию не купить: операции на ноль монет не бывает', () {
      final wallet =
          WalletService(initial: Wallet.create(balance: 100, savings: 0));
      final shop = ShopService(catalog: _tinyCatalog(), wallet: wallet);

      expect((_buy(shop, 'gift') as PurchaseRefused).textRu, 'Это не продаётся');
      expect(wallet.journal, isEmpty);
    });

    test('неизвестный id — отказ, а не падение', () {
      expect((_shop(catalog).askToBuy('no_such') as PurchaseRefused).textRu,
          'Такого товара нет');
    });

    test('смена стадии закрывает открытое окно подтверждения', () {
      final wallet =
          WalletService(initial: Wallet.create(balance: 100, savings: 0));
      final shop = ShopService(
          catalog: catalog, wallet: wallet, stage: PetStage.adult);

      final asked = shop.askToBuy('cap') as PurchaseConfirm;
      shop.setStage(PetStage.adult);
      final refused = shop.confirm(asked, at: _at);
      expect((refused as PurchaseRefused).textRu, 'Сначала спросим: купим?');
      expect(wallet.wallet.balance, 100);
    });
  });

  group('нехватка средств', () {
    test('покупка не проходит и не меняет состояние', () {
      final wallet =
          WalletService(initial: Wallet.create(balance: 10, savings: 0));
      final shop = ShopService(
          catalog: catalog, wallet: wallet, stage: PetStage.adult);

      final result = _buy(shop, 'cap', hasUnusedTasksToday: true);
      expect(result, isA<PurchaseNotEnough>());
      expect((result as PurchaseNotEnough).gap, 10);
      expect(wallet.wallet.balance, 10);
      expect(wallet.journal, isEmpty);
      expect(shop.isOwned('cap'), isFalse);
    });

    test('предлагает заработать, отложить и вариант подешевле', () {
      final shop = _shop(catalog, balance: 10);
      final result =
          _buy(shop, 'cap', hasUnusedTasksToday: true) as PurchaseNotEnough;
      expect(result.options.map((o) => o.route),
          ['tasks', 'postpone', 'shop:balloon']);
      expect(result.options.last.textRu, contains('Воздушный шарик'));
    });

    test('после задания покупка завершается тем же подтверждением', () {
      final wallet =
          WalletService(initial: Wallet.create(balance: 10, savings: 0));
      final shop = ShopService(
          catalog: catalog, wallet: wallet, stage: PetStage.adult);

      final asked = shop.askToBuy('cap') as PurchaseConfirm;
      final short = shop.confirm(asked, at: _at) as PurchaseNotEnough;
      expect(short.confirmation, same(asked));

      wallet.earn(
          amount: 10,
          sourceId: 'task:need_or_want',
          reasonText: 'Награда за задание',
          at: _at,
          dayNumber: 1);

      expect(shop.confirm(short.confirmation, at: _at), isA<PurchaseDone>());
      expect(wallet.wallet.balance, 0);
      expect(shop.isOwned('cap'), isTrue);
    });

    test('в альтернативы не попадает уже купленное', () {
      // Попрыгунчик за 15 был бы лучшей заменой, но он уже куплен,
      // поэтому предлагаем следующее по цене — яблоко.
      final shop = _shop(catalog, balance: 30, stage: PetStage.egg);
      expect(_buy(shop, 'bouncy_ball'), isA<PurchaseDone>());
      final result = _buy(shop, 'rug') as PurchaseNotEnough;
      expect(result.options.last.route, 'shop:apple');
    });
  });

  group('каталог расширяется по стадиям и дням', () {
    test('на яйце нарядов и мебели по стадиям ещё нет', () {
      final shop = _shop(catalog, stage: PetStage.egg);
      final ids = shop.showcase().map((i) => i.id);
      expect(ids, isNot(contains('bow')));
      expect(ids, isNot(contains('pouf')));
      expect(ids, contains('food'));
    });

    test('стадия открывает новое и сообщает об этом', () {
      final shop = _shop(catalog, stage: PetStage.egg);
      expect(shop.setStage(PetStage.baby), 'В магазине появились наряды!');
      expect(shop.showcase().map((i) => i.id), contains('bow'));
      expect(shop.setStage(PetStage.teen),
          'Теперь можно купить мебель для комнаты!');
    });

    test('закрытую позицию не купить', () {
      final shop = _shop(catalog, stage: PetStage.egg);
      expect(_buy(shop, 'bow'), isA<PurchaseRefused>());
    });

    test('новинка появляется по номеру дня', () {
      final shop = _shop(catalog, day: 7);
      expect(shop.showcase().map((i) => i.id), isNot(contains('night_light')));
      expect(shop.startDay(8), 'В магазине новинка! Загляни посмотреть.');
      expect(shop.showcase().map((i) => i.id), contains('night_light'));
      expect(shop.startDay(9), isNull);
    });

    test('витрина: обязательное сначала, дальше по цене', () {
      final showcase = _shop(catalog, day: 15).showcase();
      final firstOptional =
          showcase.indexWhere((i) => i.category == ExpenseCategory.optional);
      expect(
          showcase
              .take(firstOptional)
              .every((i) => i.category == ExpenseCategory.mandatory),
          isTrue);
      final optionalPrices = showcase
          .skip(firstOptional)
          .map((i) => i.price)
          .toList();
      expect(optionalPrices, orderedEquals([...optionalPrices]..sort()));
    });
  });

  // Главный риск экономики: монеты переносятся между днями, и к седьмому дню
  // бережливый ребёнок копит излишек, после которого выбирать не из чего.
  group('запас не убирает необходимость выбора', () {
    const goalPrice = 90;

    PetStage stageOfDay(int day) {
      if (day >= 10) return PetStage.adult;
      if (day >= 6) return PetStage.teen;
      if (day >= 3) return PetStage.baby;
      return PetStage.egg;
    }

    for (final income in [40, 45, 50, 55, 60]) {
      test('15 дней бережливой игры при доходе $income', () {
        final wallet = WalletService();
        final shop = ShopService(catalog: catalog, wallet: wallet);

        for (var day = 1; day <= 15; day++) {
          shop.startDay(day);
          shop.setStage(stageOfDay(day));
          wallet.earn(
              amount: income,
              sourceId: 'day:income',
              reasonText: 'Монетки нового дня',
              at: _at,
              dayNumber: day);

          // Бережливая игра: только обязательное, всё остальное копится.
          for (final id in ['food', 'water_light', 'cleaning']) {
            expect(_buy(shop, id), isA<PurchaseDone>(), reason: 'день $day');
          }

          final stash = wallet.wallet.balance + wallet.wallet.savings;
          final wanted = shop
              .showcase()
              .where((i) =>
                  i.category == ExpenseCategory.optional && !shop.isOwned(i.id))
              .fold<int>(0, (sum, i) => sum + i.price);

          // Формулировка задачи: запас не покрывает разом обязательное,
          // желаемое и остаток цели.
          expect(
            stash,
            lessThan(catalog.mandatoryCost + wanted + goalPrice),
            reason: 'день $day: запас $stash покрыл бы всё сразу — '
                'выбор перестал быть выбором',
          );
          // И строже: не хватает даже на одну витрину желаемого.
          // Именно эта планка ловит излишек к седьмому дню.
          expect(
            stash,
            lessThan(wanted),
            reason: 'день $day: запаса $stash хватает на всю витрину '
                'желаемого ($wanted) — покупать можно не выбирая',
          );
        }
      });
    }
  });
}
