import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:finni/content/content_repository.dart';
import 'package:finni/stand/stand_app.dart';
import 'package:finni/stand/stand_repository.dart';
import 'support/content.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late ContentBundle content;
  setUpAll(() async {
    content = await loadTestContent();
  });
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('stand save and reset do not affect the app profile', () async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('finni_game_v1', 'app-profile');
    final play = StandRepository(persistent: true);
    final sandbox = StandRepository();
    await play.save({'balance': 60});
    await sandbox.save({'balance': 999});
    expect((await play.load())!['balance'], 60);
    expect((await sandbox.load())!['balance'], 999);
    await play.delete();
    expect(await play.load(), isNull);
    expect(prefs.getString('finni_game_v1'), 'app-profile');
  });

  testWidgets('desktop stand shows sections and can preview growth',
      (tester) async {
    tester.view.physicalSize = const Size(1280, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final config =
        jsonDecode(File('assets/content/game.json').readAsStringSync())
            as Map<String, dynamic>;
    config['motion'] = false;
    await tester.pumpWidget(StandApp(content: content, config: config));
    await tester.pumpAndSettle();
    expect(find.text('Скачать APK'), findsOneWidget);
    await tester.tap(find.text('Малыш → подросток'));
    await tester.pumpAndSettle();
    expect(find.text('Мони подрос!'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.tap(find.text('Здорово!'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Реплики'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('С кнопкой задания'));
    await tester.pumpAndSettle();
    expect(find.text('Открыть задания'), findsOneWidget);
    expect(tester.takeException(), isNull);
    expect(find.text('Оформление'), findsNothing);
    expect(find.byTooltip('Журнал событий'), findsNothing);
    expect(find.text('Тестовый стенд Финни'), findsOneWidget);
    expect(tester.getTopLeft(find.byTooltip('Сбросить стенд')).dx,
        greaterThan(640));
    expect(find.textContaining('очк.'), findsNothing);
    expect(tester.getSize(find.byKey(const ValueKey('stand-controls'))).width,
        640);
    expect(
        tester.getSize(find.byKey(const ValueKey('stand-preview'))).width, 640);
    expect(tester.getTopLeft(find.text('Ширина')).dx, greaterThan(640));
    await tester.tap(find.text('430'));
    await tester.pumpAndSettle();
    expect(find.text('Открыть задания'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.tap(find.text('Играть'));
    await tester.pumpAndSettle();
    expect(find.text('Можно просто играть'), findsOneWidget);
    expect(tester.widget<Icon>(find.byIcon(Icons.sports_esports_outlined)).size,
        104);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });
}
