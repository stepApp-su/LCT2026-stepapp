/// Операция с монетами. reasonText обязателен — показывается ребёнку.
library;

enum TransactionType { income, expense, toSavings, fromSavings }

enum ExpenseCategory { mandatory, optional }

final class Transaction {
  const Transaction._({
    required this.id,
    required this.type,
    required this.amount,
    required this.sourceId,
    required this.category,
    required this.reasonText,
    required this.at,
    required this.dayNumber,
  });

  factory Transaction.create({
    required String id,
    required TransactionType type,
    required int amount,
    required String sourceId,
    ExpenseCategory? category,
    required String reasonText,
    required DateTime at,
    required int dayNumber,
  }) {
    if (reasonText.trim().isEmpty) {
      throw ArgumentError.value(
          reasonText, 'reasonText', 'нужно объяснение для ребёнка');
    }
    if (amount <= 0) {
      throw ArgumentError.value(amount, 'amount', 'Сумма — целое число > 0');
    }
    if (dayNumber < 1) {
      throw ArgumentError.value(dayNumber, 'dayNumber', 'Дни нумеруются с 1');
    }
    return Transaction._(
      id: id,
      type: type,
      amount: amount,
      sourceId: sourceId,
      category: category,
      reasonText: reasonText.trim(),
      at: at,
      dayNumber: dayNumber,
    );
  }

  final String id;
  final TransactionType type;

  /// Целое > 0; направление задаёт [type].
  final int amount;

  /// Источник: task:need_or_want, shop:food, event:rain...
  final String sourceId;
  final ExpenseCategory? category;
  final String reasonText;
  final DateTime at;
  final int dayNumber;

  Map<String, Object?> toJson() => {
        'id': id,
        'type': type.name,
        'amount': amount,
        'sourceId': sourceId,
        'category': category?.name,
        'reasonText': reasonText,
        'at': at.toIso8601String(),
        'dayNumber': dayNumber,
      };

  factory Transaction.fromJson(Map<String, Object?> json) {
    return Transaction.create(
      id: json['id'] as String,
      type: TransactionType.values.byName(json['type'] as String),
      amount: json['amount'] as int,
      sourceId: json['sourceId'] as String,
      category: json['category'] == null
          ? null
          : ExpenseCategory.values.byName(json['category'] as String),
      reasonText: json['reasonText'] as String,
      at: DateTime.parse(json['at'] as String),
      dayNumber: json['dayNumber'] as int,
    );
  }

  @override
  bool operator ==(Object other) =>
      other is Transaction &&
      other.id == id &&
      other.type == type &&
      other.amount == amount &&
      other.sourceId == sourceId &&
      other.category == category &&
      other.reasonText == reasonText &&
      other.at == at &&
      other.dayNumber == dayNumber;

  @override
  int get hashCode =>
      Object.hash(id, type, amount, sourceId, category, reasonText, at, dayNumber);
}
