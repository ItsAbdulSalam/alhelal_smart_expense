import 'dart:ui' as ui;
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/utils/csv_exporter.dart';
import '../../core/utils/pdf_exporter.dart';
import '../../data/models/expense_model.dart';
import '../../data/repositories/expense_repository.dart';
import 'add_expense_screen.dart';
import 'auth_screen.dart';
import '../../core/utils/locale_controller.dart';
import '../../l10n/app_localizations.dart';
import 'profile_screen.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  late final ExpenseRepository _repository;
  Future<List<ExpenseModel>>? _expensesFuture;
  int _touchedChartIndex = -1;

  double _monthlyBudget = 5000.0;

  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  String _selectedCategory = 'الكل';
  String _selectedTimeFilter = 'هذا الشهر';
  DateTimeRange? _customDateRange;

  // تخزين الكاش لتفادي تكرار عمليات التصفية في كل frame
  List<ExpenseModel>? _cachedAllExpenses;
  List<ExpenseModel> _cachedFilteredExpenses = [];
  double _cachedTotalAmount = 0.0;
  Map<String, double> _cachedCategoryTotals = {};

  @override
  void initState() {
    super.initState();
    _repository = ExpenseRepository(Supabase.instance.client);

    // تأخير الـ 150ms الضروري لأداء التليفون وخفض الـ TBT
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Future.delayed(const Duration(milliseconds: 150), () {
        if (mounted) _loadExpenses();
      });
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _loadExpenses() {
    setState(() {
      _expensesFuture = _repository.getExpenses();
      _touchedChartIndex = -1;
    });
  }

  void _recomputeMetrics(List<ExpenseModel> allExpenses) {
    _cachedAllExpenses = allExpenses;
    _cachedFilteredExpenses = _filterExpenses(allExpenses);
    _cachedTotalAmount = _calculateTotal(_cachedFilteredExpenses);
    _cachedCategoryTotals = _calculateCategoryTotals(_cachedFilteredExpenses);
  }

  bool _matchesDateFilter(DateTime date) {
    final now = DateTime.now();

    switch (_selectedTimeFilter) {
      case 'هذا الشهر':
      case 'This Month':
        return date.year == now.year && date.month == now.month;

      case 'الشهر السابق':
      case 'Last Month':
        final previousMonthDate = DateTime(now.year, now.month - 1, 1);
        return date.year == previousMonthDate.year &&
            date.month == previousMonthDate.month;

      case 'فترة مخصصة':
      case 'Custom Period':
        if (_customDateRange == null) return true;
        final start = DateTime(
          _customDateRange!.start.year,
          _customDateRange!.start.month,
          _customDateRange!.start.day,
        );
        final end = DateTime(
          _customDateRange!.end.year,
          _customDateRange!.end.month,
          _customDateRange!.end.day,
          23,
          59,
          59,
        );
        return date.isAfter(start.subtract(const Duration(seconds: 1))) &&
            date.isBefore(end.add(const Duration(seconds: 1)));

      case 'الكل':
      case 'All':
      default:
        return true;
    }
  }

  String _getTranslatedCategory(BuildContext context, String category) {
    final loc = AppLocalizations.of(context)!;
    switch (category.trim()) {
      case 'طعام ومشروبات':
      case 'Food & Drinks':
        return loc.foodAndDrink;
      case 'تسوق':
      case 'Shopping':
        return loc.shopping;
      case 'مواصلات':
      case 'Transport':
        return loc.transport;
      case 'فواتير وخدمات':
      case 'Bills & Services':
        return loc.billsAndServices;
      case 'صحة':
      case 'Health':
        return loc.health;
      case 'أخرى':
      case 'Other':
        return loc.other;
      case 'الكل':
      case 'All':
      default:
        return loc.all;
    }
  }

  List<ExpenseModel> _filterExpenses(List<ExpenseModel> allExpenses) {
    final loc = AppLocalizations.of(context)!;
    final query = _searchQuery.trim().toLowerCase();

    return allExpenses.where((expense) {
      final isAll =
          _selectedCategory == 'الكل' ||
          _selectedCategory == 'All' ||
          _selectedCategory == loc.all;

      final matchesCategory =
          isAll ||
          expense.category.trim() == _selectedCategory.trim() ||
          _getTranslatedCategory(context, expense.category) ==
              _selectedCategory;

      final matchesDate = _matchesDateFilter(expense.expenseDate);

      final matchesSearch =
          query.isEmpty ||
          expense.title.toLowerCase().contains(query) ||
          (expense.merchantName?.toLowerCase().contains(query) ?? false) ||
          (expense.notes?.toLowerCase().contains(query) ?? false);

      return matchesCategory && matchesDate && matchesSearch;
    }).toList();
  }

  double _calculateTotal(List<ExpenseModel> expenses) {
    return expenses.fold(0.0, (sum, item) => sum + item.amount);
  }

  Map<String, double> _calculateCategoryTotals(List<ExpenseModel> expenses) {
    final Map<String, double> map = {};
    for (var exp in expenses) {
      final translatedCat = _getTranslatedCategory(context, exp.category);
      map[translatedCat] = (map[translatedCat] ?? 0.0) + exp.amount;
    }
    return map;
  }

  Color _getCategoryColor(String category) {
    if (category.contains('طعام') || category.contains('Food')) {
      return const Color(0xFFF59E0B);
    }
    if (category.contains('تسوق') || category.contains('Shopping')) {
      return const Color(0xFF8B5CF6);
    }
    if (category.contains('مواصلات') || category.contains('Transport')) {
      return const Color(0xFF3B82F6);
    }
    if (category.contains('فواتير') || category.contains('Bills')) {
      return const Color(0xFF10B981);
    }
    if (category.contains('صحة') || category.contains('Health')) {
      return const Color(0xFFEF4444);
    }
    return const Color(0xFF64748B);
  }

  IconData _getCategoryIcon(String category) {
    if (category.contains('طعام') || category.contains('Food')) {
      return Icons.restaurant_rounded;
    }
    if (category.contains('تسوق') || category.contains('Shopping')) {
      return Icons.local_mall_rounded;
    }
    if (category.contains('مواصلات') || category.contains('Transport')) {
      return Icons.directions_subway_rounded;
    }
    if (category.contains('فواتير') || category.contains('Bills')) {
      return Icons.receipt_long_rounded;
    }
    if (category.contains('صحة') || category.contains('Health')) {
      return Icons.favorite_rounded;
    }
    return Icons.category_rounded;
  }

  void _showSetBudgetDialog(
    bool isDark,
    Color cardBg,
    Color textColor,
    Color subTextColor,
    Color borderColor,
  ) {
    final localizations = AppLocalizations.of(context)!;
    final controller = TextEditingController(
      text: _monthlyBudget.toStringAsFixed(0),
    );
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: cardBg,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: BorderSide(color: borderColor),
        ),
        title: Row(
          children: [
            const Icon(Icons.tune_rounded, color: Color(0xFF4F46E5)),
            const SizedBox(width: 8),
            Text(
              localizations.monthlyBudget,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: textColor,
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'أدخل سقف الإنفاق المستهدف لهذا الشهر لتلقي تنبيهات دورية:',
              style: TextStyle(fontSize: 13, color: subTextColor),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: controller,
              style: TextStyle(color: textColor, fontWeight: FontWeight.w700),
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              autofocus: true,
              decoration: InputDecoration(
                suffixText: 'TRY',
                suffixStyle: TextStyle(
                  color: subTextColor,
                  fontWeight: FontWeight.bold,
                ),
                prefixIcon: Icon(
                  Icons.account_balance_wallet_outlined,
                  size: 20,
                  color: subTextColor,
                ),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 12,
                ),
                filled: true,
                fillColor: isDark
                    ? const Color(0xFF0B132B)
                    : const Color(0xFFF8FAFC),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: borderColor),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: borderColor),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(
                    color: Color(0xFF4F46E5),
                    width: 1.5,
                  ),
                ),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(
              localizations.cancel,
              style: TextStyle(color: subTextColor),
            ),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF4F46E5),
              foregroundColor: Colors.white,
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            onPressed: () {
              final val = double.tryParse(controller.text.trim());
              if (val != null && val > 0) {
                setState(() => _monthlyBudget = val);
                Navigator.pop(ctx);
              }
            },
            child: Text(localizations.save),
          ),
        ],
      ),
    );
  }

  void _showExpenseDetails(
    ExpenseModel expense,
    bool isDark,
    Color cardBg,
    Color textColor,
    Color subTextColor,
    Color borderColor,
  ) {
    String? fullImageUrl;
    if (expense.receiptImagePath != null &&
        expense.receiptImagePath!.isNotEmpty) {
      if (expense.receiptImagePath!.startsWith('http')) {
        fullImageUrl = expense.receiptImagePath;
      } else {
        fullImageUrl = Supabase.instance.client.storage
            .from('receipts')
            .getPublicUrl(expense.receiptImagePath!);
      }
    }

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Directionality(
        textDirection: ui.TextDirection.rtl,
        child: Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: cardBg,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
            border: Border.all(color: borderColor),
          ),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 44,
                    height: 4,
                    decoration: BoxDecoration(
                      color: isDark
                          ? const Color(0xFF334155)
                          : const Color(0xFFCBD5E1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(
                        expense.title,
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: textColor,
                        ),
                      ),
                    ),
                    Text(
                      '${expense.amount.toStringAsFixed(2)} ${expense.currency}',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w900,
                        color: textColor,
                      ),
                    ),
                  ],
                ),
                if (expense.merchantName != null &&
                    expense.merchantName!.isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Text(
                    expense.merchantName!,
                    style: TextStyle(color: subTextColor, fontSize: 13),
                  ),
                ],
                Divider(height: 28, color: borderColor),
                _buildDetailRow(
                  Icons.calendar_month_rounded,
                  'تاريخ الفاتورة',
                  DateFormat('yyyy-MM-dd').format(expense.expenseDate),
                  subTextColor,
                  textColor,
                ),
                const SizedBox(height: 10),
                _buildDetailRow(
                  _getCategoryIcon(expense.category),
                  'التصنيف',
                  _getTranslatedCategory(context, expense.category),
                  subTextColor,
                  textColor,
                ),
                if (expense.notes != null && expense.notes!.isNotEmpty) ...[
                  const SizedBox(height: 10),
                  _buildDetailRow(
                    Icons.note_alt_outlined,
                    'ملاحظات',
                    expense.notes!,
                    subTextColor,
                    textColor,
                  ),
                ],
                if (fullImageUrl != null) ...[
                  const SizedBox(height: 20),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(14),
                    child: Image.network(
                      fullImageUrl,
                      height: 200,
                      width: double.infinity,
                      fit: BoxFit.contain,
                      cacheWidth: 600, // منع استهلاك الذاكرة
                    ),
                  ),
                ],
                const SizedBox(height: 20),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildDetailRow(
    IconData icon,
    String label,
    String value,
    Color subTextColor,
    Color textColor,
  ) {
    return Row(
      children: [
        Icon(icon, size: 18, color: subTextColor),
        const SizedBox(width: 8),
        Text(label, style: TextStyle(color: subTextColor, fontSize: 13)),
        const Spacer(),
        Text(
          value,
          style: TextStyle(
            fontWeight: FontWeight.w700,
            fontSize: 13,
            color: textColor,
          ),
        ),
      ],
    );
  }

  Widget _buildBudgetCard(
    double totalSpent,
    bool isDark,
    Color cardBg,
    Color borderColor,
    Color textColor,
    Color subTextColor,
  ) {
    final localizations = AppLocalizations.of(context)!;
    final isArabic = Localizations.localeOf(context).languageCode == 'ar';

    final double ratio = _monthlyBudget > 0
        ? (totalSpent / _monthlyBudget)
        : 0.0;
    final double percentage = (ratio * 100).clamp(0.0, 999.0);
    final double remaining = _monthlyBudget - totalSpent;

    Color stateColor;
    String statusText;
    IconData statusIcon;

    if (ratio >= 1.0) {
      stateColor = const Color(0xFFEF4444);
      statusText = isArabic
          ? 'تجاوزت الميزانية بـ ${(-remaining).toStringAsFixed(1)} TRY!'
          : 'Budget exceeded by ${(-remaining).toStringAsFixed(1)} TRY!';
      statusIcon = Icons.warning_rounded;
    } else if (ratio >= 0.8) {
      stateColor = const Color(0xFFF59E0B);
      statusText = isArabic
          ? 'اقتربت من السقف! المتبقي: ${remaining.toStringAsFixed(1)} TRY'
          : 'Approaching limit! Remaining: ${remaining.toStringAsFixed(1)} TRY';
      statusIcon = Icons.info_outline_rounded;
    } else {
      stateColor = const Color(0xFF10B981);
      statusText = isArabic
          ? 'ضمن الحدود المقبولة. المتبقي: ${remaining.toStringAsFixed(1)} TRY'
          : 'Within acceptable limits. Remaining: ${remaining.toStringAsFixed(1)} TRY';
      statusIcon = Icons.check_circle_outline_rounded;
    }

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: borderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(7),
                    decoration: BoxDecoration(
                      color: stateColor.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(statusIcon, color: stateColor, size: 18),
                  ),
                  const SizedBox(width: 10),
                  Text(
                    localizations.monthlyBudget,
                    style: TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 15,
                      color: textColor,
                    ),
                  ),
                ],
              ),
              InkWell(
                onTap: () => _showSetBudgetDialog(
                  isDark,
                  cardBg,
                  textColor,
                  subTextColor,
                  borderColor,
                ),
                borderRadius: BorderRadius.circular(8),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  child: Text(
                    '${_monthlyBudget.toStringAsFixed(0)} TRY',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                      color: Color(0xFF4F46E5),
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: LinearProgressIndicator(
              value: ratio.clamp(0.0, 1.0),
              minHeight: 10,
              backgroundColor: isDark
                  ? const Color(0xFF1E293B)
                  : const Color(0xFFF1F5F9),
              valueColor: AlwaysStoppedAnimation<Color>(stateColor),
            ),
          ),
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  statusText,
                  style: TextStyle(
                    color: stateColor,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              Text(
                '${percentage.toStringAsFixed(0)}%',
                style: TextStyle(
                  color: stateColor,
                  fontWeight: FontWeight.w900,
                  fontSize: 13,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildInteractiveChart(
    Map<String, double> categoryTotals,
    double totalAmount,
    bool isDark,
    Color cardBg,
    Color borderColor,
    Color textColor,
    Color subTextColor,
  ) {
    final localizations = AppLocalizations.of(context)!;
    final entries = categoryTotals.entries.toList();

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 22),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: borderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  const Icon(
                    Icons.pie_chart_rounded,
                    color: Color(0xFF4F46E5),
                    size: 18,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    localizations.expenseDistribution,
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                      color: textColor,
                    ),
                  ),
                ],
              ),
              Text(
                '${entries.length} ${localizations.sectionsCount}',
                style: TextStyle(
                  fontSize: 12,
                  color: subTextColor,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          Divider(height: 24, color: borderColor),
          LayoutBuilder(
            builder: (context, constraints) {
              final isWide = constraints.maxWidth > 580;
              final chart = SizedBox(
                height: 190,
                width: 190,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    PieChart(
                      PieChartData(
                        pieTouchData: PieTouchData(
                          touchCallback: (event, pieTouchResponse) {
                            setState(() {
                              if (!event.isInterestedForInteractions ||
                                  pieTouchResponse == null ||
                                  pieTouchResponse.touchedSection == null) {
                                _touchedChartIndex = -1;
                                return;
                              }
                              _touchedChartIndex = pieTouchResponse
                                  .touchedSection!
                                  .touchedSectionIndex;
                            });
                          },
                        ),
                        borderData: FlBorderData(show: false),
                        sectionsSpace: 3,
                        centerSpaceRadius: 60,
                        sections: List.generate(entries.length, (i) {
                          final isTouched = i == _touchedChartIndex;
                          return PieChartSectionData(
                            color: _getCategoryColor(entries[i].key),
                            value: entries[i].value,
                            title: '',
                            radius: isTouched ? 30.0 : 22.0,
                          );
                        }),
                      ),
                    ),
                    Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          _touchedChartIndex >= 0 &&
                                  _touchedChartIndex < entries.length
                              ? entries[_touchedChartIndex].key
                              : localizations.totalLabel,
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: subTextColor,
                          ),
                        ),
                        Text(
                          _touchedChartIndex >= 0 &&
                                  _touchedChartIndex < entries.length
                              ? '${entries[_touchedChartIndex].value.toStringAsFixed(1)} ₺'
                              : '${totalAmount.toStringAsFixed(1)} ₺',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w900,
                            color: textColor,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              );

              final legend = Column(
                mainAxisSize: MainAxisSize.min,
                children: entries.map((entry) {
                  final color = _getCategoryColor(entry.key);
                  final percent = totalAmount > 0
                      ? ((entry.value / totalAmount) * 100).toStringAsFixed(1)
                      : '0';
                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: Row(
                      children: [
                        Container(
                          width: 10,
                          height: 10,
                          decoration: BoxDecoration(
                            color: color,
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            entry.key,
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: textColor,
                            ),
                          ),
                        ),
                        Text(
                          '$percent% ',
                          style: TextStyle(fontSize: 12, color: subTextColor),
                        ),
                        Text(
                          '${entry.value.toStringAsFixed(1)} TRY',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w800,
                            color: textColor,
                          ),
                        ),
                      ],
                    ),
                  );
                }).toList(),
              );

              if (isWide) {
                return Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    chart,
                    const SizedBox(width: 48),
                    Flexible(child: legend),
                  ],
                );
              } else {
                return Column(
                  children: [
                    Center(child: chart),
                    const SizedBox(height: 18),
                    legend,
                  ],
                );
              }
            },
          ),
        ],
      ),
    );
  }

  Widget _buildFilterAndSearchBar(
    bool isDark,
    Color cardBg,
    Color borderColor,
    Color textColor,
    Color subTextColor,
  ) {
    final localizations = AppLocalizations.of(context)!;

    final timeFilters = [
      localizations.thisMonth,
      localizations.lastMonth,
      localizations.customPeriod,
      localizations.all,
    ];
    final categories = [
      localizations.all,
      localizations.foodAndDrink,
      localizations.shopping,
      localizations.transport,
      localizations.billsAndServices,
      localizations.health,
      localizations.other,
    ];

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: borderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TextField(
            controller: _searchController,
            style: TextStyle(color: textColor, fontWeight: FontWeight.w600),
            onChanged: (val) {
              setState(() {
                _searchQuery = val;
                if (_cachedAllExpenses != null) {
                  _recomputeMetrics(_cachedAllExpenses!);
                }
              });
            },
            decoration: InputDecoration(
              isDense: true,
              hintText: localizations.searchHint,
              hintStyle: TextStyle(color: subTextColor),
              filled: true,
              fillColor: isDark
                  ? const Color(0xFF0B132B)
                  : const Color(0xFFF8FAFC),
              prefixIcon: const Icon(
                Icons.search_rounded,
                color: Color(0xFF6366F1),
                size: 20,
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: borderColor),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: borderColor),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(
                  color: Color(0xFF4F46E5),
                  width: 1.5,
                ),
              ),
            ),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              const Icon(
                Icons.calendar_today_rounded,
                size: 14,
                color: Color(0xFF4F46E5),
              ),
              const SizedBox(width: 6),
              Text(
                localizations.timeFilter,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: textColor,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: timeFilters.map((tf) {
                final isSelected = _selectedTimeFilter == tf;
                return Padding(
                  padding: const EdgeInsets.only(left: 8),
                  child: InkWell(
                    onTap: () async {
                      if (tf == localizations.customPeriod) {
                        final picked = await showDateRangePicker(
                          context: context,
                          firstDate: DateTime(2022),
                          lastDate: DateTime(2030),
                        );
                        if (picked != null) {
                          setState(() {
                            _selectedTimeFilter = tf;
                            _customDateRange = picked;
                            if (_cachedAllExpenses != null) {
                              _recomputeMetrics(_cachedAllExpenses!);
                            }
                          });
                        }
                      } else {
                        setState(() {
                          _selectedTimeFilter = tf;
                          if (_cachedAllExpenses != null) {
                            _recomputeMetrics(_cachedAllExpenses!);
                          }
                        });
                      }
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 7,
                      ),
                      decoration: BoxDecoration(
                        color: isSelected
                            ? (isDark
                                  ? const Color(0xFF38BDF8)
                                  : const Color(0xFF1E293B))
                            : (isDark
                                  ? const Color(0xFF1E293B)
                                  : const Color(0xFFF1F5F9)),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        tf,
                        style: TextStyle(
                          color: isSelected
                              ? (isDark ? Colors.black : Colors.white)
                              : subTextColor,
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
          Divider(height: 22, color: borderColor),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: categories.map((cat) {
              final isSelected = _selectedCategory == cat;
              return InkWell(
                onTap: () {
                  setState(() {
                    _selectedCategory = cat;
                    if (_cachedAllExpenses != null) {
                      _recomputeMetrics(_cachedAllExpenses!);
                    }
                  });
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 7,
                  ),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? const Color(0xFF4F46E5)
                        : (isDark
                              ? const Color(0xFF1E293B)
                              : const Color(0xFFF1F5F9)),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    cat,
                    style: TextStyle(
                      color: isSelected ? Colors.white : subTextColor,
                      fontWeight: FontWeight.bold,
                      fontSize: 12.5,
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  Future<void> _handlePdfExport({required bool isDirectDownload}) async {
    if (_cachedFilteredExpenses.isEmpty) return;
    await PdfExporter.exportExpenseReport(
      expenses: _cachedFilteredExpenses,
      periodName: _selectedTimeFilter,
      totalAmount: _cachedTotalAmount,
      isDirectDownload: isDirectDownload,
    );
  }

  @override
  Widget build(BuildContext context) {
    final localizations = AppLocalizations.of(context)!;
    final isArabic = Localizations.localeOf(context).languageCode == 'ar';
    final screenWidth = MediaQuery.of(context).size.width;
    final isDesktop = screenWidth > 900;

    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    // استقرار الألوان والتباين التام لمنع البهتان في وضع النظام والوضع الفاتح
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

    return Scaffold(
      backgroundColor: scaffoldBg,
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.transparent,
        scrolledUnderElevation: 0,
        centerTitle: false,
        title: Row(
          children: [
            const Icon(
              Icons.account_balance_wallet_rounded,
              color: Color(0xFF4F46E5),
              size: 24,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                localizations.appTitle,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontWeight: FontWeight.w800,
                  fontSize: 18,
                  color: textColor,
                ),
              ),
            ),
          ],
        ),
        actions: [
          PopupMenuButton<Locale>(
            tooltip: 'Change Language',
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            onSelected: (loc) => LocaleController.setLocale(loc),
            itemBuilder: (context) {
              final currentLocale = Localizations.localeOf(
                context,
              ).languageCode;
              return [
                PopupMenuItem(
                  value: const Locale('ar'),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'العربية',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                      if (currentLocale == 'ar')
                        const Icon(
                          Icons.check_rounded,
                          color: Color(0xFF4F46E5),
                          size: 18,
                        ),
                    ],
                  ),
                ),
                PopupMenuItem(
                  value: const Locale('en'),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'English',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                      if (currentLocale == 'en')
                        const Icon(
                          Icons.check_rounded,
                          color: Color(0xFF4F46E5),
                          size: 18,
                        ),
                    ],
                  ),
                ),
              ];
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: const Color(0xFF4F46E5).withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: const Color(0xFF4F46E5).withValues(alpha: 0.3),
                  width: 1.5,
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.language_rounded,
                    size: 16,
                    color: Color(0xFF4F46E5),
                  ),
                  const SizedBox(width: 4),
                  Text(
                    isArabic ? 'عربي' : 'EN',
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF4F46E5),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 4),
          PopupMenuButton<String>(
            tooltip: 'Export Options',
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
            ),
            onSelected: (val) async {
              if (val == 'pdf_download') {
                _handlePdfExport(isDirectDownload: true);
              } else if (val == 'pdf_print') {
                _handlePdfExport(isDirectDownload: false);
              } else if (val == 'excel') {
                if (_cachedFilteredExpenses.isNotEmpty) {
                  CsvExporter.exportExpenses(_cachedFilteredExpenses);
                }
              }
            },
            itemBuilder: (ctx) => const [
              PopupMenuItem(
                value: 'pdf_download',
                child: Row(
                  children: [
                    Icon(
                      Icons.picture_as_pdf_rounded,
                      color: Color(0xFFEF4444),
                      size: 18,
                    ),
                    SizedBox(width: 10),
                    Text('Download PDF'),
                  ],
                ),
              ),
              PopupMenuItem(
                value: 'pdf_print',
                child: Row(
                  children: [
                    Icon(
                      Icons.print_rounded,
                      color: Color(0xFF0F172A),
                      size: 18,
                    ),
                    SizedBox(width: 10),
                    Text('Print Report'),
                  ],
                ),
              ),
              PopupMenuItem(
                value: 'excel',
                child: Row(
                  children: [
                    Icon(
                      Icons.file_download_rounded,
                      color: Color(0xFF10B981),
                      size: 18,
                    ),
                    SizedBox(width: 10),
                    Text('Export Excel'),
                  ],
                ),
              ),
            ],
            child: Container(
              padding: const EdgeInsets.all(7),
              decoration: BoxDecoration(
                color: cardBg,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: borderColor),
              ),
              child: const Icon(
                Icons.folder_shared_rounded,
                size: 18,
                color: Color(0xFF4F46E5),
              ),
            ),
          ),
          const SizedBox(width: 4),
          IconButton(
            tooltip: 'Refresh',
            constraints: const BoxConstraints(),
            padding: const EdgeInsets.all(6),
            icon: Container(
              padding: const EdgeInsets.all(7),
              decoration: BoxDecoration(
                color: cardBg,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: borderColor),
              ),
              child: Icon(Icons.refresh_rounded, size: 18, color: subTextColor),
            ),
            onPressed: _loadExpenses,
          ),
          const SizedBox(width: 4),
          // زر البروفايل التفاعلي الجديد بالصورة الحقيقية
          const DashboardUserAvatarButton(),
          const SizedBox(width: 4),
          IconButton(
            tooltip: localizations.logout,
            constraints: const BoxConstraints(),
            padding: const EdgeInsets.all(6),
            icon: Container(
              padding: const EdgeInsets.all(7),
              decoration: BoxDecoration(
                color: cardBg,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: borderColor),
              ),
              child: const Icon(
                Icons.logout_rounded,
                size: 18,
                color: Color(0xFFEF4444),
              ),
            ),
            onPressed: () async {
              final shouldLogout = await showDialog<bool>(
                context: context,
                builder: (ctx) => AlertDialog(
                  backgroundColor: cardBg,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(18),
                    side: BorderSide(color: borderColor),
                  ),
                  title: Row(
                    children: [
                      const Icon(
                        Icons.logout_rounded,
                        color: Color(0xFFEF4444),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        localizations.logout,
                        style: TextStyle(color: textColor),
                      ),
                    ],
                  ),
                  content: Text(
                    isArabic
                        ? 'هل أنت متأكد أنك تريد تسجيل الخروج من التطبيق؟'
                        : 'Are you sure you want to log out of the app?',
                    style: TextStyle(color: subTextColor),
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(ctx, false),
                      child: Text(
                        localizations.cancel,
                        style: TextStyle(color: subTextColor),
                      ),
                    ),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFEF4444),
                        foregroundColor: Colors.white,
                        elevation: 0,
                      ),
                      onPressed: () => Navigator.pop(ctx, true),
                      child: Text(localizations.logout),
                    ),
                  ],
                ),
              );
              if (shouldLogout == true) {
                await Supabase.instance.client.auth.signOut();
                if (mounted) {
                  Navigator.of(context).pushAndRemoveUntil(
                    MaterialPageRoute(builder: (context) => const AuthScreen()),
                    (route) => false,
                  );
                }
              }
            },
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxWidth: isDesktop ? double.infinity : screenWidth,
          ),
          child: Padding(
            padding: EdgeInsets.symmetric(horizontal: isDesktop ? 24.0 : 12.0),
            child: FutureBuilder<List<ExpenseModel>>(
              future: _expensesFuture,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(
                    child: CircularProgressIndicator(color: Color(0xFF4F46E5)),
                  );
                }

                final allExpenses = snapshot.data ?? [];
                // حساب المصفوفات مرة واحدة فقط عند وصول بيانات جديدة
                if (_cachedAllExpenses != allExpenses) {
                  _recomputeMetrics(allExpenses);
                }

                final filteredExpenses = _cachedFilteredExpenses;
                final totalAmount = _cachedTotalAmount;
                final categoryTotals = _cachedCategoryTotals;

                // استخدام ListView.builder / Slivers بدلاً من ListView العادي لتوفير الذاكرة وسرعة المعالجة
                return CustomScrollView(
                  slivers: [
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        child: Column(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(24),
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(20),
                                gradient: const LinearGradient(
                                  colors: [
                                    Color(0xFF1E1B4B),
                                    Color(0xFF312E81),
                                    Color(0xFF4338CA),
                                  ],
                                ),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    mainAxisAlignment:
                                        MainAxisAlignment.spaceBetween,
                                    children: [
                                      Text(
                                        '${localizations.totalExpenses} ($_selectedTimeFilter)',
                                        style: const TextStyle(
                                          color: Colors.white70,
                                          fontSize: 13,
                                        ),
                                      ),
                                      Text(
                                        isArabic
                                            ? '${filteredExpenses.length} من أصل ${allExpenses.length} فواتير'
                                            : '${filteredExpenses.length} of ${allExpenses.length} bills',
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontSize: 11,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 12),
                                  Row(
                                    children: [
                                      Text(
                                        totalAmount.toStringAsFixed(2),
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontSize: 34,
                                          fontWeight: FontWeight.w900,
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      const Text(
                                        'TRY',
                                        style: TextStyle(
                                          color: Colors.white70,
                                          fontSize: 16,
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 16),
                            _buildBudgetCard(
                              totalAmount,
                              isDark,
                              cardBg,
                              borderColor,
                              textColor,
                              subTextColor,
                            ),
                            const SizedBox(height: 16),
                            _buildFilterAndSearchBar(
                              isDark,
                              cardBg,
                              borderColor,
                              textColor,
                              subTextColor,
                            ),
                            const SizedBox(height: 18),
                            if (categoryTotals.isNotEmpty) ...[
                              _buildInteractiveChart(
                                categoryTotals,
                                totalAmount,
                                isDark,
                                cardBg,
                                borderColor,
                                textColor,
                                subTextColor,
                              ),
                              const SizedBox(height: 22),
                            ],
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  '${localizations.transactions} (${filteredExpenses.length})',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w800,
                                    color: textColor,
                                  ),
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 3,
                                  ),
                                  decoration: BoxDecoration(
                                    color: cardBg,
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(color: borderColor),
                                  ),
                                  child: Row(
                                    children: [
                                      Icon(
                                        Icons.swipe_left_rounded,
                                        size: 13,
                                        color: subTextColor,
                                      ),
                                      const SizedBox(width: 4),
                                      Text(
                                        localizations.swipeToDelete,
                                        style: TextStyle(
                                          fontSize: 11,
                                          color: subTextColor,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                    // رسم العناصر بطريقة كسولة توفر الذاكرة وزمن المعالجة
                    SliverList(
                      delegate: SliverChildBuilderDelegate((context, index) {
                        final expense = filteredExpenses[index];
                        final categoryColor = _getCategoryColor(
                          expense.category,
                        );
                        final hasImage =
                            expense.receiptImagePath != null &&
                            expense.receiptImagePath!.isNotEmpty;
                        final translatedCategory = _getTranslatedCategory(
                          context,
                          expense.category,
                        );

                        return Dismissible(
                          key: ValueKey(expense.id),
                          direction: DismissDirection.endToStart,
                          background: Container(
                            margin: const EdgeInsets.only(bottom: 12),
                            padding: const EdgeInsets.symmetric(horizontal: 20),
                            decoration: BoxDecoration(
                              color: const Color(0xFFEF4444),
                              borderRadius: BorderRadius.circular(16),
                            ),
                            alignment: Alignment.centerLeft,
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(
                                  Icons.delete_outline_rounded,
                                  color: Colors.white,
                                  size: 22,
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  localizations.delete,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          confirmDismiss: (direction) async {
                            return await showDialog(
                              context: context,
                              builder: (ctx) => AlertDialog(
                                backgroundColor: cardBg,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(18),
                                  side: BorderSide(color: borderColor),
                                ),
                                title: Row(
                                  children: [
                                    const Icon(
                                      Icons.warning_amber_rounded,
                                      color: Colors.redAccent,
                                    ),
                                    const SizedBox(width: 8),
                                    Text(
                                      isArabic
                                          ? 'تأكيد الحذف'
                                          : 'Confirm Delete',
                                      style: TextStyle(color: textColor),
                                    ),
                                  ],
                                ),
                                content: Text(
                                  isArabic
                                      ? 'هل تريد حذف فاتورة "${expense.title}" نهائياً؟'
                                      : 'Do you want to delete "${expense.title}" permanently?',
                                  style: TextStyle(color: subTextColor),
                                ),
                                actions: [
                                  TextButton(
                                    onPressed: () => Navigator.pop(ctx, false),
                                    child: Text(
                                      localizations.cancel,
                                      style: TextStyle(color: subTextColor),
                                    ),
                                  ),
                                  ElevatedButton(
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: Colors.redAccent,
                                      foregroundColor: Colors.white,
                                      elevation: 0,
                                    ),
                                    onPressed: () => Navigator.pop(ctx, true),
                                    child: Text(localizations.delete),
                                  ),
                                ],
                              ),
                            );
                          },
                          onDismissed: (_) async {
                            await _repository.deleteExpense(expense.id);
                            _loadExpenses();
                          },
                          child: Container(
                            margin: const EdgeInsets.only(bottom: 12),
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(color: borderColor),
                            ),
                            child: Material(
                              color: cardBg,
                              borderRadius: BorderRadius.circular(16),
                              child: ListTile(
                                onTap: () => _showExpenseDetails(
                                  expense,
                                  isDark,
                                  cardBg,
                                  textColor,
                                  subTextColor,
                                  borderColor,
                                ),
                                contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 18,
                                  vertical: 10,
                                ),
                                leading: Container(
                                  padding: const EdgeInsets.all(10),
                                  decoration: BoxDecoration(
                                    color: categoryColor.withValues(
                                      alpha: 0.12,
                                    ),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Icon(
                                    _getCategoryIcon(expense.category),
                                    color: categoryColor,
                                    size: 20,
                                  ),
                                ),
                                title: Text(
                                  expense.title,
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 14.5,
                                    color: textColor, // تباين قوي بدون بهتان
                                  ),
                                ),
                                subtitle: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    if (expense.merchantName != null &&
                                        expense.merchantName!.isNotEmpty)
                                      Padding(
                                        padding: const EdgeInsets.only(top: 2),
                                        child: Text(
                                          expense.merchantName!,
                                          style: TextStyle(
                                            color:
                                                subTextColor, // رمادي متزن مقروء
                                            fontSize: 12.5,
                                            fontWeight: FontWeight.w500,
                                          ),
                                        ),
                                      ),
                                    const SizedBox(height: 4),
                                    Text(
                                      '$translatedCategory • ${DateFormat('yyyy-MM-dd').format(expense.expenseDate)}',
                                      style: TextStyle(
                                        color: subTextColor.withValues(
                                          alpha: 0.8,
                                        ),
                                        fontSize: 11.5,
                                      ),
                                    ),
                                  ],
                                ),
                                trailing: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Column(
                                      mainAxisAlignment:
                                          MainAxisAlignment.center,
                                      crossAxisAlignment:
                                          CrossAxisAlignment.end,
                                      children: [
                                        Text(
                                          '${expense.amount.toStringAsFixed(2)} ${expense.currency}',
                                          style: TextStyle(
                                            fontWeight: FontWeight.w800,
                                            fontSize: 15,
                                            color: textColor,
                                          ),
                                        ),
                                        if (hasImage)
                                          Padding(
                                            padding: const EdgeInsets.only(
                                              top: 3,
                                            ),
                                            child: Row(
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                const Icon(
                                                  Icons.image_outlined,
                                                  size: 12,
                                                  color: Color(0xFF4F46E5),
                                                ),
                                                const SizedBox(width: 3),
                                                Text(
                                                  isArabic
                                                      ? 'مرفق صورة'
                                                      : 'Attached',
                                                  style: const TextStyle(
                                                    fontSize: 10.5,
                                                    color: Color(0xFF4F46E5),
                                                    fontWeight: FontWeight.bold,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        );
                      }, childCount: filteredExpenses.length),
                    ),
                    const SliverToBoxAdapter(child: SizedBox(height: 80)),
                  ],
                );
              },
            ),
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: const Color(0xFF4F46E5),
        foregroundColor: Colors.white,
        elevation: 4,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        onPressed: () async {
          final result = await Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => const AddExpenseScreen()),
          );
          if (result == true) _loadExpenses();
        },
        icon: const Icon(Icons.add_a_photo_rounded, size: 18),
        label: Text(
          localizations.newExpense,
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13.5),
        ),
      ),
    );
  }
}

/// زر الأفاتار التفاعلي المدمج في الشريط العلوي لعرض صورة الحساب الحقيقية
class DashboardUserAvatarButton extends StatelessWidget {
  const DashboardUserAvatarButton({super.key});

  @override
  Widget build(BuildContext context) {
    final user = Supabase.instance.client.auth.currentUser;
    final metadata = user?.userMetadata ?? {};
    final avatarUrl = metadata['avatar_url']?.toString();
    final fullName = metadata['full_name']?.toString() ?? user?.email ?? 'U';
    final initial = fullName.trim().isNotEmpty
        ? fullName.trim()[0].toUpperCase()
        : 'U';

    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Tooltip(
      message: 'الملف الشخصي والإعدادات',
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: () async {
            await Navigator.of(
              context,
            ).push(MaterialPageRoute(builder: (_) => const ProfileScreen()));
          },
          child: Container(
            width: 36,
            height: 36,
            padding: const EdgeInsets.all(2),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              gradient: LinearGradient(
                colors: isDark
                    ? [const Color(0xFF6366F1), const Color(0xFF38BDF8)]
                    : [const Color(0xFF4F46E5), const Color(0xFF0EA5E9)],
              ),
              boxShadow: [
                BoxShadow(
                  color:
                      (isDark
                              ? const Color(0xFF6366F1)
                              : const Color(0xFF4F46E5))
                          .withValues(alpha: 0.25),
                  blurRadius: 6,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: Container(
                color: isDark ? const Color(0xFF0F172A) : Colors.white,
                child: (avatarUrl != null && avatarUrl.trim().isNotEmpty)
                    ? Image.network(
                        avatarUrl,
                        fit: BoxFit.cover,
                        errorBuilder: (_, _, _) =>
                            _buildInitial(initial, isDark),
                      )
                    : _buildInitial(initial, isDark),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildInitial(String char, bool isDark) {
    return Center(
      child: Text(
        char,
        style: TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w800,
          color: isDark ? const Color(0xFF38BDF8) : const Color(0xFF4F46E5),
        ),
      ),
    );
  }
}
