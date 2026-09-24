import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:finni/content/content_repository.dart';
import 'package:finni/data/game_repository.dart';
import 'package:finni/domain/services/plan_service.dart';
import 'package:finni/domain/services/shop_service.dart';
import 'package:finni/domain/services/task_engine.dart';
import 'package:finni/ui/app.dart';
import 'package:finni/ui/game_controller.dart';
import 'package:finni/ui/widgets/game_icon.dart';

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
    expect(restored.wallet.wallet.balance, 45);
    expect(restored.wallet.wallet.savings, 15);
    expect(restored.wallet.journal.length, 3);
    restored.saveCoins(5);
    await restored.flush();
    expect(restored.wallet.journal.map((t) => t.id).toSet().length, 4);
    expect(restored.wallet.wallet.balance + restored.wallet.wallet.savings, 60);
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
  test('game pays coins once in full, repeats pay less, then play is free',
      () async {
    final state = GameController(config, content: content);
    const id = 'planning_choice_enough';
    final task = content.tasks.byId(id)!;
    final before = state.wallet.wallet.balance;
    final session = state.startGame(id);
    expect(session.submit(const ChoiceAnswer('no')).isCorrect, false);
    expect(state.wallet.wallet.balance, before);
    expect(session.submit(const ChoiceAnswer('yes')).isCorrect, true);
    final first = state.finishGame(session);
    expect(first.coins, task.reward.wrong);
    expect(state.wallet.wallet.balance, before + first.coins);
    await state.flush();
    final restored = GameController(config,
        content: content, saved: await state.repository.load());
    expect(restored.tasks.isCompleted(id), true);
    final again = restored.startGame(id);
    again.submit(const ChoiceAnswer('yes'));
    final repeat = restored.finishGame(again);
    expect(repeat.coins, content.economy.params.tasks.repeatReward);
    final third = restored.startGame(id);
    third.submit(const ChoiceAnswer('yes'));
    expect(restored.finishGame(third).coins, 0);
    expect(restored.wallet.wallet.balance,
        before + first.coins + repeat.coins);
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
