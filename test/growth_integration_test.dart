import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:finni/content/content_repository.dart';
import 'package:finni/domain/models/models.dart';
import 'package:finni/domain/services/plan_service.dart';
import 'package:finni/ui/game_controller.dart';
import 'package:finni/ui/app.dart';
import 'package:finni/ui/widgets/pet_celebration.dart';
import 'support/content.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late ContentBundle content;
  late Map<String, dynamic> config;
  setUpAll(() async => content = await loadTestContent());
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    config = jsonDecode(File('assets/content/game.json').readAsStringSync())
        as Map<String, dynamic>;
  });
  GameController make({Map<String, dynamic>? saved}) =>
      GameController(config, content: content, saved: saved);

  test('egg is only an introduction, baby starts at zero', () async {
    final s = make();
    s.createPet('Мони', true);
    expect(s.stage, PetStage.baby);
    expect(s.progress.growthPoints, 0);
    expect(s.celebration!['from'], 'egg');
    expect(s.progress.earnedTitles, contains('novice'));
    await s.flush();
    final restored = make(saved: await s.repository.load());
    expect(restored.stage, PetStage.baby);
    expect(restored.celebration!['from'], 'egg');
    restored.acknowledgeCelebration();
    await restored.flush();
    final again = make(saved: await restored.repository.load());
    expect(again.celebration, isNull);
    s.dispose();
    restored.dispose();
    again.dispose();
  });

  test('closing a day once persists growth, night effects and next income',
      () async {
    final s = make();
    s.plan.setAmount(PlanDirection.savings, 20);
    s.confirmPlan();
    s.saveCoins(20);
    final before = s.wallet.wallet.balance;
    expect(s.closeDay(1), true);
    final after = s.snapshot();
    expect(s.day, 2);
    expect(s.progress.growthPoints, greaterThan(0));
    expect(s.closeDay(1), false);
    expect(s.snapshot(), after);
    expect(s.wallet.wallet.balance, before + content.economy.params.day.income);
    await s.flush();
    final restored = make(saved: await s.repository.load());
    expect(restored.day, 2);
    expect(restored.progress, s.progress);
    expect(restored.stats, s.stats);
    expect(restored.closeDay(1), false);
    s.dispose();
    restored.dispose();
  });

  test(
      'stage unlock and earned title are saved; unearned title cannot be chosen',
      () async {
    final s = make();
    s.progress = s.progress.copyWith(growthPoints: 13);
    for (var i = 0; i < 3; i++) {
      s.plan.setAmount(PlanDirection.savings, 5);
      s.confirmPlan();
      s.saveCoins(5);
      expect(s.closeDay(s.day), true);
      s.acknowledgeCelebration();
    }
    expect(s.stage, PetStage.teen);
    expect(s.shop.stage, PetStage.teen);
    expect(s.progress.earnedTitles, contains('planner'));
    s.chooseTitle('planner');
    expect(() => s.chooseTitle('mentor'), throwsArgumentError);
    await s.flush();
    final restored = make(saved: await s.repository.load());
    expect(restored.currentTitle!.id, 'planner');
    expect(restored.stage, PetStage.teen);
    s.dispose();
    restored.dispose();
  });

  test('old egg save becomes baby without deleting balance or accessories', () {
    final s = make(saved: {
      'stage': 'egg',
      'balance': 75,
      'owned': ['cap'],
      'outfit': {'head': 'cap'}
    });
    expect(s.stage, PetStage.baby);
    expect(s.wallet.wallet.balance, 75);
    expect(s.outfit['head'], 'cap');
    s.dispose();
  });

  testWidgets('reduced motion shows final pet and lets user continue',
      (tester) async {
    final s = make()..motion = false;
    await tester.pumpWidget(MaterialApp(
        home: Scaffold(
            body: PetCelebration(state: s, event: const {
      'from': 'egg',
      'to': 'baby',
      'headline': 'Привет, Мони!',
      'reason': 'Растём вместе',
      'titles': []
    }))));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    final button = tester.widget<FilledButton>(
        find.widgetWithText(FilledButton, 'Начать дружить'));
    expect(button.onPressed, isNotNull);
    await tester.pumpWidget(const SizedBox());
    s.dispose();
  });

  testWidgets('hatching keeps the same dialog bounds throughout the animation',
      (tester) async {
    tester.view.physicalSize = const Size(360, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final s = make();
    await tester.pumpWidget(MaterialApp(
        home: Scaffold(
            body: PetCelebration(
      state: s,
      event: const {
        'from': 'egg',
        'to': 'baby',
        'headline': 'Привет, Мони!',
        'reason': 'Растём вместе',
        'titles': <String>[],
      },
    ))));
    final frame = find.byKey(const ValueKey('celebration-frame'));
    final initial = tester.getRect(frame);
    final timeline = tester
        .widgetList<AnimatedBuilder>(find.descendant(
          of: find.byType(PetCelebration),
          matching: find.byType(AnimatedBuilder),
        ))
        .map((widget) => widget.animation)
        .whereType<AnimationController>()
        .firstWhere((controller) =>
            controller.duration == const Duration(milliseconds: 4200));
    timeline.forward();
    await tester.pump();
    for (var i = 0; i < 10; i++) {
      await tester.pump(const Duration(milliseconds: 450));
      expect(tester.getRect(frame), initial);
      expect(tester.takeException(), isNull);
    }
    expect(timeline.isCompleted, isTrue);
    await tester.pumpWidget(const SizedBox());
    s.dispose();
  });

  testWidgets('celebrations can be dismissed and shown again in the app',
      (tester) async {
    final s = make(saved: {'onboarded': true, 'motion': false});
    await tester.pumpWidget(FinniApp(controller: s));
    await tester.pumpAndSettle();
    for (var i = 0; i < 2; i++) {
      s.celebration = {
        'from': 'baby',
        'to': 'teen',
        'headline': 'Подрос!',
        'reason': 'Растём',
        'titles': <String>[]
      };
      s.changed();
      await tester.pumpAndSettle();
      expect(find.byType(PetCelebration), findsOneWidget);
      await tester.tap(find.text('Здорово!'));
      await tester.pumpAndSettle();
      expect(s.celebration, isNull);
      expect(find.byType(PetCelebration), findsNothing);
    }
    await tester.pumpWidget(const SizedBox());
    s.dispose();
  });
}
