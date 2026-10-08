import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import '../../data/models/expense_model.dart';
import 'csv_saver_stub.dart'
    if (dart.library.js_interop) 'csv_saver_web.dart'
    if (dart.library.io) 'csv_saver_mobile.dart';

class CsvExporter {
  static Future<void> exportExpenses(
    List<ExpenseModel> expenses, {
    BuildContext? context,
  }) async {
    if (expenses.isEmpty) {
      if (context != null && context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('لا توجد مصاريف لتصديرها!')),
        );
      }
      return;
    }

    final double totalAmount = expenses.fold(0.0, (sum, e) => sum + e.amount);
    final String printDate = DateFormat('yyyy-MM-dd HH:mm').format(DateTime.now());

    try {
      final StringBuffer excelHtml = StringBuffer();
      excelHtml.writeln('''
<html xmlns:o="urn:schemas-microsoft-com:office:office" 
      xmlns:x="urn:schemas-microsoft-com:office:excel" 
      xmlns="http://www.w3.org/TR/REC-html40">
<head>
<meta http-equiv="Content-Type" content="text/html; charset=utf-8">
<!--[if gte mso 9]>
<xml>
 <x:ExcelWorkbook>
  <x:ExcelWorksheets>
   <x:ExcelWorksheet>
    <x:Name>كشف المصاريف</x:Name>
    <x:WorksheetOptions>
     <x:DisplayRightToLeft/>
     <x:DoNotDisplayGridlines/>
    </x:WorksheetOptions>
   </x:ExcelWorksheet>
  </x:ExcelWorksheets>
 </x:ExcelWorkbook>
</xml>
<![endif]-->
<style>
  body { font-family: 'Segoe UI', Arial, sans-serif; direction: rtl; }
  .report-title { font-size: 20px; font-weight: bold; color: #1E1B4B; text-align: center; padding: 15px; }
  .report-meta { font-size: 12px; color: #475569; text-align: center; padding-bottom: 15px; }
  table { border-collapse: collapse; width: 100%; margin: 0 auto; }
  th { background-color: #312E81; color: #ffffff; font-weight: bold; padding: 12px 18px; border: 1px solid #1E1B4B; text-align: center; font-size: 13px; }
  td { padding: 10px 14px; border: 1px solid #CBD5E1; text-align: center; font-size: 12px; color: #1E293B; mso-number-format:"\\@"; }
  .td-text { text-align: right; }
  .td-money { font-weight: bold; color: #047857; text-align: center; }
  tr:nth-child(even) { background-color: #F8FAFC; }
  .total-row { background-color: #EEF2FF; font-weight: bold; border-top: 2px solid #312E81; }
  .total-label { font-size: 14px; color: #1E1B4B; font-weight: bold; text-align: center; }
  .total-val { font-size: 15px; color: #1E1B4B; font-weight: 900; }
</style>
</head>
<body>
  <div class="report-title">كشف المصاريف والعمليات المالية</div>
  <div class="report-meta">تاريخ الاستخراج: $printDate | عدد الفواتير: ${expenses.length}</div>
  <table>
    <thead>
      <tr>
        <th style="width: 50px;">#</th>
        <th style="width: 120px;">التاريخ</th>
        <th style="width: 220px;">بيان الفاتورة</th>
        <th style="width: 180px;">المتجر / الجهة</th>
        <th style="width: 140px;">التصنيف</th>
        <th style="width: 110px;">المبلغ</th>
        <th style="width: 80px;">العملة</th>
        <th style="width: 280px;">الملاحظات والبيانات</th>
      </tr>
    </thead>
    <tbody>
''');

      for (int i = 0; i < expenses.length; i++) {
        final exp = expenses[i];
        final merchant = (exp.merchantName != null && exp.merchantName!.trim().isNotEmpty) ? exp.merchantName! : '—';
        final notes = (exp.notes != null && exp.notes!.trim().isNotEmpty) ? exp.notes! : '—';
        final date = DateFormat('yyyy-MM-dd').format(exp.expenseDate);

        excelHtml.writeln('''
      <tr>
        <td>${i + 1}</td>
        <td>$date</td>
        <td class="td-text">${exp.title}</td>
        <td class="td-text">$merchant</td>
        <td>${exp.category}</td>
        <td class="td-money">${exp.amount.toStringAsFixed(2)}</td>
        <td>${exp.currency}</td>
        <td class="td-text">$notes</td>
      </tr>
''');
      }

      excelHtml.writeln('''
      <tr class="total-row">
        <td colspan="5" class="total-label">المجموع الإجمالي لكافة النفقات</td>
        <td class="total-val">${totalAmount.toStringAsFixed(2)}</td>
        <td style="font-weight: bold;">TRY</td>
        <td></td>
      </tr>
    </tbody>
  </table>
</body>
</html>
''');

      final List<int> bytes = utf8.encode(excelHtml.toString());
      final String filename = 'Expenses_Report_${DateFormat('yyyyMMdd_HHmm').format(DateTime.now())}.xls';

      if (!kIsWeb && Platform.isWindows) {
        Directory? downloadDir = await getDownloadsDirectory();
        downloadDir ??= await getApplicationDocumentsDirectory();
        final file = File('${downloadDir.path}\\$filename');
        await file.writeAsBytes(bytes);

        if (context != null && context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('تم تصدير ملف الإكسل الاحترافي بنجاح إلى التنزيلات: ${file.path}'),
              backgroundColor: const Color(0xFF10B981),
            ),
          );
        }
        await Process.run('explorer.exe', [file.path]);
        return;
      }

      await saveAndLaunchCsv(bytes, filename);
    } catch (e) {
      if (context != null && context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('حدث خطأ أثناء التصدير: $e'),
            backgroundColor: const Color(0xFFE11D48),
          ),
        );
      }
    }
  }
}