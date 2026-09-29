import 'dart:convert';
import 'dart:io';

import 'package:finni/domain/models/models.dart';
import 'package:finni/domain/services/task_engine.dart';
import 'package:finni/domain/services/wallet_service.dart';
import 'package:finni/domain/stop_words.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/answers.dart';

Map<String, Object?> _raw(String file) =>
    (jsonDecode(File('assets/content/$file').readAsStringSync()) as Map)
        .cast<String, Object?>();

final TaskCatalog _catalog = TaskCatalog.fromJson(_raw('tasks.json'));
final TaskRewardRules _rewards =
    EconomyConfig.fromJson(_raw('economy.json')).params.tasks;

TaskEngine _engine({Iterable<String> completed = const []}) =>
    TaskEngine(catalog: _catalog, rewards: _rewards, completedTaskIds: completed);

TaskAnswer? _wrongAnswer(TaskDef task, TaskVariant variant) => switch (variant.payload) {
      SortPayload(:final bins, :final cards) => SortAnswer({
          for (final c in cards)
            c.id: identical(c, cards.first) ? bins.firstWhere((b) => b != c.bin) : c.bin,
        }),
      CoinsPayload() => const CoinsAnswer({}),
      DistributePayload(:final counters) =>
        DistributeAnswer({for (final c in counters) c.id: c.min}),
      OrderPayload(:final items) => OrderAnswer([
          for (final i in [...items]..sort((a, b) => b.rank.compareTo(a.rank))) i.id,
        ]),
      ChoicePayload(:final options) => task.allOptionsValid
          ? null
          : ChoiceAnswer(options.firstWhere((o) => !o.isCorrect).id),
      BasketPayload() => const BasketAnswer({}),
      WeekPayload(:final days) => WeekAnswer(List.filled(days, 0)),
      BoardPayload payload => BoardAnswer(
          searchBoard(payload, (run) => run.savings == 0 && run.joy == 0)!),
      StallPayload payload => StallAnswer(List.filled(
          payload.days.length, StallChoice(portions: 0, price: payload.prices.first))),
      CashierPayload payload => CashierAnswer(
          List.filled(payload.customers.length, const <int, int>{})),
      PriceTagPayload(:final rounds) => PriceTagAnswer([
          for (final round in rounds)
            round.offers.firstWhere((o) => o.id != round.best.id).id,
        ]),
    };

void _expectKindText(String text, String where) {
  expect(text.trim(), isNotEmpty, reason: where);
  expect(findStopWords(text), isEmpty, reason: '$where: $text');
  expect(text.contains('{'), isFalse, reason: '$where: $text');
}

