import '../datasources/budget_laravel_remote_data_source.dart';
import '../models/budget_model.dart';

class LaravelBudgetRepository {
  final BudgetLaravelRemoteDataSource _remoteDataSource;

  LaravelBudgetRepository(this._remoteDataSource);

  Future<List<BudgetModel>> getBudgets({String? monthYear}) {
    return _remoteDataSource.getBudgets(monthYear: monthYear);
  }

  Future<void> setBudget({
    required String category,
    required double amount,
    String? currency,
    String? monthYear,
  }) {
    return _remoteDataSource.setBudget(
      category: category,
      amount: amount,
      currency: currency,
      monthYear: monthYear,
    );
  }

  Future<void> deleteBudget(String id) {
    return _remoteDataSource.deleteBudget(id);
  }
}
