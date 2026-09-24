import 'package:shared_preferences/shared_preferences.dart';

import '../domain/models/models.dart';
import '../domain/profile_codec.dart';
import '../domain/profile_repository.dart';
import 'game_repository.dart';

final class SharedPrefsProfileRepository implements ProfileRepository {
  SharedPrefsProfileRepository({required this.defaults});

  static const key = 'finni_profile';

  static const unreadableKey = 'finni_profile_unreadable';

  static const allKeys = [
    key,
    unreadableKey,
    LocalGameRepository.key,
    LocalGameRepository.legacyKey,
  ];

  final ProfileDefaults defaults;

  @override
  Future<ProfileLoad> load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(key);
    if (raw != null) {
      final result = ProfileCodec.decode(raw);
      if (result is ProfileUnreadable &&
          prefs.getString(unreadableKey) != raw) {
        await prefs.setString(unreadableKey, raw);
      }
      return result;
    }
    final Map<String, dynamic>? snapshot;
    try {
      snapshot = await LocalGameRepository().load();
    } catch (e) {
      return ProfileUnreadable('сохранение первой сборки: $e');
    }
    if (snapshot == null) return const ProfileMissing();
    return ProfileCodec.migrateV1(snapshot.cast<String, Object?>(), defaults);
  }

  @override
  Future<void> save(Profile profile) async {
    final prefs = await SharedPreferences.getInstance();
    if (!await prefs.setString(key, ProfileCodec.encode(profile))) {
      throw StateError('Не удалось сохранить профиль');
    }
  }

  @override
  Future<void> reset(Profile initial) async {
    await save(initial);
    final prefs = await SharedPreferences.getInstance();
    await _remove(prefs, [
      unreadableKey,
      LocalGameRepository.key,
      LocalGameRepository.legacyKey,
    ]);
  }

  @override
  Future<void> delete() async {
    final prefs = await SharedPreferences.getInstance();
    await _remove(prefs, [
      unreadableKey,
      LocalGameRepository.legacyKey,
      LocalGameRepository.key,
      key,
    ]);
  }

  static Future<void> _remove(
      SharedPreferences prefs, List<String> keys) async {
    for (final name in keys) {
      if (prefs.containsKey(name) && !await prefs.remove(name)) {
        throw StateError('Не удалось удалить профиль');
      }
    }
  }
}
