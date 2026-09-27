import 'package:hive/hive.dart';

class LocalExpenseService {
  static const String _expenseBoxName = 'expenses_box';
  static const String _queueBoxName = 'offline_expenses_queue';

  /// حفظ البيانات المخزنة مؤقتاً للقراءة أوفلاين
  static Future<void> cacheExpenses(List<Map<String, dynamic>> expenses) async {
    final box = Hive.box(_expenseBoxName);
    await box.put('cached_expenses', expenses);
  }

  /// استرجاع المصروفات المخزنة محلياً
  static List<Map<String, dynamic>> getCachedExpenses() {
    final box = Hive.box(_expenseBoxName);
    final data = box.get('cached_expenses');
    if (data != null) {
      return (data as List)
          .map((item) => Map<String, dynamic>.from(item))
          .toList();
    }
    return [];
  }

  /// تهيئة صندوق طابور الانتظار
  static Future<void> initQueueBox() async {
    if (!Hive.isBoxOpen(_queueBoxName)) {
      await Hive.openBox(_queueBoxName);
    }
  }

  /// إضافة عملية معلقة جديدة للطابور (إضافة أو حذف)
  static Future<void> queueOfflineAction({
    required String action, // 'insert' أو 'delete'
    required Map<String, dynamic> payload,
  }) async {
    final box = Hive.box(_queueBoxName);
    await box.add({
      'action': action,
      'payload': payload,
      'timestamp': DateTime.now().toIso8601String(),
    });
  }

  /// استرجاع طابور العمليات المعلقة
  static List<Map<String, dynamic>> getOfflineQueue() {
    final box = Hive.box(_queueBoxName);
    return box.values.map((item) => Map<String, dynamic>.from(item)).toList();
  }

  /// تفريغ طابور الانتظار بعد نجاح المزامنة
  static Future<void> clearOfflineQueue() async {
    final box = Hive.box(_queueBoxName);
    await box.clear();
  }
}
