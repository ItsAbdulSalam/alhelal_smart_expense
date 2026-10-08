class BudgetModel {
  final String id;
  final String category;
  final double amount;
  final double spent;
  final double remaining;
  final double percentage;
  final String currency;
  final String monthYear;

  const BudgetModel({
    required this.id,
    required this.category,
    required this.amount,
    required this.spent,
    required this.remaining,
    required this.percentage,
    required this.currency,
    required this.monthYear,
  });

  factory BudgetModel.fromJson(Map<String, dynamic> json) {
    return BudgetModel(
      id: json['id']?.toString() ?? '',
      category: json['category'] ?? '',
      amount: (json['amount'] as num?)?.toDouble() ?? 0.0,
      spent: (json['spent'] as num?)?.toDouble() ?? 0.0,
      remaining: (json['remaining'] as num?)?.toDouble() ?? 0.0,
      percentage: (json['percentage'] as num?)?.toDouble() ?? 0.0,
      currency: json['currency'] ?? 'TRY',
      monthYear: json['month_year'] ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'category': category,
      'amount': amount,
      'currency': currency,
      'month_year': monthYear,
    };
  }
}