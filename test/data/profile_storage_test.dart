import 'dart:convert';
import 'dart:io';

import 'package:finni/content/content_loader.dart';
import 'package:finni/data/game_repository.dart';
import 'package:finni/data/profile_storage.dart';
import 'package:finni/domain/models/models.dart';
import 'package:finni/domain/profile_codec.dart';
import 'package:finni/domain/profile_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../support/profiles.dart';

const _bannedKeys = {
  'name',
  'realname',
  'firstname',
  'lastname',
  'fullname',
  'surname',
  'childname',
  'parentname',
  'phone',
  'phonenumber',
  'email',
  'mail',
  'birthdate',
  'birthday',
  'dateofbirth',
  'age',
  'deviceid',
  'androidid',
  'imei',
  'advertisingid',
  'location',
  'geo',
  'latitude',
  'longitude',
  'lat',
  'lon',
  'lng',
  'address',
  'city',
  'school',
};

const _bannedTokens = {
  'phone',
  'email',
  'birth',
  'birthday',
  'device',
  'imei',
  'geo',
  'latitude',
  'longitude',
  'address',
  'surname',
  'age',
};

List<String> _words(String key) => key
    .replaceAllMapped(RegExp('([a-z0-9])([A-Z])'), (m) => '${m[1]}_${m[2]}')
    .toLowerCase()
    .split(RegExp('[^a-z0-9]+'))
    .where((w) => w.isNotEmpty)
    .toList();

