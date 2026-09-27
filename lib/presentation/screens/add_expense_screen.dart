import 'dart:io';

import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';

import 'package:flutter/material.dart';

import 'package:image_picker/image_picker.dart';

import 'package:intl/intl.dart';

import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:alhelal_smart_expense/core/services/gemini_service.dart';

import 'package:alhelal_smart_expense/data/models/expense_model.dart';

import 'package:alhelal_smart_expense/data/repositories/expense_repository.dart';

import '../../l10n/app_localizations.dart'; // استدعاء الترجمة

class AddExpenseScreen extends StatefulWidget {

  const AddExpenseScreen({super.key});

  @override

  State<AddExpenseScreen> createState() => _AddExpenseScreenState();

}

class _AddExpenseScreenState extends State<AddExpenseScreen> {

  final _formKey = GlobalKey<FormState>();

  final _titleController = TextEditingController();

  final _merchantController = TextEditingController();

  final _amountController = TextEditingController();

  final _notesController = TextEditingController();

  String _selectedCategory = ''; // سيتم تعيينها ديناميكياً بناءً على اللغة

  String _selectedCurrency = 'TRY';

  DateTime _selectedDate = DateTime.now();

  XFile? _pickedImage;

  bool _isAnalyzing = false;

  bool _isSaving = false;

  final ImagePicker _picker = ImagePicker();

  late final ExpenseRepository _repository;

  final GeminiReceiptService _geminiService = GeminiReceiptService();

  final List<String> _currencies = ['TRY', 'USD', 'EUR', 'SAR'];

  @override

  void initState() {

    super.initState();

    _repository = ExpenseRepository(Supabase.instance.client);

  }

  @override

  void dispose() {

    _titleController.dispose();

    _merchantController.dispose();

    _amountController.dispose();

    _notesController.dispose();

    super.dispose();

  }

  Future<void> _pickAndProcessImage(ImageSource source) async {

    final isArabic = Localizations.localeOf(context).languageCode == 'ar';

    try {

      final XFile? image = await _picker.pickImage(

        source: source,

        imageQuality: 85,

      );

      if (image == null) return;

      setState(() {

        _pickedImage = image;

        _isAnalyzing = true;

      });

      final imageBytes = await image.readAsBytes();

      final extractedData = await _geminiService.analyzeReceipt(imageBytes);

      setState(() {

        if (extractedData['title'] != null) {

          _titleController.text = extractedData['title'].toString();

        }

        if (extractedData['merchant_name'] != null) {

          _merchantController.text = extractedData['merchant_name'].toString();

        }

        if (extractedData['amount'] != null) {

          _amountController.text = extractedData['amount'].toString();

        }

        if (extractedData['currency'] != null &&

            _currencies.contains(

              extractedData['currency'].toString().toUpperCase(),

            )) {

          _selectedCurrency = extractedData['currency']

              .toString()

              .toUpperCase();

        }

        // ربط التصنيف بذكاء ليتوافق مع اللغات

        if (extractedData['category'] != null && mounted) {

          final cat = extractedData['category'].toString();

          final loc = AppLocalizations.of(context)!;

          if (cat.contains('طعام') || cat.contains('Food')) {

            _selectedCategory = loc.foodAndDrink;

          } else if (cat.contains('تسوق') || cat.contains('Shop'))

            // ignore: curly_braces_in_flow_control_structures

            _selectedCategory = loc.shopping;

          else if (cat.contains('مواصلات') || cat.contains('Trans'))

            // ignore: curly_braces_in_flow_control_structures

            _selectedCategory = loc.transport;

          else if (cat.contains('فواتير') || cat.contains('Bill'))

            // ignore: curly_braces_in_flow_control_structures

            _selectedCategory = loc.billsAndServices;

          else if (cat.contains('صحة') || cat.contains('Health'))

            // ignore: curly_braces_in_flow_control_structures

            _selectedCategory = loc.health;

          else

            // ignore: curly_braces_in_flow_control_structures

            _selectedCategory = loc.other;

        }

        if (extractedData['date'] != null) {

          try {

            _selectedDate = DateTime.parse(extractedData['date'].toString());

          } catch (_) {}

        }

        if (extractedData['notes'] != null) {

          _notesController.text = extractedData['notes'].toString();

        }

      });

      if (mounted) {

        ScaffoldMessenger.of(context).showSnackBar(

          SnackBar(

            content: Row(

              children: [

                const Icon(

                  Icons.check_circle_rounded,

                  color: Colors.greenAccent,

                ),

                const SizedBox(width: 8),

                Text(

                  isArabic

                      ? 'تمت قراءة بيانات الفاتورة بنجاح'

                      : 'Receipt data extracted successfully',

                ),

              ],

            ),

            backgroundColor: const Color(0xFF1E293B),

            behavior: SnackBarBehavior.floating,

            shape: RoundedRectangleBorder(

              borderRadius: BorderRadius.circular(10),

            ),

          ),

        );

      }

    } catch (e) {

      if (mounted) {

        ScaffoldMessenger.of(context).showSnackBar(

          SnackBar(

            content: Text(

              isArabic

                  ? 'تعذر قراءة بيانات الفاتورة: $e'

                  : 'Failed to read receipt: $e',

            ),

            backgroundColor: const Color(0xFFE11D48),

            behavior: SnackBarBehavior.floating,

          ),

        );

      }

    } finally {

      if (mounted) {

        setState(() => _isAnalyzing = false);

      }

    }

  }

