import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:finni/content/content_repository.dart';
import 'package:finni/data/game_repository.dart';
import 'package:finni/domain/game_clock.dart';
import 'package:finni/domain/models/models.dart';
import 'package:finni/domain/services/plan_service.dart';
import 'package:finni/domain/services/shop_service.dart';
import 'package:finni/domain/services/task_engine.dart';
import 'package:finni/ui/app.dart';
import 'package:finni/ui/game_controller.dart';
import 'package:finni/ui/widgets/game_icon.dart';

import 'support/answers.dart';
import 'support/content.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Map<String, dynamic> config;
  late ContentBundle content;
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    config = jsonDecode(File('assets/content/game.json').readAsStringSync())
        as Map<String, dynamic>;
  });
  setUpAll(() async {
    content = await loadTestContent();
    final font = FontLoader('Nunito')
      ..addFont(rootBundle.load('assets/fonts/Nunito.ttf'));
    await font.load();
  });
  test('savings and full journal survive restart; ids remain unique', () async {
    final repository = LocalGameRepository();
    final state = GameController(config, content: content, repository: repository);
    state.saveCoins(20);
    state.withdraw(5);
    await state.flush();
    final restored = GameController(config,
        content: content,
        saved: await repository.load(), repository: repository);
    expect(restored.wallet.wallet.balance, 25);
    expect(restored.wallet.wallet.savings, 15);
    expect(restored.wallet.journal.length, 3);
    restored.saveCoins(5);
    await restored.flush();
    expect(restored.wallet.journal.map((t) => t.id).toSet().length, 4);
    expect(restored.wallet.wallet.balance + restored.wallet.wallet.savings, 40);
  });
  test('legacy progress migrates without touching original data', () async {
    final old = jsonEncode({
      'points': 37,
      'completedTaskIds': ['task_save_jar'],
      'purchasedItemIds': ['shop_hat', 'shop_house']
    });
    SharedPreferences.setMockInitialValues(
        {LocalGameRepository.legacyKey: old});
    final repository = LocalGameRepository();
    final state = GameController(config,
        content: content,
        saved: await repository.load(), repository: repository);
    expect(state.wallet.wallet.balance, 37);
    expect(state.owned, containsAll(['cap', 'shop_house']));
    expect(state.legacyCompletedTasks, ['task_save_jar']);
    state.setMotion(false);
    await state.flush();
    expect(
        (await SharedPreferences.getInstance())
            .getString(LocalGameRepository.legacyKey),
        old);
  });
  test('damaged save is not silently replaced', () async {
    SharedPreferences.setMockInitialValues({LocalGameRepository.key: 'broken'});
    await expectLater(LocalGameRepository().load(), throwsFormatException);
    expect(
        (await SharedPreferences.getInstance())
            .getString(LocalGameRepository.key),
        'broken');
  });
  test('practice games pay nothing but keep stars and progress', () async {
    final state = GameController(config, content: content);
    const id = 'planning_choice_enough';
    final before = state.wallet.wallet.balance;
    final session = state.startGame(id);
    expect(session.submit(const ChoiceAnswer('no')).isCorrect, false);
    expect(session.submit(const ChoiceAnswer('yes')).isCorrect, true);
    final reward = state.finishGame(session);
    expect(reward.coins, 0);
    expect(reward.stars, 2);
    expect(state.wallet.wallet.balance, before);
    expect(state.tasks.isCompleted(id), true);
    expect(state.starsOf(id), 2);
  });
  test('level of the day pays once, survives restart, next level tomorrow',
      () async {
    final state = GameController(config, content: content);
    expect(state.levelNumber, 1);
    expect(state.isGameUnlocked('savings_week_plan'), false);
    final run = state.startLevel()!;
    expect(run.slots, hasLength(3));
    expect(run.slots.every((slot) => !slot.isHard), true);
    final before = state.wallet.wallet.balance;
    final first = state.startLevelGame();
    first.submit(rightAnswer(first.variant));
    final firstStep = state.finishLevelGame(first);
    expect(firstStep.finished, isNull);
    expect(firstStep.reward.coins, run.shareOf(0));
    expect(state.wallet.wallet.balance, before + run.shareOf(0));
    expect(state.isGameUnlocked(run.slots.first.taskId), true);
    expect(state.isGameUnlocked(run.slots.last.taskId), false);
    await state.flush();
    final resumed = GameController(config,
        content: content, saved: await state.repository.load());
    expect(resumed.levelRun?.done, 1);
    LevelStep? step;
    while (resumed.levelRun != null) {
      final session = resumed.startLevelGame();
      session.submit(rightAnswer(session.variant));
      final index = resumed.levelRun!.done;
      step = resumed.finishLevelGame(session);
      expect(step.reward.coins, run.shareOf(index));
    }
    expect(step?.finished?.coins, run.coins);
    expect(resumed.wallet.wallet.balance, before + run.coins);
    expect(resumed.levelDoneToday, true);
    expect(resumed.canEarnFromGames, false);
    expect(resumed.startLevel(), isNull);
    expect(resumed.dayFacts.tasksDone, 3);
    await resumed.flush();
    final restored = GameController(config,
        content: content, saved: await resumed.repository.load());
    expect(restored.levelsDone, 1);
    expect(restored.todayLevel?.stars, [3, 3, 3]);
    expect(restored.closeDay(restored.day), true);
    expect(restored.levelDoneToday, false);
    expect(restored.levelNumber, 2);
    final next = restored.upcomingLevel;
    expect(next.slots.where((slot) => slot.isNew).map((slot) => slot.taskId),
        ['planning_choice_enough']);
    expect(restored.isGameUnlocked('planning_choice_enough'), false);
    expect(restored.practiceGames.map((task) => task.id).toSet(),
        run.slots.map((slot) => slot.taskId).toSet());
  });
  test('daily challenge: once per real day, hard, safe from clock rollback',
      () async {
    final clock = _CalendarClock(DateTime(2026, 9, 28, 10));
    final state = GameController(config, content: content, clock: clock);
    expect(state.dailyTask, isNull);
    expect(state.startDaily(), isNull);
    state.startLevel();
    while (state.levelRun != null) {
      final session = state.startLevelGame();
      session.submit(rightAnswer(session.variant));
      state.finishLevelGame(session);
    }
    final task = state.startDaily()!;
    expect(state.practiceGames, contains(task));
    final session = state.startDailyGame();
    expect(session.variant.difficulty, TaskDifficulty.hard);
    final before = state.wallet.wallet.balance;
    session.submit(rightAnswer(session.variant));
    final reward = state.finishDaily(session);
    final rules = content.levels.daily;
    expect(reward.coins, rules.coins + rules.perfectBonus);
    expect(state.wallet.wallet.balance, before + reward.coins);
    expect(state.dailyDoneToday, true);
    expect(state.dailyCoinsToday, reward.coins);
    expect(state.startDaily(), isNull);
    expect(state.closeDay(state.day), true);
    expect(state.dailyDoneToday, true);
    await state.flush();
    final restored = GameController(config,
        content: content, saved: await state.repository.load(), clock: clock);
    expect(restored.dailyDoneToday, true);
    expect(restored.dailyHistory, {'2026-09-28'});
    clock.at = DateTime(2026, 9, 27, 12);
    expect(restored.dailyDoneToday, true);
    clock.at = DateTime(2026, 9, 29, 0, 5);
    expect(restored.dailyDoneToday, false);
    final tomorrow = restored.startDaily()!;
    expect(tomorrow.id, isNot(task.id));
    final again = restored.startDailyGame();
    again.submit(rightAnswer(again.variant));
    expect(restored.finishDaily(again).coins, rules.coins + rules.perfectBonus);
    expect(restored.dailyHistory, {'2026-09-28', '2026-09-29'});
  });
  test('owned accessory cannot be charged twice', () async {
    final state = GameController(config, content: content);
    expect(state.buyNow('bow'), isA<PurchaseDone>());
    final balance = state.wallet.wallet.balance;
    final transactions = state.wallet.journal.length;
    expect(state.buyNow('bow'), isA<PurchaseRefused>());
    expect(state.wallet.wallet.balance, balance);
    expect(state.wallet.journal.length, transactions);
    await state.flush();
  });
  test('goal change preserves savings; wish and outfit persist', () async {
    final state = GameController(config, content: content);
    state.buyNow('bow');
    state.equip('bow');
    state.postpone('glasses');
    state.saveCoins(10);
    state.changeGoal('ball_rope');
    state.changePlan(PlanDirection.savings, 5);
    await state.flush();
    final restored =
        GameController(config, content: content, saved: await state.repository.load());
    expect(restored.wallet.wallet.savings, 10);
    expect(restored.target, 90);
    expect(restored.outfit['head'], 'bow');
    expect(restored.wishlist, contains('glasses'));
    restored.equip('bow');
    await restored.flush();
    expect(restored.outfit, isEmpty);
  });
  test(
      'deleting profile removes migrated and current saves, not unrelated keys',
      () async {
    SharedPreferences.setMockInitialValues(
        {LocalGameRepository.legacyKey: '{}', 'other': 'keep'});
    final state = GameController(config, content: content);
    state.createPet('Мони', true);
    await state.flush();
    await state.deleteProfile();
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getKeys(), {'other'});
    expect(state.onboarded, false);
  });
  for (final scale in [1.0, 2.0]) {
    testWidgets('main routes 360dp at $scale text scale', (tester) async {
      tester.view.physicalSize = const Size(360, 740);
      tester.view.devicePixelRatio = 1;
      tester.platformDispatcher.textScaleFactorTestValue = scale;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      final state =
          GameController(config, content: content, saved: {'onboarded': true, 'motion': false});
      await tester.pumpWidget(FinniApp(controller: state));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      for (final kind in [
        GameIconKind.navHome,
        GameIconKind.navPlan,
        GameIconKind.navShop,
        GameIconKind.navGames,
        GameIconKind.navMore,
      ]) {
        expect(
            find.byWidgetPredicate(
              (widget) => widget is GameIcon && widget.kind == kind,
            ),
            findsOneWidget);
      }
      if (scale == 1) {
        expect(find.byType(CircularProgressIndicator), findsNothing);
        for (final label in ['Сытость', 'Уход', 'Радость', 'Уют']) {
          expect(find.text(label), findsOneWidget);
        }
        final food = tester.getRect(find.text('Сытость'));
        final care = tester.getRect(find.text('Уход'));
        final joy = tester.getRect(find.text('Радость'));
        expect(food.top, closeTo(care.top, 1));
        expect(joy.top, greaterThan(food.bottom));
        expect(find.byType(LinearProgressIndicator), findsOneWidget);
        expect(find.text('0 из 120'), findsOneWidget);
        expect(find.text('0 из 120 монет'), findsNothing);
        final goalIcon = find.byWidgetPredicate(
            (widget) => widget.runtimeType.toString() == '_GoalIcon');
        expect(
            tester.getBottomLeft(goalIcon).dy,
            closeTo(
                tester.getBottomLeft(find.byType(LinearProgressIndicator)).dy,
                1));
        expect(
            tester.getCenter(find.text('0 из 120')).dy,
            closeTo(
                tester.getCenter(find.byType(LinearProgressIndicator)).dy, 1));
        final chip = find
            .byWidgetPredicate(
                (widget) => widget.runtimeType.toString() == '_ResourceChip')
            .first;
        expect(tester.getCenter(find.text('День 1')).dy,
            closeTo(tester.getCenter(chip).dy, 1));
        expect(
            tester
                .state<ScrollableState>(find.byType(Scrollable).first)
                .position
                .maxScrollExtent,
            0);
      }
      for (final label in ['План', 'Магазин']) {
        await tester.tap(find.text(label).last);
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        expect(find.byTooltip('Назад домой'), findsNothing);
      }
      expect(find.byTooltip('Для взрослого'), findsNothing);
      expect(find.byTooltip('Твой прогресс'), findsNothing);
      await tester.tap(find.text('Игры').last);
      await tester.pumpAndSettle();
      expect(find.text('Учимся на маленьких решениях'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.tap(find.text('Дом').last);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Ещё').last);
      await tester.pumpAndSettle();
      for (final label in [
        'Комната и гардероб',
        'Дневник',
        'Звания и рост',
        'Спокойной ночи',
        'Словарик'
      ]) {
        await tester.ensureVisible(find.text(label));
        await tester.tap(find.text(label));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        await tester.tap(find.byTooltip('Назад').last);
        await tester.pumpAndSettle();
      }
      await tester.pumpWidget(const SizedBox());
      state.dispose();
    });
  }
  testWidgets('first launch creates guest pet without personal fields',
      (tester) async {
    final state = GameController(config, content: content)..motion = false;
    await tester.pumpWidget(FinniApp(controller: state));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Пропустить знакомство'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Дальше'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Начать дружить'));
    await tester.pumpAndSettle();
    expect(state.onboarded, true);
    expect(find.text('Мони'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
    state.dispose();
  });
}

final class _CalendarClock implements GameClock {
  _CalendarClock(this.at);

  DateTime at;

  @override
  DateTime now() => at;

  @override
  int cooldownMs(String key) => 0;

  @override
  bool isNewCalendarDay(DateTime last) =>
      DateTime(at.year, at.month, at.day)
          .isAfter(DateTime(last.year, last.month, last.day));
}
