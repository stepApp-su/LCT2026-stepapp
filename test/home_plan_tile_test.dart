import 'dart:convert';
import 'dart:io';

import 'package:finni/ui/game_controller.dart';
import 'package:finni/ui/games/quests.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:finni/ui/theme/finni_theme.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'support/content.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() async {
    final fonts = FontLoader('Nunito')
      ..addFont(rootBundle.load('assets/fonts/Nunito.ttf'));
    await fonts.load();
  });
  for (final width in [360.0, 430.0]) {
    testWidgets('home plan uses a compact horizontal layout at $width',
        (tester) async {
      SharedPreferences.setMockInitialValues({});
      final content = (await tester.runAsync(loadTestContent))!;
      final config = jsonDecode(
          File('assets/content/game.json').readAsStringSync())
          as Map<String, dynamic>;
      config['motion'] = false;
      final state = GameController(config, content: content);
      addTearDown(state.dispose);
      var opened = false;
      await tester.pumpWidget(MaterialApp(
        theme: finniTheme(),
        home: Scaffold(
          body: Center(
            child: SizedBox(
              width: width - 32,
              child: HomeQuests(
                state: state,
                onLevel: () {},
                onDaily: () {},
                onPractice: () {},
                onBedtime: () {},
                onPlan: () => opened = true,
              ),
            ),
          ),
        ),
      ));
      final title = find.text('Составь план на день');
      final icon = find.byIcon(Icons.edit_note_rounded);
      expect(tester.getTopLeft(title).dx, greaterThan(tester.getTopRight(icon).dx));
      expect(tester.getSize(find.byType(HomeQuests)).height, lessThan(80));
      expect(tester.takeException(), isNull);
      await tester.tap(title);
      expect(opened, isTrue);
      await tester.pumpWidget(const SizedBox.shrink());
    });
  }
}
