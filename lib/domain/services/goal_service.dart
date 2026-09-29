/// Цели и копилка. Срок достижения считается по средней сумме регулярного
/// пополнения и ОБЪЯСНЯЕТСЯ словами: ребёнок должен понимать, откуда
/// взялась цифра. Смена цели ничего не обнуляет, снятие из копилки —
/// только после отдельного подтверждения и с предпросмотром последствий.
library;

import '../models/models.dart';
import '../ru_words.dart';
import '../text_template.dart';
import 'wallet_service.dart';

/// Срок достижения цели. [days] == null — посчитать не из чего,
/// но текст есть всегда: ни бесконечности, ни минуса, ни «N/A».
final class GoalEta {
  const GoalEta({
    required this.days,
    required this.averageDeposit,
    required this.textRu,
  });

  final int? days;

  /// Среднее пополнение, на котором построен расчёт.
  final int? averageDeposit;

  /// Объяснение расчёта словами, а не просто число.
  final String textRu;
}

/// Всё, что показывает экран цели.
final class GoalView {
  const GoalView({
    required this.goal,
    required this.saved,
    required this.left,
    required this.percent,
    required this.progressText,
    required this.leftText,
    required this.eta,
    required this.isReached,
    required this.reachedButton,
  });

  final Goal goal;
  final int saved;
  final int left;

  /// 0..100 — для прогресс-бара и вех.
  final int percent;

  final String progressText;
  final String leftText;
  final GoalEta eta;
  final bool isReached;
  final String reachedButton;

  int get price => goal.price;
}

sealed class GoalOutcome {
  const GoalOutcome();
}

/// Действие не выполнено, состояние не изменилось.
final class GoalRefused extends GoalOutcome {
  const GoalRefused(this.textRu);

  final String textRu;
}

/// Окно смены цели. Создаётся только сервисом: подтвердить то,
/// чего ребёнку не показали, невозможно.
final class GoalSelectConfirm extends GoalOutcome {
  const GoalSelectConfirm._({
    required this.goal,
    required this.savedNow,
    required this.question,
    required this.keepSavingsText,
    required this.confirmLabel,
    required this.cancelLabel,
  });

  final Goal goal;

  /// Сколько сейчас в копилке — столько и останется.
  final int savedNow;

  final String question;

  /// «Все 75 монет останутся в копилке.»
  final String keepSavingsText;

  final String confirmLabel;
  final String cancelLabel;
}

final class GoalSelected extends GoalOutcome {
  const GoalSelected({
    required this.goal,
    required this.savedCarriedOver,
    required this.selectPhrase,
    required this.view,
  });

  final Goal goal;

  /// Накопленное переносится полностью.
  final int savedCarriedOver;

  final String selectPhrase;
  final GoalView view;
}

final class GoalDepositDone extends GoalOutcome {
  const GoalDepositDone({
    required this.wallet,
    required this.transaction,
    required this.view,
    required this.milestoneText,
    required this.justReached,
  });

  final Wallet wallet;
  final Transaction transaction;
  final GoalView? view;

  /// Микропраздник на 25/50/75%, если веха взята именно сейчас.
  final String? milestoneText;

  final bool justReached;
}

final class GoalDepositNotEnough extends GoalOutcome {
  const GoalDepositNotEnough({required this.gap, required this.options});

  final int gap;
  final List<NotEnoughOption> options;
}

/// Предпросмотр снятия. Ничего не меняет — ни копилку, ни журнал, ни цель.
/// Снять можно только по свежему предпросмотру: [savedBefore] сверяется
/// с копилкой в момент подтверждения.
final class WithdrawPreview extends GoalOutcome {
  const WithdrawPreview._({
    required this.amount,
    required this.goalId,
    required this.price,
    required this.savedBefore,
    required this.savedAfter,
    required this.etaBefore,
    required this.etaAfter,
    required this.question,
    required this.savedChangeText,
    required this.etaChangeText,
    required this.confirmLabel,
    required this.cancelLabel,
  });

  final int amount;
  final String goalId;
  final int price;
  final int savedBefore;
  final int savedAfter;
  final GoalEta etaBefore;
  final GoalEta etaAfter;

  final String question;

  /// «Было 75 из 120 → станет 55 из 120».
  final String savedChangeText;

  /// «До цели: было 3 дня → станет 5 дней».
  final String etaChangeText;

  /// Вариант «Да» всегда доступен и не спрятан: задача приложения —
  /// показать последствие, а не отговорить.
  final String confirmLabel;
  final String cancelLabel;
}

