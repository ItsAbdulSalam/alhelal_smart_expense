import 'dart:convert';
import 'dart:typed_data';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:alhelal_smart_expense/core/utils/image_compressor.dart';

class GeminiReceiptService {
  final SupabaseClient _supabase = Supabase.instance.client;

  Future<Map<String, dynamic>> analyzeReceipt(Uint8List imageBytes) async {
    // 1. ضغط الصورة وتصغير أبعادها محلياً لتسريع الإرسال وتوفير استهلاك البيانات
    final base64Image = await ImageCompressor.compressAndEncodeBase64(
      imageBytes,
    );

    // 2. استدعاء الدالة السحابية
    final FunctionResponse response = await _supabase.functions.invoke(
      'analyze-receipt',
      body: {'imageBase64': base64Image},
    );

    // 3. التحقق من حالة الطلب
    if (response.status != 200) {
      final errorDetail = response.data is Map && response.data['error'] != null
          ? response.data['error']
          : response.data?.toString() ?? 'خطأ غير معروف';
      throw Exception('فشل تحليل الفاتورة: $errorDetail');
    }

    // 4. معالجة البيانات المستلمة بمرونة وأمان
    final data = response.data;
    if (data is Map<String, dynamic>) {
      return data;
    } else if (data is String) {
      final decoded = jsonDecode(data);
      if (decoded is Map<String, dynamic>) {
        return decoded;
      }
    }

    throw Exception('صيغة البيانات المستلمة غير صالحة');
  }
}
