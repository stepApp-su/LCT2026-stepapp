import 'package:flutter_test/flutter_test.dart';
import 'package:finni/domain/models/models.dart';
import 'package:finni/domain/services/wallet_service.dart';

final _at = DateTime(2026, 9, 21, 12);

ShopItem _item(String id, int price, ExpenseCategory cat) =>
    ShopItem.create(id: id, title: id, price: price, category: cat);

void main() {
  group('операции', () {
    test('earn начисляет и пишет в журнал', () {
      final s = WalletService();
      final r = s.earn(
          amount: 40,
          sourceId: 'day:income',
          reasonText: 'Монетки нового дня',
          at: _at,
          dayNumber: 1);
      expect(r.wallet.balance, 40);
      expect(s.journal.single.reasonText, 'Монетки нового дня');
      expect(s.journal.single.sourceId, 'day:income');
    });

    test('spend списывает, категория и источник в журнале', () {
      final s = WalletService(initial: Wallet.create(balance: 40, savings: 0));
      final r = s.spend(
          amount: 15,
          itemId: 'food',
          category: ExpenseCategory.mandatory,
          reasonText: 'Купили еду — Финни поел',
          at: _at,
          dayNumber: 1);
      expect(r, isA<WalletOk>());
      expect(s.wallet.balance, 25);
      expect(s.journal.single.sourceId, 'shop:food');
      expect(s.journal.single.category, ExpenseCategory.mandatory);
    });

    test('переводы баланс-копилка', () {
      final s = WalletService(initial: Wallet.create(balance: 30, savings: 5));
      s.toSavings(amount: 10, at: _at, dayNumber: 1);
      expect(s.wallet.balance, 20);
      expect(s.wallet.savings, 15);
      s.fromSavings(amount: 5, at: _at, dayNumber: 1);
      expect(s.wallet.balance, 25);
      expect(s.wallet.savings, 10);
      expect(s.journal.length, 2);
    });
  });

  group('минуса не бывает', () {
    test('трата больше баланса: отказ, ничего не списано', () {
      final s = WalletService(initial: Wallet.create(balance: 15, savings: 0));
      final r = s.spend(
          amount: 20,
          itemId: 'ball',
          category: ExpenseCategory.optional,
          reasonText: 'Мячик',
          at: _at,
          dayNumber: 1);
      expect(r, isA<WalletNotEnough>());
      expect((r as WalletNotEnough).gap, 5);
      expect(s.wallet.balance, 15);
      expect(s.journal, isEmpty);
    });

    test('из копилки больше накопленного — отказ', () {
      final s = WalletService(initial: Wallet.create(balance: 0, savings: 12));
      final r = s.fromSavings(amount: 20, at: _at, dayNumber: 1);
      expect(r, isA<WalletNotEnough>());
      expect((r as WalletNotEnough).gap, 8);
      expect(s.wallet.savings, 12);
    });

    test('в копилку больше баланса — отказ', () {
      final s = WalletService(initial: Wallet.create(balance: 7, savings: 0));
      final r = s.toSavings(amount: 10, at: _at, dayNumber: 1);
      expect(r, isA<WalletNotEnough>());
      expect(s.wallet.balance, 7);
      expect(s.wallet.savings, 0);
    });
  });

  group('варианты при нехватке', () {
    final catalog = [
      _item('ball', 20, ExpenseCategory.optional),
      _item('treat', 8, ExpenseCategory.optional),
      _item('sticker', 5, ExpenseCategory.optional),
      _item('food', 15, ExpenseCategory.mandatory),
    ];

    WalletNotEnough attempt(WalletService s,
            {bool tasks = false, List<ShopItem> cat = const []}) =>
        s.spend(
          amount: 20,
          itemId: 'ball',
          category: ExpenseCategory.optional,
          reasonText: 'Мячик',
          at: _at,
          dayNumber: 1,
          hasUnusedTasksToday: tasks,
          catalog: cat,
        ) as WalletNotEnough;

    test('задания + дешёвый аналог = три варианта', () {
      final s = WalletService(initial: Wallet.create(balance: 10, savings: 0));
      final r = attempt(s, tasks: true, cat: catalog);
      expect(r.options.map((o) => o.route),
          ['tasks', 'postpone', 'shop:treat']);
    });

    test('альтернатива — лучшая доступная той же категории', () {
      final s = WalletService(initial: Wallet.create(balance: 10, savings: 0));
      final r = attempt(s, cat: catalog);
      expect(r.options.last.route, 'shop:treat');
      expect(r.options.last.textRu, contains('за 8'));
    });

    test('нет заданий и аналогов — только отложить', () {
      final s = WalletService(initial: Wallet.create(balance: 1, savings: 0));
      final r = attempt(s, cat: [_item('ball', 20, ExpenseCategory.optional)]);
      expect(r.options.map((o) => o.route), ['postpone']);
    });
  });

  group('покупка из копилки', () {
    WalletOutcome buy(WalletService wallet, int amount) => wallet.spendSavings(
          amount: amount,
          sourceId: 'goal:scooter',
          withdrawReason: 'Взяли 120 монет из копилки.',
          spendReason: 'Купили самокат на накопленные монеты!',
          at: _at,
          dayNumber: 3,
        );

    test('копилка уменьшается, баланс не растёт, в журнале снятие и трата', () {
      final wallet =
          WalletService(initial: Wallet.create(balance: 10, savings: 120));
      final outcome = buy(wallet, 120) as WalletOk;

      expect(outcome.wallet, Wallet.create(balance: 10, savings: 0));
      expect(wallet.wallet, outcome.wallet);
      final [withdraw, spend] = wallet.journal;
      expect(withdraw.type, TransactionType.fromSavings);
      expect(withdraw.amount, 120);
      expect(withdraw.sourceId, 'goal:scooter');
      expect(withdraw.reasonText, 'Взяли 120 монет из копилки.');
      expect(withdraw.dayNumber, 3);
      expect(spend.type, TransactionType.expense);
      expect(spend.amount, 120);
      expect(spend.sourceId, 'goal:scooter');
      expect(spend.category, ExpenseCategory.optional);
      expect(spend.reasonText, 'Купили самокат на накопленные монеты!');
      expect(spend.dayNumber, 3);
      expect(spend.id, isNot(withdraw.id));
      expect(outcome.transaction, spend);
    });

    test('копилки мало — отказ, ничего не списано и не записано', () {
      final wallet =
          WalletService(initial: Wallet.create(balance: 500, savings: 100));
      final outcome = buy(wallet, 120) as WalletNotEnough;
      expect(outcome.gap, 20);
      expect(wallet.wallet, Wallet.create(balance: 500, savings: 100));
      expect(wallet.journal, isEmpty);
    });

    test('баланс и копилка по-прежнему сходятся с журналом', () {
      final wallet = WalletService()
        ..earn(
            amount: 200,
            sourceId: 'day_income',
            reasonText: 'Монеты на день',
            at: _at,
            dayNumber: 3)
        ..toSavings(amount: 150, at: _at, dayNumber: 3);
      buy(wallet, 120);
      var balance = 0;
      var savings = 0;
      for (final t in wallet.journal) {
        switch (t.type) {
          case TransactionType.income:
            balance += t.amount;
          case TransactionType.expense:
            balance -= t.amount;
          case TransactionType.toSavings:
            balance -= t.amount;
            savings += t.amount;
          case TransactionType.fromSavings:
            balance += t.amount;
            savings -= t.amount;
        }
      }
      expect(wallet.wallet, Wallet.create(balance: balance, savings: savings));
      expect(wallet.wallet, Wallet.create(balance: 50, savings: 30));
    });
  });

  group('журнал', () {
    test('только для чтения снаружи', () {
      final s = WalletService();
      s.earn(
          amount: 5,
          sourceId: 'login',
          reasonText: 'Бонус за вход',
          at: _at,
          dayNumber: 1);
      expect(
          () => s.journal.add(s.journal.first), throwsUnsupportedError);
    });

    test('записи с объяснением, фильтр по дням', () {
      final s = WalletService(initial: Wallet.create(balance: 50, savings: 0));
      s.earn(
          amount: 5, sourceId: 'login', reasonText: 'Бонус', at: _at, dayNumber: 1);
      s.spend(
          amount: 15,
          itemId: 'food',
          category: ExpenseCategory.mandatory,
          reasonText: 'Еда',
          at: _at,
          dayNumber: 2);
      s.toSavings(amount: 10, at: _at, dayNumber: 2);
      expect(s.journal.length, 3);
      expect(s.journal.every((t) => t.reasonText.trim().isNotEmpty), isTrue);
      expect(s.journalOfDay(2).length, 2);
      expect(s.journalOfDay(1).single.sourceId, 'login');
    });
  });
}