void main() {
  group('все варианты каждого задания', () {
    for (final task in _catalog.tasks) {
      for (final pool in TaskPool.values) {
      for (final difficulty in TaskDifficulty.values) {
        if (pool == TaskPool.daily && difficulty == TaskDifficulty.easy) continue;
        for (var i = 0; i < task.variantsIn(pool, difficulty).length; i++) {
          final where = '${task.id}/${pool.name}/${difficulty.name}/$i';
          test('$where: решается, объясняется, помнит свой номер', () {
            final session =
                _engine().start(task.id, difficulty, index: i, pool: pool);
            expect(session.index, i);
            expect(session.variantKey, task.keyIn(pool, difficulty, i));
            final feedback = session.submit(rightAnswer(session.variant));
            expect(feedback.isCorrect, isTrue, reason: where);
            _expectKindText(feedback.explanation, where);
            final again =
                _engine().start(task.id, difficulty, index: i, pool: pool);
            final wrong = _wrongAnswer(task, again.variant);
            if (wrong != null) {
              final first = again.submit(wrong);
              expect(first.isCorrect, isFalse, reason: where);
              _expectKindText(first.explanation, where);
            }
          });
        }
      }
      }
    }

    test('у каждой игры свои задания для уровня и задания дня', () {
      for (final task in _catalog.tasks) {
        for (final difficulty in TaskDifficulty.values) {
          expect(task.hasOwn(TaskPool.level, difficulty), isTrue,
              reason: '${task.id}/${difficulty.name}');
        }
        expect(task.hasOwn(TaskPool.daily, TaskDifficulty.hard), isTrue,
            reason: task.id);
        final practice = {
          for (final list in task.variantSets.values)
            for (final v in list) v.intro
        };
        final challenges = [
          for (final list in task.levelSets.values)
            for (final v in list) v.intro,
          for (final v in task.dailyVariants) v.intro,
        ];
        for (final intro in challenges) {
          expect(practice, isNot(contains(intro)), reason: task.id);
        }
      }
    });

    test('номер варианта по кругу, счётчик считает все варианты', () {
      final task = _catalog.byId('payments_sort_needs')!;
      final easy = task.variantsOf(TaskDifficulty.easy).length;
      expect(easy, greaterThan(1));
      expect(task.variantCount,
          easy + task.variantsOf(TaskDifficulty.hard).length);
      expect(task.variantKeys.toSet(), hasLength(task.variantCount));
      expect(_engine().start(task.id, TaskDifficulty.easy, index: easy).index, 0);
    });
  });

  group('каждое задание из JSON', () {
    for (final task in _catalog.tasks) {
      for (final difficulty in TaskDifficulty.values) {
        final where = '${task.id}/${difficulty.name}';

        test('$where: верный ответ — объяснение и полная награда', () {
          final session = _engine().start(task.id, difficulty);
          final feedback = session.submit(rightAnswer(session.variant));
          expect(feedback.isCorrect, isTrue, reason: where);
          _expectKindText(feedback.explanation, where);
          expect(feedback.completion!.coins, task.reward.correct);
          expect(feedback.completion!.firstTime, isTrue);
          expect(feedback.completion!.withMistakes, isFalse);
          expect(feedback.canRetry, isFalse);
        });

        test('$where: ошибка — объяснение, повтор, награда за попытку', () {
          final session = _engine().start(task.id, difficulty);
          final wrong = _wrongAnswer(task, session.variant);
          if (wrong == null) return;
          final first = session.submit(wrong);
          expect(first.verdict, TaskVerdict.wrong, reason: where);
          _expectKindText(first.explanation, where);
          expect(first.canRetry, isTrue);
          expect(first.completion, isNull);
          expect(session.mistakes, 1);

          final second = session.submit(rightAnswer(session.variant));
          expect(second.isCorrect, isTrue);
          expect(second.attempt, 2);
          expect(second.completion!.coins, task.reward.wrong);
          expect(second.completion!.coins, greaterThan(0));
          expect(second.completion!.withMistakes, isTrue);
        });
      }
    }
  });

  group('награда', () {
    test('первое прохождение даёт монеты, повтор — меньше, но не ноль', () {
      final engine = _engine();
      final task = _catalog.tasks.first;
      final first = engine.start(task.id, TaskDifficulty.easy);
      final firstCoins =
          first.submit(rightAnswer(first.variant)).completion!.coins;
      expect(firstCoins, task.reward.correct);
      expect(engine.isCompleted(task.id), isTrue);

      final again = engine.start(task.id, TaskDifficulty.easy);
      final repeat = again.submit(rightAnswer(again.variant)).completion!;
      expect(repeat.firstTime, isFalse);
      expect(repeat.coins, greaterThan(0));
      expect(repeat.coins, lessThan(firstCoins));
      expect(repeat.coins, _rewards.repeatReward);
    });

    test('задание, пройденное раньше, помнится между сессиями', () {
      final task = _catalog.tasks.first;
      final session = _engine(completed: [task.id]).start(task.id, TaskDifficulty.hard);
      final completion = session.submit(rightAnswer(session.variant)).completion!;
      expect(completion.firstTime, isFalse);
      expect(completion.coins, greaterThan(0));
    });

    test('сдался после ошибки — монет нет, и задание не засчитано', () {
      final task = _catalog.byType(TaskType.basket).first;
      final engine = _engine();
      final session = engine.start(task.id, TaskDifficulty.easy);
      session.submit(const BasketAnswer({}));
      final completion = session.finish();
      expect(completion.coins, 0);
      expect(completion.withMistakes, isTrue);
      expect(engine.isCompleted(task.id), isFalse);
      expect(session.isFinished, isTrue);
      expect(() => session.submit(const BasketAnswer({})), throwsStateError);
    });

    test('закончить без единой попытки нельзя', () {
      final session = _engine().start(_catalog.tasks.first.id, TaskDifficulty.easy);
      expect(session.finish, throwsStateError);
    });

    test('монеты попадают в кошелёк с источником и объяснением, один раз', () {
      final task = _catalog.tasks.first;
      final wallet = WalletService();
      final session = _engine().start(task.id, TaskDifficulty.easy);
      expect(() => session.collect(wallet, at: DateTime(2026, 9, 24), dayNumber: 1),
          throwsStateError);
      session.submit(rightAnswer(session.variant));
      final ok = session.collect(wallet, at: DateTime(2026, 9, 24), dayNumber: 1);
      expect(ok.wallet.balance, task.reward.correct);
      expect(ok.transaction.type, TransactionType.income);
      expect(ok.transaction.sourceId, 'task:${task.id}');
      expect(ok.transaction.reasonText, contains(task.title));
      expect(session.isCollected, isTrue);
      expect(() => session.collect(wallet, at: DateTime(2026, 9, 24), dayNumber: 1),
          throwsStateError);
      expect(wallet.wallet.balance, task.reward.correct);
    });
  });

  group('подробности проверки', () {
    TaskSession start(TaskType type, [TaskDifficulty difficulty = TaskDifficulty.easy]) =>
        _engine().start(_catalog.byType(type).first.id, difficulty);

    test('SORT: не всё разложено — подсказка, а не ошибка', () {
      final session = start(TaskType.sort);
      final cards = (session.variant.payload as SortPayload).cards;
      final feedback = session.submit(SortAnswer({cards.first.id: cards.first.bin}));
      expect(feedback.verdict, TaskVerdict.incomplete);
      expect(feedback.explanation, contains('${cards.length - 1}'));
      expect(session.attempts, 0);
      expect(session.mistakes, 0);
    });

    test('SORT: подсказки на неверно разложенных карточках', () {
      final session = start(TaskType.sort);
      final payload = session.variant.payload as SortPayload;
      final feedback = session.submit(_wrongAnswer(session.task, session.variant)!);
      expect(feedback.check.details, [payload.cards.first.why]);
      expect(feedback.check.placedRight, isNot(contains(payload.cards.first.id)));
      expect(feedback.check.placedRight.length, payload.cards.length - 1);
    });

    test('COINS: лишняя монета — объяснение с суммой на прилавке', () {
      final session = start(TaskType.coins);
      final payload = session.variant.payload as CoinsPayload;
      final right = solveCoins(payload)!;
      final extra = payload.wallet.keys.firstWhere(
          (d) => (right[d] ?? 0) < payload.wallet[d]!);
      final answer = {...right, extra: (right[extra] ?? 0) + 1};
      final feedback = session.submit(CoinsAnswer(answer));
      expect(feedback.check.failCode, 'tooMuch');
      expect(feedback.explanation, contains('${payload.expected + extra}'));
    });

    test('COINS: монет больше, чем в кошельке, выложить нельзя', () {
      final session = start(TaskType.coins);
      final payload = session.variant.payload as CoinsPayload;
      final denomination = payload.wallet.keys.first;
      expect(
          () => session.submit(
              CoinsAnswer({denomination: payload.wallet[denomination]! + 1})),
          throwsArgumentError);
    });

    test('DISTRIBUTE: больше, чем есть монет, не распределить', () {
      final task = _catalog.byId('planning_distribute_day')!;
      final session = _engine().start(task.id, TaskDifficulty.easy);
      final payload = session.variant.payload as DistributePayload;
      final feedback = session.submit(DistributeAnswer({
        'mandatory': payload.pool!,
        'optional': 0,
        'savings': 10,
      }));
      expect(feedback.check.failCode, TaskCheck.overPoolCode);
      _expectKindText(feedback.explanation, task.id);
    });

    test('DISTRIBUTE: не хватает на обязательное — объяснение именно про это', () {
      final session = _engine().start('planning_distribute_day', TaskDifficulty.easy);
      final feedback = session.submit(
          const DistributeAnswer({'mandatory': 10, 'optional': 0, 'savings': 10}));
      expect(feedback.check.failCode, 'mandatoryShort');
      expect(feedback.explanation,
          session.variant.explanationsByReason['mandatoryShort']);
    });

    test('DISTRIBUTE: счёт дней — лишние дни тоже подсказываем', () {
      final session = _engine().start('savings_distribute_days', TaskDifficulty.easy);
      final feedback = session.submit(const DistributeAnswer({'days': 9}));
      expect(feedback.check.failCode, 'tooMany');
    });

    test('DISTRIBUTE: шаг счётчика соблюдается', () {
      final session = _engine().start('planning_distribute_day', TaskDifficulty.easy);
      expect(() => session.submit(const DistributeAnswer({'mandatory': 23})),
          throwsArgumentError);
    });

    test('ORDER: объяснение берёт «почему» с неверно стоящей карточки', () {
      final session = start(TaskType.order);
      final payload = session.variant.payload as OrderPayload;
      final feedback = session.submit(_wrongAnswer(session.task, session.variant)!);
      expect(feedback.check.failCode, 'wrongOrder');
      expect(payload.items.map((i) => i.why), contains(feedback.explanation));
    });

    test('ORDER: одинаковый ранг — порядок внутри группы любой', () {
      final session = _engine().start('planning_order_priority', TaskDifficulty.easy);
      final feedback = session.submit(
          const OrderAnswer(['water_light', 'food', 'stickers', 'toy']));
      expect(feedback.isCorrect, isTrue);
    });

    test('CHOICE: у каждого варианта своё объяснение', () {
      final task = _catalog.byId('planning_choice_enough')!;
      final session = _engine().start(task.id, TaskDifficulty.hard);
      final options = (session.variant.payload as ChoicePayload).options;
      final wrong = options.firstWhere((o) => !o.isCorrect);
      final feedback = session.submit(ChoiceAnswer(wrong.id));
      expect(feedback.explanation, wrong.explanation);
      expect(feedback.check.failCode, TaskCheck.wrongOptionCode);
    });

    test('CHOICE без единственно верного ответа: любой выбор засчитан', () {
      final task = _catalog.tasks.firstWhere((t) => t.allOptionsValid);
      for (final difficulty in TaskDifficulty.values) {
        final options = (task.variant(difficulty).payload as ChoicePayload).options;
        for (final option in options) {
          final session = _engine().start(task.id, difficulty);
          final feedback = session.submit(ChoiceAnswer(option.id));
          expect(feedback.isCorrect, isTrue, reason: option.id);
          expect(feedback.explanation, option.explanation);
        }
      }
    });

    test('BASKET: называем, что забыли из списка', () {
      final session = start(TaskType.basket);
      final payload = session.variant.payload as BasketPayload;
      final forgotten = payload.fromList.last;
      final feedback = session.submit(BasketAnswer({
        for (final p in payload.fromList)
          if (p.id != forgotten.id) p.id,
      }));
      expect(feedback.check.failCode, TaskCheck.missingRequiredCode);
      expect(feedback.explanation, contains(forgotten.label.toLowerCase()));
    });

    test('BASKET: всё из списка, но перебор по бюджету', () {
      final session = start(TaskType.basket);
      final payload = session.variant.payload as BasketPayload;
      final feedback = session.submit(BasketAnswer({for (final p in payload.products) p.id}));
      expect(feedback.check.failCode, TaskCheck.overBudgetCode);
    });

    test('WEEK: не хватило в день события — день и сумма в объяснении', () {
      final session = start(TaskType.week);
      final payload = session.variant.payload as WeekPayload;
      final feedback = session.submit(
          WeekAnswer(List.filled(payload.days, payload.maxSavePerDay)));
      final event = payload.events.first;
      expect(feedback.check.failCode, 'notEnoughOnEventDay');
      expect(feedback.explanation, contains('${event.day}'));
      expect(feedback.explanation, contains(event.label));
    });

    test('WEEK: подарок купили, а в копилке мало — говорим, сколько не хватает', () {
      final session = start(TaskType.week);
      final payload = session.variant.payload as WeekPayload;
      final feedback = session.submit(WeekAnswer(List.filled(payload.days, 0)));
      expect(feedback.check.failCode, 'goalShort');
      expect(feedback.explanation, contains('${payload.target}'));
    });

    test('ответ не того типа — ошибка программы, а не ребёнка', () {
      final session = start(TaskType.sort);
      expect(() => session.submit(const ChoiceAnswer('yes')), throwsArgumentError);
      expect(session.attempts, 0);
    });

    test('неизвестное задание не запускается', () {
      expect(() => _engine().start('no_such_task', TaskDifficulty.easy),
          throwsArgumentError);
    });
  });

  group('новые игры', () {
    test('PRICETAG: яркий ценник — объяснение берём с выбранного варианта', () {
      final task = _catalog.byType(TaskType.pricetag).first;
      final session = _engine().start(task.id, TaskDifficulty.easy);
      final payload = session.variant.payload as PriceTagPayload;
      final answer = [for (final round in payload.rounds) round.best.id];
      final tricky = payload.rounds.first.offers
          .firstWhere((o) => o.id != payload.rounds.first.best.id);
      answer[0] = tricky.id;
      final feedback = session.submit(PriceTagAnswer(answer));
      expect(feedback.check.failCode, 'notBest');
      expect(feedback.explanation, tricky.why);
      expect(feedback.check.placedRight, isNot(contains(payload.rounds.first.id)));
    });

    test('PRICETAG: бывают и честные акции, и «ничего не покупать»', () {
      final hard = _catalog.byType(TaskType.pricetag).first
          .variant(TaskDifficulty.hard)
          .payload as PriceTagPayload;
      expect(hard.rounds.any((r) => r.best.tag != null), isTrue);
      expect(hard.rounds.any((r) => r.best.pay == 0), isTrue);
    });

    test('у каждой игры есть обучение', () {
      for (final task in _catalog.tasks) {
        final steps = _catalog.tutorialFor(task);
        expect(steps, isNotEmpty, reason: task.id);
        for (final step in steps) {
          expect(step.emoji.trim(), isNotEmpty, reason: task.id);
          _expectKindText(step.text, task.id);
        }
      }
    });

    test('BOARD: всё в копилку перед обедом — не хватит на обязательное', () {
      final task = _catalog.byType(TaskType.board).first;
      final session = _engine().start(task.id, TaskDifficulty.easy);
      final payload = session.variant.payload as BoardPayload;
      final decisions =
          searchBoard(payload, (run) => run.shortages.isNotEmpty)!;
      final feedback = session.submit(BoardAnswer(decisions));
      expect(feedback.check.failCode, 'mandatoryShort');
      _expectKindText(feedback.explanation, task.id);
      expect(feedback.check.details, isNotEmpty);
    });

    test('BOARD: одно желание по дороге не мешает цели', () {
      final task = _catalog.byType(TaskType.board).first;
      final session = _engine().start(task.id, TaskDifficulty.easy);
      final payload = session.variant.payload as BoardPayload;
      final decisions =
          searchBoard(payload, (run) => payload.passes(run) && run.joy >= 1);
      expect(decisions, isNotNull);
      expect(session.submit(BoardAnswer(decisions!)).isCorrect, isTrue);
    });

    test('BOARD: шаг игры повторяет проверку движка', () {
      final payload = _catalog.byType(TaskType.board).first
          .variant(TaskDifficulty.hard)
          .payload as BoardPayload;
      var run = BoardRun.start(payload);
      while (!run.isFinished) {
        run = run.pending ? run.decide(run.options().first) : run.roll();
      }
      expect(BoardRun.play(payload, run.decisions).savings, run.savings);
      expect(() => BoardRun.play(payload, [...run.decisions, 0]),
          throwsArgumentError);
    });

    test('STALL: в дождь лишние порции не продать', () {
      final task = _catalog.byType(TaskType.stall).first;
      final payload = task.variant(TaskDifficulty.easy).payload as StallPayload;
      final first = payload.playDay(
          0, payload.startCoins, StallChoice(portions: 10, price: payload.prices.first));
      final second = payload.playDay(1, first.coinsAfter,
          StallChoice(portions: payload.portionOptions(first.coinsAfter).last, price: payload.prices.last));
      expect(second.leftover, greaterThan(0));
      expect(second.sold, payload.days[1].demand[payload.prices.last]);
    });

    test('STALL: больше, чем по карману, закупить нельзя', () {
      final payload = _catalog.byType(TaskType.stall).first
          .variant(TaskDifficulty.easy)
          .payload as StallPayload;
      expect(
          () => payload.playDay(0, 2,
              StallChoice(portions: payload.maxPortions, price: payload.prices.first)),
          throwsArgumentError);
    });

    test('CASHIER: называем покупателя, которому сдача не та', () {
      final task = _catalog.byType(TaskType.cashier).first;
      final session = _engine().start(task.id, TaskDifficulty.easy);
      final payload = session.variant.payload as CashierPayload;
      final changes = [
        for (final customer in payload.customers)
          changeCoins(payload, customer.change),
      ];
      changes[1] = {1: 1};
      final feedback = session.submit(CashierAnswer(changes));
      expect(feedback.check.failCode, 'wrongChange');
      expect(feedback.explanation, contains(payload.customers[1].name));
      expect(feedback.check.placedRight, isNot(contains(payload.customers[1].id)));
      _expectKindText(feedback.explanation, task.id);
    });
  });

  test('в движке нет ни одного id задания: всё содержание приходит из JSON', () {
    final source = File('lib/domain/services/task_engine.dart').readAsStringSync();
    for (final task in _catalog.tasks) {
      expect(source.contains(task.id), isFalse, reason: task.id);
    }
  });
}
