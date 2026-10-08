import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import '../../data/models/expense_model.dart';

class PdfExporter {
  static Future<Uint8List> buildPdfDocument({
    required List<ExpenseModel> expenses,
    required String periodName,
    required double totalAmount,
  }) async {
    final pdf = pw.Document();
    final arabicFont = await PdfGoogleFonts.amiriRegular();
    final arabicFontBold = await PdfGoogleFonts.amiriBold();

    final now = DateTime.now();
    final reportDate = DateFormat('yyyy-MM-dd HH:mm').format(now);

    final Map<String, double> categoryTotals = {};
    for (var exp in expenses) {
      categoryTotals[exp.category] = (categoryTotals[exp.category] ?? 0.0) + exp.amount;
    }

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        textDirection: pw.TextDirection.rtl,
        theme: pw.ThemeData.withFont(base: arabicFont, bold: arabicFontBold),
        margin: const pw.EdgeInsets.all(32),
        build: (context) => [
          pw.Container(
            padding: const pw.EdgeInsets.only(bottom: 16),
            decoration: const pw.BoxDecoration(
              border: pw.Border(bottom: pw.BorderSide(color: PdfColors.indigo700, width: 2)),
            ),
            child: pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text(
                      'كشف المصاريف والعمليات المالية',
                      style: pw.TextStyle(fontSize: 22, fontWeight: pw.FontWeight.bold, color: PdfColors.indigo900),
                    ),
                    pw.SizedBox(height: 4),
                    pw.Text('التقرير المالي الموحد لنظام إدارة النفقات', style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey700)),
                  ],
                ),
                pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.end,
                  children: [
                    pw.Text('تاريخ الإصدار: $reportDate', style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey700)),
                    pw.Text('الفترة: $periodName', style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold, color: PdfColors.indigo700)),
                  ],
                ),
              ],
            ),
          ),
          pw.SizedBox(height: 20),
          pw.Row(
            children: [
              pw.Expanded(
                child: pw.Container(
                  padding: const pw.EdgeInsets.all(12),
                  decoration: pw.BoxDecoration(
                    color: PdfColors.grey100,
                    borderRadius: pw.BorderRadius.circular(8),
                    border: pw.Border.all(color: PdfColors.grey300),
                  ),
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text('إجمالي المصروفات', style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey700)),
                      pw.SizedBox(height: 4),
                      pw.Text('${totalAmount.toStringAsFixed(2)} TRY', style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold, color: PdfColors.indigo900)),
                    ],
                  ),
                ),
              ),
              pw.SizedBox(width: 14),
              pw.Expanded(
                child: pw.Container(
                  padding: const pw.EdgeInsets.all(12),
                  decoration: pw.BoxDecoration(
                    color: PdfColors.grey100,
                    borderRadius: pw.BorderRadius.circular(8),
                    border: pw.Border.all(color: PdfColors.grey300),
                  ),
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text('عدد الفواتير المقيدة', style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey700)),
                      pw.SizedBox(height: 4),
                      pw.Text('${expenses.length} عملية', style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold, color: PdfColors.indigo900)),
                    ],
                  ),
                ),
              ),
            ],
          ),
          pw.SizedBox(height: 20),
          pw.Text('توزيع النفقات حسب التصنيف:', style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold, color: PdfColors.grey800)),
          pw.SizedBox(height: 8),
          pw.TableHelper.fromTextArray(
            headers: ['التصنيف', 'النسبة', 'المجموع'],
            data: categoryTotals.entries.map((e) {
              final pct = totalAmount > 0 ? ((e.value / totalAmount) * 100).toStringAsFixed(1) : '0';
              return [e.key, '$pct%', '${e.value.toStringAsFixed(2)} TRY'];
            }).toList(),
            headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold, color: PdfColors.white, fontSize: 10),
            headerDecoration: const pw.BoxDecoration(color: PdfColors.indigo800),
            cellStyle: const pw.TextStyle(fontSize: 9),
            cellAlignment: pw.Alignment.center,
            cellHeight: 22,
          ),
          pw.SizedBox(height: 24),
          pw.Text('بيان العمليات التفصيلية:', style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold, color: PdfColors.grey800)),
          pw.SizedBox(height: 8),
          pw.TableHelper.fromTextArray(
            headers: ['#', 'بيان الفاتورة', 'المتجر / الشركة', 'التصنيف', 'التاريخ', 'المبلغ'],
            data: List.generate(expenses.length, (i) {
              final exp = expenses[i];
              return [
                '${i + 1}',
                exp.title,
                exp.merchantName ?? '-',
                exp.category,
                DateFormat('yyyy-MM-dd').format(exp.expenseDate),
                '${exp.amount.toStringAsFixed(2)} ${exp.currency}',
              ];
            }),
            headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold, color: PdfColors.white, fontSize: 10),
            headerDecoration: const pw.BoxDecoration(color: PdfColors.blueGrey800),
            rowDecoration: const pw.BoxDecoration(border: pw.Border(bottom: pw.BorderSide(color: PdfColors.grey200, width: 0.5))),
            cellStyle: const pw.TextStyle(fontSize: 9),
            cellAlignment: pw.Alignment.center,
            cellHeight: 24,
          ),
        ],
      ),
    );

    return await pdf.save();
  }

  static Future<void> exportExpenseReport({
    required List<ExpenseModel> expenses,
    required String periodName,
    required double totalAmount,
    bool isDirectDownload = true,
  }) async {
    final bytes = await buildPdfDocument(
      expenses: expenses,
      periodName: periodName,
      totalAmount: totalAmount,
    );

    final fileName = 'كشف_المصاريف_${DateFormat('yyyyMMdd_HHmm').format(DateTime.now())}.pdf';

    if (!kIsWeb && Platform.isWindows) {
      Directory? downloadDir = await getDownloadsDirectory();
      downloadDir ??= await getApplicationDocumentsDirectory();
      final file = File('${downloadDir.path}\\$fileName');
      await file.writeAsBytes(bytes);
      await Process.run('explorer.exe', [file.path]);
      return;
    }

    if (isDirectDownload) {
      await Printing.sharePdf(bytes: bytes, filename: fileName);
    }
  }
}