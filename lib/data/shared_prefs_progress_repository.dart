import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../domain/progress.dart';
import '../domain/repositories.dart';

/// Персистентность прогресса в SharedPreferences (локально, офлайн).
class SharedPrefsProgressRepository implements ProgressRepository {
  static const _key = 'finni_progress_v1';

  @override
  Future<Progress> load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_key);
    if (raw == null) return const Progress();

    final map = jsonDecode(raw) as Map<String, dynamic>;
    return Progress(
      points: map['points'] as int? ?? 0,
      completedTaskIds:
          (map['completedTaskIds'] as List<dynamic>?)?.cast<String>().toSet() ??
              const {},
      purchasedItemIds:
          (map['purchasedItemIds'] as List<dynamic>?)?.cast<String>().toSet() ??
              const {},
    );
  }

  @override
  Future<void> save(Progress progress) async {
    final prefs = await SharedPreferences.getInstance();
    final map = {
      'points': progress.points,
      'completedTaskIds': progress.completedTaskIds.toList(),
      'purchasedItemIds': progress.purchasedItemIds.toList(),
    };
    await prefs.setString(_key, jsonEncode(map));
  }
}
