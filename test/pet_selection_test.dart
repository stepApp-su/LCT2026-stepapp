import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:finni/content/content_repository.dart';
import 'package:finni/domain/models/pet.dart';
import 'package:finni/ui/game_controller.dart';
import 'package:finni/ui/pet_appearance.dart';
import 'package:finni/ui/screens/welcome_screen.dart';
import 'package:finni/ui/widgets/moni_scene.dart';
import 'package:finni/stand/stand_app.dart';
import 'package:finni/domain/services/plan_service.dart';
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
    config['motion'] = false;
  });
  GameController make([Map<String, dynamic>? saved]) =>
      GameController(config, content: content, saved: saved);

  test('old and unknown species saves keep Moni and custom names', () {
    for (final id in [null, 'unavailable']) {
      final game = make({'character': id, 'petName': 'Финни'});
      expect(game.appearance, PetAppearance.moni);
      expect(game.petName, 'Финни');
      game.dispose();
    }
  });

  for (final pet in PetAppearance.values) {
    test('${pet.name}: the same daily actions award the same growth', () async {
      final game = make();
      game.createPet(pet.name, true, pet: pet);
      game.acknowledgeCelebration();
      game.progress = game.progress.copyWith(growthPoints: 13);
      for (var day = 0; day < 3; day++) {
        game.plan.setAmount(PlanDirection.savings, 5);
        game.confirmPlan();
        game.saveCoins(5);
        expect(game.closeDay(game.day), true);
        game.acknowledgeCelebration();
      }
      expect(game.stage, PetStage.teen);
      expect(game.progress.earnedTitles, contains('planner'));
      expect(game.appearance, pet);
      await game.flush();
      game.dispose();
    });
    test('${pet.name}: hatch, save and reload keep species and growth',
        () async {
      final game = make();
      game.createPet(pet.name, true, pet: pet);
      expect(game.character, pet.character);
      expect(game.stage, PetStage.baby);
      expect(game.progress.growthPoints, 0);
      expect(game.celebration!['from'], 'egg');
      expect(game.celebration!['headline'], 'Привет, ${pet.name}!');
      expect(game.progress.earnedTitles, contains('novice'));
      game.acknowledgeCelebration();
      game.progress =
          game.progress.copyWith(stage: PetStage.adult, growthPoints: 100);
      game.changed();
      await game.flush();
      final restored = make(await game.repository.load());
      expect(restored.appearance, pet);
      expect(restored.petName, pet.name);
      expect(restored.stage, PetStage.adult);
      expect(restored.celebration, isNull);
      expect(restored.progress, game.progress);
      restored.dispose();
      game.dispose();
    });

    test('${pet.name}: production artwork includes all ages and egg', () {
      for (final art in ['rig', 'rig-baby', 'rig-adult', 'egg']) {
        final bytes = File('${pet.assets}/$art.png').readAsBytesSync();
        expect(bytes.take(8), [137, 80, 78, 71, 13, 10, 26, 10]);
      }
    });
  }

  testWidgets('stand switches pet and previews growth and hatching',
      (tester) async {
    tester.view.physicalSize = const Size(1440, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(StandApp(content: content, config: config));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(ChoiceChip, 'Пикс'));
    await tester.pumpAndSettle();
    expect(tester.widget<MoniScene>(find.byType(MoniScene)).appearance,
        PetAppearance.pix);
    await tester.tap(find.text('Подросток → взрослый'));
    await tester.pumpAndSettle();
    expect(find.text('Пикс подрос!'), findsOneWidget);
    await tester.tap(find.text('Здорово!'));
    await tester.pumpAndSettle();
    expect(
        tester.widget<MoniScene>(find.byType(MoniScene)).stage, PetStage.adult);
    await tester.tap(find.text('Появление из яйца'));
    await tester.pumpAndSettle();
    expect(find.text('Привет, Пикс!'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('welcome selects Pix without changing an existing profile',
      (tester) async {
    final game = make();
    await tester.pumpWidget(MaterialApp(home: WelcomeScreen(state: game)));
    await tester.tap(find.text('Пикс'));
    await tester.pump();
    expect(tester.widget<MoniScene>(find.byType(MoniScene)).appearance,
        PetAppearance.pix);
    expect(game.appearance, PetAppearance.moni);
    await tester.tap(find.text('Дальше'));
    await tester.pump();
    await tester.tap(find.text('Дальше'));
    await tester.pump();
    await tester
        .tap(find.textContaining(RegExp(r'^Выбрать:|^Дальше$')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Начать дружить'));
    await tester.pump();
    expect(game.appearance, PetAppearance.pix);
    expect(game.petName, 'Пикс');
    expect(game.celebration!['from'], 'egg');
    await tester.pumpWidget(const SizedBox());
    await game.flush();
    game.dispose();
  });
}
