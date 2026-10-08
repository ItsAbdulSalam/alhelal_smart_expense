import 'dart:io';
import 'dart:ui' as ui;
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:alhelal_smart_expense/core/services/gemini_service.dart';
import '../../l10n/app_localizations.dart';
import '../../data/datasources/expense_laravel_remote_data_source.dart';

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

  String _selectedCategory = '';
  String _selectedCurrency = 'TRY';
  DateTime _selectedDate = DateTime.now();

  final ExpenseLaravelRemoteDataSource _remoteDataSource =
      ExpenseLaravelRemoteDataSource();

  XFile? _pickedImage;
  bool _isAnalyzing = false;
  bool _isSaving = false;

  final ImagePicker _picker = ImagePicker();
  final GeminiReceiptService _geminiService = GeminiReceiptService();

  final List<String> _currencies = ['TRY', 'USD', 'EUR', 'SAR'];

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

    final effectiveSource =
        (!kIsWeb &&
            (Platform.isWindows || Platform.isLinux || Platform.isMacOS))
        ? ImageSource.gallery
        : source;

    try {
      final XFile? image = await _picker.pickImage(
        source: effectiveSource,
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

        if (extractedData['category'] != null && mounted) {
          final cat = extractedData['category'].toString();
          final loc = AppLocalizations.of(context)!;
          if (cat.contains('طعام') || cat.contains('Food')) {
            _selectedCategory = loc.foodAndDrink;
          } else if (cat.contains('تسوق') || cat.contains('Shop')) {
            _selectedCategory = loc.shopping;
          } else if (cat.contains('مواصلات') || cat.contains('Trans')) {
            _selectedCategory = loc.transport;
          } else if (cat.contains('فواتير') || cat.contains('Bill')) {
            _selectedCategory = loc.billsAndServices;
          } else if (cat.contains('صحة') || cat.contains('Health')) {
            _selectedCategory = loc.health;
          } else {
            _selectedCategory = loc.other;
          }
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
                      ? 'تمت قراءة بيانات الفاتورة بنجاح عبر الذكاء الاصطناعي'
                      : 'Receipt data extracted successfully via AI',
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

  Future<void> _pickDate(
    bool isDark,
    Color cardBg,
    Color textColor,
    Color borderColor,
  ) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2020),
      lastDate: DateTime(2030),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: isDark
                ? const ColorScheme.dark(
                    primary: Color(0xFF4F46E5),
                    onPrimary: Colors.white,
                    surface: Color(0xFF0F172A),
                    onSurface: Color(0xFFF8FAFC),
                  )
                : const ColorScheme.light(
                    primary: Color(0xFF4F46E5),
                    onPrimary: Colors.white,
                    surface: Colors.white,
                    onSurface: Color(0xFF0F172A),
                  ),
            dialogTheme: DialogThemeData(backgroundColor: cardBg),
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
      final parsedAmount = double.tryParse(_amountController.text.trim());
      if (parsedAmount == null || parsedAmount <= 0) {
        throw Exception(
          isArabic ? 'المبلغ المدخل غير صالح' : 'The entered amount is invalid',
        );
      }

      final formattedDate = DateFormat('yyyy-MM-dd').format(_selectedDate);

      // تجهيز الحزمة عبر FormData لضمان رفع ونقل الصورة إلى Laravel بشكل سليم
      dynamic payload;

      if (_pickedImage != null) {
        MultipartFile multipartImage;
        if (kIsWeb) {
          final bytes = await _pickedImage!.readAsBytes();
          multipartImage = MultipartFile.fromBytes(
            bytes,
            filename: _pickedImage!.name,
          );
        } else {
          multipartImage = await MultipartFile.fromFile(
            _pickedImage!.path,
            filename: _pickedImage!.path.split(Platform.pathSeparator).last,
          );
        }

        payload = FormData.fromMap({
          'title': _titleController.text.trim(),
          'merchant_name': _merchantController.text.trim().isEmpty
              ? null
              : _merchantController.text.trim(),
          'amount': parsedAmount,
          'currency': _selectedCurrency,
          'category': _selectedCategory,
          'expense_date': formattedDate,
          'notes': _notesController.text.trim().isEmpty
              ? null
              : _notesController.text.trim(),
          'receipt_image': multipartImage,
          'receipt_image_path': _pickedImage!.path,
        });
      } else {
        payload = {
          'title': _titleController.text.trim(),
          'merchant_name': _merchantController.text.trim().isEmpty
              ? null
              : _merchantController.text.trim(),
          'amount': parsedAmount,
          'currency': _selectedCurrency,
          'category': _selectedCategory,
          'expense_date': formattedDate,
          'notes': _notesController.text.trim().isEmpty
              ? null
              : _notesController.text.trim(),
        };
      }

      await _remoteDataSource.createExpense(payload);

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

    final isDark = Theme.of(context).brightness == Brightness.dark;
    final scaffoldBg = isDark
        ? const Color(0xFF030712)
        : const Color(0xFFF1F5F9);
    final cardBg = isDark ? const Color(0xFF0F172A) : Colors.white;
    final borderColor = isDark
        ? const Color(0xFF1E293B)
        : const Color(0xFFE2E8F0);
    final textColor = isDark
        ? const Color(0xFFF8FAFC)
        : const Color(0xFF0F172A);
    final subTextColor = isDark
        ? const Color(0xFF94A3B8)
        : const Color(0xFF64748B);
    final inputFill = isDark ? const Color(0xFF0B132B) : Colors.white;

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
        backgroundColor: scaffoldBg,
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
              color: textColor,
            ),
            onPressed: () => Navigator.pop(context),
          ),
          title: Text(
            loc.newExpense,
            style: TextStyle(
              fontWeight: FontWeight.w800,
              fontSize: 18,
              color: textColor,
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
                  _buildReceiptPickerCard(
                    isArabic,
                    cardBg,
                    borderColor,
                    textColor,
                    subTextColor,
                    isDark,
                  ),
                  const SizedBox(height: 20),
                  _buildTextField(
                    controller: _titleController,
                    label: isArabic
                        ? 'عنوان الفاتورة / الوصف *'
                        : 'Expense Title / Description *',
                    hint: isArabic
                        ? 'مثال: فاتورة كهرباء، مشتريات ماركت'
                        : 'e.g. Electricity bill, Groceries',
                    icon: Icons.receipt_long_rounded,
                    textColor: textColor,
                    subTextColor: subTextColor,
                    inputFill: inputFill,
                    borderColor: borderColor,
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
                    textColor: textColor,
                    subTextColor: subTextColor,
                    inputFill: inputFill,
                    borderColor: borderColor,
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
                              ? 'المبلغ الإجمالي *'
                              : 'Total Amount *',
                          hint: '0.00',
                          icon: Icons.attach_money_rounded,
                          textColor: textColor,
                          subTextColor: subTextColor,
                          inputFill: inputFill,
                          borderColor: borderColor,
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
                          textColor: textColor,
                          subTextColor: subTextColor,
                          inputFill: inputFill,
                          borderColor: borderColor,
                          dropdownColor: cardBg,
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
                    textColor: textColor,
                    subTextColor: subTextColor,
                    inputFill: inputFill,
                    borderColor: borderColor,
                    dropdownColor: cardBg,
                    onChanged: (val) {
                      if (val != null) setState(() => _selectedCategory = val);
                    },
                  ),
                  const SizedBox(height: 14),
                  InkWell(
                    onTap: () =>
                        _pickDate(isDark, cardBg, textColor, borderColor),
                    borderRadius: BorderRadius.circular(14),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 14,
                      ),
                      decoration: BoxDecoration(
                        color: inputFill,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: borderColor),
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
                                  color: subTextColor,
                                  fontSize: 11.5,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                DateFormat('yyyy-MM-dd').format(_selectedDate),
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 14,
                                  color: textColor,
                                ),
                              ),
                            ],
                          ),
                          const Spacer(),
                          Icon(
                            Icons.keyboard_arrow_down_rounded,
                            color: subTextColor,
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
                    textColor: textColor,
                    subTextColor: subTextColor,
                    inputFill: inputFill,
                    borderColor: borderColor,
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

  Widget _buildReceiptPickerCard(
    bool isArabic,
    Color cardBg,
    Color borderColor,
    Color textColor,
    Color subTextColor,
    bool isDark,
  ) {
    return Container(
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: borderColor),
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
                    color: isDark
                        ? const Color(0xFF070D1E)
                        : const Color(0xFFF1F5F9),
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
                        foregroundColor: isDark
                            ? const Color(0xFF38BDF8)
                            : const Color(0xFF4F46E5),
                        side: BorderSide(color: borderColor),
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
                        backgroundColor: isDark
                            ? const Color(0xFF1E293B)
                            : const Color(0xFF0F172A),
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
    required Color textColor,
    required Color subTextColor,
    required Color inputFill,
    required Color borderColor,
    int maxLines = 1,
    TextInputType? keyboardType,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: controller,
      maxLines: maxLines,
      keyboardType: keyboardType,
      validator: validator,
      style: TextStyle(
        fontSize: 14,
        fontWeight: FontWeight.w600,
        color: textColor,
      ),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: TextStyle(color: subTextColor, fontSize: 13),
        hintText: hint,
        hintStyle: TextStyle(
          color: subTextColor.withValues(alpha: 0.6),
          fontSize: 13,
        ),
        prefixIcon: Icon(icon, color: const Color(0xFF4F46E5), size: 20),
        filled: true,
        fillColor: inputFill,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 14,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: borderColor),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: borderColor),
        ),
        focusedBorder: const OutlineInputBorder(
          borderRadius: BorderRadius.all(Radius.circular(14)),
          borderSide: BorderSide(color: Color(0xFF4F46E5), width: 1.5),
        ),
      ),
    );
  }

  Widget _buildDropdown({
    required String label,
    required String selectedValue,
    required List<String> items,
    required void Function(String?) onChanged,
    required Color textColor,
    required Color subTextColor,
    required Color inputFill,
    required Color borderColor,
    required Color dropdownColor,
    IconData? icon,
  }) {
    return DropdownButtonFormField<String>(
      initialValue: selectedValue,
      dropdownColor: dropdownColor,
      style: TextStyle(
        fontSize: 13.5,
        fontWeight: FontWeight.w600,
        color: textColor,
      ),
      items: items.map((item) {
        return DropdownMenuItem(
          value: item,
          child: Text(
            item,
            style: TextStyle(
              fontSize: 13.5,
              fontWeight: FontWeight.w600,
              color: textColor,
            ),
          ),
        );
      }).toList(),
      onChanged: onChanged,
      decoration: InputDecoration(
        labelText: label,
        labelStyle: TextStyle(color: subTextColor, fontSize: 13),
        prefixIcon: icon != null
            ? Icon(icon, color: const Color(0xFF4F46E5), size: 20)
            : null,
        filled: true,
        fillColor: inputFill,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 14,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: borderColor),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: borderColor),
        ),
        focusedBorder: const OutlineInputBorder(
          borderRadius: BorderRadius.all(Radius.circular(14)),
          borderSide: BorderSide(color: Color(0xFF4F46E5), width: 1.5),
        ),
      ),
    );
  }
}
