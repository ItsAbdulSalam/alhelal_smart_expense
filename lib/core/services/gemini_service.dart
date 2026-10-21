import 'dart:typed_data';
import 'package:dio/dio.dart';
import 'package:alhelal_smart_expense/core/services/api_client.dart';

class GeminiReceiptService {
  Future<Map<String, dynamic>> analyzeReceipt(Uint8List imageBytes) async {
    final formData = FormData.fromMap({
      'receipt_image': MultipartFile.fromBytes(
        imageBytes,
        filename: 'receipt_${DateTime.now().millisecondsSinceEpoch}.jpg',
      ),
    });

    final response = await ApiClient.dio.post(
      '/expenses/analyze-receipt',
      data: formData,
      options: Options(
        sendTimeout: ApiClient.aiSendTimeout,
        receiveTimeout: ApiClient.aiReceiveTimeout,
      ),
    );

    if (response.statusCode == 200 && response.data['status'] == true) {
      final data = response.data['data'];
      if (data is Map<String, dynamic>) {
        return data;
      }
    }

    throw Exception(
      response.data['message'] ?? 'فشل استخراج بيانات الفاتورة من السيرفر',
    );
  }
}