  Future<void> _pickDate() async {

    final DateTime? picked = await showDatePicker(

      context: context,

      initialDate: _selectedDate,

      firstDate: DateTime(2020),

      lastDate: DateTime(2030),

      builder: (context, child) {

        return Theme(

          data: Theme.of(context).copyWith(

            colorScheme: const ColorScheme.light(

              primary: Color(0xFF4F46E5),

              onPrimary: Colors.white,

              onSurface: Color(0xFF0F172A),

            ),

          ),

          child: child!,

        );

      },

    );

    if (picked != null && picked != _selectedDate) {

      setState(() => _selectedDate = picked);

    }

  }

  Future<void> _saveExpense() async {
    if (_isSaving) return;
    if (!(_formKey.currentState?.validate() ?? false)) return;

    setState(() => _isSaving = true);

    final isArabic = Localizations.localeOf(context).languageCode == 'ar';

    try {

      String? uploadedImagePath;

      if (_pickedImage != null) {

        final bytes = await _pickedImage!.readAsBytes();

        final fileName =

            '${DateTime.now().millisecondsSinceEpoch}_${_pickedImage!.name}';

        uploadedImagePath = await _repository.uploadReceiptImage(

          bytes: bytes,

          fileName: fileName,

        );

      }

      final currentUser = Supabase.instance.client.auth.currentUser;
      if (currentUser == null) {
        throw Exception(
          isArabic
              ? 'انتهت جلسة تسجيل الدخول. يرجى تسجيل الدخول مرة أخرى.'
              : 'Your login session has expired. Please sign in again.',
        );
      }
      final currentUserId = currentUser.id;

      final parsedAmount = double.tryParse(_amountController.text.trim());
      if (parsedAmount == null || parsedAmount <= 0) {
        throw Exception(
          isArabic ? 'المبلغ المدخل غير صالح' : 'The entered amount is invalid',
        );
      }

      final expense = ExpenseModel(

        id: '',

        userId: currentUserId,

        title: _titleController.text.trim(),

        merchantName: _merchantController.text.trim().isEmpty

            ? null

            : _merchantController.text.trim(),

        amount: parsedAmount,

        currency: _selectedCurrency,

        category: _selectedCategory,

        expenseDate: _selectedDate,

        receiptImagePath: uploadedImagePath,

        notes: _notesController.text.trim().isEmpty

            ? null

            : _notesController.text.trim(),

        isAiExtracted: _pickedImage != null,

        createdAt: DateTime.now(),

      );

      // الحفظ عبر الدالة الفعلية الموجودة في ExpenseRepository.
      // لا نستخدم dynamic ولا createExpense لأن createExpense غير موجودة.
      await _repository.addExpense(expense);

      if (mounted) {

        ScaffoldMessenger.of(context).showSnackBar(

          SnackBar(

            content: Row(

              children: [

                const Icon(

                  Icons.check_circle_rounded,

                  color: Colors.greenAccent,

                ),

                const SizedBox(width: 8),

                Text(

                  isArabic

                      ? 'تم قيد الفاتورة بنجاح في السجلات المالية'

                      : 'Expense successfully saved to records',

                ),

              ],

            ),

            backgroundColor: const Color(0xFF1E293B),

            behavior: SnackBarBehavior.floating,

            shape: RoundedRectangleBorder(

              borderRadius: BorderRadius.circular(10),

            ),

          ),

        );

        Navigator.pop(context, true);

      }

    } catch (e) {

      if (mounted) {

        ScaffoldMessenger.of(context).showSnackBar(

          SnackBar(

            content: Text(

              isArabic

                  ? 'حدث خطأ أثناء حفظ الفاتورة: $e'

                  : 'Error saving expense: $e',

            ),

            backgroundColor: const Color(0xFFE11D48),

            behavior: SnackBarBehavior.floating,

          ),

        );

      }

    } finally {

      if (mounted) setState(() => _isSaving = false);

    }

  }

