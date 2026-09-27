import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:hive/hive.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/services/local_expense_service.dart';
import '../models/expense_model.dart';
import 'package:flutter/foundation.dart';

class ExpenseRepository {
  final SupabaseClient _client;

  ExpenseRepository(this._client);

  /// جلب كافة مصاريف المستخدم الحالي
  /// مع دعم التخزين المحلي Offline-First
  Future<List<ExpenseModel>> getExpenses() async {
    String? userId;

    try {
      final user = _client.auth.currentUser;

      if (user != null) {
        userId = user.id;

        if (Hive.isBoxOpen('expenses_box')) {
          final box = Hive.box('expenses_box');
          await box.put('cached_user_id', userId);
        }
      }
    } catch (e) {
      print('⚠️ تعذر الحصول على المستخدم الحالي: $e');
    }

    // محاولة الحصول على userId من التخزين المحلي
    if (userId == null && Hive.isBoxOpen('expenses_box')) {
      try {
        final box = Hive.box('expenses_box');
        final cachedUserId = box.get('cached_user_id');

        if (cachedUserId != null) {
          userId = cachedUserId.toString();
        }
      } catch (e) {
        print('⚠️ تعذر قراءة المستخدم من Hive: $e');
      }
    }

    // لا يوجد مستخدم
    if (userId == null || userId.isEmpty) {
      final cachedData = LocalExpenseService.getCachedExpenses();
      final offlineQueue = LocalExpenseService.getOfflineQueue();

      final combinedList = [
        ..._extractOfflineExpenses(offlineQueue),
        ...cachedData,
      ];

      if (combinedList.isNotEmpty) {
        return combinedList.map((item) => ExpenseModel.fromJson(item)).toList();
      }

      throw Exception('لا يوجد مستخدم مسجل ولا توجد بيانات محفوظة محلياً');
    }

    try {
      // مزامنة العمليات القديمة أولاً
      await _syncOfflineQueue();

      final response = await _client
          .from('expenses')
          .select()
          .eq('user_id', userId)
          .order('expense_date', ascending: false);

      final List<Map<String, dynamic>> rawData = (response as List)
          .map((item) => Map<String, dynamic>.from(item as Map))
          .toList();

      await LocalExpenseService.cacheExpenses(rawData);

      return rawData.map((item) => ExpenseModel.fromJson(item)).toList();
    } catch (e) {
      print('⚠️ فشل تحميل المصاريف من Supabase: $e');

      final cachedData = LocalExpenseService.getCachedExpenses();
      final offlineQueue = LocalExpenseService.getOfflineQueue();

      final combinedList = [
        ..._extractOfflineExpenses(offlineQueue),
        ...cachedData,
      ];

      if (combinedList.isNotEmpty) {
        print('🟢 تم استرجاع ${combinedList.length} مصروف محلياً');

        return combinedList.map((item) => ExpenseModel.fromJson(item)).toList();
      }

      throw Exception('فشل الاتصال ولا توجد بيانات مخزنة محلياً: $e');
    }
  }

  /// إضافة مصروف جديد
  Future<void> addExpense(ExpenseModel expense) async {
    final user = _client.auth.currentUser;

    if (user == null) {
      throw Exception('No authenticated user');
    }

    final data = expense.toJson();

    // Supabase ينشئ هذه القيم
    data.remove('id');
    data.remove('created_at');

    // ضمان أن المصروف يعود للمستخدم الحالي
    data['user_id'] = user.id;

    debugPrint('==============================');
    debugPrint('ADDING EXPENSE TO SUPABASE');
    debugPrint('USER ID: ${user.id}');
    debugPrint('DATA: $data');
    debugPrint('==============================');

    try {
      final response = await _client
          .from('expenses')
          .insert(data)
          .select()
          .single();

      debugPrint('EXPENSE INSERT SUCCESS: $response');
    } catch (e, stackTrace) {
      debugPrint('EXPENSE INSERT FAILED');
      debugPrint('ERROR: $e');
      debugPrint('$stackTrace');

      rethrow;
    }
  }

  /// تعديل مصروف
  Future<void> updateExpense(ExpenseModel expense) async {
    final expenseId = expense.id;

    if (expenseId.isEmpty) {
      throw Exception('لا يمكن تعديل فاتورة بدون معرف ID');
    }

    final data = Map<String, dynamic>.from(expense.toJson());

    try {
      await _client.from('expenses').update(data).eq('id', expenseId);

      print('✅ تم تعديل الفاتورة بنجاح');

      await _syncOfflineQueue();
    } catch (e) {
      print('⚠️ فشل التعديل على السيرفر: $e');

      try {
        await LocalExpenseService.queueOfflineAction(
          action: 'update',
          payload: data,
        );

        print('🟡 تم حفظ عملية التعديل محلياً للمزامنة لاحقاً');
      } catch (localError) {
        throw Exception(
          'فشل تعديل الفاتورة: $e\n'
          'وفشل حفظ التعديل محلياً: $localError',
        );
      }
    }
  }

