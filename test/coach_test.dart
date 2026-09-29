import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:finni/content/content_repository.dart';
import 'package:finni/domain/models/models.dart';
import 'package:finni/domain/services/goal_service.dart';
import 'package:finni/domain/services/plan_service.dart';
import 'package:finni/domain/services/shop_service.dart';
import 'package:finni/ui/game_controller.dart';
import 'package:finni/ui/widgets/coach.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'support/content.dart';

const _conditions = {
  'planConfirmed',
  'needsPaid',
  'wantBought',
  'wantsPlanned',
  'noWants',
  'savedAll',
  'onHome',
  'nothingSaved',
  'somethingSaved',
};

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late ContentBundle content;
  late Map<String, dynamic> config;

  setUpAll(() async {
    content = await loadTestContent();
  });

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    config = jsonDecode(File('assets/content/game.json').readAsStringSync())
        as Map<String, dynamic>;
  });

  Iterable<(String, TutorialStep)> allSteps() sync* {
    for (final step in content.coach.allSteps) {
      yield ('coach.json', step);
    }
    for (final task in content.tasks.tasks) {
      for (final step in content.tasks.tutorialFor(task)) {
        yield (task.id, step);
      }
    }
  }

  group('обучение: содержание', () {
    test('все подсвечиваемые места существуют в приложении', () {
      final sources = [
        for (final file in Directory('lib/ui').listSync(recursive: true))
          if (file is File &&
              file.path.endsWith('.dart') &&
              !file.path.endsWith('coach.dart'))
            file.readAsStringSync(),
      ].join('\n');
      for (final id in CoachIds.all) {
        expect(sources.contains("'$id'"), isTrue, reason: id);
      }
      for (final (where, step) in allSteps()) {
        if (step.target case final target?) {
          expect(CoachIds.all, contains(target), reason: '$where: $target');
        }
        for (final condition in step.conditions) {
          expect(_conditions, contains(condition), reason: '$where: $condition');
        }
      }
    });

    test('в каждой игре есть шаг, где ребёнок пробует сам', () {
      for (final task in content.tasks.tasks) {
        final steps = content.tasks.tutorialFor(task);
        expect(steps.any((s) => s.action == CoachAction.tap), isTrue,
            reason: task.id);
        expect(steps.every((s) => s.target != null), isTrue, reason: task.id);
      }
    });

    test('первый день — четыре урока: план, покупки, копилка, заработок', () {
      final lessons = [
        for (final id in ['home', 'shopping', 'piggy', 'work']) content.coach.tour(id)!,
      ];
      List<String?> targets(CoachTour tour) => [for (final step in tour.steps) step.target];
      expect(targets(lessons[0]).first, 'home.pet');
      expect(targets(lessons[0]), containsAll(['plan.mandatory', 'plan.optional', 'plan.savings', 'plan.confirm']));
      expect(targets(lessons[1]), containsAll(['shop.plan', 'shop.wants', 'shop.items']));
      expect(targets(lessons[2]), containsAll(['plan.save', 'savings.change', 'section.back']));
      expect(targets(lessons[3]).last, 'home.level');
      expect(lessons[3].steps.last.action, CoachAction.tap);
      for (final lesson in lessons.skip(1)) {
        expect(lesson.requires, 'planConfirmed', reason: lesson.id);
        expect(lesson.title, isNotNull, reason: lesson.id);
      }
      expect(lessons[0].seenAfter(finished: true), isNot(contains('shopping')));
      expect(lessons[0].seenAfter(finished: false), containsAll(['shopping', 'piggy', 'work']));
      for (final id in ['plan', 'shop', 'hub', 'more', 'level', 'daily', 'event', 'bedtime']) {
        expect(content.coach.tour(id), isNotNull, reason: id);
      }
      expect(content.coach.gameFirst, isNotEmpty);
      expect(content.coach.gameLast, isNotEmpty);
    });

    test('шаг «нажми» без цели не загрузится', () {
      expect(
          () => TutorialStep.fromJson(const {'emoji': '👆', 'text': 'Нажми', 'action': 'tap'}),
          throwsArgumentError);
      expect(
          () => TutorialStep.fromJson(const {'emoji': '⏳', 'text': 'Жди', 'action': 'wait'}),
          throwsArgumentError);
    });
  });

  group('обучение: что запоминает игра', () {
    test('мечта из знакомства становится текущей', () {
      final state = GameController(config, content: content);
      state.createPet('Мони', true, goalId: 'smartwatch');
      expect(state.goalId, 'smartwatch');
      final same = GameController(config, content: content);
      final before = same.goalId;
      same.createPet('Мони', true, goalId: before);
      expect(same.goalId, before);
    });

    test('новичок видит обучение, старый профиль — нет', () {
      final fresh = GameController(config, content: content);
      expect(fresh.coachSeen('home'), isFalse);
      final old = GameController(config, content: content, saved: {'onboarded': true});
      expect(old.coachSeen('home'), isTrue);
      expect(old.coachSeen('hub'), isTrue);
    });

    test('пройденное обучение сохраняется и сбрасывается', () async {
      final state = GameController(config, content: content);
      state.createPet('Мони', true);
      state.markCoachSeen(['home', 'plan']);
      await state.flush();
      final restored = GameController(config,
          content: content, saved: await state.repository.load());
      expect(restored.coachSeen('home'), isTrue);
      expect(restored.coachSeen('plan'), isTrue);
      expect(restored.coachSeen('hub'), isFalse);
      restored.markTutorialSeen('payments_sort_needs');
      restored.resetCoach();
      expect(restored.coachSeen('home'), isFalse);
      expect(restored.tutorialSeen('payments_sort_needs'), isFalse);
    });

    test('в первой игре — общее знакомство, дальше только правила игры', () {
      final state = GameController(config, content: content);
      final task = content.tasks.tasks.first;
      final first = state.gameCoach(task, first: true);
      expect(first.first.target, 'game.intro');
      expect(first.last.target, content.coach.gameLast.last.target);
      state.markCoachSeen(['game']);
      expect(state.gameCoach(task, first: true), content.tasks.tutorialFor(task));
      expect(state.gameCoach(task, first: false), content.tasks.tutorialFor(task));
    });
  });

  group('план в магазине', () {
    GameController planned() {
      final state = GameController(config, content: content);
      for (var i = 0; i < 5; i++) {
        state.changePlan(PlanDirection.mandatory, 5);
      }
      state.changePlan(PlanDirection.optional, 5);
      state.changePlan(PlanDirection.optional, 5);
      state.changePlan(PlanDirection.savings, 5);
      state.confirmPlan();
      return state;
    }

    ShopItem item(String id) => content.shop.byId(id)!;

    test('покупка в пределах плана и сверх плана', () {
      final state = planned();
      expect(state.planLeft(PlanDirection.optional), 10);
      expect(state.planCheck(item('balloon')).fits, isTrue);
      final ball = state.planCheck(item('bouncy_ball'));
      expect(ball.fits, isFalse);
      expect(ball.gap, 5);
      expect(ball.delayDays, 1);
      expect(ball.needsShort, 0);
      final bowtie = state.planCheck(item('bowtie'));
      expect(bowtie.gap, 25);
      expect(bowtie.needsShort, greaterThan(0));
      expect(state.planCheck(item('food')).direction, PlanDirection.mandatory);
    });

    test('мечта из копилки не съедает план дня и не считается желаемым', () {
      config['savings'] = 500;
      final state = planned();
      expect(state.buyNow('treat'), isA<PurchaseDone>());
      final goal = content.goals.byId('constructor')!;
      state.changeGoal(goal.id);
      final balance = state.wallet.wallet.balance;
      final optional = state.planLeft(PlanDirection.optional);
      final savings = state.planLeft(PlanDirection.savings);
      final savedToday = state.savedToday;
      final report = state.report;

      expect(state.claimGoal(), isA<GoalClaimed>());
      expect(state.wallet.wallet.balance, balance);
      expect(state.wallet.wallet.savings, 500 - goal.price);
      expect(state.planLeft(PlanDirection.optional), optional);
      expect(state.planLeft(PlanDirection.savings), savings);
      expect(state.savedToday, savedToday);
      expect(state.report.optional, report.optional);
      expect(state.report.saved, report.saved);
    });

    test('после покупок и копилки план показывает остаток', () {
      final state = planned();
      for (final need in content.economy.pet.needs) {
        expect(state.buyNow(need.itemId), isA<PurchaseDone>());
      }
      expect(state.planLeft(PlanDirection.mandatory), 0);
      expect(state.buyNow('treat'), isA<PurchaseDone>());
      expect(state.wantBought, isTrue);
      expect(state.planLeft(PlanDirection.optional), 5);
      expect(state.savingsToDeposit, 5);
      expect(state.saveByPlan(), isTrue);
      expect(state.savedToday, 5);
      expect(state.savingsToDeposit, 0);
      expect(state.planLeft(PlanDirection.savings), 0);
    });
  });

  group('обучение: подсветка', () {
    Future<void> pumpHost(WidgetTester tester, VoidCallback onOther, VoidCallback onGo) async {
      await tester.pumpWidget(MaterialApp(
        builder: (context, child) => CoachHost(child: child!),
        home: Scaffold(
          body: Column(
            children: [
              CoachTarget(
                id: 'a',
                child: ElevatedButton(onPressed: onOther, child: const Text('Другое')),
              ),
              const SizedBox(height: 200),
              CoachTarget(
                id: 'b',
                child: ElevatedButton(onPressed: onGo, child: const Text('Сюда')),
              ),
            ],
          ),
        ),
      ));
    }

    testWidgets('ведёт по шагам и пропускает нажатие только в подсветку',
        (tester) async {
      var other = 0;
      var go = 0;
      await pumpHost(tester, () => other++, () => go++);
      final context = tester.element(find.text('Другое'));
      bool? result;
      unawaited(Coach.run(
        context,
        motion: false,
        steps: const [
          TutorialStep(emoji: '👋', text: 'Первый шаг', target: 'a'),
          TutorialStep(emoji: '👆', text: 'Нажми сюда', target: 'b', action: CoachAction.tap),
        ],
      ).then((value) => result = value));
      await tester.pumpAndSettle();
      expect(find.text('Первый шаг'), findsOneWidget);
      await tester.tap(find.text('Дальше'));
      await tester.pumpAndSettle();
      expect(find.text('Нажми сюда'), findsOneWidget);
      await tester.tap(find.text('Другое'), warnIfMissed: false);
      await tester.pumpAndSettle();
      expect(other, 0);
      await tester.tap(find.text('Сюда'));
      await tester.pump(const Duration(milliseconds: 400));
      await tester.pumpAndSettle();
      expect(go, 1);
      expect(result, isTrue);
      expect(find.text('Нажми сюда'), findsNothing);
      await tester.tap(find.text('Другое'));
      await tester.pump();
      expect(other, 1);
    });

    testWidgets('обучение можно пропустить', (tester) async {
      await pumpHost(tester, () {}, () {});
      final context = tester.element(find.text('Другое'));
      bool? result;
      unawaited(Coach.run(
        context,
        motion: false,
        steps: const [
          TutorialStep(emoji: '👋', text: 'Первый шаг', target: 'a'),
          TutorialStep(emoji: '👋', text: 'Второй шаг', target: 'b'),
        ],
      ).then((value) => result = value));
      await tester.pumpAndSettle();
      expect(find.text('1 из 2'), findsOneWidget);
      await tester.tap(find.text('Пропустить'));
      await tester.pumpAndSettle();
      expect(result, isFalse);
      expect(find.text('Первый шаг'), findsNothing);
    });

    testWidgets('если подсвечивать нечего, появляется кнопка «Дальше»',
        (tester) async {
      await pumpHost(tester, () {}, () {});
      final context = tester.element(find.text('Другое'));
      unawaited(Coach.run(
        context,
        motion: false,
        steps: const [
          TutorialStep(emoji: '🙈', text: 'Нет такого места', target: 'none', action: CoachAction.tap),
        ],
      ));
      await tester.pump();
      expect(find.text('Нет такого места'), findsNothing);
      await tester.pump(const Duration(seconds: 1));
      await tester.pumpAndSettle();
      expect(find.text('Нет такого места'), findsOneWidget);
      await tester.tap(find.text('Понятно!'));
      await tester.pumpAndSettle();
      expect(find.text('Нет такого места'), findsNothing);
    });
  });
}