  @override

  Widget build(BuildContext context) {

    final loc = AppLocalizations.of(context)!;

    final isArabic = Localizations.localeOf(context).languageCode == 'ar';

    final categories = [

      loc.foodAndDrink,

      loc.shopping,

      loc.transport,

      loc.billsAndServices,

      loc.health,

      loc.other,

    ];

    if (!categories.contains(_selectedCategory)) {

      _selectedCategory = loc.billsAndServices;

    }

    return Directionality(

      textDirection: isArabic ? ui.TextDirection.rtl : ui.TextDirection.ltr,

      child: Scaffold(

        backgroundColor: const Color(0xFFF8FAFC),

        appBar: AppBar(

          elevation: 0,

          backgroundColor: Colors.transparent,

          scrolledUnderElevation: 0,

          centerTitle: true,

          leading: IconButton(

            icon: Icon(

              isArabic

                  ? Icons.arrow_forward_ios_rounded

                  : Icons.arrow_back_ios_new_rounded,

              size: 18,

              color: const Color(0xFF0F172A),

            ),

            onPressed: () => Navigator.pop(context),

          ),

          title: Text(

            loc.newExpense,

            style: const TextStyle(

              fontWeight: FontWeight.w800,

              fontSize: 18,

              color: Color(0xFF0F172A),

            ),

          ),

        ),

        body: Center(

          child: ConstrainedBox(

            constraints: const BoxConstraints(maxWidth: 760),

            child: Form(

              key: _formKey,

              child: ListView(

                padding: const EdgeInsets.symmetric(

                  horizontal: 20,

                  vertical: 16,

                ),

                children: [

                  _buildReceiptPickerCard(isArabic),

                  const SizedBox(height: 20),

                  _buildTextField(

                    controller: _titleController,

                    label: isArabic

                        ? 'عنوان الفاتورة / الوصف \*'

                        : 'Expense Title / Description \*',

                    hint: isArabic

                        ? 'مثال: فاتورة كهرباء، مشتريات ماركت'

                        : 'e.g. Electricity bill, Groceries',

                    icon: Icons.receipt_long_rounded,

                    validator: (val) {

                      if (val == null || val.trim().isEmpty) {

                        return isArabic

                            ? 'يرجى إدخال عنوان الفاتورة'

                            : 'Please enter an expense title';

                      }

                      return null;

                    },

                  ),

                  const SizedBox(height: 14),

                  _buildTextField(

                    controller: _merchantController,

                    label: isArabic ? 'المتجر / الشركة' : 'Store / Merchant',

                    hint: 'مثال: CK BOĞAZİÇİ ELEKTRİK, BIM, Migros',

                    icon: Icons.storefront_rounded,

                  ),

                  const SizedBox(height: 14),

                  Row(

                    crossAxisAlignment: CrossAxisAlignment.start,

                    children: [

                      Expanded(

                        flex: 5,

                        child: _buildTextField(

                          controller: _amountController,

                          label: isArabic

                              ? 'المبلغ الإجمالي \*'

                              : 'Total Amount \*',

                          hint: '0.00',

                          icon: Icons.attach_money_rounded,

                          keyboardType: const TextInputType.numberWithOptions(

                            decimal: true,

                          ),

                          validator: (val) {

                            if (val == null || val.trim().isEmpty) {

                              return isArabic

                                  ? 'يرجى تحديد المبلغ'

                                  : 'Please specify the amount';

                            }

                            if (double.tryParse(val.trim()) == null) {

                              return isArabic

                                  ? 'أدخل رقماً صحيحاً'

                                  : 'Enter a valid number';

                            }

                            return null;

                          },

                        ),

                      ),

                      const SizedBox(width: 12),

                      Expanded(

                        flex: 3,

                        child: _buildDropdown(

                          label: isArabic ? 'العملة' : 'Currency',

                          selectedValue: _selectedCurrency,

                          items: _currencies,

                          onChanged: (val) {

                            if (val != null) {

                              setState(() => _selectedCurrency = val);

                            }

                          },

                        ),

                      ),

                    ],

                  ),

                  const SizedBox(height: 14),

                  _buildDropdown(

                    label: isArabic ? 'التصنيف' : 'Category',

                    selectedValue: _selectedCategory,

                    items: categories,

                    icon: Icons.category_outlined,

                    onChanged: (val) {

                      if (val != null) setState(() => _selectedCategory = val);

                    },

                  ),

                  const SizedBox(height: 14),

                  InkWell(

                    onTap: _pickDate,

                    borderRadius: BorderRadius.circular(14),

                    child: Container(

                      padding: const EdgeInsets.symmetric(

                        horizontal: 16,

                        vertical: 14,

                      ),

                      decoration: BoxDecoration(

                        color: Colors.white,

                        borderRadius: BorderRadius.circular(14),

                        border: Border.all(color: const Color(0xFFE2E8F0)),

                      ),

                      child: Row(

                        children: [

                          const Icon(

                            Icons.calendar_month_rounded,

                            color: Color(0xFF4F46E5),

                            size: 20,

                          ),

                          const SizedBox(width: 12),

                          Column(

                            crossAxisAlignment: CrossAxisAlignment.start,

                            children: [

                              Text(

                                isArabic ? 'تاريخ الفاتورة' : 'Expense Date',

                                style: TextStyle(

                                  color: Colors.grey.shade500,

                                  fontSize: 11.5,

                                ),

                              ),

                              const SizedBox(height: 2),

                              Text(

                                DateFormat('yyyy-MM-dd').format(_selectedDate),

                                style: const TextStyle(

                                  fontWeight: FontWeight.bold,

                                  fontSize: 14,

                                ),

                              ),

                            ],

                          ),

                          const Spacer(),

                          const Icon(

                            Icons.keyboard_arrow_down_rounded,

                            color: Colors.grey,

                          ),

                        ],

                      ),

                    ),

                  ),

                  const SizedBox(height: 14),

                  _buildTextField(

                    controller: _notesController,

                    label: isArabic ? 'ملاحظات إضافية' : 'Additional Notes',

                    hint: isArabic

                        ? 'أي تفاصيل خاصة ترغب بحفظها...'

                        : 'Any special details you want to save...',

                    icon: Icons.notes_rounded,

                    maxLines: 2,

                  ),

                  const SizedBox(height: 32),

                  ElevatedButton(

                    onPressed: _isSaving ? null : _saveExpense,

                    style: ElevatedButton.styleFrom(

                      backgroundColor: const Color(0xFF4F46E5),

                      foregroundColor: Colors.white,

                      elevation: 0,

                      padding: const EdgeInsets.symmetric(vertical: 16),

                      shape: RoundedRectangleBorder(

                        borderRadius: BorderRadius.circular(14),

                      ),

                    ),

                    child: _isSaving

                        ? const SizedBox(

                            height: 20,

                            width: 20,

                            child: CircularProgressIndicator(

                              strokeWidth: 2,

                              color: Colors.white,

                            ),

                          )

                        : Row(

                            mainAxisAlignment: MainAxisAlignment.center,

                            children: [

                              const Icon(Icons.save_rounded, size: 18),

                              const SizedBox(width: 8),

                              Text(

                                isArabic

                                    ? 'حفظ الفاتورة في الحساب'

                                    : 'Save Expense to Account',

                                style: const TextStyle(

                                  fontWeight: FontWeight.bold,

                                  fontSize: 14.5,

                                ),

                              ),

                            ],

                          ),

                  ),

                  const SizedBox(height: 40),

                ],

              ),

            ),

          ),

        ),

      ),

    );

  }

