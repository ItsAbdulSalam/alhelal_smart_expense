import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import '../../core/utils/pdf_exporter.dart';
import '../../data/models/expense_model.dart';

class ReportPreviewScreen extends StatelessWidget {
  final List<ExpenseModel> expenses;
  final String periodName;
  final double totalAmount;

  const ReportPreviewScreen({
    super.key,
    required this.expenses,
    required this.periodName,
    required this.totalAmount,
  });

  Future<void> _openNativePrint(BuildContext context) async {
    try {
      final bytes = await PdfExporter.buildPdfDocument(
        expenses: expenses,
        periodName: periodName,
        totalAmount: totalAmount,
      );

      final tempDir = await getTemporaryDirectory();
      final file = File('${tempDir.path}\\Expense_Report_Print.pdf');
      await file.writeAsBytes(bytes);

      // فتح المستند في قارئ PDF الرسمي للنظام (Edge / Adobe) للحصول على أفضل تجربة طباعة
      if (!kIsWeb && Platform.isWindows) {
        await Process.run('cmd', ['/c', 'start', '', file.path]);
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('تعذر فتح واجهة الطباعة: $e'),
            backgroundColor: const Color(0xFFE11D48),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final scaffoldBg = isDark
        ? const Color(0xFF030712)
        : const Color(0xFFF8FAFC);
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

    final Map<String, double> categoryTotals = {};
    for (var exp in expenses) {
      categoryTotals[exp.category] =
          (categoryTotals[exp.category] ?? 0.0) + exp.amount;
    }

    final printDate = DateFormat('yyyy-MM-dd HH:mm').format(DateTime.now());

    return Scaffold(
      backgroundColor: scaffoldBg,
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.transparent,
        scrolledUnderElevation: 0,
        leading: IconButton(
          icon: Icon(
            Icons.arrow_back_ios_new_rounded,
            color: textColor,
            size: 20,
          ),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'التقرير المالي التنفيذي',
          style: TextStyle(
            color: textColor,
            fontWeight: FontWeight.w800,
            fontSize: 18,
          ),
        ),
        actions: [
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF4F46E5),
              foregroundColor: Colors.white,
              elevation: 0,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            icon: const Icon(Icons.print_rounded, size: 18),
            label: const Text(
              'طباعة المستند',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
            ),
            onPressed: () => _openNativePrint(context),
          ),
          const SizedBox(width: 8),
          IconButton(
            tooltip: 'تنزيل PDF',
            icon: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: cardBg,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: borderColor),
              ),
              child: const Icon(
                Icons.download_rounded,
                color: Color(0xFF10B981),
                size: 18,
              ),
            ),
            onPressed: () async {
              await PdfExporter.exportExpenseReport(
                expenses: expenses,
                periodName: periodName,
                totalAmount: totalAmount,
                isDirectDownload: true,
              );
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('تم تنزيل نسخة PDF بنجاح في مجلد Downloads'),
                    backgroundColor: Color(0xFF10B981),
                  ),
                );
              }
            },
          ),
          const SizedBox(width: 16),
        ],
      ),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1000),
            child: ListView(
              padding: const EdgeInsets.all(24),
              children: [
                // Header Banner
                Container(
                  padding: const EdgeInsets.all(28),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(20),
                    gradient: const LinearGradient(
                      colors: [
                        Color(0xFF1E1B4B),
                        Color(0xFF312E81),
                        Color(0xFF4338CA),
                      ],
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF4338CA).withValues(alpha: 0.25),
                        blurRadius: 18,
                        offset: const Offset(0, 6),
                      ),
                    ],
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Row(
                            children: [
                              Icon(
                                Icons.verified_rounded,
                                color: Color(0xFF38BDF8),
                                size: 22,
                              ),
                              SizedBox(width: 8),
                              Text(
                                'نظام إدارة المصاريف المالية المعتمد',
                                style: TextStyle(
                                  color: Colors.white70,
                                  fontSize: 13,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          const Text(
                            'كشف الحساب والنفقات المالي الموحد',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 22,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            'الفترة المحددة: $periodName  •  تاريخ التدقيق: $printDate',
                            style: const TextStyle(
                              color: Colors.white70,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 10,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: Colors.white24),
                        ),
                        child: Column(
                          children: [
                            const Text(
                              'إجمالي المبلغ',
                              style: TextStyle(
                                color: Colors.white70,
                                fontSize: 11,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              '${totalAmount.toStringAsFixed(2)} ₺',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 20,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),

                // KPI Cards
                Row(
                  children: [
                    Expanded(
                      child: _buildMetricCard(
                        'إجمالي النفقات',
                        '${totalAmount.toStringAsFixed(2)} TRY',
                        Icons.account_balance_wallet_rounded,
                        const Color(0xFF4F46E5),
                        cardBg,
                        borderColor,
                        textColor,
                        subTextColor,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: _buildMetricCard(
                        'عدد الفواتير والعمليات',
                        '${expenses.length} عملية موثقة',
                        Icons.receipt_long_rounded,
                        const Color(0xFF10B981),
                        cardBg,
                        borderColor,
                        textColor,
                        subTextColor,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: _buildMetricCard(
                        'متوسط العملية الواحدة',
                        '${(expenses.isNotEmpty ? (totalAmount / expenses.length) : 0).toStringAsFixed(2)} TRY',
                        Icons.analytics_rounded,
                        const Color(0xFFF59E0B),
                        cardBg,
                        borderColor,
                        textColor,
                        subTextColor,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),

                // Category Summary
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: cardBg,
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(color: borderColor),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'ملخص توزيع النفقات حسب الأقسام',
                        style: TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 15,
                          color: textColor,
                        ),
                      ),
                      const SizedBox(height: 16),
                      Wrap(
                        spacing: 12,
                        runSpacing: 12,
                        children: categoryTotals.entries.map((e) {
                          final pct = totalAmount > 0
                              ? ((e.value / totalAmount) * 100).toStringAsFixed(
                                  1,
                                )
                              : '0';
                          return Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 14,
                              vertical: 8,
                            ),
                            decoration: BoxDecoration(
                              color: isDark
                                  ? const Color(0xFF1E293B)
                                  : const Color(0xFFF1F5F9),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: borderColor),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  e.key,
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 12.5,
                                    color: textColor,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  '$pct%  (${e.value.toStringAsFixed(1)} TRY)',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w800,
                                    fontSize: 12,
                                    color: Color(0xFF4F46E5),
                                  ),
                                ),
                              ],
                            ),
                          );
                        }).toList(),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),

                // Details Table
                Container(
                  decoration: BoxDecoration(
                    color: cardBg,
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(color: borderColor),
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(18),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 20,
                            vertical: 14,
                          ),
                          color: isDark
                              ? const Color(0xFF1E293B)
                              : const Color(0xFFEEF2FF),
                          child: Row(
                            children: [
                              _tableHeadCell('#', width: 40, color: textColor),
                              _tableHeadCell(
                                'تاريخ الفاتورة',
                                width: 110,
                                color: textColor,
                              ),
                              Expanded(
                                flex: 3,
                                child: _tableHeadCell(
                                  'بيان المصروف',
                                  color: textColor,
                                ),
                              ),
                              Expanded(
                                flex: 2,
                                child: _tableHeadCell(
                                  'المتجر / الجهة',
                                  color: textColor,
                                ),
                              ),
                              _tableHeadCell(
                                'التصنيف',
                                width: 120,
                                color: textColor,
                              ),
                              _tableHeadCell(
                                'المبلغ',
                                width: 110,
                                color: textColor,
                                align: TextAlign.end,
                              ),
                            ],
                          ),
                        ),
                        Divider(height: 1, color: borderColor),
                        ListView.separated(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          itemCount: expenses.length,
                          separatorBuilder: (_, _) =>
                              Divider(height: 1, color: borderColor),
                          itemBuilder: (context, i) {
                            final exp = expenses[i];
                            return Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 20,
                                vertical: 14,
                              ),
                              child: Row(
                                children: [
                                  SizedBox(
                                    width: 40,
                                    child: Text(
                                      '${i + 1}',
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: subTextColor,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                  SizedBox(
                                    width: 110,
                                    child: Text(
                                      DateFormat(
                                        'yyyy-MM-dd',
                                      ).format(exp.expenseDate),
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: subTextColor,
                                      ),
                                    ),
                                  ),
                                  Expanded(
                                    flex: 3,
                                    child: Text(
                                      exp.title,
                                      style: TextStyle(
                                        fontSize: 13,
                                        fontWeight: FontWeight.w700,
                                        color: textColor,
                                      ),
                                    ),
                                  ),
                                  Expanded(
                                    flex: 2,
                                    child: Text(
                                      exp.merchantName ?? '—',
                                      style: TextStyle(
                                        fontSize: 12.5,
                                        color: subTextColor,
                                      ),
                                    ),
                                  ),
                                  SizedBox(
                                    width: 120,
                                    child: Text(
                                      exp.category,
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: textColor,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ),
                                  SizedBox(
                                    width: 110,
                                    child: Text(
                                      '${exp.amount.toStringAsFixed(2)} ${exp.currency}',
                                      textAlign: TextAlign.end,
                                      style: TextStyle(
                                        fontSize: 13.5,
                                        fontWeight: FontWeight.w900,
                                        color: isDark
                                            ? const Color(0xFF38BDF8)
                                            : const Color(0xFF4F46E5),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            );
                          },
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 32),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _tableHeadCell(
    String text, {
    double? width,
    required Color color,
    TextAlign align = TextAlign.start,
  }) {
    final w = Text(
      text,
      textAlign: align,
      style: TextStyle(
        fontWeight: FontWeight.w800,
        fontSize: 12.5,
        color: color,
      ),
    );
    return width != null ? SizedBox(width: width, child: w) : w;
  }

  Widget _buildMetricCard(
    String title,
    String value,
    IconData icon,
    Color iconColor,
    Color cardBg,
    Color borderColor,
    Color textColor,
    Color subTextColor,
  ) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: borderColor),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: iconColor.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: iconColor, size: 22),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(color: subTextColor, fontSize: 12),
                ),
                const SizedBox(height: 4),
                Text(
                  value,
                  style: TextStyle(
                    color: textColor,
                    fontSize: 15,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
