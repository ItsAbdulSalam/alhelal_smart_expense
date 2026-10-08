import '../../core/services/api_client.dart';
import '../models/budget_model.dart';

class BudgetLaravelRemoteDataSource {
  BudgetLaravelRemoteDataSource();

  /// جلب قائمة الميزانيات لشهر محدد (صيغة YYYY-MM)
  Future<List<BudgetModel>> getBudgets({String? monthYear}) async {
    final response = await ApiClient.dio.get(
      '/budgets',
      queryParameters: monthYear != null ? {'month_year': monthYear} : null,
    );

    final List data = response.data['data'] ?? [];
    return data.map((json) => BudgetModel.fromJson(json)).toList();
  }

  /// إنشاء أو تحديث ميزانية لفئة معينة
  Future<void> setBudget({
    required String category,
    required double amount,
    String? currency,
    String? monthYear,
  }) async {
    await ApiClient.dio.post(
      '/budgets',
      data: {
        'category': category,
        'amount': amount,
        'currency': ?currency,
        'month_year': ?monthYear,
      },
    );
  }

  /// حذف ميزانية
  Future<void> deleteBudget(String budgetId) async {
    await ApiClient.dio.delete('/budgets/$budgetId');
  }
}
