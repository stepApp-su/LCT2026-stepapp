import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:finni/content/content_repository.dart';
import 'package:finni/domain/models/models.dart';
import 'package:finni/domain/services/day_controller.dart';
import 'package:finni/domain/services/day_summary_service.dart';
import 'package:finni/domain/services/demo_service.dart';
import 'package:finni/domain/services/task_engine.dart';
import 'package:finni/domain/services/title_service.dart';

import '../support/content.dart';
import '../support/day.dart';

DemoService _service(ContentBundle content) => DemoService(
      economy: content.economy,
      shop: content.shop,
      goals: content.goals,
      events: content.events,
      titles: TitleService.forContent(content.titles,
          tasks: content.tasks, shop: content.shop),
      summaries: DaySummaryService(templates: content.summaries.explain),
    );

void main() {
  late ContentBundle content;
  late DemoService demo;

  setUpAll(() async {
    content = await loadTestContent();
    demo = _service(content);
  });

  group('снятие ожиданий', () {
    test('кулдауны нулевые, сутки идут по запросу', () {
      final clock = demo.clock();
      expect(clock.cooldownMs('petChore'), 0);
      expect(clock.cooldownMs('dailyTask'), 0);
      expect(clock.isNewCalendarDay(clock.now()), isTrue);
      final before = clock.now();
      clock.advanceDay();
      expect(clock.now().difference(before).inDays, 1);
    });

    test('каждое задание каталога открыто с первого дня', () {
      final engine = TaskEngine(
        catalog: content.tasks,
        rewards: content.economy.params.tasks,
      );
      for (final task in content.tasks.tasks) {
        for (final difficulty in TaskDifficulty.values) {
          expect(engine.start(task.id, difficulty), isNotNull,
              reason: '${task.id} / ${difficulty.name}');
        }
      }
    });
  });

  group('сброс эталонного профиля', () {
    final raw = File('assets/content/test_profile.json').readAsStringSync();

    test('возвращает ровно эталон и кладёт его в хранилище', () async {
      final repository = MemoryProfileRepository();
      final profile = await demo.resetTestProfile(raw, repository: repository);
      expect(profile.currentDay.number, 1);
      final stored = await repository.loadProfile();
      expect(stored.toJson(), profile.toJson());
      final again = await demo.resetTestProfile(raw, repository: repository);
      expect(again.toJson(), profile.toJson());
    });

    test('битый эталон — ошибка, а не пустой профиль', () {
      final repository = MemoryProfileRepository();
      expect(demo.resetTestProfile('{"schemaVersion":2}', repository: repository),
          throwsArgumentError);
      expect(demo.resetTestProfile('не json', repository: repository),
          throwsArgumentError);
    });
  });

  group('пять дней подряд без ожиданий', () {
    test('обязательный сценарий проходит, прогресс не теряется', () async {
      final clock = demo.clock();
      final repository = MemoryProfileRepository();
      final controller =
          dayController(content, repository: repository, clock: clock);
      var profile = await controller.startGame(
          petName: 'Мони', species: 'fox', palette: 0);
      final tasks = [for (final t in content.tasks.tasks) t.id];

      for (var day = 1; day <= 5; day++) {
        profile = liveDay(
          profile,
          content,
          at: clock.now(),
          plan: BudgetPlan.create(
              mandatory: 25, optional: 5, savings: 10, income: 60),
          buy: const ['food', 'water_light', 'cleaning', 'treat'],
          deposit: 10,
          task: tasks[day - 1],
        );
        final night =
            await controller.goToSleep(profile, day: day) as Night;
        expect(night.newDay.number, day + 1);
        clock.advanceDay();

        // перезапуск между днями: профиль читается из сохранения
        final restored = await repository.loadProfile();
        expect(withoutMoments(restored.toJson()),
            withoutMoments(night.profile.toJson()));
        profile = restored;
      }

      expect(profile.currentDay.number, 6);
      expect(profile.history.length, 5);
      expect(profile.progress.growthPoints, greaterThan(0));
      final spent = [
        for (final t in profile.journal)
          if (t.type == TransactionType.expense) t.amount
      ].fold(0, (a, b) => a + b);
      expect(spent, 5 * 30);
    });

    test('экономика в демо та же: доход и цены из общего конфига', () async {
      final run = await demo.prudentPlayer();
      for (final night in run.nights) {
        expect(night.income.amount, content.economy.params.day.income);
      }
      final food = content.shop.byId('food')!;
      final buys = [
        for (final t in run.profile.journal)
          if (t.sourceId == 'shop:food') t.amount
      ];
      expect(buys, isNotEmpty);
      expect(buys.toSet(), {food.price});
    });
  });

  group('профили-витрины', () {
    late DemoRun prudent;
    late DemoRun spendthrift;

    setUpAll(() async {
      prudent = await demo.prudentPlayer();
      spendthrift = await demo.spendthrift();
    });

    test('разумный: шесть дней по плану, вырос до взрослого', () {
      final p = prudent.profile;
      expect(prudent.nights.length, 6);
      expect(p.progress.stage, PetStage.adult);
      expect(p.history.length, 6);
      expect(p.wallet.balance, greaterThanOrEqualTo(0));
    });

    test('разумный: мечта куплена на накопленное, монеты не вернулись', () {
      final p = prudent.profile;
      final price = content.goals.byId('constructor')!.price;
      final dream = [
        for (final t in p.allTransactions)
          if (t.sourceId == 'goal:constructor') (t.type, t.amount)
      ];
      expect(dream, [
        (TransactionType.fromSavings, price),
        (TransactionType.expense, price),
      ]);
      var balance = 0;
      var savings = 0;
      for (final t in p.allTransactions) {
        switch (t.type) {
          case TransactionType.income:
            balance += t.amount;
          case TransactionType.expense:
            balance -= t.amount;
          case TransactionType.toSavings:
            balance -= t.amount;
            savings += t.amount;
          case TransactionType.fromSavings:
            balance += t.amount;
            savings -= t.amount;
        }
      }
      expect(p.wallet, Wallet.create(balance: balance, savings: savings));
    });

    test('разумный: мечта достигнута, не меньше трёх званий', () {
      final p = prudent.profile;
      expect(p.reachedGoalIds, contains('constructor'));
      expect(p.progress.earnedTitles.length, greaterThanOrEqualTo(3));
    });

    test('разумный: комната обставлена', () {
      final furniture = [
        for (final id in prudent.profile.ownedItems)
          if (content.shop.byId(id)?.kind == ShopItemKind.furniture) id
      ];
      expect(furniture.length, greaterThanOrEqualTo(3));
    });

    test('транжира: без плана и копилки, стадия ниже', () {
      final p = spendthrift.profile;
      expect(spendthrift.nights.length, 6);
      expect(p.progress.stage, PetStage.teen);
      expect(p.reachedGoalIds, isEmpty);
      expect(p.wallet.savings, 0);
    });

    test('транжира: комната пустая', () {
      final furniture = [
        for (final id in spendthrift.profile.ownedItems)
          if (content.shop.byId(id)?.kind == ShopItemKind.furniture) id
      ];
      expect(furniture, isEmpty);
    });

    test('транжира: питомец здоров и весел, стратегия не карается', () {
      final s = spendthrift.profile.state;
      expect(s.of(PetStat.satiety), greaterThan(50));
      expect(s.of(PetStat.care), greaterThan(30));
      expect(s.of(PetStat.mood), greaterThanOrEqualTo(60));
    });

    test('витрины не трогают основное хранилище', () async {
      final repository = MemoryProfileRepository();
      await demo.resetTestProfile(
          File('assets/content/test_profile.json').readAsStringSync(),
          repository: repository);
      final before = repository.stored;
      await demo.prudentPlayer();
      await demo.spendthrift();
      expect(repository.stored, before);
    });
  });
}