  Widget _buildReceiptPickerCard(bool isArabic) {

    return Container(

      decoration: BoxDecoration(

        color: Colors.white,

        borderRadius: BorderRadius.circular(18),

        border: Border.all(color: const Color(0xFFE2E8F0)),

      ),

      child: ClipRRect(

        borderRadius: BorderRadius.circular(18),

        child: Column(

          children: [

            if (_pickedImage != null)

              Stack(

                alignment: Alignment.center,

                children: [

                  Container(

                    height: 220,

                    width: double.infinity,

                    color: const Color(0xFFF1F5F9),

                    child: kIsWeb

                        ? Image.network(_pickedImage!.path, fit: BoxFit.contain)

                        : Image.file(

                            File(_pickedImage!.path),

                            fit: BoxFit.contain,

                          ),

                  ),

                  if (_isAnalyzing)

                    Container(

                      height: 220,

                      width: double.infinity,

                      color: Colors.black.withValues(alpha: 0.5),

                      child: Column(

                        mainAxisAlignment: MainAxisAlignment.center,

                        children: [

                          const CircularProgressIndicator(color: Colors.white),

                          const SizedBox(height: 12),

                          Text(

                            isArabic

                                ? 'جاري معالجة بيانات الإيصال...'

                                : 'Processing receipt data...',

                            style: const TextStyle(

                              color: Colors.white,

                              fontWeight: FontWeight.bold,

                            ),

                          ),

                        ],

                      ),

                    ),

                ],

              ),

            Padding(

              padding: const EdgeInsets.all(14),

              child: Row(

                children: [

                  Expanded(

                    child: OutlinedButton.icon(

                      onPressed: _isAnalyzing

                          ? null

                          : () => _pickAndProcessImage(ImageSource.gallery),

                      icon: const Icon(Icons.file_upload_outlined, size: 18),

                      label: Text(

                        _pickedImage == null

                            ? (isArabic

                                  ? 'أرشفة صورة الفاتورة'

                                  : 'Upload Receipt')

                            : (isArabic ? 'تغيير الصورة' : 'Change Image'),

                        style: const TextStyle(

                          fontWeight: FontWeight.bold,

                          fontSize: 13,

                        ),

                      ),

                      style: OutlinedButton.styleFrom(

                        padding: const EdgeInsets.symmetric(vertical: 12),

                        side: const BorderSide(color: Color(0xFFCBD5E1)),

                        shape: RoundedRectangleBorder(

                          borderRadius: BorderRadius.circular(12),

                        ),

                      ),

                    ),

                  ),

                  const SizedBox(width: 10),

                  Expanded(

                    child: ElevatedButton.icon(

                      onPressed: _isAnalyzing

                          ? null

                          : () => _pickAndProcessImage(ImageSource.camera),

                      icon: const Icon(Icons.camera_alt_outlined, size: 18),

                      label: Text(

                        isArabic ? 'مسح بالماسح الضوئي' : 'Scan with Scanner',

                        style: const TextStyle(

                          fontWeight: FontWeight.bold,

                          fontSize: 13,

                        ),

                      ),

                      style: ElevatedButton.styleFrom(

                        backgroundColor: const Color(0xFF1E293B),

                        foregroundColor: Colors.white,

                        elevation: 0,

                        padding: const EdgeInsets.symmetric(vertical: 12),

                        shape: RoundedRectangleBorder(

                          borderRadius: BorderRadius.circular(12),

                        ),

                      ),

                    ),

                  ),

                ],

              ),

            ),

          ],

        ),

      ),

    );

  }

