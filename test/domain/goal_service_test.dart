import 'dart:convert';
import 'dart:io';

import 'package:finni/domain/models/models.dart';
import 'package:finni/domain/services/goal_service.dart';
import 'package:finni/domain/services/wallet_service.dart';
import 'package:flutter_test/flutter_test.dart';

final _at = DateTime(2026, 9, 22, 12);

Map<String, Object?> _rawCatalog() =>
    (jsonDecode(File('assets/content/goals.json').readAsStringSync()) as Map)
        .cast<String, Object?>();

GoalCatalog _catalog() => GoalCatalog.fromJson(_rawCatalog());

/// Пополнения по дням, как их сделал бы ребёнок: из баланса в копилку.
WalletService _wallet({
  int balance = 0,
  int savings = 0,
  Map<int, int> deposits = const {},
}) {
  final wallet =
      WalletService(initial: Wallet.create(balance: balance, savings: savings));
  final days = deposits.keys.toList()..sort();
  for (final day in days) {
    wallet.toSavings(amount: deposits[day]!, at: _at, dayNumber: day);
  }
  return wallet;
}

GoalService _goals(
  GoalCatalog catalog, {
  WalletService? wallet,
  String? goalId = 'scooter',
  int day = 1,
  Iterable<String> reached = const [],
}) =>
    GoalService(
      catalog: catalog,
      wallet: wallet ?? _wallet(),
      selectedGoalId: goalId,
      dayNumber: day,
      reachedGoalIds: reached,
    );