final class WithdrawDone extends GoalOutcome {
  const WithdrawDone({
    required this.wallet,
    required this.transaction,
    required this.view,
  });

  final Wallet wallet;
  final Transaction transaction;
  final GoalView? view;
}

final class GoalClaimed extends GoalOutcome {
  const GoalClaimed({
    required this.goal,
    required this.wallet,
    required this.transaction,
    required this.effects,
    required this.reachedText,
    required this.unlockedText,
  });

  final Goal goal;
  final Wallet wallet;
  final Transaction transaction;

  /// Достигнутая цель добавляет уюта навсегда.
  final List<StateEffect> effects;

  final String reachedText;

  /// «Появились новые большие цели!» — если открылись.
  final String? unlockedText;
}

final class GoalService {
  GoalService({
    required GoalCatalog catalog,
    required WalletService wallet,
    String? selectedGoalId,
    Iterable<String> reachedGoalIds = const [],
    int dayNumber = 1,
  })  : _catalog = catalog,
        _wallet = wallet,
        _day = dayNumber,
        _reached = {...reachedGoalIds} {
    if (selectedGoalId != null && catalog.byId(selectedGoalId) == null) {
      throw ArgumentError.value(
          selectedGoalId, 'selectedGoalId', 'такой цели нет в каталоге');
    }
    _selectedGoalId = selectedGoalId;
  }

  final GoalCatalog _catalog;
  final WalletService _wallet;
  final Set<String> _reached;

  int _day;
  String? _selectedGoalId;

  bool openAll = false;

  GoalCatalog get catalog => _catalog;
  GoalTexts get texts => _catalog.texts;
  int get dayNumber => _day;

  /// Копилка одна на всё приложение и живёт в кошельке — поэтому смена
  /// цели физически не может обнулить накопленное.
  int get saved => _wallet.wallet.savings;

  /// Достигнутые цели не теряются никогда.
  Set<String> get reachedGoalIds => Set.unmodifiable(_reached);

  int get goalsReached => _reached.length;

  String get starterHint => texts.starterHint;

  /// Что советуем новичку: маленькую цель достичь легче.
  Goal? get recommended {
    final goal = _catalog.recommended;
    if (goal == null || _reached.contains(goal.id)) return null;
    return goal;
  }

  /// Текущая цель с подставленной суммой копилки: left и isReached
  /// считаются от настоящих накоплений.
  Goal? get current {
    final id = _selectedGoalId;
    if (id == null) return null;
    return _catalog.byId(id)?.copyWith(saved: saved);
  }

  /// Цели, которые можно выбрать: ещё не достигнутые и уже открытые.
  /// Маленькие впереди.
  List<Goal> available() {
    final list = [
      for (final goal in _catalog.goals)
        if (!_reached.contains(goal.id) && isUnlocked(goal))
          goal.copyWith(saved: saved)
    ];
    list.sort((a, b) => a.price.compareTo(b.price));
    return List.unmodifiable(list);
  }

  bool isUnlocked(Goal goal) =>
      openAll || _reached.length >= goal.minGoalsReached;

  void startDay(int dayNumber) => _day = dayNumber;

  // --- срок достижения -----------------------------------------------------

  /// Среднее пополнение за последние N завершённых дней, в которых
  /// пополнение было. Меньше N дней — берём имеющиеся.
  /// null — пополнений не было вообще.
  int? averageDeposit() {
    final byDay = <int, int>{};
    for (final tx in _wallet.journal) {
      if (tx.type != TransactionType.toSavings) continue;
      byDay.update(tx.dayNumber, (sum) => sum + tx.amount,
          ifAbsent: () => tx.amount);
    }
    if (byDay.isEmpty) return null;

    final completed = byDay.keys.where((day) => day < _day).toList()..sort();
    // Если завершённых дней с пополнением ещё нет, считаем по сегодняшним:
    // иначе ребёнок только что отложил, а в ответ — «начни откладывать».
    final days = completed.isNotEmpty ? completed : (byDay.keys.toList()..sort());

    final window = _catalog.settings.averageWindowDays;
    final take =
        days.length <= window ? days : days.sublist(days.length - window);
    var sum = 0;
    for (final day in take) {
      sum += byDay[day]!;
    }

    final step = _catalog.settings.roundAverageTo;
    final rounded = (sum / take.length / step).round() * step;
    // Нижняя граница — шаг округления: делить на ноль не на чем.
    return rounded < step ? step : rounded;
  }

