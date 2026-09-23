import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

abstract interface class GameRepository {
  Future<Map<String, dynamic>?> load();
  Future<void> save(Map<String, dynamic> value);
  Future<void> delete();
}

/// Старый профиль не удаляется при переносе; при сбросе удаляются оба формата.
class LocalGameRepository implements GameRepository {
  static const key = 'finni_game_v1';
  static const legacyKey = 'finni_progress_v1';
  @override
  Future<Map<String, dynamic>?> load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(key);
    if (raw != null) return (jsonDecode(raw) as Map).cast<String, dynamic>();
    final old = prefs.getString(legacyKey);
    if (old == null) return null;
    final legacy = (jsonDecode(old) as Map).cast<String, dynamic>();
    const mapping = {
      'shop_hat': 'cap',
      'shop_scarf': 'scarf',
      'shop_glasses': 'glasses'
    };
    return {
      'balance': legacy['points'] ?? 0,
      'onboarded': true,
      'owned': [
        for (final id in legacy['purchasedItemIds'] as List? ?? [])
          mapping[id] ?? id
      ],
      'legacyCompletedTasks': legacy['completedTaskIds'] ?? [],
    };
  }

  @override
  Future<void> save(Map<String, dynamic> value) async {
    final prefs = await SharedPreferences.getInstance();
    if (!await prefs.setString(key, jsonEncode(value))) {
      throw StateError('Не удалось сохранить профиль');
    }
  }

  @override
  Future<void> delete() async {
    final prefs = await SharedPreferences.getInstance();
    for (final name in [key, legacyKey]) {
      if (prefs.containsKey(name) && !await prefs.remove(name)) {
        throw StateError('Не удалось удалить профиль');
      }
    }
  }
}