  Widget _buildTextField({

    required TextEditingController controller,

    required String label,

    required String hint,

    required IconData icon,

    int maxLines = 1,

    TextInputType? keyboardType,

    String? Function(String?)? validator,

  }) {

    return TextFormField(

      controller: controller,

      maxLines: maxLines,

      keyboardType: keyboardType,

      validator: validator,

      style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),

      decoration: InputDecoration(

        labelText: label,

        labelStyle: TextStyle(color: Colors.grey.shade600, fontSize: 13),

        hintText: hint,

        hintStyle: TextStyle(color: Colors.grey.shade400, fontSize: 13),

        prefixIcon: Icon(icon, color: const Color(0xFF4F46E5), size: 20),

        filled: true,

        fillColor: Colors.white,

        contentPadding: const EdgeInsets.symmetric(

          horizontal: 16,

          vertical: 14,

        ),

        border: OutlineInputBorder(

          borderRadius: BorderRadius.circular(14),

          borderSide: const BorderSide(color: Color(0xFFE2E8F0)),

        ),

        enabledBorder: OutlineInputBorder(

          borderRadius: BorderRadius.circular(14),

          borderSide: const BorderSide(color: Color(0xFFE2E8F0)),

        ),

        focusedBorder: OutlineInputBorder(

          borderRadius: BorderRadius.circular(14),

          borderSide: const BorderSide(color: Color(0xFF4F46E5), width: 1.5),

        ),

      ),

    );

  }

  Widget _buildDropdown({

    required String label,

    required String selectedValue,

    required List<String> items,

    required void Function(String?) onChanged,

    IconData? icon,

  }) {

    return DropdownButtonFormField<String>(

      initialValue: selectedValue,

      items: items.map((item) {

        return DropdownMenuItem(

          value: item,

          child: Text(

            item,

            style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600),

          ),

        );

      }).toList(),

      onChanged: onChanged,

      decoration: InputDecoration(

        labelText: label,

        labelStyle: TextStyle(color: Colors.grey.shade600, fontSize: 13),

        prefixIcon: icon != null

            ? Icon(icon, color: const Color(0xFF4F46E5), size: 20)

            : null,

        filled: true,

        fillColor: Colors.white,

        contentPadding: const EdgeInsets.symmetric(

          horizontal: 16,

          vertical: 14,

        ),

        border: OutlineInputBorder(

          borderRadius: BorderRadius.circular(14),

          borderSide: const BorderSide(color: Color(0xFFE2E8F0)),

        ),

        enabledBorder: OutlineInputBorder(

          borderRadius: BorderRadius.circular(14),

          borderSide: const BorderSide(color: Color(0xFFE2E8F0)),

        ),

        focusedBorder: OutlineInputBorder(

          borderRadius: BorderRadius.circular(14),

          borderSide: const BorderSide(color: Color(0xFF4F46E5), width: 1.5),

        ),

      ),

    );

  }

}