  /// Срок достижения цели. [savedOverride] — «что было бы, если»:
  /// используется предпросмотром снятия и ничего не меняет.
  GoalEta eta({int? savedOverride}) {
    final goal = current;
    if (goal == null) {
      return GoalEta(
          days: null, averageDeposit: averageDeposit(), textRu: texts.noGoalSelected);
    }
    final have = savedOverride ?? saved;
    final left = goal.price - have;
    final average = averageDeposit();
    if (left <= 0) {
      return GoalEta(
          days: 0, averageDeposit: average, textRu: texts.eta.reached);
    }
    if (average == null) {
      return GoalEta(
          days: null, averageDeposit: null, textRu: texts.eta.noDeposits);
    }
    // Целочисленный ceil: делений в double и сюрпризов округления нет.
    final days = (left + average - 1) ~/ average;
    final text = days == 1
        ? texts.eta.lastStep
        : fillTemplate(texts.eta.estimate, {
            'avg': '$average',
            'coin': ruCoins(average),
            'left': '$left',
            'days': '$days',
            'day': ruDays(days),
            'title': goal.title,
            'titleGenitive': goal.titleGenitive,
          });
    return GoalEta(days: days, averageDeposit: average, textRu: text);
  }

  GoalView? view() {
    final goal = current;
    if (goal == null) return null;
    final have = saved;
    final left = goal.left;
    return GoalView(
      goal: goal,
      saved: have,
      left: left,
      percent: (have * 100 ~/ goal.price).clamp(0, 100),
      progressText: fillTemplate(
          texts.progress, {'saved': '$have', 'price': '${goal.price}'}),
      leftText:
          fillTemplate(texts.left, {'left': '$left', 'coin': ruCoins(left)}),
      eta: eta(),
      isReached: goal.isReached,
      reachedButton: texts.reachedButton,
    );
  }

  // --- выбор и смена цели --------------------------------------------------

  /// Шаг 1: окно «выбрать новую цель?». Копилки не касается.
  GoalOutcome askToSelect(String goalId) {
    final goal = _catalog.byId(goalId);
    if (goal == null) return GoalRefused(texts.unknownGoal);
    if (_reached.contains(goal.id)) {
      return GoalRefused(texts.goalAlreadyReached);
    }
    if (!isUnlocked(goal)) return GoalRefused(texts.goalLocked);
    if (goal.id == _selectedGoalId) return GoalRefused(texts.sameGoal);

    final have = saved;
    return GoalSelectConfirm._(
      goal: goal.copyWith(saved: have),
      savedNow: have,
      question: fillTemplate(texts.changeGoal.question, {
        'title': goal.title,
        'titleAccusative': goal.titleAccusative,
        'price': '${goal.price}',
      }),
      keepSavingsText: fillTemplate(texts.changeGoal.keepSavings,
          {'saved': '$have', 'coin': ruCoins(have)}),
      confirmLabel: texts.changeGoal.confirm,
      cancelLabel: texts.changeGoal.cancel,
    );
  }

  /// Шаг 2: цель меняется, накопленное переносится полностью.
  GoalOutcome confirmSelect(GoalSelectConfirm confirmation) {
    final goal = _catalog.byId(confirmation.goal.id);
    if (goal == null) return GoalRefused(texts.unknownGoal);
    if (_reached.contains(goal.id)) {
      return GoalRefused(texts.goalAlreadyReached);
    }
    if (!isUnlocked(goal)) return GoalRefused(texts.goalLocked);

    _selectedGoalId = goal.id;
    return GoalSelected(
      goal: goal.copyWith(saved: saved),
      savedCarriedOver: saved,
      selectPhrase: goal.selectPhrase,
      view: view()!,
    );
  }

  // --- копилка -------------------------------------------------------------

  /// Регулярное пополнение копилки.
  GoalOutcome deposit({required int amount, required DateTime at}) {
    if (amount <= 0) {
      throw ArgumentError.value(amount, 'amount', 'Пополнение — целое > 0');
    }
    final before = saved;
    final outcome = _wallet.toSavings(
      amount: amount,
      at: at,
      dayNumber: _day,
      reasonText: fillTemplate(
          texts.journal.toSavings, {'amount': '$amount', 'coin': ruCoins(amount)}),
    );
    switch (outcome) {
      case WalletNotEnough(:final gap, :final options):
        return GoalDepositNotEnough(gap: gap, options: options);
      case WalletOk(:final wallet, :final transaction):
        final after = saved;
        final goal = current;
        return GoalDepositDone(
          wallet: wallet,
          transaction: transaction,
          view: view(),
          milestoneText: _milestoneCrossed(before, after),
          justReached:
              goal != null && before < goal.price && after >= goal.price,
        );
    }
  }

