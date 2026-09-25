import 'dart:convert';
import 'dart:io';

import 'package:finni/content/content_loader.dart';
import 'package:finni/domain/models/models.dart';
import 'package:finni/domain/profile_codec.dart';
import 'package:finni/domain/profile_repository.dart';
import 'package:finni/domain/services/goal_service.dart';
import 'package:finni/domain/services/growth_service.dart';
import 'package:finni/domain/services/title_service.dart';
import 'package:finni/domain/services/wallet_service.dart';
import 'package:finni/domain/stop_words.dart';
import 'package:flutter_test/flutter_test.dart';

Map<String, Object?> _raw(String file) =>
    (jsonDecode(File('assets/content/$file').readAsStringSync()) as Map)
        .cast<String, Object?>();

final DateTime _at = DateTime(2026, 9, 24, 18);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final catalog = TitleCatalog.fromJson(_raw('titles.json'));
  final tasks = TaskCatalog.fromJson(_raw('tasks.json'));
  final shop = ShopCatalog.fromJson(_raw('shop.json'));
  final goals = GoalCatalog.fromJson(_raw('goals.json'));
  final economy = EconomyConfig.fromJson(_raw('economy.json'));
  final titles = TitleService.forContent(catalog, tasks: tasks, shop: shop);

  group('titles.json', () {
    test('приложение загружает его тем же путём, без пропущенных записей',
        () async {
      final loaded = await const ContentLoader().loadTitleCatalog();
      expect(loaded.problems, isEmpty);
      expect([for (final t in loaded.titles) t.id],
          [for (final t in catalog.titles) t.id]);
      expect(catalog.problems, isEmpty);
      expect(titles.problems, isEmpty);
    });

    test('восемь стартовых званий ТЗ с их условиями', () {
      String describe(TitleCondition condition) => switch (condition) {
            StartCondition() => 'старт',
            DaysCondition(
              :final count,
              :final marks,
              :final inARow,
              :final planTolerance
            ) =>
              '${inARow ? 'подряд' : 'дней'} $count '
                  '${[for (final m in marks) m.name].join('+')}'
                  '${planTolerance == null ? '' : ' ${planTolerance.percent}% '
                      'от ${planTolerance.atLeast}'
                      '${planTolerance.roundUp ? '' : ' строго'}'}',
            ThemeCondition(:final themeId) => 'тема $themeId',
            GoalsCondition(:final count) => 'целей $count',
            ReserveCondition(:final days) => 'запас $days',
          };

      expect({
        for (final t in catalog.titles) t.title: describe(t.condition)
      }, {
        'Новичок': 'старт',
        'Планировщик': 'дней 3 planMade',
        'Бережливый': 'подряд 5 saved',
        'Знаток покупок': 'тема payments',
        'Хранитель запаса': 'запас 2',
        'Мечтатель': 'целей 1',
        'Мастер бюджета': 'дней 10 mandatoryPaid+onPlan 10% от 0 строго',
        'Наставник': 'дней 30 active',
      });
      expect(tasks.theme('payments')!.title, 'Платежи и покупки');
    });

    test('запас считается от цены всего нужного на день', () {
      final needsCost = economy.pet.needs
          .fold(0, (sum, need) => sum + shop.byId(need.itemId)!.price);
      expect(titles.dailyNeedsCost, needsCost);
    });

    test('каждое звание связано с компетенцией из Единой рамки', () {
      final framework = CompetenceCatalog.fromJson(_raw('competences.json'));
      for (final title in catalog.titles) {
        expect(framework.byId(title.competenceId), isNotNull, reason: title.id);
      }
      expect(catalog.byId('saver')!.competenceId, 'savings_regular');
    });

    test('иконки свои у каждого звания, атрибуты — у четырёх званий из E-02',
        () {
      final icons = [for (final t in catalog.titles) t.iconId];
      expect(icons.toSet(), hasLength(icons.length));
      for (final title in catalog.titles) {
        expect(title.iconId, 'icon_title_${title.id}');
      }
      expect({
        for (final t in catalog.titles)
          if (t.attributeId.isNotEmpty) t.id: t.attributeId
      }, {
        'planner': 'attr_notebook',
        'reserve_keeper': 'attr_badge',
        'dreamer': 'attr_crown',
        'budget_master': 'attr_medal',
      });
      final shopIds = {for (final item in shop.items) item.id};
      for (final title in catalog.titles) {
        expect(shopIds, isNot(contains(title.attributeId)), reason: title.id);
      }
    });

    test('тексты для ребёнка: коротко, без стоп-слов и пропусков', () {
      for (final title in catalog.titles) {
        for (final text in [
          titles.headlineOf(title),
          titles.reasonOf(title),
          title.title,
        ]) {
          expect(phraseWordCount(text), lessThanOrEqualTo(10), reason: text);
          expect(findStopWords(text), isEmpty, reason: text);
          expect(text, isNot(matches(RegExp(r'[{}]'))), reason: text);
        }
      }
    });

    test('объяснение «за что» говорит ровно то, за что дано звание', () {
      expect({
        for (final t in catalog.titles) t.id: titles.reasonOf(t)
      }, {
        'novice': 'Начали учиться обращаться с деньгами.',
        'planner': '3 дня составляли план на день.',
        'saver': '5 дней подряд откладывали в копилку.',
        'shopping_expert': 'Прошли все задания темы «Платежи и покупки».',
        'reserve_keeper': 'Отложили запас на 2 дня вперёд.',
        'dreamer': 'Накопили и получили то, о чём мечтали.',
        'budget_master': '10 дней покупали нужное и держались своего плана.',
        'mentor': '30 дней вместе учились обращаться с деньгами.',
      });
      expect(titles.headlineOf(catalog.byId('saver')!),
          'Новое звание: «Бережливый»!');
    });

    test('название любого звания помещается во все реплики питомца', () {
      final phrases = PhraseCatalog.fromJson(_raw('phrases.json'));
      final praises = phrases.byTrigger('title_earned');
      expect(praises, isNotEmpty);
      for (final praise in praises) {
        for (final template in praise.templates.values) {
          for (final title in catalog.titles) {
            final text = template.replaceAll('{title}', title.title);
            expect(phraseWordCount(text),
                lessThanOrEqualTo(phrases.rules.maxWords),
                reason: text);
            expect(findStopWords(text), isEmpty, reason: text);
          }
        }
      }
    });

    test('тестовый профиль эксперта начинается с Новичка', () {
      final result = ProfileCodec.decode(
          File('assets/content/test_profile.json').readAsStringSync());
      final progress = (result as ProfileLoaded).profile.progress;
      expect(progress.earnedTitles, ['novice']);
      expect(titles.current(progress)?.id, 'novice');
      expect(titles.start(progress), same(progress));
    });
  });

  group('звания на настоящих сервисах', () {
    final needs = [for (final need in economy.pet.needs) need.itemId];
    final growth = GrowthService(economy.growth);
    final payments = [for (final task in tasks.byTheme('payments')) task.id];

    Map<String, int> live(
      int days, {
      required BudgetPlan plan,
      bool confirmed = true,
      List<String> buy = const [],
      int deposit = 0,
      bool learn = false,
      String? goalId,
    }) {
      final wallet = WalletService();
      final targets = GoalService(catalog: goals, wallet: wallet);
      final completed = <String>[];
      var progress = titles.start(PetProgress.initial());
      final earnedOn = {for (final id in progress.earnedTitles) id: 0};
      if (goalId != null) {
        targets.confirmSelect(targets.askToSelect(goalId) as GoalSelectConfirm);
      }
      for (var day = 1; day <= days; day++) {
        targets.startDay(day);
        wallet.earn(
            amount: plan.income,
            sourceId: 'day_income',
            reasonText: 'Монеты на день',
            at: _at,
            dayNumber: day);
        for (final id in buy) {
          final item = shop.byId(id)!;
          expect(
              wallet.spend(
                  amount: item.price,
                  itemId: id,
                  category: item.category,
                  reasonText: item.diaryText,
                  at: _at,
                  dayNumber: day),
              isA<WalletOk>(),
              reason: 'день $day: $id');
        }
        if (deposit > 0) {
          expect(wallet.toSavings(amount: deposit, at: _at, dayNumber: day),
              isA<WalletOk>());
        }
        if (learn && completed.length < payments.length) {
          final task = payments[completed.length];
          completed.add(task);
          wallet.earn(
              amount: 10,
              sourceId: 'task:$task',
              reasonText: 'Задание',
              at: _at,
              dayNumber: day);
        }
        if (targets.current?.isReached ?? false) {
          expect(targets.claim(at: _at), isA<GoalClaimed>());
        }
        progress = growth
            .closeDay(
                progress,
                DayFacts.fromDay(
                    GameDay.create(
                      number: day,
                      income: plan.income,
                      plan: plan,
                      transactions: wallet.journalOfDay(day),
                      planConfirmed: confirmed,
                    ),
                    mandatoryItemIds: needs))
            .progress;
        final award = titles.award(
            progress,
            TitleFacts.create(
              dayNumber: day,
              completedTaskIds: completed,
              reachedGoalIds: targets.reachedGoalIds,
              savings: wallet.wallet.savings,
            ));
        progress = award.progress;
        for (final earned in award.earned) {
          earnedOn[earned.title.id] = day;
        }
      }
      expect(progress.earnedTitles, earnedOn.keys);
      expect(progress.currentTitleId, earnedOn.keys.last);
      return earnedOn;
    }

    test('разумный игрок получает все восемь званий, каждое — за своё дело',
        () {
      final earnedOn = live(30,
          plan: BudgetPlan.create(
              mandatory: 25, optional: 5, savings: 30, income: 60),
          buy: [...needs, 'treat'],
          deposit: 30,
          learn: true,
          goalId: 'ball_rope');
      expect(earnedOn, {
        'novice': 0,
        'reserve_keeper': 2,
        'planner': 3,
        'dreamer': 3,
        'saver': 5,
        'shopping_expert': payments.length,
        'budget_master': 10,
        'mentor': 30,
      });
    });

    test('транжира по своему плану: без копилки нет «Бережливого» и запаса',
        () {
      final earnedOn = live(30,
          plan: BudgetPlan.create(
              mandatory: 25, optional: 35, savings: 0, income: 60),
          buy: [...needs, 'bouncy_ball', 'puzzle']);
      expect(earnedOn, {
        'novice': 0,
        'planner': 3,
        'budget_master': 10,
        'mentor': 30,
      });
    });

    test('тридцать пустых вечеров — только Новичок, даже с нажатым «готово»',
        () {
      for (final confirmed in [false, true]) {
        expect(live(30, plan: BudgetPlan.empty(60), confirmed: confirmed),
            {'novice': 0},
            reason: 'план подтверждён: $confirmed');
      }
    });
  });
}
