import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:finni/content/content_repository.dart';
import 'package:finni/domain/game_clock.dart';
import 'package:finni/domain/models/pet.dart';
import 'package:finni/domain/services/pet_need_service.dart';
import 'package:finni/ui/game_controller.dart';
import 'package:finni/ui/pet_appearance.dart';
import 'support/content.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late ContentBundle content;
  late GameController game;
  late DemoClock clock;
  setUpAll(() async => content = await loadTestContent());
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    clock = DemoClock();
    game = GameController(
      jsonDecode(File('assets/content/game.json').readAsStringSync()),
      content: content,
      clock: clock,
    );
  });
  tearDown(() async {
    await game.flush();
    game.dispose();
  });

  PetState stats({int food = 100, int care = 100, int mood = 100}) =>
      PetState.create(satiety: food, care: care, mood: mood, cozy: 0);

  test('zero cozy is not a need; low food, care and mood are', () {
    expect(currentPetNeed(PetState.initial(), content.economy.pet), isNull);
    expect(
        currentPetNeed(stats(food: 20), content.economy.pet), PetStat.satiety);
    expect(currentPetNeed(stats(care: 20), content.economy.pet), PetStat.care);
    expect(currentPetNeed(stats(mood: 30), content.economy.pet), PetStat.mood);
    expect(
        currentPetNeed(
            stats(food: 20, care: 20, mood: 30), content.economy.pet),
        PetStat.satiety);
  });

  for (final pet in PetAppearance.values) {
    test('${pet.name}: every need has an actionable reminder', () {
      game.createPet(pet.name, true, pet: pet);
      game.acknowledgeCelebration();
      for (final stat in [PetStat.satiety, PetStat.care, PetStat.mood]) {
        game.dismissBubble();
        clock.advance(const Duration(minutes: 4));
        game.stats = stats(
            food: stat == PetStat.satiety ? 40 : 100,
            care: stat == PetStat.care ? 20 : 100,
            mood: stat == PetStat.mood ? 30 : 100);
        expect(game.petIsSad, true);
        expect(game.remindNeed(), true);
        expect(game.bubble!.id, 'need_${stat.name}');
        expect(game.bubble!.textRu, isNotEmpty);
        game.stats = stats();
        game.changed();
        expect(game.bubble, isNull);
        expect(game.petIsSad, false);
      }
    });
  }

  test('сильный голод — своя просьба купить еду', () {
    game.createPet('Мони', true);
    game.acknowledgeCelebration();
    game.dismissBubble();
    game.stats = stats(food: 20);
    expect(game.veryHungry, isTrue);
    expect(game.remindNeed(), true);
    expect(game.bubble!.id, 'need_satiety_hungry');
    expect(game.bubble!.action?.route, 'shop');
  });

  test('reminders respect cooldown and never interrupt another bubble', () {
    game.stats = stats(food: 20);
    game.say('app_open');
    final greeting = game.bubble;
    expect(game.remindNeed(), false);
    expect(game.bubble, same(greeting));
    game.dismissBubble();
    expect(game.remindNeed(), true);
    game.dismissBubble();
    clock.advance(const Duration(seconds: 30));
    expect(game.remindNeed(), false);
    clock.advance(const Duration(minutes: 4));
    expect(game.remindNeed(), true);
  });

  test('no reminders during hatching or when needs are met', () {
    expect(game.remindNeed(), false);
    game.createPet('Пуф', true, pet: PetAppearance.puf);
    game.stats = stats(food: 20);
    expect(game.remindNeed(), false);
    game.acknowledgeCelebration();
    game.dismissBubble();
    expect(game.remindNeed(), true);
  });
}
