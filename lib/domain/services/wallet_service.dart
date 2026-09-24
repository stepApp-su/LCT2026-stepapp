/// Все операции с монетами и журнал. Минуса и долгов не бывает;
/// при нехватке возвращаем, сколько не хватает и что можно сделать.
library;

import '../models/models.dart';

sealed class WalletOutcome {
  const WalletOutcome();
}

final class WalletOk extends WalletOutcome {
  const WalletOk({required this.wallet, required this.transaction});

  final Wallet wallet;
  final Transaction transaction;
}

/// Не хватило: ничего не списано, журнал не тронут.
final class WalletNotEnough extends WalletOutcome {
  const WalletNotEnough({required this.gap, required this.options});

  final int gap;
  final List<NotEnoughOption> options;
}

/// Вариант при нехватке: текст + куда ведём.
final class NotEnoughOption {
  const NotEnoughOption({required this.textRu, required this.route});

  final String textRu;

  /// tasks / postpone / shop:<itemId>
  final String route;

  @override
  bool operator ==(Object other) =>
      other is NotEnoughOption && other.textRu == textRu && other.route == route;

  @override
  int get hashCode => Object.hash(textRu, route);
}

final class WalletService {
  WalletService({Wallet? initial, Iterable<Transaction> journal = const []})
      : _wallet = initial ?? Wallet.empty(),
        _journal = List.of(journal);

  Wallet _wallet;
  final List<Transaction> _journal;
  int _txCounter = 0;

  Wallet get wallet => _wallet;

  /// Журнал только дописывается; наружу — только чтение.
  List<Transaction> get journal => List.unmodifiable(_journal);

  List<Transaction> journalOfDay(int dayNumber) => List.unmodifiable(
      _journal.where((t) => t.dayNumber == dayNumber));

  String _nextId(int dayNumber) {
    String id;
    do {
      id = 'd$dayNumber-${++_txCounter}';
    } while (_journal.any((entry) => entry.id == id));
    return id;
  }

  WalletOk earn({
    required int amount,
    required String sourceId,
    required String reasonText,
    required DateTime at,
    required int dayNumber,
  }) {
    final tx = Transaction.create(
      id: _nextId(dayNumber),
      type: TransactionType.income,
      amount: amount,
      sourceId: sourceId,
      reasonText: reasonText,
      at: at,
      dayNumber: dayNumber,
    );
    _wallet = Wallet.create(
        balance: _wallet.balance + amount, savings: _wallet.savings);
    _journal.add(tx);
    return WalletOk(wallet: _wallet, transaction: tx);
  }

  /// При нехватке ничего не списывает: вернёт gap и варианты
  /// (задание / отложить / дешевле той же категории).
  WalletOutcome spend({
    required int amount,
    required String itemId,
    required ExpenseCategory category,
    required String reasonText,
    required DateTime at,
    required int dayNumber,
    bool hasUnusedTasksToday = false,
    List<ShopItem> catalog = const [],
  }) {
    if (amount > _wallet.balance) {
      final gap = amount - _wallet.balance;
      final options = <NotEnoughOption>[
        if (hasUnusedTasksToday)
          const NotEnoughOption(
              textRu: 'Заработать: выполнить задание', route: 'tasks'),
        const NotEnoughOption(
            textRu: 'Отложить покупку до следующего дня', route: 'postpone'),
      ];
      final cheaper = _cheaperAlternative(catalog, itemId, category);
      if (cheaper != null) {
        options.add(NotEnoughOption(
            textRu: 'Выбрать подешевле: «${cheaper.title}» за ${cheaper.price}',
            route: 'shop:${cheaper.id}'));
      }
      return WalletNotEnough(gap: gap, options: options);
    }
    final tx = Transaction.create(
      id: _nextId(dayNumber),
      type: TransactionType.expense,
      amount: amount,
      sourceId: 'shop:$itemId',
      category: category,
      reasonText: reasonText,
      at: at,
      dayNumber: dayNumber,
    );
    _wallet = Wallet.create(
        balance: _wallet.balance - amount, savings: _wallet.savings);
    _journal.add(tx);
    return WalletOk(wallet: _wallet, transaction: tx);
  }

  ShopItem? _cheaperAlternative(
      List<ShopItem> catalog, String itemId, ExpenseCategory category) {
    ShopItem? best;
    for (final item in catalog) {
      if (item.id == itemId) continue;
      if (item.category != category) continue;
      if (item.price > _wallet.balance) continue;
      if (best == null || item.price > best.price) best = item;
    }
    return best;
  }

  WalletOutcome toSavings({
    required int amount,
    required DateTime at,
    required int dayNumber,
    String reasonText = 'Отложил в копилку — мечта ближе',
  }) {
    if (amount > _wallet.balance) {
      return WalletNotEnough(
        gap: amount - _wallet.balance,
        options: const [
          NotEnoughOption(
              textRu: 'Отложить столько, сколько есть', route: 'savings'),
        ],
      );
    }
    final tx = Transaction.create(
      id: _nextId(dayNumber),
      type: TransactionType.toSavings,
      amount: amount,
      sourceId: 'savings',
      reasonText: reasonText,
      at: at,
      dayNumber: dayNumber,
    );
    _wallet = Wallet.create(
        balance: _wallet.balance - amount, savings: _wallet.savings + amount);
    _journal.add(tx);
    return WalletOk(wallet: _wallet, transaction: tx);
  }

  WalletOutcome fromSavings({
    required int amount,
    required DateTime at,
    required int dayNumber,
    String reasonText = 'Взял монетки из копилки',
    String sourceId = 'savings',
  }) {
    if (amount > _wallet.savings) {
      return WalletNotEnough(
        gap: amount - _wallet.savings,
        options: const [
          NotEnoughOption(
              textRu: 'Взять столько, сколько накоплено', route: 'savings'),
        ],
      );
    }
    final tx = Transaction.create(
      id: _nextId(dayNumber),
      type: TransactionType.fromSavings,
      amount: amount,
      sourceId: sourceId,
      reasonText: reasonText,
      at: at,
      dayNumber: dayNumber,
    );
    _wallet = Wallet.create(
        balance: _wallet.balance + amount, savings: _wallet.savings - amount);
    _journal.add(tx);
    return WalletOk(wallet: _wallet, transaction: tx);
  }
}
