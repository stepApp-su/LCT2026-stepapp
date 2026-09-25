import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:finni/domain/models/models.dart';
import 'package:finni/domain/services/day_summary_service.dart';
import 'package:finni/domain/stop_words.dart';

final _at = DateTime(2026, 9, 24, 12);

Map<String, String> _loadTemplates() {
  final raw = jsonDecode(File('assets/content/summaries.json').readAsStringSync());
  return SummaryTexts.fromJson((raw as Map).cast<String, Object?>()).explain;
}

Transaction _tx(TransactionType type, int amount,
        {ExpenseCategory? cat, int day = 3, String source = 'test'}) =>
    Transaction.create(
      id: 'x$amount${type.name}$source$day',
      type: type,
      amount: amount,
      sourceId: source,
      category: cat,
      reasonText: 'тестовая запись',
      at: _at,
      dayNumber: day,
    );

GameDay _day(List<Transaction> txs,
        {int m = 25, int o = 5, int sv = 10, int income = 40}) =>
    GameDay.create(
      number: 3,
      income: income,
      plan: BudgetPlan.create(
          mandatory: m, optional: o, savings: sv, income: income),
      transactions: txs,
    );

void main() {
  final service = DaySummaryService(templates: _loadTemplates());
  final stateBefore = PetState.create(satiety: 60, care: 70, mood: 80, cozy: 5);
  final stateAfter = PetState.create(satiety: 90, care: 70, mood: 85, cozy: 5);

  DayResult build(List<Transaction> txs,
          {int m = 25, int o = 5, int sv = 10}) =>
      service.build(
        day: _day(txs, m: m, o: o, sv: sv),
        before: stateBefore,
        after: stateAfter,
        growthPoints: 5,
        petName: 'Мони',
        savedTotal: 40,
      );

  group('разницы', () {
    test('факт собирается из журнала, разницы по трём направлениям', () {
      final r = build([
        _tx(TransactionType.income, 40),
        _tx(TransactionType.expense, 25, cat: ExpenseCategory.mandatory),
        _tx(TransactionType.expense, 13, cat: ExpenseCategory.optional),
        _tx(TransactionType.toSavings, 2),
      ]);
      expect(r.summary.actualMandatory, 25);
      expect(r.summary.actualOptional, 13);
      expect(r.summary.actualSavings, 2);
      expect(r.diffMandatory, 0);
      expect(r.diffOptional, 8);
      expect(r.diffSavings, -8);
      expect(r.purchases.length, 2);
    });

    test('снятие из копилки уменьшает фактические накопления', () {
      final r = build([
        _tx(TransactionType.toSavings, 10),
        _tx(TransactionType.fromSavings, 4),
      ]);
      expect(r.summary.actualSavings, 6);
    });

    test('изменения питомца попадают в результат', () {
      final r = build([_tx(TransactionType.income, 5)]);
      expect(r.stateChanges[PetStat.satiety], 30);
      expect(r.stateChanges[PetStat.mood], 5);
      expect(r.stateChanges.containsKey(PetStat.care), isFalse);
    });

    test('операции мечты не считаются ни тратой, ни копилкой', () {
      final r = build([
        _tx(TransactionType.toSavings, 10),
        _tx(TransactionType.fromSavings, 90, source: 'goal:ball_rope'),
        _tx(TransactionType.expense, 90,
            cat: ExpenseCategory.optional, source: 'goal:ball_rope'),
      ]);
      expect(r.summary.actualOptional, 0);
      expect(r.summary.actualSavings, 10);
      expect(r.purchases, isEmpty);
    });

    test('операции чужого дня отбрасываются', () {
      final r = build([
        _tx(TransactionType.expense, 25, cat: ExpenseCategory.mandatory),
        _tx(TransactionType.expense, 40, cat: ExpenseCategory.mandatory, day: 2),
        _tx(TransactionType.income, 40, day: 2),
      ]);
      expect(r.summary.actualMandatory, 25);
      expect(r.purchases.length, 1);
    });

    test('факт совпадает с подсчётом роста', () {
      final txs = [
        _tx(TransactionType.income, 40),
        _tx(TransactionType.expense, 20, cat: ExpenseCategory.mandatory),
        _tx(TransactionType.expense, 7, cat: ExpenseCategory.optional),
        _tx(TransactionType.toSavings, 12),
        _tx(TransactionType.fromSavings, 4),
        _tx(TransactionType.fromSavings, 90, source: 'goal:scooter'),
      ];
      final facts = DayFacts.fromDay(_day(txs), mandatoryItemIds: const []);
      final r = build(txs);
      expect(r.summary.actualMandatory, facts.spentMandatory);
      expect(r.summary.actualOptional, facts.spentOptional);
      expect(r.summary.actualSavings, facts.deposited);
    });
  });

  group('объяснение', () {
    test('перебор желаемого: причина и следствие с числом', () {
      final r = build([
        _tx(TransactionType.expense, 25, cat: ExpenseCategory.mandatory),
        _tx(TransactionType.expense, 15, cat: ExpenseCategory.optional),
      ]);
      expect(r.explainText, contains('на 10 монеток больше'));
      expect(r.explainText.toLowerCase(), contains('копилку'));
      expect(r.explainText.toLowerCase(), contains('следующий раз'));
    });

    test('не хватило на нужное: без осуждения, с шагом на завтра', () {
      final r = build([
        _tx(TransactionType.expense, 10, cat: ExpenseCategory.mandatory),
      ]);
      expect(r.explainText, contains('15 монеток'));
      expect(r.explainText, contains('Мони'));
      expect(r.explainText.toLowerCase(), contains('завтра'));
    });

    test('план исполнен: конкретная похвала', () {
      final r = build([
        _tx(TransactionType.expense, 25, cat: ExpenseCategory.mandatory),
        _tx(TransactionType.expense, 5, cat: ExpenseCategory.optional),
        _tx(TransactionType.toSavings, 10),
      ]);
      expect(r.explainText, contains('ровно столько'));
    });

    test('отложил больше плана: мечта ближе', () {
      final r = build([
        _tx(TransactionType.expense, 25, cat: ExpenseCategory.mandatory),
        _tx(TransactionType.toSavings, 15),
      ]);
      expect(r.explainText, contains('на 5 монеток больше'));
    });

    test('пустой день тоже объясняется', () {
      final r = build([]);
      expect(r.explainText.trim(), isNotEmpty);
      expect(r.explainText.toLowerCase(), contains('завтра'));
    });

    test('объяснение есть при любом раскладе', () {
      final cases = [
        <Transaction>[],
        [_tx(TransactionType.income, 40)],
        [_tx(TransactionType.expense, 3, cat: ExpenseCategory.optional)],
        [_tx(TransactionType.fromSavings, 5)],
      ];
      for (final txs in cases) {
        expect(build(txs).explainText.trim(), isNotEmpty);
      }
    });
  });

  group('стоп-лист', () {
    test('в шаблонах summaries.json нет запрещённых формулировок', () {
      for (final e in _loadTemplates().entries) {
        expect(findStopWords(e.value), isEmpty, reason: 'шаблон ${e.key}');
      }
    });

    test('в собранных текстах всех сценариев нет запрещённых формулировок',
        () {
      final scenarios = [
        build([]),
        build([
          _tx(TransactionType.expense, 25, cat: ExpenseCategory.mandatory),
          _tx(TransactionType.expense, 15, cat: ExpenseCategory.optional),
        ]),
        build([_tx(TransactionType.expense, 10, cat: ExpenseCategory.mandatory)]),
        build([
          _tx(TransactionType.expense, 25, cat: ExpenseCategory.mandatory),
          _tx(TransactionType.expense, 5, cat: ExpenseCategory.optional),
          _tx(TransactionType.toSavings, 10),
        ]),
      ];
      for (final r in scenarios) {
        expect(findStopWords(r.explainText), isEmpty, reason: r.explainText);
      }
    });
  });
}
