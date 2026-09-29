import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:finni/ui/game_controller.dart';
import 'package:finni/content/content_repository.dart';
import 'support/content.dart';

void main() {
  late ContentBundle content;
  late Map<String, dynamic> config;
  setUpAll(() async {
    content = await loadTestContent();
    config = jsonDecode(File('assets/content/game.json').readAsStringSync())
        as Map<String, dynamic>;
  });
  GameController make(Map<String, dynamic> saved) =>
      GameController(config, content: content, saved: saved);

  test('retired backpack is not sold and has no wardrobe slot', () {
    expect(content.shop.byId('backpack'), isNull);
    expect(content.shop.items.where((item) => item.slot == 'back'), isEmpty);
  });

  test('old owner receives one refund without losing other items or progress',
      () {
    final saved = {
      'balance': 10,
      'savings': 70,
      'day': 5,
      'character': 'puppy',
      'owned': ['backpack', 'bow'],
      'outfit': {'back': 'backpack', 'head': 'bow'},
      'wishlist': ['backpack', 'cap'],
    };
    final game = make(saved);
    expect(game.wallet.wallet.balance, 45);
    expect(game.wallet.wallet.savings, 70);
    expect(game.day, 5);
    expect(game.character, 'puppy');
    expect(game.owned, isNot(contains('backpack')));
    expect(game.owned, contains('bow'));
    expect(game.outfit, {'head': 'bow'});
    expect(game.wishlist, {'cap'});
    expect((saved['outfit'] as Map)['back'], 'backpack');
    final snapshot = game.snapshot();
    game.dispose();
    final restored = make(snapshot);
    expect(restored.wallet.wallet.balance, 45);
    expect(
        restored.wallet.journal.where((tx) => tx.sourceId == 'refund:backpack'),
        hasLength(1));
    restored.dispose();
    // Even a stale ownership flag must not duplicate a recorded refund.
    final stale = make({
      ...snapshot,
      'owned': ['backpack', 'bow']
    });
    expect(stale.wallet.wallet.balance, 45);
    stale.dispose();
  });

  test('wishlist or stale equipped item alone does not award coins', () {
    final game = make({
      'balance': 10,
      'outfit': {'back': 'backpack'},
      'wishlist': ['backpack']
    });
    expect(game.wallet.wallet.balance, 10);
    expect(game.outfit, isEmpty);
    expect(game.wishlist, isEmpty);
    game.dispose();
  });
}