void main() {
  final catalog = _catalog();

  group('каталог целей', () {
    test('целей больше минимума ТЗ, цены растут', () {
      expect(catalog.goals.length, greaterThanOrEqualTo(3));
      final prices = catalog.goals.map((g) => g.price).toList();
      expect(prices, orderedEquals([...prices]..sort()));
      expect(prices.first, 90);
    });

    test('у каждой цели есть падежи, иконка, награда и тексты', () {
      for (final goal in catalog.goals) {
        expect(goal.titleAccusative, isNotEmpty, reason: goal.id);
        expect(goal.titleGenitive, isNotEmpty, reason: goal.id);
        expect(goal.iconId, isNotEmpty, reason: goal.id);
        expect(goal.description, isNotEmpty, reason: goal.id);
        expect(goal.reachedText, isNotEmpty, reason: goal.id);
        expect(goal.rewardEffects.single.stat, PetStat.cozy, reason: goal.id);
      }
    });

    test('новичку советуем цель поменьше', () {
      expect(catalog.recommended?.id, 'constructor');
      expect(catalog.recommended?.price, 90);
    });

    test('округление среднего до нуля каталог не пропустит', () {
      final broken = _rawCatalog();
      (broken['settings'] as Map)['roundAverageTo'] = 0;
      expect(() => GoalCatalog.fromJson(broken), throwsArgumentError);
    });

    test('веха без текста каталог не пропустит', () {
      final broken = _rawCatalog();
      (broken['settings'] as Map)['milestonesPercent'] = [25, 50, 75, 90];
      expect(() => GoalCatalog.fromJson(broken), throwsArgumentError);
    });

    test('ссылка на несуществующую стартовую цель ловится при загрузке', () {
      final broken = _rawCatalog();
      (broken['settings'] as Map)['starterRecommendationId'] = 'no_such_goal';
      expect(() => GoalCatalog.fromJson(broken), throwsArgumentError);
    });

    test('повтор id ловится при загрузке', () {
      final broken = _rawCatalog();
      final goals = broken['goals'] as List;
      goals.add(goals.first);
      expect(() => GoalCatalog.fromJson(broken), throwsArgumentError);
    });
  });

  group('срок достижения цели', () {
    test('пополнений не было — срок не показываем, а зовём начать', () {
      final service = _goals(catalog, wallet: _wallet(savings: 30));
      final eta = service.eta();
      expect(eta.days, isNull);
      expect(eta.averageDeposit, isNull);
      expect(eta.textRu, 'Начни откладывать, и я посчитаю, когда накопим.');
    });

    test('расчёт объясняется словами, а не одной цифрой', () {
      final service = _goals(
        catalog,
        wallet: _wallet(balance: 45, deposits: {1: 15, 2: 15, 3: 15}),
        day: 4,
      );
      final eta = service.eta();
      expect(eta.averageDeposit, 15);
      expect(eta.days, 5);
      expect(eta.textRu,
          'Ты откладываешь примерно по 15 монет. Осталось 75. Это ещё 5 дней.');
    });

    test('меньше трёх дней — берём что есть', () {
      final service =
          _goals(catalog, wallet: _wallet(balance: 15, deposits: {1: 15}), day: 2);
      expect(service.averageDeposit(), 15);
      expect(service.eta().days, 7);
    });

    test('берутся последние три дня с пополнением, а не все', () {
      final service = _goals(
        catalog,
        wallet: _wallet(
            balance: 75, deposits: {1: 5, 2: 5, 3: 5, 4: 20, 5: 20, 6: 20}),
        day: 7,
      );
      expect(service.averageDeposit(), 20);
      expect(service.eta().days, 3);
    });

    test('в среднее идут только завершённые дни', () {
      final service = _goals(catalog,
          wallet: _wallet(balance: 40, deposits: {1: 10, 2: 30}), day: 2);
      expect(service.averageDeposit(), 10);
      service.startDay(3);
      expect(service.averageDeposit(), 20);
    });

    test('дробное среднее округляется по настройке', () {
      final service = _goals(catalog,
          wallet: _wallet(balance: 35, deposits: {1: 10, 2: 10, 3: 15}), day: 4);
      expect(service.averageDeposit(), 12);
      expect(service.eta().days, 8);
    });

    test('деления на ноль не бывает: среднее не опускается ниже шага', () {
      final raw = _rawCatalog();
      (raw['settings'] as Map)['roundAverageTo'] = 5;
      final service = GoalService(
        catalog: GoalCatalog.fromJson(raw),
        wallet: _wallet(balance: 1, deposits: {1: 1}),
        selectedGoalId: 'scooter',
        dayNumber: 2,
      );
      expect(service.averageDeposit(), 5);
      expect(service.eta().days, 24);
    });

    test('остался один шаг — говорим об этом, а не «ещё 1 день»', () {
      final service = _goals(catalog,
          wallet: _wallet(balance: 15, savings: 95, deposits: {1: 15}), day: 2);
      expect(service.saved, 110);
      expect(service.eta().days, 1);
      expect(service.eta().textRu, 'Ещё одно пополнение — и цель наша!');
    });

    test('накоплено с запасом — ни минуса, ни бесконечности', () {
      final service = _goals(catalog,
          wallet: _wallet(balance: 130, deposits: {1: 130}), day: 2);
      final eta = service.eta();
      expect(eta.days, 0);
      expect(eta.textRu, 'Хватает! Можно забирать.');
    });

    test('без выбранной цели срок не выдумывается', () {
      final service = _goals(catalog, goalId: null);
      expect(service.eta().days, isNull);
      expect(service.view(), isNull);
    });
  });

  group('витрина цели', () {
    test('стоимость, накопленное и остаток', () {
      final service = _goals(catalog, wallet: _wallet(savings: 30));
      final view = service.view()!;
      expect(view.price, 120);
      expect(view.saved, 30);
      expect(view.left, 90);
      expect(view.percent, 25);
      expect(view.progressText, 'Накоплено 30 из 120');
      expect(view.leftText, 'Осталось 90 монет');
      expect(view.isReached, isFalse);
    });

    test('неизвестная цель в конструкторе — ошибка сразу', () {
      expect(
          () => GoalService(
              catalog: catalog, wallet: _wallet(), selectedGoalId: 'no_such'),
          throwsArgumentError);
    });
  });

  group('выбор и смена цели', () {
    test('смена цели переносит накопленное полностью', () {
      final service = _goals(catalog, wallet: _wallet(savings: 75));
      final confirm = service.askToSelect('smartwatch') as GoalSelectConfirm;

      expect(confirm.question, 'Выбрать новую цель: умные часы?');
      expect(confirm.keepSavingsText, 'Все 75 монет останутся в копилке.');
      expect(confirm.confirmLabel, 'Да, выбираем');

      final done = service.confirmSelect(confirm) as GoalSelected;
      expect(done.savedCarriedOver, 75);
      expect(service.current!.id, 'smartwatch');
      expect(service.saved, 75);
      expect(done.view.price, 160);
      expect(done.view.left, 85);
    });

    test('окно ничего не меняет, пока не подтвердили', () {
      final service = _goals(catalog, wallet: _wallet(savings: 75));
      service.askToSelect('smartwatch');
      expect(service.current!.id, 'scooter');
    });

    test('закрытую цель не выбрать', () {
      final service = _goals(catalog);
      expect((service.askToSelect('robot_kit') as GoalRefused).textRu,
          'Эта цель откроется позже');
    });

    test('цель открывается, когда достигнуты предыдущие', () {
      final service = _goals(catalog,
          reached: ['constructor', 'scooter', 'smartwatch'], goalId: null);
      expect(service.available().map((g) => g.id), contains('robot_kit'));
      expect(service.askToSelect('robot_kit'), isA<GoalSelectConfirm>());
    });

    test('достигнутую цель заново не выбрать', () {
      final service = _goals(catalog, reached: ['smartwatch']);
      expect((service.askToSelect('smartwatch') as GoalRefused).textRu,
          'Эта цель уже достигнута');
    });

    test('ту же цель второй раз не предлагаем', () {
      expect((_goals(catalog).askToSelect('scooter') as GoalRefused).textRu,
          'Эта цель уже выбрана');
    });

    test('список целей: сначала маленькие, достигнутых нет', () {
      final service = _goals(catalog, reached: ['constructor']);
      final ids = service.available().map((g) => g.id).toList();
      expect(ids, isNot(contains('constructor')));
      expect(service.available().first.price, 90);
      final prices = service.available().map((g) => g.price).toList();
      expect(prices, orderedEquals([...prices]..sort()));
    });
  });

  group('пополнение копилки', () {
    test('монеты уходят в копилку с объяснением в журнале', () {
      final wallet = _wallet(balance: 40);
      final service = _goals(catalog, wallet: wallet);

      final done = service.deposit(amount: 15, at: _at) as GoalDepositDone;
      expect(done.wallet.balance, 25);
      expect(done.wallet.savings, 15);
      expect(wallet.journal.single.reasonText, 'Отложили 15 монет в копилку.');
      expect(wallet.journal.single.type, TransactionType.toSavings);
      expect(done.view!.saved, 15);
    });

    test('нечем пополнять — ничего не меняется', () {
      final wallet = _wallet(balance: 5);
      final service = _goals(catalog, wallet: wallet);

      final result = service.deposit(amount: 50, at: _at);
      expect(result, isA<GoalDepositNotEnough>());
      expect((result as GoalDepositNotEnough).gap, 45);
      expect(wallet.wallet.savings, 0);
      expect(wallet.journal, isEmpty);
    });

    test('вехи 25 и 50 процентов празднуются по одному разу', () {
      final service = _goals(catalog, wallet: _wallet(balance: 100));

      expect((service.deposit(amount: 30, at: _at) as GoalDepositDone).milestoneText,
          'Четверть пути позади!');
      expect((service.deposit(amount: 35, at: _at) as GoalDepositDone).milestoneText,
          'Половина есть! Осталось столько же.');
      expect((service.deposit(amount: 10, at: _at) as GoalDepositDone).milestoneText,
          isNull);
    });

    test('момент достижения цели виден отдельно', () {
      final service =
          _goals(catalog, goalId: 'constructor', wallet: _wallet(balance: 90));
      expect((service.deposit(amount: 80, at: _at) as GoalDepositDone).justReached,
          isFalse);
      final done = service.deposit(amount: 10, at: _at) as GoalDepositDone;
      expect(done.justReached, isTrue);
      expect(done.view!.eta.textRu, 'Хватает! Можно забирать.');
    });
  });

  group('снятие с накоплений', () {
    GoalService withHistory() => _goals(
          catalog,
          wallet: _wallet(balance: 75, savings: 30, deposits: {1: 15, 2: 15, 3: 15}),
          day: 4,
        );

    test('предпросмотр показывает и сумму, и новый срок', () {
      final service = withHistory();
      expect(service.saved, 75);

      final preview = service.previewWithdraw(20) as WithdrawPreview;
      expect(preview.savedBefore, 75);
      expect(preview.savedAfter, 55);
      expect(preview.etaBefore.days, 3);
      expect(preview.etaAfter.days, 5);
      expect(preview.question, 'Взять 20 монет из копилки?');
      expect(preview.savedChangeText, 'Было 75 из 120 → станет 55 из 120');
      expect(preview.etaChangeText, 'До цели: было 3 дня → станет 5 дней');
    });

    test('предпросмотр не меняет ничего', () {
      final service = withHistory();
      final journalBefore = service.eta().textRu;

      service.previewWithdraw(20);
      service.previewWithdraw(70);

      expect(service.saved, 75);
      expect(service.current!.id, 'scooter');
      expect(service.eta().days, 3);
      expect(service.eta().textRu, journalBefore);
      expect(service.view()!.saved, 75);
    });

    test('тон нейтральный, «Да» доступно', () {
      final preview = withHistory().previewWithdraw(20) as WithdrawPreview;
      expect(preview.confirmLabel, 'Да, взять');
      expect(preview.cancelLabel, 'Отмена');
    });

    test('без истории пополнений срок не выдумываем', () {
      final service = _goals(catalog, wallet: _wallet(savings: 50));
      final preview = service.previewWithdraw(10) as WithdrawPreview;
      expect(preview.etaChangeText,
          'Срок посчитаем, когда снова начнёшь откладывать.');
    });

    test('снятие уменьшает копилку и пишется в журнал', () {
      final service = withHistory();
      final preview = service.previewWithdraw(20) as WithdrawPreview;

      final done = service.withdraw(preview, at: _at) as WithdrawDone;
      expect(done.wallet.savings, 55);
      expect(done.transaction.reasonText, 'Взяли 20 монет из копилки.');
      expect(done.transaction.type, TransactionType.fromSavings);
      expect(service.eta().days, 5);
    });

    test('устаревший предпросмотр не срабатывает', () {
      final service = withHistory();
      final preview = service.previewWithdraw(20) as WithdrawPreview;

      service.deposit(amount: 5, at: _at);
      expect(service.withdraw(preview, at: _at), isA<GoalRefused>());
      expect(service.saved, 80);
    });

    test('снятие без подтверждения невозможно дважды подряд', () {
      final service = withHistory();
      final preview = service.previewWithdraw(20) as WithdrawPreview;

      expect(service.withdraw(preview, at: _at), isA<WithdrawDone>());
      expect(service.withdraw(preview, at: _at), isA<GoalRefused>());
      expect(service.saved, 55);
    });

    test('больше, чем накоплено, не снять', () {
      final service = withHistory();
      expect((service.previewWithdraw(200) as GoalRefused).textRu,
          'В копилке пока меньше');
      expect(service.saved, 75);
    });
  });

  group('достижение цели', () {
    test('цель забирается, уют растёт, прогресс не теряется', () {
      final wallet = _wallet(balance: 120, deposits: {1: 120});
      final service = _goals(catalog, wallet: wallet, day: 2);

      final claimed = service.claim(at: _at) as GoalClaimed;
      expect(claimed.goal.id, 'scooter');
      expect(claimed.effects.single.stat, PetStat.cozy);
      expect(claimed.effects.single.delta, 24);
      expect(claimed.reachedText, catalog.byId('scooter')!.reachedText);
      expect(wallet.wallet.savings, 0);
      expect(wallet.journal.last.reasonText,
          'Купили самокат на накопленные монеты!');
      expect(service.reachedGoalIds, contains('scooter'));
      expect(service.current, isNull);
    });

    test('мечта покупается на накопленное: копилка пустеет, баланс не растёт',
        () {
      final wallet = _wallet(balance: 150, deposits: {1: 120});
      final service = _goals(catalog, wallet: wallet, day: 2);
      expect(wallet.wallet, Wallet.create(balance: 30, savings: 120));

      final claimed = service.claim(at: _at) as GoalClaimed;
      expect(wallet.wallet, Wallet.create(balance: 30, savings: 0));
      expect(claimed.wallet, wallet.wallet);
      final [withdraw, spend] = wallet.journal.skip(1).toList();
      expect(withdraw.type, TransactionType.fromSavings);
      expect(withdraw.reasonText, 'Взяли 120 монет из копилки.');
      expect(spend.type, TransactionType.expense);
      expect(spend.reasonText, 'Купили самокат на накопленные монеты!');
      for (final t in [withdraw, spend]) {
        expect(t.sourceId, 'goal:scooter');
        expect(t.amount, 120);
        expect(t.dayNumber, 2);
      }
      expect(claimed.transaction, spend);
    });

    test('третья цель открывает большие', () {
      final service = _goals(
        catalog,
        wallet: _wallet(balance: 160, deposits: {1: 160}),
        goalId: 'smartwatch',
        reached: ['constructor', 'scooter'],
        day: 2,
      );
      final claimed = service.claim(at: _at) as GoalClaimed;
      expect(claimed.unlockedText, 'Появились новые большие цели!');
      expect(service.available().map((g) => g.id), contains('robot_kit'));
    });

    test('пока не накоплено — забрать нельзя', () {
      final service = _goals(catalog, wallet: _wallet(savings: 119));
      expect((service.claim(at: _at) as GoalRefused).textRu,
          'В копилке пока меньше');
      expect(service.saved, 119);
    });

    test('без выбранной цели забирать нечего', () {
      final service = _goals(catalog, goalId: null, wallet: _wallet(savings: 200));
      expect((service.claim(at: _at) as GoalRefused).textRu, 'Сначала выбери цель');
    });
  });
}
