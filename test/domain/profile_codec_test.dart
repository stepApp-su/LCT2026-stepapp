import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:finni/domain/models/models.dart';
import 'package:finni/domain/profile_codec.dart';
import 'package:finni/domain/profile_repository.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/profiles.dart';

Map<String, Object?> _content(String file) =>
    (jsonDecode(File('assets/content/$file').readAsStringSync()) as Map)
        .cast<String, Object?>();

Profile _loaded(ProfileLoad result) {
  expect(result, isA<ProfileLoaded>(),
      reason: result is ProfileUnreadable ? result.reason : '$result');
  return (result as ProfileLoaded).profile;
}

(int, int) _walletByJournal(Profile profile) {
  var balance = 0;
  var savings = 0;
  for (final t in profile.allTransactions) {
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
  return (balance, savings);
}

void main() {
  group('формат версии 2', () {
    test('полный профиль в JSON и обратно без потерь', () {
      final result = ProfileCodec.decode(ProfileCodec.encode(richProfile()));
      expect(
          (result as ProfileLoaded).fromVersion, ProfileCodec.currentVersion);
      expectSameProfile(_loaded(result), richProfile());
    });

    test('в конверте номер формата и больше ничего', () {
      final envelope = jsonDecode(ProfileCodec.encode(richProfile())) as Map;
      expect(envelope['schemaVersion'], ProfileCodec.currentVersion);
      expect(envelope.keys, {'schemaVersion', 'profile'});
    });

    test('сохранение без новых полей открывается со значениями по умолчанию',
        () {
      final json = viaJson(richProfile().toJson());
      for (final key in [
        'journal',
        'wishlist',
        'reachedGoalIds',
        'activeWallpaperId',
        'settings',
        'petActionsToday',
        'petChangesToday',
      ]) {
        json.remove(key);
      }
      (json['currentDay'] as Map).remove('planConfirmed');

      final profile = _loaded(ProfileCodec.decode(
          jsonEncode({'schemaVersion': 2, 'profile': json})));
      expect(profile.journal, isEmpty);
      expect(profile.wishlist, isEmpty);
      expect(profile.reachedGoalIds, isEmpty);
      expect(profile.activeWallpaperId, isNull);
      expect(profile.settings, const ProfileSettings());
      expect(profile.petActionsToday, isEmpty);
      expect(profile.petChangesToday, isEmpty);
      expect(profile.currentDay.planConfirmed, isFalse);
      expect(profile.wallet, richProfile().wallet);
      expect(profile.currentDay.transactions, hasLength(2));
      expect(profile.progress, richProfile().progress);
    });

    test('весь журнал: сначала прошлые дни, потом сегодня', () {
      expect(richProfile().allTransactions.map((t) => t.id),
          ['d1-1', 'd1-2', 'd2-1', 'd2-2']);
    });

    test('цель и обои можно снять явным null, без аргумента они остаются', () {
      final profile = richProfile();
      expect(profile.copyWith(simpleMode: true).goalId, 'scooter');
      expect(profile.copyWith(petName: 'Бумба').activeWallpaperId, 'wp_dots');
      expect(profile.copyWith(goalId: null).goalId, isNull);
      expect(
          profile.copyWith(activeWallpaperId: null).activeWallpaperId, isNull);
      expect(profile.copyWith(goalId: 'treehouse').goalId, 'treehouse');
    });

    test('настройки: чего нет в сохранении — то включено', () {
      expect(ProfileSettings.fromJson({}), const ProfileSettings());
      expect(ProfileSettings.fromJson({'motion': false}),
          const ProfileSettings(sound: true, motion: false));
      const off = ProfileSettings(sound: false, motion: false);
      expect(ProfileSettings.fromJson(viaJson(off.toJson())), off);
    });

    test('подтверждённый план — часть дня: сохраняется и отличает день', () {
      final day = freshProfile().currentDay;
      final confirmed = day.copyWith(planConfirmed: true);
      expect(confirmed, isNot(day));
      expect(
          GameDay.fromJson(viaJson(confirmed.toJson())).planConfirmed, isTrue);
      expect(GameDay.fromJson(viaJson(day.toJson())).planConfirmed, isFalse);
    });

    test('счётчики питомца не бывают отрицательными', () {
      expect(() => richProfile().copyWith(petActionsToday: {'pet_tap': -1}),
          throwsArgumentError);
    });
  });

  group('порча не роняет приложение', () {
    final broken = {
      'не JSON': 'broken',
      'пустая строка': '',
      'список вместо объекта': '[]',
      'нет версии': '{}',
      'версия строкой': '{"schemaVersion":"2"}',
      'нет профиля': '{"schemaVersion":2}',
      'профиль не объект': '{"schemaVersion":2,"profile":[]}',
      'формат 1 под новым ключом': '{"schemaVersion":1,"balance":10}',
      'версия 0': '{"schemaVersion":0}',
    };
    for (final MapEntry(key: name, value: raw) in broken.entries) {
      test('не читается, но и не падает: $name', () {
        expect(ProfileCodec.decode(raw), isA<ProfileUnreadable>());
      });
    }

    test('сохранение из более новой версии приложения не угадываем', () {
      final result = ProfileCodec.decode(
          jsonEncode({'schemaVersion': 3, 'profile': richProfile().toJson()}));
      expect(result, isA<ProfileUnreadable>());
      expect((result as ProfileUnreadable).reason, contains('новее'));
    });

    test('минус в кошельке, не те типы, битая дата — «не читается»', () {
      final damages = <String, void Function(Map<String, Object?>)>{
        'минус в кошельке': (p) => (p['wallet'] as Map)['balance'] = -5,
        'палитра строкой': (p) => p['palette'] = '3',
        'шкала словом': (p) => (p['state'] as Map)['satiety'] = 'много',
        'битая дата': (p) => (((p['currentDay'] as Map)['transactions']
            as List)[0] as Map)['at'] = 'вчера',
        'операция без объяснения': (p) =>
            (((p['currentDay'] as Map)['transactions'] as List)[0]
                as Map)['reasonText'] = '',
        'купленное не строкой': (p) => p['ownedItems'] = [1, 2],
        'лимит питомца минус': (p) => p['petActionsToday'] = {'pet_tap': -2},
      };
      for (final MapEntry(key: name, value: damage) in damages.entries) {
        final profile = viaJson(richProfile().toJson());
        damage(profile);
        expect(
            ProfileCodec.decode(
                jsonEncode({'schemaVersion': 2, 'profile': profile})),
            isA<ProfileUnreadable>(),
            reason: name);
      }
    });

    test('тысяча случайных повреждений: разбор никогда не бросает', () {
      final raw = ProfileCodec.encode(richProfile());
      const alphabet = '{}[]":,0123456789-abcxyzАБВ ';
      final random = Random(7);
      var unreadable = 0;
      for (var i = 0; i < 1000; i++) {
        final chars = raw.split('');
        final at = random.nextInt(chars.length);
        final mutated = switch (random.nextInt(3)) {
          0 => raw.substring(0, at),
          1 => (chars..removeAt(at)).join(),
          _ => (chars..[at] = alphabet[random.nextInt(alphabet.length)]).join(),
        };
        final result = ProfileCodec.decode(mutated);
        expect(result, anyOf(isA<ProfileLoaded>(), isA<ProfileUnreadable>()));
        if (result is ProfileUnreadable) unreadable++;
      }
      expect(unreadable, greaterThan(500));
    });
  });

  group('переход с первой сборки (формат 1)', () {
    test('всё, что было на экране, переезжает', () {
      final result =
          ProfileCodec.migrateV1(viaJson(v1Snapshot()), sampleDefaults);
      expect((result as ProfileLoaded).fromVersion, 1);
      final profile = _loaded(result);
      expect(profile.petName, 'Лаки');
      expect(profile.species, 'fox');
      expect(profile.simpleMode, isFalse);
      expect(profile.wallet, Wallet.create(balance: 45, savings: 15));
      expect(profile.state,
          PetState.create(satiety: 90, care: 75, mood: 95, cozy: 10));
      expect(profile.goalId, 'scooter');
      expect(profile.currentDay.number, 1);
      expect(
          profile.currentDay.plan,
          BudgetPlan.create(
              mandatory: 25, optional: 10, savings: 15, income: 60));
      expect(profile.currentDay.planConfirmed, isTrue);
      expect(profile.currentDay.transactions.map((t) => t.id),
          ['d1-1', 'd1-2', 'd1-3']);
      expect(profile.journal, isEmpty);
      expect(profile.ownedItems, ['bow']);
      expect(profile.equipped, {'head': 'bow'});
      expect(profile.wishlist, ['glasses']);
      expect(profile.completedTasks, ['task_save_jar']);
      expect(
          profile.settings, const ProfileSettings(sound: true, motion: false));
      expect(profile.progress, PetProgress.initial());
      expect(_walletByJournal(profile),
          (profile.wallet.balance, profile.wallet.savings));
    });

    test('самая старая сборка (очки вместо монет) тоже открывается', () {
      final profile = _loaded(ProfileCodec.migrateV1({
        'balance': 37,
        'onboarded': true,
        'owned': ['cap', 'shop_house'],
        'legacyCompletedTasks': ['task_save_jar'],
      }, sampleDefaults));
      expect(profile.wallet, Wallet.create(balance: 37, savings: 0));
      expect(profile.state, sampleDefaults.state);
      expect(profile.currentDay.number, 1);
      expect(profile.currentDay.plan, BudgetPlan.empty(60));
      expect(profile.ownedItems, ['cap', 'shop_house']);
      expect(profile.completedTasks, ['task_save_jar']);
    });

    test('питомца не создали — это первый запуск', () {
      expect(
          ProfileCodec.migrateV1(
              {'onboarded': false, 'balance': 60}, sampleDefaults),
          isA<ProfileMissing>());
      expect(ProfileCodec.migrateV1({}, sampleDefaults), isA<ProfileMissing>());
    });

    test('операции прошлых дней уходят в журнал, сегодняшние — в текущий день',
        () {
      final profile = _loaded(ProfileCodec.migrateV1(
          viaJson({
            'onboarded': true,
            'journal': [
              sampleTx('d1-1', TransactionType.income, 60, 1).toJson(),
              sampleTx('d2-1', TransactionType.income, 60, 2).toJson(),
            ],
            'balance': 120,
          }),
          sampleDefaults));
      expect(profile.currentDay.number, 2);
      expect(profile.currentDay.transactions.map((t) => t.id), ['d2-1']);
      expect(profile.journal.map((t) => t.id), ['d1-1']);
    });

    test('порченая первая сборка — «не читается», без падения', () {
      for (final snapshot in <Map<String, Object?>>[
        {'onboarded': true, 'balance': -5},
        {'onboarded': true, 'stats': 'много'},
        {
          'onboarded': true,
          'journal': [
            {'id': 1}
          ]
        },
        {
          'onboarded': true,
          'plan': {'mandatory': 100, 'optional': 0, 'savings': 0}
        },
        {'onboarded': true, 'petName': 42},
      ]) {
        expect(ProfileCodec.migrateV1(snapshot, sampleDefaults),
            isA<ProfileUnreadable>(),
            reason: '$snapshot');
      }
    });

    test('переехавший профиль пишется новым форматом и читается обратно', () {
      final migrated = _loaded(
          ProfileCodec.migrateV1(viaJson(v1Snapshot()), sampleDefaults));
      final again = ProfileCodec.decode(ProfileCodec.encode(migrated));
      expect((again as ProfileLoaded).fromVersion, ProfileCodec.currentVersion);
      expectSameProfile(again.profile, migrated);
    });
  });

  group('сверка с каталогом', () {
    test('ссылки на пропавшее убираются, история и деньги остаются', () {
      final profile = reconcileProfile(
        richProfile().copyWith(
          goalId: 'moon',
          wishlist: ['glasses', 'rocket'],
          equipped: {'head': 'crown', 'neck': 'scarf', 'eyes': null},
          activeWallpaperId: 'wp_gone',
          ownedItems: ['cap', 'rocket'],
          reachedGoalIds: ['ball_rope', 'moon'],
        ),
        goalIds: {'ball_rope', 'scooter'},
        itemIds: {'glasses', 'scarf', 'cap', 'wp_dots'},
      );
      expect(profile.goalId, isNull);
      expect(profile.wishlist, ['glasses']);
      expect(profile.equipped, {'head': null, 'neck': 'scarf', 'eyes': null});
      expect(profile.activeWallpaperId, isNull);
      expect(profile.ownedItems, ['cap', 'rocket']);
      expect(profile.reachedGoalIds, ['ball_rope', 'moon']);
      expect(profile.wallet, richProfile().wallet);
    });

    test('всё знакомое не трогается', () {
      final profile = richProfile();
      final same = reconcileProfile(profile,
          goalIds: {'scooter', 'ball_rope'},
          itemIds: {'glasses', 'cap', 'wp_dots', 'bouncy_ball'});
      expectSameProfile(same, profile);
    });

    test('настоящий каталог: цель «книга» из первой сборки снимается', () {
      final goals = GoalCatalog.fromJson(_content('goals.json'));
      final shop = ShopCatalog.fromJson(_content('shop.json'));
      final goalIds = {for (final g in goals.goals) g.id};
      final itemIds = {for (final i in shop.items) i.id};

      Profile migrate(String goalId) {
        final snapshot = viaJson(v1Snapshot())..['goalId'] = goalId;
        return reconcileProfile(
            _loaded(ProfileCodec.migrateV1(snapshot, sampleDefaults)),
            goalIds: goalIds,
            itemIds: itemIds);
      }

      expect(migrate('book').goalId, isNull);
      expect(migrate('scooter').goalId, 'scooter');
      expect(migrate('scooter').equipped, {'head': 'bow'});
    });
  });

  test('тестовый профиль эксперта согласован с контентом', () {
    final profile = _loaded(ProfileCodec.decode(
        File('assets/content/test_profile.json').readAsStringSync()));
    final goals = GoalCatalog.fromJson(_content('goals.json'));
    final shop = ShopCatalog.fromJson(_content('shop.json'));
    final economy = EconomyConfig.fromJson(_content('economy.json'));

    expect(goals.byId(profile.goalId!), isNotNull);
    expect(shop.byId(profile.activeWallpaperId!), isNotNull);
    expect(profile.state, economy.pet.initialState);
    expect(_walletByJournal(profile),
        (profile.wallet.balance, profile.wallet.savings));
    for (final t in profile.currentDay.transactions) {
      expect(t.dayNumber, profile.currentDay.number);
    }
    final reconciled = reconcileProfile(profile,
        goalIds: {for (final g in goals.goals) g.id},
        itemIds: {for (final i in shop.items) i.id});
    expectSameProfile(reconciled, profile);
  });
}