  /// Веха, взятая именно этим пополнением. Долгая цель обязана иметь
  /// промежуточные праздники, иначе семилетний потеряет интерес.
  String? _milestoneCrossed(int before, int after) {
    final goal = current;
    if (goal == null) return null;
    String? text;
    for (final percent in _catalog.milestones) {
      final threshold = (goal.price * percent + 99) ~/ 100;
      if (before < threshold && after >= threshold) {
        text = texts.milestoneText(percent) ?? text;
      }
    }
    return text;
  }

  /// Предпросмотр снятия: сколько станет в копилке и как изменится срок.
  /// Метод ЧИСТЫЙ — ни копилка, ни журнал, ни цель не меняются.
  GoalOutcome previewWithdraw(int amount) {
    if (amount <= 0) {
      throw ArgumentError.value(amount, 'amount', 'Снятие — целое > 0');
    }
    final goal = current;
    if (goal == null) return GoalRefused(texts.noGoalSelected);
    if (amount > saved) return GoalRefused(texts.notEnoughSavings);

    final before = saved;
    final after = before - amount;
    final etaBefore = eta();
    final etaAfter = eta(savedOverride: after);

    final daysBefore = etaBefore.days;
    final daysAfter = etaAfter.days;
    final etaChangeText = (daysBefore == null || daysAfter == null)
        ? texts.withdraw.etaUnknown
        : fillTemplate(texts.withdraw.etaChange, {
            'daysBefore': '$daysBefore',
            'dayBefore': ruDays(daysBefore),
            'daysAfter': '$daysAfter',
            'dayAfter': ruDays(daysAfter),
          });

    return WithdrawPreview._(
      amount: amount,
      goalId: goal.id,
      price: goal.price,
      savedBefore: before,
      savedAfter: after,
      etaBefore: etaBefore,
      etaAfter: etaAfter,
      question: fillTemplate(texts.withdraw.question,
          {'amount': '$amount', 'coin': ruCoins(amount)}),
      savedChangeText: fillTemplate(texts.withdraw.savedChange, {
        'before': '$before',
        'after': '$after',
        'price': '${goal.price}',
      }),
      etaChangeText: etaChangeText,
      confirmLabel: texts.withdraw.confirm,
      cancelLabel: texts.withdraw.cancel,
    );
  }

  /// Снятие — только по свежему предпросмотру. Устаревший (копилка или
  /// цель успели измениться) не срабатывает: ребёнку показали другие числа.
  GoalOutcome withdraw(WithdrawPreview preview, {required DateTime at}) {
    if (preview.goalId != _selectedGoalId || preview.savedBefore != saved) {
      return GoalRefused(texts.needsConfirmation);
    }
    final outcome = _wallet.fromSavings(
      amount: preview.amount,
      at: at,
      dayNumber: _day,
      reasonText: fillTemplate(texts.journal.fromSavings, {
        'amount': '${preview.amount}',
        'coin': ruCoins(preview.amount),
      }),
    );
    switch (outcome) {
      case WalletNotEnough():
        return GoalRefused(texts.notEnoughSavings);
      case WalletOk(:final wallet, :final transaction):
        return WithdrawDone(
            wallet: wallet, transaction: transaction, view: view());
    }
  }

  /// Цель достигнута: копилка тратится на неё, цель уходит в достигнутые
  /// навсегда, уют растёт.
  GoalOutcome claim({required DateTime at}) {
    final goal = current;
    if (goal == null) return GoalRefused(texts.noGoalSelected);
    if (saved < goal.price) return GoalRefused(texts.notEnoughSavings);

    final before = {for (final g in available()) g.id};
    final outcome = _wallet.spendSavings(
      amount: goal.price,
      at: at,
      dayNumber: _day,
      sourceId: 'goal:${goal.id}',
      withdrawReason: fillTemplate(texts.journal.fromSavings, {
        'amount': '${goal.price}',
        'coin': ruCoins(goal.price),
      }),
      spendReason: fillTemplate(texts.journal.goalReached, {
        'title': goal.title,
        'titleAccusative': goal.titleAccusative,
        'price': '${goal.price}',
      }),
    );
    switch (outcome) {
      case WalletNotEnough():
        return GoalRefused(texts.notEnoughSavings);
      case WalletOk(:final wallet, :final transaction):
        _reached.add(goal.id);
        _selectedGoalId = null;
        final unlocked =
            available().any((g) => !before.contains(g.id));
        return GoalClaimed(
          goal: goal,
          wallet: wallet,
          transaction: transaction,
          effects: goal.rewardEffects,
          reachedText: goal.reachedText,
          unlockedText: unlocked ? texts.newGoalsUnlocked : null,
        );
    }
  }
}
