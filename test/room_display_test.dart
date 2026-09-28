import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:finni/content/content_repository.dart';
import 'package:finni/stand/stand_repository.dart';
import 'package:finni/stand/stand_app.dart';
import 'package:finni/ui/game_controller.dart';
import 'package:finni/ui/widgets/sprite_sheet.dart';
import 'package:finni/ui/widgets/room_scene.dart';
import 'package:finni/ui/widgets/emoji_art.dart';
import 'support/content.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late ContentBundle content;
  late Map<String, dynamic> config;
  setUpAll(() async {
    content = await loadTestContent();
    config = jsonDecode(File('assets/content/game.json').readAsStringSync())
        as Map<String, dynamic>;
  });
  GameController make([Map<String, dynamic>? saved]) => GameController(config,
      content: content, saved: saved, repository: StandRepository());

  test('old saves have a furnished starter room without hidden objects', () {
    final game = make();
    expect(game.hiddenRoomItems, isEmpty);
    expect(game.shop.activeWallpaperId, 'wp_plain');
    game.dispose();
  });
  test('hiding owned furniture is free, reversible and survives reload',
      () async {
    final game = make({
      'owned': ['rug', 'palm']
    });
    final balance = game.wallet.wallet.balance;
    game.toggleRoomItem('palm');
    expect(game.hiddenRoomItems, contains('palm'));
    expect(game.shop.isOwned('palm'), isTrue);
    expect(game.wallet.wallet.balance, balance);
    final restored = make(game.snapshot());
    expect(restored.hiddenRoomItems, contains('palm'));
    restored.toggleRoomItem('palm');
    expect(restored.hiddenRoomItems, isEmpty);
    await game.flush();
    await restored.flush();
    game.dispose();
    restored.dispose();
  });
  test('only owned room items can be hidden', () {
    final game = make();
    for (final id in ['palm', 'not-real', 'cap', 'wp_plain', 'scooter']) {
      game.toggleRoomItem(id);
    }
    expect(game.hiddenRoomItems, isEmpty);
    game.dispose();
  });
  test('wallpapers can be changed without repeat payment only after buying',
      () async {
    final game = make({
      'owned': ['wp_clouds']
    });
    final balance = game.wallet.wallet.balance;
    game.applyWallpaper('wp_space');
    expect(game.shop.activeWallpaperId, 'wp_plain');
    game.applyWallpaper('wp_clouds');
    expect(game.shop.activeWallpaperId, 'wp_clouds');
    game.applyWallpaper('wp_plain');
    expect(game.shop.activeWallpaperId, 'wp_plain');
    expect(game.wallet.wallet.balance, balance);
    await game.flush();
    game.dispose();
  });
  test('every accepted room object has artwork or a catalog icon', () {
    for (final spot in content.rooms.byId('main')!.spots) {
      for (final id in spot.accepts) {
        expect({...furnitureCells, ...goalCells, ...wallpaperCells, ...kEmoji},
            contains(id));
      }
    }
    for (final item in content.shop.items.where((i) => i.slot.isNotEmpty)) {
      expect(accessoryCells, contains(item.id));
    }
    for (final name in ['furniture', 'goals']) {
      expect(File('assets/room/$name.png').existsSync(), isTrue);
    }
  });

  test('scene has at most one item per place and keeps all purchases',
      () async {
    final game = make({
      'owned': furnitureCells.keys.toList(),
      'reachedGoals': goalCells.keys.toList()
    });
    expect(game.visibleRoomItems.length, 5);
    expect(game.shop.owned, containsAll(furnitureCells.keys));
    game.selectRoomItem('left', 'bicycle');
    expect(game.visibleRoomItems['left'], 'bicycle');
    expect(game.visibleRoomItems.values, isNot(contains('bed')));
    game.selectRoomItem('right', 'palm');
    expect(game.visibleRoomItems['right'], 'palm');
    game.selectRoomItem('wall', null);
    expect(game.visibleRoomItems, isNot(contains('wall')));
    final restored = make(game.snapshot());
    expect(restored.visibleRoomItems, game.visibleRoomItems);
    await game.flush();
    game.dispose();
    restored.dispose();
  });
  test('room placement refuses wrong categories and unowned items', () async {
    final game = make({
      'owned': ['palm']
    });
    final before = game.visibleRoomItems;
    game.selectRoomItem('left', 'palm');
    game.selectRoomItem('left', 'bicycle');
    game.selectRoomItem('wall', 'poster');
    expect(game.visibleRoomItems, before);
    game.dispose();
  });

  testWidgets('stand room and clothing controls update the real game',
      (tester) async {
    tester.view.physicalSize = const Size(1280, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
        StandApp(content: content, config: {...config, 'motion': false}));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Комната'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Вся мебель и игрушки'));
    await tester.pumpAndSettle();
    GameController current() =>
        tester.widget<RoomScene>(find.byType(RoomScene)).state;
    expect(current().shop.owned, containsAll(furnitureCells.keys));
    final dreams = find.text('Все сбывшиеся мечты');
    await tester.ensureVisible(dreams);
    await tester.tap(dreams);
    await tester.pumpAndSettle();
    expect(current().snapshot()['reachedGoals'],
        containsAll(content.goals.goals.map((g) => g.id)));
    final cloud = find.text(content.shop.byId('wp_clouds')!.title);
    await tester.ensureVisible(cloud);
    await tester.tap(cloud);
    await tester.pumpAndSettle();
    expect(current().shop.activeWallpaperId, 'wp_clouds');
    await tester.tap(find.text('Одежда'));
    await tester.pumpAndSettle();
    final coat = find.text('Дождевик');
    await tester.ensureVisible(coat);
    await tester.tap(coat);
    await tester.pumpAndSettle();
    expect(current().outfit['body'], 'raincoat');
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });
}
