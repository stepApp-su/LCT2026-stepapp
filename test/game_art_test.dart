import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:finni/ui/widgets/game_glyph.dart';
import 'package:finni/ui/widgets/game_text.dart';
import 'package:finni/ui/widgets/emoji_art.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets(
      'switching between a single image and an atlas does not reuse old cells',
      (tester) async {
    await tester.runAsync(() async {
      await loadGameArtSheet('dreams-solo-robot');
      await loadGameArtSheet('dreams-solo-keyboard');
      await loadGameArtSheet('dreams-b');
    });
    for (final id in ['robot_kit', 'tent', 'keyboard', 'bike']) {
      await tester.pumpWidget(
          MaterialApp(home: Scaffold(body: GameGlyph(id, size: 72))));
      await tester.pump();
      expect(tester.takeException(), isNull, reason: id);
    }
  });

  test('every published dream has its own game-style illustration', () {
    final json =
        jsonDecode(File('assets/content/goals.json').readAsStringSync());
    final goals = json is List ? json : (json as Map)['goals'] as List;
    for (final goal in goals) {
      final id = goal['id'] as String;
      expect(gameArtCells[id], isNotNull, reason: id);
      expect(gameArtCells[id]!.sheet, startsWith('dreams-'));
    }
    expect(goals.length, 18);
  });

  test('every pictogram in interface and content has a replacement', () {
    final unknown = <String>{};
    for (final root in ['lib/ui', 'assets/content']) {
      for (final file
          in Directory(root).listSync(recursive: true).whereType<File>()) {
        if (!file.path.endsWith('.dart') && !file.path.endsWith('.json')) {
          continue;
        }
        for (final match
            in gameGlyphPattern.allMatches(file.readAsStringSync())) {
          if (!hasGameArt(match.group(0)!)) unknown.add(match.group(0)!);
        }
      }
    }
    expect(unknown, isEmpty);
    expect(kEmoji.values.every(hasGameArt), isTrue);
  });

  testWidgets(
      'all atlas cells are present, visible and have transparent surroundings',
      (tester) async {
    await tester.runAsync(() async {
      for (final name
          in gameArtCells.values.map((cell) => cell.sheet).toSet()) {
        final sheet = await loadGameArtSheet(name);
        expect(sheet.cells.length, gameArtColumns(name) * gameArtRows(name));
        final rgba = (await sheet.image.toByteData())!;
        expect(rgba.getUint8(3), lessThan(10), reason: '$name background');
        for (var i = 0; i < sheet.cells.length; i++) {
          final cell = sheet.cells[i];
          expect(cell.width, greaterThan(30), reason: '$name/$i');
          expect(cell.height, greaterThan(30), reason: '$name/$i');
          expect(cell.left, greaterThanOrEqualTo(0));
          expect(cell.right, lessThanOrEqualTo(sheet.image.width));
          expect(cell.bottom, lessThanOrEqualTo(sheet.image.height));
          var visible = 0;
          for (var y = cell.top.ceil(); y < cell.bottom.floor(); y += 4) {
            for (var x = cell.left.ceil(); x < cell.right.floor(); x += 4) {
              if (rgba.getUint8((y * sheet.image.width + x) * 4 + 3) > 100) {
                visible++;
              }
            }
          }
          expect(visible, greaterThan(100), reason: '$name/$i empty');
        }
      }
    });
  });

  testWidgets('inline pictograms become artwork, not font glyphs',
      (tester) async {
    await tester.pumpWidget(const MaterialApp(
        home: Scaffold(
      body: GameText('Получено 🪙 20! ✓', style: TextStyle(fontSize: 18)),
    )));
    expect(find.text('Получено 🪙 20! ✓'), findsOneWidget);
    expect(find.byType(GameGlyph), findsNWidgets(2));
    for (final rich in tester.widgetList<RichText>(find.byType(RichText))) {
      expect(
          gameGlyphPattern
              .hasMatch(rich.text.toPlainText(includeSemanticsLabels: false)),
          isFalse);
    }
    expect(tester.takeException(), isNull);
  });

  testWidgets('nested rich text keeps labels and replaces icons',
      (tester) async {
    await tester.pumpWidget(const MaterialApp(
        home: Scaffold(
      body: GameText.rich(TextSpan(children: [
        TextSpan(text: '✨ За сегодня ', style: TextStyle(fontSize: 16)),
        TextSpan(
            text: '🪙 20',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
      ])),
    )));
    expect(find.byType(GameGlyph), findsNWidgets(2));
    expect(tester.takeException(), isNull);
  });

  testWidgets('dream icon identifiers work in both catalogue and badges',
      (tester) async {
    await tester.pumpWidget(const MaterialApp(
        home: Scaffold(
            body: Row(children: [
      ItemArt('constructor'),
      EmojiBadge('icon_goal_constructor'),
    ]))));
    final glyphs = tester.widgetList<GameGlyph>(find.byType(GameGlyph));
    expect(glyphs.map((g) => g.id), everyElement('constructor'));
    expect(glyphs.length, 2);
  });
}
