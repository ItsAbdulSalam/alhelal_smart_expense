class ExpenseModel {
  final String id;
  final String userId;
  final String title;
  final String? merchantName;
  final String category;
  final double amount;
  final String currency;
  final DateTime expenseDate;
  final String? receiptImagePath;
  final Map<String, dynamic>? rawGeminiJson;
  final bool isAiExtracted;
  final String? notes;
  final DateTime createdAt;

  ExpenseModel({
    required this.id,
    required this.userId,
    required this.title,
    this.merchantName,
    required this.category,
    required this.amount,
    required this.currency,
    required this.expenseDate,
    this.receiptImagePath,
    this.rawGeminiJson,
    this.isAiExtracted = false,
    this.notes,
    required this.createdAt,
  });

  factory ExpenseModel.fromJson(Map<String, dynamic> json) {
    return ExpenseModel(
      id: json['id']?.toString() ?? '',
      userId: json['user_id']?.toString() ?? '',
      title: json['title']?.toString() ?? 'بدون عنوان',
      merchantName: json['merchant_name']?.toString(),
      category: json['category']?.toString() ?? 'عام',
      amount: json['amount'] != null
          ? (json['amount'] is num
                ? (json['amount'] as num).toDouble()
                : double.tryParse(json['amount'].toString()) ?? 0.0)
          : 0.0,
      currency: json['currency']?.toString() ?? 'TRY',
      expenseDate: json['expense_date'] != null
          ? DateTime.parse(json['expense_date'].toString())
          : DateTime.now(),
      // السطر المعدل لدعم جميع مسميات روابط ومسارات الصور القادمة من Laravel:
      receiptImagePath:
          (json['receipt_image_path'] ??
                  json['receipt_image_url'] ??
                  json['receipt_path'] ??
                  json['image_url'] ??
                  json['image'])
              ?.toString(),
      rawGeminiJson: json['raw_gemini_json'] != null
          ? Map<String, dynamic>.from(json['raw_gemini_json'])
          : null,
      isAiExtracted: json['is_ai_extracted'] == true,
      notes: json['notes']?.toString(),
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'].toString())
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id, // أضفنا الid هنا لضمان حفظه واسترجاعه محلياً بشكل صحيح
      'user_id': userId,
      'title': title,
      'merchant_name': merchantName,
      'category': category,
      'amount': amount,
      'currency': currency,
      'expense_date': expenseDate.toIso8601String().split('T').first,
      'receipt_image_path': receiptImagePath,
      'raw_gemini_json': rawGeminiJson,
      'is_ai_extracted': isAiExtracted,
      'notes': notes,
      'created_at': createdAt
          .toIso8601String(), // أضفنا توثيق وقت الإنشاء محلياً
    };
  }
}
