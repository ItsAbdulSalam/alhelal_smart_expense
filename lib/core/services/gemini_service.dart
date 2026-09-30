import 'dart:convert';
import 'dart:typed_data';
import 'package:supabase_flutter/supabase_flutter.dart';

class GeminiReceiptService {
  final SupabaseClient _supabase = Supabase.instance.client;

  Future<Map<String, dynamic>> analyzeReceipt(Uint8List imageBytes) async {
    final base64Image = base64Encode(imageBytes);

    final FunctionResponse response = await _supabase.functions.invoke(
      'analyze-receipt',
      body: {'imageBase64': base64Image},
    );

    if (response.status != 200) {
      throw Exception('فشل تحليل الفاتورة: ${response.data}');
    }

    if (response.data is Map<String, dynamic>) {
      return response.data as Map<String, dynamic>;
    } else {
      return jsonDecode(response.data.toString()) as Map<String, dynamic>;
    }
  }
}