  /// حذف مصروف
  Future<void> deleteExpense(String expenseId) async {
    if (expenseId.isEmpty) {
      throw Exception('معرف الفاتورة غير صالح');
    }

    try {
      await _client.from('expenses').delete().eq('id', expenseId);

      print('✅ تم حذف الفاتورة بنجاح');

      await _syncOfflineQueue();
    } catch (e) {
      print('⚠️ فشل الحذف من السيرفر: $e');

      try {
        await LocalExpenseService.queueOfflineAction(
          action: 'delete',
          payload: {'id': expenseId},
        );

        print('🟡 تم حفظ عملية الحذف محلياً للمزامنة لاحقاً');
      } catch (localError) {
        throw Exception(
          'فشل حذف الفاتورة: $e\n'
          'وفشل حفظ عملية الحذف محلياً: $localError',
        );
      }
    }
  }

  /// مزامنة العمليات المحفوظة Offline
  Future<void> _syncOfflineQueue() async {
    List<Map<String, dynamic>> offlineItems;

    try {
      offlineItems = LocalExpenseService.getOfflineQueue();
    } catch (e) {
      print('⚠️ تعذر قراءة Offline Queue: $e');
      return;
    }

    if (offlineItems.isEmpty) {
      return;
    }

    final List<Map<String, dynamic>> remainingItems = [];

    for (final item in offlineItems) {
      final action = item['action'];

      final rawPayload = item['payload'];

      if (rawPayload is! Map) {
        print('⚠️ Payload غير صالح، تم تجاهل العملية');
        continue;
      }

      final payload = Map<String, dynamic>.from(rawPayload);

      try {
        if (action == 'insert') {
          await _client.from('expenses').insert(payload);
        } else if (action == 'update') {
          final id = payload['id'];

          if (id == null || id.toString().isEmpty) {
            throw Exception('عملية update لا تحتوي على ID');
          }

          await _client.from('expenses').update(payload).eq('id', id);
        } else if (action == 'delete') {
          final id = payload['id'];

          if (id == null || id.toString().isEmpty) {
            throw Exception('عملية delete لا تحتوي على ID');
          }

          await _client.from('expenses').delete().eq('id', id);
        } else {
          print('⚠️ Offline action غير معروف: $action');
          continue;
        }

        print('🟢 تمت مزامنة عملية ($action) بنجاح');
      } catch (e) {
        print('🟡 فشلت مزامنة ($action): $e');

        remainingItems.add({'action': action, 'payload': payload});
      }
    }

    try {
      await LocalExpenseService.clearOfflineQueue();

      for (final failedItem in remainingItems) {
        await LocalExpenseService.queueOfflineAction(
          action: failedItem['action'].toString(),
          payload: Map<String, dynamic>.from(failedItem['payload'] as Map),
        );
      }
    } catch (e) {
      print('⚠️ تعذر تحديث Offline Queue: $e');
    }
  }

  /// استخراج عمليات Insert فقط لعرضها كفواتير Offline
  List<Map<String, dynamic>> _extractOfflineExpenses(
    List<Map<String, dynamic>> queue,
  ) {
    final List<Map<String, dynamic>> result = [];

    for (final item in queue) {
      if (item['action'] != 'insert') {
        continue;
      }

      final payload = item['payload'];

      if (payload is Map) {
        result.add(Map<String, dynamic>.from(payload));
      }
    }

    return result;
  }

  /// رفع صورة الفاتورة
  Future<String> uploadReceiptImage({
    required Uint8List bytes,
    required String fileName,
  }) async {
    final user = _client.auth.currentUser;

    if (user == null) {
      throw Exception('المستخدم غير مسجل الدخول');
    }

    if (bytes.isEmpty) {
      throw Exception('ملف الصورة فارغ');
    }

    final extension = fileName.contains('.')
        ? fileName.split('.').last.toLowerCase()
        : 'jpg';

    String mimeType;

    switch (extension) {
      case 'png':
        mimeType = 'image/png';
        break;

      case 'webp':
        mimeType = 'image/webp';
        break;

      case 'jpg':
      case 'jpeg':
      default:
        mimeType = 'image/jpeg';
        break;
    }

    final safeFileName = fileName.replaceAll(RegExp(r'[^a-zA-Z0-9._-]'), '_');

    final fullPath =
        '${user.id}/'
        '${DateTime.now().millisecondsSinceEpoch}_'
        '$safeFileName';

    try {
      await _client.storage
          .from('receipts')
          .uploadBinary(
            fullPath,
            bytes,
            fileOptions: FileOptions(upsert: true, contentType: mimeType),
          );

      return _client.storage.from('receipts').getPublicUrl(fullPath);
    } catch (e) {
      throw Exception('فشل رفع صورة الفاتورة: $e');
    }
  }
}
