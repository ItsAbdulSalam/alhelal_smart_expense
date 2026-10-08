import 'package:alhelal_smart_expense/core/services/api_client.dart';
import 'package:dio/dio.dart';

class ExpenseLaravelRemoteDataSource {
  final Dio dio;

  // إذا لم يُمرر عميل Dio، يعتمد افتراضياً على ApiClient.dio المهيأ مركزياً
  ExpenseLaravelRemoteDataSource({Dio? dio}) : dio = dio ?? ApiClient.dio;

  /// جلب قائمة المصاريف
  Future<List<Map<String, dynamic>>> getExpenses() async {
    final response = await dio.get('/expenses');

    // 🔍 طباعة الرد الخام القادم من سيرفر Laravel لمعاينة الحقول ومسار الصورة
    print("RAW EXPENSES FROM API: ${response.data}");

    final raw = response.data;
    if (raw == null) return [];

    // التعامل المرن مع كافة أشكال استجابات Laravel الممكنة:
    // 1) كائن مغلف: { data: { data: [...] } } أو { data: [...] }
    // 2) مصفوفة مباشرة: [ {...}, {...} ]
    dynamic responseData = raw;
    if (raw is Map && raw.containsKey('data')) {
      responseData = raw['data'];
    }

    if (responseData is Map && responseData.containsKey('data')) {
      final List list = responseData['data'];
      return list.map((e) => Map<String, dynamic>.from(e as Map)).toList();
    } else if (responseData is List) {
      return responseData
          .map((e) => Map<String, dynamic>.from(e as Map))
          .toList();
    }

    return [];
  }

  /// إنشاء مصروف جديد (يدعم FormData لرفع الصور أو Map عادي)
  Future<Map<String, dynamic>> createExpense(dynamic data) async {
    final response = await dio.post('/expenses', data: data);
    print("CREATE EXPENSE RESPONSE: ${response.data}");

    final raw = response.data;
    if (raw is Map && raw.containsKey('data')) {
      return Map<String, dynamic>.from(raw['data']);
    } else if (raw is Map) {
      return Map<String, dynamic>.from(raw);
    }
    return {};
  }

  /// حذف مصروف
  Future<void> deleteExpense(String expenseId) async {
    await dio.delete('/expenses/$expenseId');
  }
}
