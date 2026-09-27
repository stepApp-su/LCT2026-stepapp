import 'dart:convert';
import 'dart:io';

import 'package:finni/content/content_repository.dart';
import 'package:finni/domain/models/models.dart';
import 'package:finni/domain/services/plan_service.dart';
import 'package:finni/domain/services/shop_service.dart';
import 'package:finni/ui/game_controller.dart';
import 'package:finni/ui/widgets/bedtime_screen.dart';
import 'package:finni/ui/widgets/day_end.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'support/content.dart';

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

  GameController dayBeforeSleep() {
    final state = GameController(config, content: content)..motion = false;
    state.createPet('Мони', true);
    state.acknowledgeCelebration();
    for (var i = 0; i < 5; i++) {
      state.changePlan(PlanDirection.mandatory, 5);
    }
    state.changePlan(PlanDirection.savings, 5);
    state.confirmPlan();
    for (final need in content.economy.pet.needs) {
      expect(state.buyNow(need.itemId), isA<PurchaseDone>());
    }
    expect(state.saveByPlan(), isTrue);
    return state;
  }

  testWidgets('перед сном: полоски план/факт и оставшиеся дела', (tester) async {
    tester.view.physicalSize = const Size(360, 780);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final state = dayBeforeSleep();
    var slept = 0;
    final todos = <Object>[];
    await tester.pumpWidget(MaterialApp(
      home: BedtimeScreen(
        state: state,
        onSleep: (_) => slept++,
        onTodo: (_, todo) => todos.add(todo),
      ),
    ));
    await tester.pumpAndSettle();
    expect(find.text('Как прошёл день'), findsOneWidget);
    expect(find.text('Ровно по плану'), findsWidgets);
    expect(find.text('25 из 25'), findsOneWidget);
    expect(tester.takeException(), isNull);
    expect(state.bedtimeTodos, isNotEmpty);
    await tester.tap(find.text('Всё равно уложить спать'));
    expect(slept, 1);
    final action = switch (state.bedtimeTodos.first) {
      BedtimeTodo.plan => 'План',
      BedtimeTodo.needs => 'В магазин',
      BedtimeTodo.task => 'Играть',
      BedtimeTodo.event => 'Открыть',
    };
    await tester.scrollUntilVisible(find.text(action), 120,
        scrollable: find.byType(Scrollable).first);
    await tester.pumpAndSettle();
    await tester.tap(find.text(action).first);
    expect(todos, isNotEmpty);
    await tester.pumpWidget(const SizedBox());
    state.dispose();
  });

  GameController playedDay() {
    final state = GameController(config, content: content)..motion = false;
    state.createPet('Мони', true);
    state.acknowledgeCelebration();
    for (var i = 0; i < 5; i++) {
      state.changePlan(PlanDirection.mandatory, 5);
    }
    state.changePlan(PlanDirection.savings, 5);
    state.confirmPlan();
    for (final need in content.economy.pet.needs) {
      expect(state.buyNow(need.itemId), isA<PurchaseDone>());
    }
    expect(state.saveByPlan(), isTrue);
    expect(state.closeDay(state.day), isTrue);
    return state;
  }

  test('ночь приносит всё для двух экранов', () {
    final state = playedDay();
    final event = state.celebration!;
    expect(event['kind'], 'night');
    expect(event['day'], 1);
    expect(event['spent'], greaterThan(0));
    expect(event['earned'], greaterThanOrEqualTo(40));
    expect((event['factors'] as List), hasLength(4));
    expect((event['rows'] as List), hasLength(3));
    expect(event['nextAt'], isNotNull);
    final night = (event['night'] as List).cast<Map>();
    expect(night.map((n) => n['stat']), contains('satiety'));
    for (final shift in night) {
      expect(shift['after'], lessThan(shift['before'] as int));
    }
    expect((event['nightReasons'] as List), isNotEmpty);
    expect(jsonDecode(jsonEncode(event)), event);
  });

  testWidgets('ночь → итоги дня → утро → план', (tester) async {
    tester.view.physicalSize = const Size(400, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final state = playedDay();
    final event = Map<String, dynamic>.of(state.celebration!);
    String? result = 'none';
    await tester.pumpWidget(MaterialApp(
      home: Builder(
        builder: (context) => Scaffold(
          body: Center(
            child: FilledButton(
              onPressed: () async => result = await showDayEnd(context, state, event),
              child: const Text('open'),
            ),
          ),
        ),
      ),
    ));
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    expect(find.text('Мони сладко спит'), findsOneWidget);
    expect(find.text('День 1 завершён'), findsOneWidget);
    expect(tester.takeException(), isNull);

    await tester.tap(find.text('Итоги дня'));
    await tester.pumpAndSettle();
    expect(find.text('Итоги дня 1'), findsOneWidget);
    expect(find.text('Факт'), findsOneWidget);
    await tester.tap(find.text('Понятно'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Дальше'));
    await tester.pumpAndSettle();
    expect(find.text('Доброе утро!'), findsOneWidget);
    expect(find.text('Что изменилось за ночь'), findsOneWidget);
    expect(find.text('Сытость'), findsOneWidget);
    expect(find.text('+${state.plan.plan.income}'), findsOneWidget);
    expect(tester.takeException(), isNull);

    await tester.ensureVisible(find.text('Составить план на день'));
    await tester.tap(find.text('Составить план на день'));
    await tester.pumpAndSettle();
    expect(result, 'plan');
    await tester.pumpWidget(const SizedBox());
    state.dispose();
  });
}
