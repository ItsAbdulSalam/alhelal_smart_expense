import 'package:flutter/foundation.dart';

import '../../core/services/local_expense_service.dart';
import '../datasources/expense_laravel_remote_data_source.dart';
import '../models/expense_model.dart';

class LaravelExpenseRepository {
  final ExpenseLaravelRemoteDataSource _remoteDataSource;

  LaravelExpenseRepository(this._remoteDataSource);

  /// جلب كافة المصاريف مع دعم التخزين المحلي
  Future<List<ExpenseModel>> getExpenses() async {
    try {
      // جلب البيانات من سيرفر Laravel
      final rawData = await _remoteDataSource.getExpenses();

      // تحديث الكاش المحلي
      await LocalExpenseService.cacheExpenses(rawData);

      return rawData.map((item) => ExpenseModel.fromJson(item)).toList();
    } catch (e) {
      debugPrint('⚠️ فشل جلب المصاريف من Laravel: $e');

      // العودة للكاش المحلي والعمليات غير المتزامنة في حال انقطاع السيرفر
      final cachedData = LocalExpenseService.getCachedExpenses();
      final offlineQueue = LocalExpenseService.getOfflineQueue();

      final combinedList = [
        ..._extractOfflineExpenses(offlineQueue),
        ...cachedData,
      ];

      if (combinedList.isNotEmpty) {
        debugPrint('🟢 تم استرجاع ${combinedList.length} مصروف محلياً');
        return combinedList.map((item) => ExpenseModel.fromJson(item)).toList();
      }

      throw Exception(
        'فشل الاتصال بسيرفر Laravel ولا توجد بيانات مخزنة محلياً: $e',
      );
    }
  }

  /// إضافة مصروف جديد
  Future<void> addExpense(ExpenseModel expense) async {
    final data = expense.toJson();

    // السيرفر هو من يولد الـ id و الـ timestamps ويربط المصروف بالمستخدم عبر الـ Bearer Token
    data.remove('id');
    data.remove('created_at');
    data.remove('updated_at');

    try {
      final createdData = await _remoteDataSource.createExpense(data);
      debugPrint('✅ تم حفظ المصروف في Laravel بنجاح: $createdData');
    } catch (e) {
      debugPrint('⚠️ فشل الحفظ على سيرفر Laravel: $e');

      // تخزين محلي عند فشل الاتصال للمزامنة لاحقاً
      await LocalExpenseService.queueOfflineAction(
        action: 'insert',
        payload: data,
      );
      debugPrint('🟡 تم حفظ المصروف في قائمة الانتظار (Offline Queue)');
    }
  }

  /// حذف مصروف
  Future<void> deleteExpense(String expenseId) async {
    if (expenseId.isEmpty) {
      throw Exception('معرف الفاتورة غير صالح');
    }

    try {
      await _remoteDataSource.deleteExpense(expenseId);
      debugPrint('✅ تم حذف المصروف من Laravel');
    } catch (e) {
      debugPrint('⚠️ فشل الحذف من سيرفر Laravel: $e');
      await LocalExpenseService.queueOfflineAction(
        action: 'delete',
        payload: {'id': expenseId},
      );
    }
  }

  /// استخراج عمليات Insert غير المتزامنة لعرضها محلياً
  List<Map<String, dynamic>> _extractOfflineExpenses(
    List<Map<String, dynamic>> queue,
  ) {
    final List<Map<String, dynamic>> result = [];
    for (final item in queue) {
      if (item['action'] == 'insert' && item['payload'] is Map) {
        result.add(Map<String, dynamic>.from(item['payload'] as Map));
      }
    }
    return result;
  }
}
