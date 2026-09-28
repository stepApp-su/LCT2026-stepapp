import 'package:finni/domain/models/models.dart';
import 'package:finni/domain/services/hint_service.dart';
import 'package:finni/domain/services/task_engine.dart';
import 'package:finni/domain/stop_words.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/answers.dart';
import '../support/content.dart';

void main() {
  late TaskCatalog catalog;
  late HintService hints;

  setUpAll(() async {
    catalog = (await loadTestContent()).tasks;
    hints = HintService(catalog.texts.hints);
  });

  TaskVariant variantOf(TaskType type) =>
      catalog.byType(type).first.variant(TaskDifficulty.easy);

  void expectKind(String text) {
    expect(text.trim(), isNotEmpty);
    expect(text.contains('{'), isFalse, reason: text);
    expect(findStopWords(text), isEmpty, reason: text);
  }

  test('у каждого шаблона подсказки есть текст', () {
    for (final key in HintService.keys) {
      expect(catalog.texts.hints.values[key], isNotNull, reason: key);
    }
  });

  test('«Безопасно или опасно?»: подсказка про обманщика, а не про покупки', () {
    final task = catalog.byId('payments_sort_safety')!;
    final variant = task.variant(TaskDifficulty.easy);
    final payload = variant.payload as SortPayload;
    final card = payload.cards.first;
    final other = payload.bins.firstWhere((b) => b != card.bin);
    final wrong = hints.hint(variant, answer: SortAnswer({card.id: other}));
    expect(wrong.text, contains(card.label));
    expect(wrong.text, contains('обманщику'));
    expectKind(wrong.text);
    final start = hints.hint(variant);
    expect(start.text, contains('опасно'));
    expect(catalog.texts.sort.bins.keys, containsAll(payload.bins));
    expect(catalog.tutorialFor(task).first.text, contains('ситуации'));
    for (final difficulty in TaskDifficulty.values) {
      expect(task.variantsOf(difficulty).length, greaterThanOrEqualTo(2));
    }
  });

  test('SORT: подсказка называет карточку не на своём месте', () {
    final variant = variantOf(TaskType.sort);
    final payload = variant.payload as SortPayload;
    final card = payload.cards.first;
    final other = payload.bins.firstWhere((b) => b != card.bin);
    final hint = hints.hint(variant, answer: SortAnswer({card.id: other}));
    expect(hint.text, contains(card.label));
    expect(hint.ready, isFalse);
    expectKind(hint.text);
    final done = hints.hint(variant, answer: rightAnswer(variant));
    expect(done.ready, isTrue);
  });

  test('COINS: считает, сколько не хватает или лишнего', () {
    final variant = variantOf(TaskType.coins);
    final payload = variant.payload as CoinsPayload;
    final coin = payload.wallet.keys.reduce((a, b) => a < b ? a : b);
    final less = hints.hint(variant, answer: CoinsAnswer({coin: 1}));
    expect(less.text, contains('${payload.expected - coin}'));
    expectKind(less.text);
    final start = hints.hint(variant);
    expect(start.text, contains('${payload.expected}'));
    expect(hints.hint(variant, answer: rightAnswer(variant)).ready, isTrue);
  });

  test('BASKET: напоминает про товар из списка и про бюджет', () {
    final variant = variantOf(TaskType.basket);
    final payload = variant.payload as BasketPayload;
    final list = payload.fromList;
    final partial = hints.hint(variant,
        answer: BasketAnswer({for (final p in list.skip(1)) p.id}));
    expect(partial.text, contains(list.first.label));
    expectKind(partial.text);
    final all = hints.hint(variant,
        answer: BasketAnswer({for (final p in payload.products) p.id}));
    expect(all.text, contains('дороже бюджета'));
  });

  test('WEEK: показывает день, где не хватит монет', () {
    final variant = variantOf(TaskType.week);
    final payload = variant.payload as WeekPayload;
    final greedy = WeekAnswer(List.filled(payload.days, payload.maxSavePerDay));
    final hint = hints.hint(variant, answer: greedy);
    expect(hint.text, contains('${payload.events.first.day}'));
    expectKind(hint.text);
    expect(hints.hint(variant, answer: rightAnswer(variant)).ready, isTrue);
  });

  test('ORDER: называет пару, которую стоит поменять', () {
    final variant = variantOf(TaskType.order);
    final payload = variant.payload as OrderPayload;
    final sorted = [...payload.items]..sort((a, b) => a.rank.compareTo(b.rank));
    final reversed = OrderAnswer([for (final i in sorted.reversed) i.id]);
    final hint = hints.hint(variant, answer: reversed);
    expect(hint.ready, isFalse);
    expect(payload.items.any((i) => hint.text.contains(i.label)), isTrue);
    expectKind(hint.text);
    expect(hints.hint(variant, answer: rightAnswer(variant)).ready, isTrue);
  });

  test('игры-симуляции: подсказка от текущего шага', () {
    final board = variantOf(TaskType.board);
    final run = BoardRun.start(board.payload as BoardPayload);
    expectKind(hints.hint(board, situation: BoardSituation(run)).text);

    final stall = variantOf(TaskType.stall);
    final stallPayload = stall.payload as StallPayload;
    final demand = stallPayload.days.first.demand[stallPayload.prices.first]!;
    final extra = hints.hint(stall,
        situation: StallSituation(
            day: 0,
            coins: stallPayload.startCoins,
            portions: demand + 2,
            price: stallPayload.prices.first,
            dayShown: false));
    expect(extra.text, contains('непроданными'));
    expectKind(extra.text);

    final cashier = variantOf(TaskType.cashier);
    final customer = (cashier.payload as CashierPayload).customers.first;
    final more = hints.hint(cashier,
        situation: CashierSituation(customer: 0, given: customer.change + 1, answered: false));
    expect(more.text, contains('Убери'));
    final ready = hints.hint(cashier,
        situation: CashierSituation(customer: 0, given: customer.change, answered: false));
    expect(ready.ready, isTrue);

    final price = variantOf(TaskType.pricetag);
    expectKind(hints.hint(price, situation: const PriceTagSituation(round: 0, picked: false)).text);
  });

  test('подсказки не ломаются ни в одном варианте', () {
    for (final task in catalog.tasks) {
      for (final variant in task.allVariants) {
        expectKind(hints.hint(variant).text);
        final right = rightAnswer(variant);
        expectKind(hints.hint(variant, answer: right).text);
      }
    }
  });
}
