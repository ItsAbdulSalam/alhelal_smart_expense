import 'package:supabase_flutter/supabase_flutter.dart';

class ExpenseService {
  final SupabaseClient _supabase = Supabase.instance.client;

  Future<void> saveExpense({
    required String title,
    required String? merchantName,
    required double amount,
    required String currency,
    required String category,
    required DateTime date,
    String? notes,
  }) async {
    final user = _supabase.auth.currentUser;
    if (user == null) {
      throw Exception('يجب تسجيل الدخول أولاً لحفظ الفاتورة');
    }

    final data = {
      'user_id': user.id,
      'title': title.trim(),
      'merchant_name': merchantName?.trim(),
      'amount': amount,
      'currency': currency,
      'category': category,
      'expense_date': date.toIso8601String().split('T')[0], // YYYY-MM-DD
      'notes': notes?.trim(),
    };

    await _supabase.from('expenses').insert(data);
  }
}