List<String> _personalData(Object? node, [String path = r'$']) {
  final found = <String>[];
  if (node is Map) {
    for (final MapEntry(:key, :value) in node.entries) {
      final name = '$key';
      if (_bannedKeys.contains(name.toLowerCase()) ||
          _words(name).any(_bannedTokens.contains)) {
        found.add('$path.$name');
      }
      found.addAll(_personalData(value, '$path.$name'));
    }
  } else if (node is List) {
    for (var i = 0; i < node.length; i++) {
      found.addAll(_personalData(node[i], '$path[$i]'));
    }
  } else if (node is String) {
    final digits = node.replaceAll(RegExp(r'[\s()+-]'), '');
    if (RegExp(r'[\w.+-]+@[\w-]+\.[\w.-]+').hasMatch(node) ||
        RegExp(r'^\d{10,}$').hasMatch(digits) ||
        RegExp(r'^[0-9a-fA-F-]{16,}$').hasMatch(node)) {
      found.add('$path = $node');
    }
  }
  return found;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  SharedPrefsProfileRepository repository() =>
      SharedPrefsProfileRepository(defaults: sampleDefaults);

  Future<SharedPreferences> prefs() => SharedPreferences.getInstance();

  Future<Profile> loadedProfile() async {
    final result = await repository().load();
    expect(result, isA<ProfileLoaded>(),
        reason: result is ProfileUnreadable ? result.reason : '$result');
    return (result as ProfileLoaded).profile;
  }

  setUp(() => SharedPreferences.setMockInitialValues({}));

  group('сохранение и загрузка', () {
    test('первый запуск: профиля нет', () async {
      expect(await repository().load(), isA<ProfileMissing>());
    });

    test('профиль целиком переживает перезапуск', () async {
      await repository().save(richProfile());
      final result = await repository().load();
      expect(
          (result as ProfileLoaded).fromVersion, ProfileCodec.currentVersion);
      expectSameProfile(result.profile, richProfile());
    });

    test('каждое сохранение — целиком, последнее выигрывает', () async {
      await repository().save(richProfile());
      await repository().save(freshProfile());
      expectSameProfile(await loadedProfile(), freshProfile());
    });
  });

  group('нет персональных данных', () {
    test('в записанном на устройство JSON — ни одного персонального поля',
        () async {
      await repository().save(richProfile());
      final stored = await prefs();
      expect(stored.getKeys(), {SharedPrefsProfileRepository.key});
      final json =
          jsonDecode(stored.getString(SharedPrefsProfileRepository.key)!);
      expect(_personalData(json), isEmpty);
    });

    test('проверка сама ловит то, что должна', () {
      expect(_personalData({'petName': 'Мони', 'stage': 'baby'}), isEmpty);
      expect(_personalData({'at': '2026-09-22T18:30:00.000'}), isEmpty);
      for (final leak in <Map<String, Object?>>[
        {'childName': 'Вася'},
        {'email': 'x'},
        {'parentPhone': '1'},
        {'birthDate': '2019-01-01'},
        {'age': 8},
        {'deviceId': 'abc'},
        {
          'home': {'address': 'ул. Ленина'}
        },
        {'note': 'mama@mail.ru'},
        {'note': '+7 (916) 123-45-67'},
        {'id': '9774d56d682e549c'},
      ]) {
        expect(_personalData(leak), isNotEmpty, reason: '$leak');
      }
    });
  });

  group('сброс', () {
    test('возвращает исходное состояние и убирает старые форматы', () async {
      SharedPreferences.setMockInitialValues({
        LocalGameRepository.key: jsonEncode(v1Snapshot()),
        LocalGameRepository.legacyKey: '{}',
        SharedPrefsProfileRepository.unreadableKey: 'broken',
        'other': 'keep',
      });
      await repository().save(richProfile());

      await repository().reset(freshProfile());

      expectSameProfile(await loadedProfile(), freshProfile());
      expect((await prefs()).getKeys(),
          {SharedPrefsProfileRepository.key, 'other'});
    });

    test(
        'тестовый профиль эксперта: из ассетов, без персональных данных, '
        'возвращается одной кнопкой', () async {
      final expert = await const ContentLoader().loadTestProfile();
      expect(_personalData(asJson(expert)), isEmpty);
      expect(
          _personalData(jsonDecode(
              File(ContentLoader.testProfilePath).readAsStringSync())),
          isEmpty);

      await repository().reset(expert);
      await repository().save(expert.copyWith(
        wallet: Wallet.create(balance: 5, savings: 20),
        petActionsToday: {'pet_tap': 3},
      ));
      await repository().reset(expert);

      expectSameProfile(await loadedProfile(), expert);
    });
  });

  group('удаление', () {
    test('после удаления — как первый запуск, чужие ключи целы', () async {
      SharedPreferences.setMockInitialValues({
        LocalGameRepository.key: jsonEncode(v1Snapshot()),
        LocalGameRepository.legacyKey: '{}',
        SharedPrefsProfileRepository.unreadableKey: 'broken',
        'other': 'keep',
      });
      await repository().save(richProfile());

      await repository().delete();

      expect(await repository().load(), isA<ProfileMissing>());
      expect((await prefs()).getKeys(), {'other'});
      await repository().save(freshProfile());
      expectSameProfile(await loadedProfile(), freshProfile());
    });

    test('удалять нечего — ничего не ломается', () async {
      await repository().delete();
      expect(await repository().load(), isA<ProfileMissing>());
    });
  });

  group('порченые и чужие сохранения', () {
    test('порченое сохранение не перезаписывается молча', () async {
      SharedPreferences.setMockInitialValues(
          {SharedPrefsProfileRepository.key: 'broken'});

      expect(await repository().load(), isA<ProfileUnreadable>());
      final stored = await prefs();
      expect(stored.getString(SharedPrefsProfileRepository.key), 'broken');
      expect(stored.getString(SharedPrefsProfileRepository.unreadableKey),
          'broken');

      await repository().save(freshProfile());
      expectSameProfile(await loadedProfile(), freshProfile());
      expect(stored.getString(SharedPrefsProfileRepository.unreadableKey),
          'broken');
    });

    test('сохранение из более новой версии приложения не трогаем', () async {
      final future = jsonEncode({'schemaVersion': 99, 'profile': {}});
      SharedPreferences.setMockInitialValues(
          {SharedPrefsProfileRepository.key: future});
      expect(await repository().load(), isA<ProfileUnreadable>());
      expect(
          (await prefs()).getString(SharedPrefsProfileRepository.key), future);
    });
  });

  group('сохранения первой сборки', () {
    test('открываются и переходят в новый формат', () async {
      SharedPreferences.setMockInitialValues(
          {LocalGameRepository.key: jsonEncode(v1Snapshot())});

      final first = await repository().load();
      expect((first as ProfileLoaded).fromVersion, 1);
      expect(first.profile.petName, 'Лаки');
      expect(first.profile.wallet, Wallet.create(balance: 45, savings: 15));

      await repository().save(first.profile);
      expect((await prefs()).containsKey(LocalGameRepository.key), isTrue,
          reason: 'старый формат убирают только сброс и удаление');
      final second = await repository().load();
      expect(
          (second as ProfileLoaded).fromVersion, ProfileCodec.currentVersion);
      expectSameProfile(second.profile, first.profile);
    });

    test('самая старая сборка (очки вместо монет) тоже открывается', () async {
      SharedPreferences.setMockInitialValues({
        LocalGameRepository.legacyKey: jsonEncode({
          'points': 37,
          'completedTaskIds': ['task_save_jar'],
          'purchasedItemIds': ['shop_hat'],
        }),
      });
      final result = await repository().load();
      expect((result as ProfileLoaded).fromVersion, 1);
      expect(result.profile.wallet, Wallet.create(balance: 37, savings: 0));
      expect(result.profile.ownedItems, ['cap']);
      expect(result.profile.completedTasks, ['task_save_jar']);
      expect(result.profile.state, sampleDefaults.state);
    });

    test('питомца ещё не создали — это первый запуск', () async {
      SharedPreferences.setMockInitialValues({
        LocalGameRepository.key: jsonEncode(
            {'schemaVersion': 1, 'onboarded': false, 'motion': false}),
      });
      expect(await repository().load(), isA<ProfileMissing>());
    });

    test('битое сохранение первой сборки — «не читается», данные на месте',
        () async {
      SharedPreferences.setMockInitialValues(
          {LocalGameRepository.key: 'broken'});
      expect(await repository().load(), isA<ProfileUnreadable>());
      expect((await prefs()).getString(LocalGameRepository.key), 'broken');
    });
  });
}
