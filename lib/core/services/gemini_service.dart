import 'dart:convert';
import 'dart:typed_data';
import 'package:http/http.dart' as http;

class GeminiReceiptService {
  static const String _apiKey =
      'AQ.Ab8RN6LC03AWuvk2K827sjhpO9IPRoxeWNf7QIDJepD6ylT3yw';

  // قائمة النماذج الرسمية النشطة والمدعومة لحسابك بالترتيب
  static const List<String> _models = [
    'gemini-3.5-flash-lite',
    'gemini-3.1-pro-preview',
    'gemini-3.6-flash',
  ];

  Future<Map<String, dynamic>> analyzeReceipt(Uint8List imageBytes) async {
    final base64Image = base64Encode(imageBytes);

    const String prompt = '''
You are a senior professional financial accountant and OCR expert analyzing an official receipt or utility invoice (electricity, water, gas, telecom, supermarket, restaurant, etc.).

Analyze this invoice image with extreme accuracy and extract the data as a clean JSON object without any Markdown formatting or code fences:

{
  "title": "Clear descriptive title in Arabic (e.g. فاتورة كهرباء, فاتورة غاز, مشتريات سوبرماركت)",
  "merchant_name": "Official company/store name exactly as written (e.g. CK BOĞAZİÇİ ELEKTRİK PERAKENDE SATIŞ A.Ş.)",
  "amount": 0.0,
  "currency": "TRY",
  "category": "One of: طعام ومشروبات, تسوق, مواصلات, فواتير وخدمات, صحة, أخرى",
  "date": "YYYY-MM-DD",
  "notes": "Any brief additional relevant notes or null"
}

CRITICAL RULES FOR ACCURACY:
1. "amount" (EXACT PAYABLE AMOUNT):
   - You MUST extract the FINAL NET PAYABLE AMOUNT that the consumer is required to pay.
   - For Turkish utility bills (CK Boğaziçi, İGDAŞ, İSKİ, Enerjisa, Türk Telekom, etc.), DO NOT use the pre-rounded subtotal. Instead, find the highlighted/boxed "Ödenecek Tutar", "Fatura Tutarı" in the main top/due-date summary box (e.g., if there is 1440.00 TL in the prominent box and 1438.19 in the breakdown table, the correct answer is 1440.00).
   - Look for terms like: "Ödenecek Tutar", "Genel Toplam", "Total to Pay", "Grand Total", "Net Amount".
   - Return "amount" strictly as a number (e.g., 1440.00, not 1438.19).

2. "date":
   - Use the official invoice date ("Fatura Tarihi" or "Düzenleme Tarihi"). 
   - Format strictly as YYYY-MM-DD.

3. "category":
   - Utility companies (Electricity, Water, Gas, Telecom, Internet) MUST ALWAYS be categorized as "فواتير وخدمات".

Return ONLY the raw JSON object.
''';

    final requestBody = {
      "contents": [
        {
          "parts": [
            {"text": prompt},
            {
              "inline_data": {"mime_type": "image/jpeg", "data": base64Image},
            },
          ],
        },
      ],
      "generationConfig": {"response_mime_type": "application/json"},
    };

    String lastError = '';

    // محاولة الاتصال بالنماذج المدعومة واحداً تلو الآخر في حال وجود ضغط على أحدهم
    for (final model in _models) {
      try {
        final url = Uri.parse(
          'https://generativelanguage.googleapis.com/v1beta/models/$model:generateContent',
        );

        final response = await http.post(
          url,
          headers: {
            'Content-Type': 'application/json',
            'X-goog-api-key': _apiKey,
          },
          body: jsonEncode(requestBody),
        );

        if (response.statusCode == 200) {
          final data = jsonDecode(response.body);
          final candidates = data['candidates'] as List?;
          if (candidates != null && candidates.isNotEmpty) {
            final text = candidates[0]['content']['parts'][0]['text'] as String;
            final cleanJson = text
                .replaceAll('```json', '')
                .replaceAll('```', '')
                .trim();
            return jsonDecode(cleanJson) as Map<String, dynamic>;
          }
        } else {
          lastError =
              'Model $model failed (${response.statusCode}): ${response.body}';
        }
      } catch (e) {
        lastError = 'Exception on $model: $e';
      }
    }

    throw Exception('فشل التحليل على جميع النماذج: $lastError');
  }
}
