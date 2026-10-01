import 'package:flutter/foundation.dart';
import 'package:hive/hive.dart';

class LocalExpenseService {
  static const String _expenseBoxName = 'expenses_box';
  static const String _queueBoxName = 'offline_expenses_queue';

  // كاش داخلي في الذاكرة لتشغيل الويب مع WASM بدون أخطاء
  static List<Map<String, dynamic>> _webMemoryExpenses = [];
  static final List<Map<String, dynamic>> _webMemoryQueue = [];

  /// حفظ البيانات المخزنة مؤقتاً
  static Future<void> cacheExpenses(List<Map<String, dynamic>> expenses) async {
    if (kIsWeb) {
      _webMemoryExpenses = List<Map<String, dynamic>>.from(expenses);
      return;
    }

    try {
      if (Hive.isBoxOpen(_expenseBoxName)) {
        final box = Hive.box(_expenseBoxName);
        await box.put('cached_expenses', expenses);
      }
    } catch (e) {
      debugPrint('⚠️ Error caching expenses: $e');
    }
  }

  /// استرجاع المصروفات المخزنة محلياً
  static List<Map<String, dynamic>> getCachedExpenses() {
    if (kIsWeb) {
      return List<Map<String, dynamic>>.from(_webMemoryExpenses);
    }

    try {
      if (Hive.isBoxOpen(_expenseBoxName)) {
        final box = Hive.box(_expenseBoxName);
        final data = box.get('cached_expenses');
        if (data != null) {
          return (data as List)
              .map((item) => Map<String, dynamic>.from(item))
              .toList();
        }
      }
    } catch (e) {
      debugPrint('⚠️ Error getting cached expenses: $e');
    }
    return [];
  }

  /// تهيئة صندوق طابور الانتظار
  static Future<void> initQueueBox() async {
    if (kIsWeb) return;

    try {
      if (!Hive.isBoxOpen(_queueBoxName)) {
        await Hive.openBox(_queueBoxName);
      }
    } catch (e) {
      debugPrint('⚠️ Error initializing queue box: $e');
    }
  }

  /// إضافة عملية معلقة جديدة للطابور
  static Future<void> queueOfflineAction({
    required String action,
    required Map<String, dynamic> payload,
  }) async {
    if (kIsWeb) {
      _webMemoryQueue.add({
        'action': action,
        'payload': payload,
        'timestamp': DateTime.now().toIso8601String(),
      });
      return;
    }

    try {
      if (Hive.isBoxOpen(_queueBoxName)) {
        final box = Hive.box(_queueBoxName);
        await box.add({
          'action': action,
          'payload': payload,
          'timestamp': DateTime.now().toIso8601String(),
        });
      }
    } catch (e) {
      debugPrint('⚠️ Error queueing offline action: $e');
    }
  }

  /// استرجاع طابور العمليات المعلقة
  static List<Map<String, dynamic>> getOfflineQueue() {
    if (kIsWeb) {
      return List<Map<String, dynamic>>.from(_webMemoryQueue);
    }

    try {
      if (Hive.isBoxOpen(_queueBoxName)) {
        final box = Hive.box(_queueBoxName);
        return box.values
            .map((item) => Map<String, dynamic>.from(item))
            .toList();
      }
    } catch (e) {
      debugPrint('⚠️ Error getting offline queue: $e');
    }
    return [];
  }

  /// تفريغ طابور الانتظار بعد نجاح المزامنة
  static Future<void> clearOfflineQueue() async {
    if (kIsWeb) {
      _webMemoryQueue.clear();
      return;
    }

    try {
      if (Hive.isBoxOpen(_queueBoxName)) {
        final box = Hive.box(_queueBoxName);
        await box.clear();
      }
    } catch (e) {
      debugPrint('⚠️ Error clearing offline queue: $e');
    }
  }
}
