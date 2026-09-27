import 'dart:convert';
import 'dart:io';
import 'dart:js_interop';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:web/web.dart' as web;
import '../../data/models/expense_model.dart';

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
    final String printDate = DateFormat(
      'yyyy-MM-dd HH:mm',
    ).format(DateTime.now());

    // -------------------------------------------------------------------------
    // 1. طريقة الويب: تصميم HTML احترافي وفخم يفتح في إكسل كجدول منسق ومرتب 100%
    // -------------------------------------------------------------------------
    if (kIsWeb) {
      final StringBuffer htmlBuffer = StringBuffer();

      htmlBuffer.writeln('''
<html xmlns:o="urn:schemas-microsoft-com:office:office" 
      xmlns:x="urn:schemas-microsoft-com:office:excel" 
      xmlns="http://www.w3.org/TR/REC-html40">
<head>
<meta http-equiv="Content-Type" content="text/html; charset=utf-8">
<style>
  body { font-family: 'Segoe UI', Tahoma, Arial, sans-serif; direction: rtl; }
  table { border-collapse: collapse; width: 100%; margin-top: 10px; }
  th { background-color: #1E293B; color: #FFFFFF; font-weight: bold; padding: 12px 14px; border: 1px solid #CBD5E1; text-align: center; }
  td { padding: 10px 14px; border: 1px solid #E2E8F0; text-align: center; color: #334155; mso-number-format:"\\@"; }
  tr:nth-child(even) { background-color: #F8FAFC; }
  .total-row { background-color: #EEF2FF; font-weight: bold; color: #312E81; }
  .title-header { font-size: 18px; font-weight: bold; color: #0F172A; text-align: center; padding: 16px; }
  .sub-header { font-size: 12px; color: #64748B; text-align: center; padding-bottom: 12px; }
</style>
</head>
<body>
  <div class="title-header">كشف المصاريف والنفقات المالية</div>
  <div class="sub-header">تاريخ الإصدار: $printDate | إجمالي السجلات: ${expenses.length}</div>
  <table>
    <thead>
      <tr>
        <th>م</th>
        <th>التاريخ</th>
        <th>بيان المصروف</th>
        <th>الجهة / المتجر</th>
        <th>التصنيف</th>
        <th>المبلغ</th>
        <th>العملة</th>
        <th>ملاحظات إضافية</th>
      </tr>
    </thead>
    <tbody>
''');

      for (int i = 0; i < expenses.length; i++) {
        final exp = expenses[i];
        final index = i + 1;
        final date = DateFormat('yyyy-MM-dd').format(exp.expenseDate);
        final title = exp.title;
        final merchant =
            (exp.merchantName != null && exp.merchantName!.isNotEmpty)
            ? exp.merchantName!
            : '—';
        final category = exp.category;
        final amount = exp.amount.toStringAsFixed(2);
        final currency = exp.currency;
        final notes = (exp.notes != null && exp.notes!.isNotEmpty)
            ? exp.notes!
            : '—';

        htmlBuffer.writeln('''
      <tr>
        <td>$index</td>
        <td>$date</td>
        <td style="text-align: right;">$title</td>
        <td style="text-align: right;">$merchant</td>
        <td>$category</td>
        <td style="font-weight: bold;">$amount</td>
        <td>$currency</td>
        <td style="text-align: right;">$notes</td>
      </tr>
''');
      }

      htmlBuffer.writeln('''
      <tr class="total-row">
        <td colspan="5" style="text-align: center;">المجموع الكلي للمصاريف</td>
        <td style="font-weight: 900; font-size: 15px;">${totalAmount.toStringAsFixed(2)}</td>
        <td>TRY</td>
        <td></td>
      </tr>
    </tbody>
  </table>
</body>
</html>
''');

      final Uint8List bytes = utf8.encode(htmlBuffer.toString());
      final filename =
          'كشف_المصاريف_${DateFormat('yyyy-MM-dd').format(DateTime.now())}.xls';

      // بديل متوافق مع WebAssembly (package:web) بدل universal_html القديمة
      final blob = web.Blob(
        [bytes.toJS].toJS,
        web.BlobPropertyBag(type: 'application/vnd.ms-excel;charset=utf-8'),
      );
      final url = web.URL.createObjectURL(blob);
      final anchor = web.document.createElement('a') as web.HTMLAnchorElement
        ..href = url
        ..download = filename
        ..style.display = 'none';
      web.document.body!.appendChild(anchor);
      anchor.click();
      anchor.remove();
      web.URL.revokeObjectURL(url);
    }
    // -------------------------------------------------------------------------
    // 2. طريقة الموبايل: ملف CSV منظم ومضبوط للمشاركة
    // -------------------------------------------------------------------------
    else {
      try {
        final List<List<dynamic>> rows = [];
        rows.add(['كشف المصاريف والنفقات المالية']);
        rows.add([
          'تاريخ الإصدار:',
          printDate,
          'إجمالي السجلات:',
          expenses.length,
        ]);
        rows.add([]);
        rows.add([
          'م',
          'التاريخ',
          'بيان المصروف',
          'الجهة / المتجر',
          'التصنيف',
          'المبلغ',
          'العملة',
          'ملاحظات إضافية',
        ]);

        for (int i = 0; i < expenses.length; i++) {
          final exp = expenses[i];
          rows.add([
            i + 1,
            DateFormat('yyyy-MM-dd').format(exp.expenseDate),
            exp.title,
            exp.merchantName ?? '—',
            exp.category,
            exp.amount.toStringAsFixed(2),
            exp.currency,
            exp.notes ?? '—',
          ]);
        }

        rows.add([]);
        rows.add([
          'المجموع الكلي',
          '',
          '',
          '',
          '',
          totalAmount.toStringAsFixed(2),
          'TRY',
          '',
        ]);

        String csvData = rows
            .map((row) => row.map((val) => '"$val"').join(','))
            .join('\n');
        final List<int> bytes = utf8.encode('\uFEFF$csvData');
        final String dateStr = DateFormat('yyyy_MM_dd').format(DateTime.now());
        final filename = 'Expense_Report_$dateStr.csv';

        final directory = await getTemporaryDirectory();
        final file = File('${directory.path}/$filename');
        await file.writeAsBytes(bytes);

        final xFile = XFile(file.path);
        // ignore: deprecated_member_use
        await Share.shareXFiles(
          [xFile],
          text: 'كشف المصاريف والنفقات المالية - Alhelal Smart Expense',
          sharePositionOrigin: const Rect.fromLTWH(0, 0, 10, 10 / 2),
        );
      } catch (e) {
        if (context != null && context.mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text('حدث خطأ أثناء التصدير: $e')));
        }
      }
    }
  }
}