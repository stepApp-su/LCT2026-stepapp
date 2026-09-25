import 'package:flutter/material.dart';
import 'content/content_loader.dart';
import 'content/game_content.dart';
import 'stand/stand_app.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    final content = await const ContentLoader().loadAll();
    final config = await GameContent.load();
    runApp(StandApp(content: content, config: config));
  } catch (_) {
    runApp(const MaterialApp(
        home: Scaffold(
            body: Center(
                child: SelectableText(
      'Не удалось загрузить стенд. Обновите страницу. Если ошибка повторяется, проверьте сборку и файлы контента.',
    )))));
  }
}
