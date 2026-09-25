import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../data/game_repository.dart';

class StandRepository implements GameRepository {
  StandRepository({this.persistent = false});
  final bool persistent;
  bool failWrites = false;
  static const key = 'finni_stand_play_v1';
  Map<String, dynamic>? memory;
  @override
  Future<Map<String, dynamic>?> load() async {
    if (!persistent) return memory;
    final raw = (await SharedPreferences.getInstance()).getString(key);
    return raw == null
        ? null
        : (jsonDecode(raw) as Map).cast<String, dynamic>();
  }

  @override
  Future<void> save(Map<String, dynamic> value) async {
    if (failWrites) throw StateError('Проверка ошибки сохранения');
    memory = jsonDecode(jsonEncode(value)) as Map<String, dynamic>;
    if (persistent &&
        !await (await SharedPreferences.getInstance())
            .setString(key, jsonEncode(value))) {
      throw StateError('Не удалось сохранить игру стенда');
    }
  }

  @override
  Future<void> delete() async {
    memory = null;
    if (persistent &&
        !await (await SharedPreferences.getInstance()).remove(key)) {
      throw StateError('Не удалось сбросить игру стенда');
    }
  }
}
