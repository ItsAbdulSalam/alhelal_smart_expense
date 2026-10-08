import 'dart:math';
import 'dart:ui' as ui;
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../core/services/api_client.dart';

class AnalyticsScreen extends StatefulWidget {
  const AnalyticsScreen({super.key});

  @override
  State<AnalyticsScreen> createState() => _AnalyticsScreenState();
}

class _AnalyticsScreenState extends State<AnalyticsScreen> {
  bool _isLoading = true;
  String? _errorMessage;
  Map<String, dynamic> _data = {};

  bool _isLoadingAiAdvice = false;
  Map<String, dynamic>? _aiAdviceData;
  String? _currentLoadedLocale;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final currentLocale = Localizations.localeOf(context).languageCode;
    if (_currentLoadedLocale != currentLocale) {
      _currentLoadedLocale = currentLocale;
      _fetchAnalytics();
      _fetchAiAdvice(currentLocale);
    }
  }

  Future<void> _fetchAnalytics() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final res = await ApiClient.dio.get('/analytics/summary');
      if (res.data != null && mounted) {
        final raw = res.data;
        setState(() {
          _data = (raw is Map && raw['data'] != null)
              ? Map<String, dynamic>.from(raw['data'])
              : (raw is Map ? Map<String, dynamic>.from(raw) : {});
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = Localizations.localeOf(context).languageCode == 'ar'
              ? 'تعذر تحميل الإحصائيات، تأكد من الاتصال بالسيرفر'
              : 'Failed to load analytics. Please check server connection.';
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _fetchAiAdvice([String? langCode]) async {
    final locale = langCode ?? Localizations.localeOf(context).languageCode;
    setState(() {
      _isLoadingAiAdvice = true;
    });

    try {
      final res = await ApiClient.dio.get(
        '/analytics/ai-advice',
        queryParameters: {'locale': locale},
      );
      if (res.data != null && mounted) {
        final raw = res.data;
        setState(() {
          _aiAdviceData = (raw is Map && raw['data'] != null)
              ? Map<String, dynamic>.from(raw['data'])
              : null;
          _isLoadingAiAdvice = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _isLoadingAiAdvice = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final isArabic = Localizations.localeOf(context).languageCode == 'ar';

    final bg = isDark ? const Color(0xFF030712) : const Color(0xFFF8FAFC);
    final cardBg = isDark ? const Color(0xFF0F172A) : Colors.white;
    final borderColor = isDark
        ? const Color(0xFF1E293B)
        : const Color(0xFFE2E8F0);
    final textPrimary = isDark
        ? const Color(0xFFF8FAFC)
        : const Color(0xFF0F172A);
    final textSecondary = isDark
        ? const Color(0xFF94A3B8)
        : const Color(0xFF64748B);

    return Directionality(
      textDirection: isArabic ? ui.TextDirection.rtl : ui.TextDirection.ltr,
      child: Scaffold(
        backgroundColor: bg,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          scrolledUnderElevation: 0,
          centerTitle: false,
          leading: IconButton(
            icon: Icon(
              isArabic
                  ? Icons.arrow_back_ios_new_rounded
                  : Icons.arrow_back_rounded,
              size: 20,
              color: textPrimary,
            ),
            onPressed: () => Navigator.of(context).pop(),
          ),
          title: Text(
            isArabic ? 'التحليلات والرؤى المالية' : 'Analytics & Insights',
            style: TextStyle(
              color: textPrimary,
              fontWeight: FontWeight.w900,
              fontSize: 19,
            ),
          ),
          actions: [
            Container(
              margin: const EdgeInsetsDirectional.only(end: 14),
              child: IconButton(
                tooltip: isArabic ? 'تحديث الكل' : 'Refresh All',
                style: IconButton.styleFrom(
                  backgroundColor: cardBg,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                    side: BorderSide(color: borderColor),
                  ),
                ),
                icon: Icon(
                  Icons.refresh_rounded,
                  size: 20,
                  color: textSecondary,
                ),
                onPressed: () {
                  _fetchAnalytics();
                  _fetchAiAdvice();
                },
              ),
            ),
          ],
        ),
        body: _isLoading
            ? const Center(
                child: CircularProgressIndicator(color: Color(0xFF4F46E5)),
              )
            : _errorMessage != null
            ? Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.error_outline_rounded,
                      size: 48,
                      color: Colors.redAccent.shade200,
                    ),
                    const SizedBox(height: 12),
                    Text(
                      _errorMessage!,
                      style: TextStyle(color: textSecondary),
                    ),
                    const SizedBox(height: 16),
                    ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF4F46E5),
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      onPressed: () {
                        _fetchAnalytics();
                        _fetchAiAdvice();
                      },
                      icon: const Icon(Icons.refresh_rounded, size: 18),
                      label: Text(isArabic ? 'إعادة المحاولة' : 'Try Again'),
                    ),
                  ],
                ),
              )
            : RefreshIndicator(
                color: const Color(0xFF4F46E5),
                onRefresh: () async {
                  await _fetchAnalytics();
                  await _fetchAiAdvice();
                },
                child: SingleChildScrollView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 16,
                  ),
                  child: Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 1040),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          _buildHeroOverviewCard(isArabic),
                          const SizedBox(height: 20),
                          _buildAiAdvisorCard(
                            isDark,
                            cardBg,
                            borderColor,
                            textPrimary,
                            textSecondary,
                            isArabic,
                          ),
                          const SizedBox(height: 20),
                          _buildKpiGrid(
                            cardBg,
                            borderColor,
                            textPrimary,
                            textSecondary,
                            isArabic,
                          ),
                          const SizedBox(height: 24),
                          _buildMonthlyTrendChart(
                            isDark,
                            cardBg,
                            borderColor,
                            textPrimary,
                            textSecondary,
                            isArabic,
                          ),
                          const SizedBox(height: 24),
                          _buildTopMerchantsCard(
                            cardBg,
                            borderColor,
                            textPrimary,
                            textSecondary,
                            isArabic,
                          ),
                          const SizedBox(height: 40),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
      ),
    );
  }

  Widget _buildHeroOverviewCard(bool isArabic) {
    final currentMonthTotal = (_data['current_month_total'] ?? 0.0) as num;
    final lastMonthTotal = (_data['last_month_total'] ?? 0.0) as num;
    final currency = (_data['currency'] ?? 'TRY').toString();

    double diffPercent = 0.0;
    bool isIncreased = false;
    if (lastMonthTotal > 0) {
      final diff = currentMonthTotal - lastMonthTotal;
      diffPercent = (diff / lastMonthTotal * 100).abs();
      isIncreased = diff > 0;
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(26),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        gradient: const LinearGradient(
          begin: Alignment.topRight,
          end: Alignment.bottomLeft,
          colors: [Color(0xFF2E2A72), Color(0xFF4338CA), Color(0xFF4F46E5)],
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF4338CA).withValues(alpha: 0.28),
            blurRadius: 24,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                isArabic
                    ? 'إجمالي نفقات الشهر الحالي'
                    : 'Current Month Spending',
                style: const TextStyle(
                  color: Colors.white70,
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.16),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.2),
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      isIncreased
                          ? Icons.trending_up_rounded
                          : Icons.trending_down_rounded,
                      color: isIncreased
                          ? const Color(0xFFFCA5A5)
                          : const Color(0xFF86EFAC),
                      size: 16,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      lastMonthTotal > 0
                          ? (isArabic
                                ? '${diffPercent.toStringAsFixed(1)}% عن الشهر الماضي'
                                : '${diffPercent.toStringAsFixed(1)}% vs Last Month')
                          : (isArabic ? 'بداية المقارنة' : 'Base Period'),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 11.5,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(
                NumberFormat('#,##0.00').format(currentMonthTotal),
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 36,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                currency,
                style: const TextStyle(
                  color: Colors.white70,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            isArabic
                ? 'إنفاق الشهر السابق: ${NumberFormat('#,##0.00').format(lastMonthTotal)} $currency'
                : 'Previous Month: ${NumberFormat('#,##0.00').format(lastMonthTotal)} $currency',
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.75),
              fontSize: 12.5,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAiAdvisorCard(
    bool isDark,
    Color cardBg,
    Color borderColor,
    Color textPrimary,
    Color textSecondary,
    bool isArabic,
  ) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: const Color(0xFF6366F1).withValues(alpha: isDark ? 0.35 : 0.2),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(
              0xFF6366F1,
            ).withValues(alpha: isDark ? 0.12 : 0.05),
            blurRadius: 20,
            offset: const Offset(0, 6),
          ),
        ],
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
                    padding: const EdgeInsets.all(9),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFF6366F1), Color(0xFF8B5CF6)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(14),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFF6366F1).withValues(alpha: 0.3),
                          blurRadius: 8,
                          offset: const Offset(0, 3),
                        ),
                      ],
                    ),
                    child: const Icon(
                      Icons.auto_awesome_rounded,
                      color: Colors.white,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        isArabic
                            ? 'المستشار المالي الذكي'
                            : 'AI Financial Advisor',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w900,
                          color: textPrimary,
                        ),
                      ),
                      Text(
                        isArabic
                            ? 'تحليل وتوصيات مخصصة عبر Gemini AI'
                            : 'Smart insights powered by Gemini AI',
                        style: TextStyle(
                          fontSize: 11,
                          color: textSecondary,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              if (_isLoadingAiAdvice)
                const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2.2,
                    color: Color(0xFF6366F1),
                  ),
                )
              else
                IconButton(
                  tooltip: isArabic
                      ? 'إعادة التحليل الآن'
                      : 'Regenerate Analysis',
                  style: IconButton.styleFrom(
                    backgroundColor: const Color(
                      0xFF6366F1,
                    ).withValues(alpha: 0.1),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  icon: const Icon(
                    Icons.refresh_rounded,
                    size: 18,
                    color: Color(0xFF6366F1),
                  ),
                  onPressed: () => _fetchAiAdvice(),
                ),
            ],
          ),
          const SizedBox(height: 18),
          if (_isLoadingAiAdvice)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 16),
              child: Row(
                children: [
                  const Icon(
                    Icons.hourglass_top_rounded,
                    size: 18,
                    color: Color(0xFF6366F1),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      isArabic
                          ? 'جاري استخراج وتحليل نمط الصرف وتقديم التوصيات...'
                          : 'Analyzing spending patterns and generating personalized advice...',
                      style: TextStyle(
                        fontSize: 13,
                        color: textSecondary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            )
          else if (_aiAdviceData != null) ...[
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                color: const Color(
                  0xFF6366F1,
                ).withValues(alpha: isDark ? 0.15 : 0.08),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                _aiAdviceData!['headline']?.toString() ??
                    (isArabic ? 'نظرة عامة على نفقاتك' : 'Spending Overview'),
                style: const TextStyle(
                  fontSize: 14.5,
                  fontWeight: FontWeight.w900,
                  color: Color(0xFF6366F1),
                ),
              ),
            ),
            const SizedBox(height: 12),
            Text(
              _aiAdviceData!['analysis']?.toString() ?? '',
              textAlign: TextAlign.start,
              style: TextStyle(
                fontSize: 13.5,
                color: textPrimary.withValues(alpha: 0.95),
                height: 1.6,
                fontWeight: FontWeight.w500,
              ),
            ),
            if (_aiAdviceData!['tips'] is List &&
                (_aiAdviceData!['tips'] as List).isNotEmpty) ...[
              const SizedBox(height: 16),
              Divider(height: 1, color: borderColor),
              const SizedBox(height: 14),
              ...(_aiAdviceData!['tips'] as List).map((tip) {
                return Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        margin: const EdgeInsets.only(top: 3),
                        padding: const EdgeInsets.all(4),
                        decoration: BoxDecoration(
                          color: const Color(
                            0xFF10B981,
                          ).withValues(alpha: 0.12),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.check_rounded,
                          color: Color(0xFF10B981),
                          size: 13,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          tip.toString(),
                          textAlign: TextAlign.start,
                          style: TextStyle(
                            fontSize: 13,
                            color: textSecondary,
                            fontWeight: FontWeight.w600,
                            height: 1.45,
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              }),
            ],
          ] else
            Text(
              isArabic
                  ? 'أضف مزيداً من الفواتير لتوليد استشارات مالية مخصصة لمساعدتك في التوفير.'
                  : 'Add more receipts to generate smart insights and personalized budget advice.',
              style: TextStyle(fontSize: 13, color: textSecondary),
            ),
        ],
      ),
    );
  }

  Widget _buildKpiGrid(
    Color cardBg,
    Color borderColor,
    Color textPrimary,
    Color textSecondary,
    bool isArabic,
  ) {
    final dailyAvg = (_data['daily_average'] ?? 0.0) as num;
    final totalReceipts =
        (_data['total_receipts_count'] ?? _data['total_count'] ?? 0) as num;
    final highestExpense = (_data['highest_expense_amount'] ?? 0.0) as num;
    final currency = (_data['currency'] ?? 'TRY').toString();

    return Row(
      children: [
        Expanded(
          child: _buildMetricTile(
            title: isArabic ? 'المعدل اليومي' : 'Daily Average',
            value: '${dailyAvg.toStringAsFixed(1)} $currency',
            icon: Icons.calendar_today_rounded,
            iconColor: const Color(0xFF0EA5E9),
            cardBg: cardBg,
            borderColor: borderColor,
            textPrimary: textPrimary,
            textSecondary: textSecondary,
          ),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: _buildMetricTile(
            title: isArabic ? 'عدد الفواتير' : 'Total Receipts',
            value: isArabic ? '$totalReceipts فاتورة' : '$totalReceipts Bills',
            icon: Icons.receipt_long_rounded,
            iconColor: const Color(0xFF10B981),
            cardBg: cardBg,
            borderColor: borderColor,
            textPrimary: textPrimary,
            textSecondary: textSecondary,
          ),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: _buildMetricTile(
            title: isArabic ? 'أعلى فاتورة' : 'Highest Bill',
            value: '${highestExpense.toStringAsFixed(0)} $currency',
            icon: Icons.star_rounded,
            iconColor: const Color(0xFFF59E0B),
            cardBg: cardBg,
            borderColor: borderColor,
            textPrimary: textPrimary,
            textSecondary: textSecondary,
          ),
        ),
      ],
    );
  }

  Widget _buildMetricTile({
    required String title,
    required String value,
    required IconData icon,
    required Color iconColor,
    required Color cardBg,
    required Color borderColor,
    required Color textPrimary,
    required Color textSecondary,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 18),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: borderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: iconColor.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: iconColor, size: 20),
          ),
          const SizedBox(height: 14),
          Text(
            title,
            style: TextStyle(
              color: textSecondary,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 4),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              value,
              style: TextStyle(
                color: textPrimary,
                fontSize: 16.5,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMonthlyTrendChart(
    bool isDark,
    Color cardBg,
    Color borderColor,
    Color textPrimary,
    Color textSecondary,
    bool isArabic,
  ) {
    final rawTrend = _data['monthly_trend'] as List<dynamic>? ?? [];
    final List<Map<String, dynamic>> trendData = rawTrend
        .map((e) => Map<String, dynamic>.from(e as Map))
        .toList();

    double maxY = 100.0;
    for (var item in trendData) {
      final val = (item['total'] ?? 0.0) as num;
      if (val > maxY) maxY = val.toDouble();
    }
    maxY = (maxY * 1.25).ceilToDouble();

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: borderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: const Color(0xFF4F46E5).withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(
                  Icons.bar_chart_rounded,
                  color: Color(0xFF4F46E5),
                  size: 20,
                ),
              ),
              const SizedBox(width: 10),
              Text(
                isArabic ? 'مسار الإنفاق الشهري' : 'Monthly Spending Trend',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w900,
                  color: textPrimary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 26),
          trendData.isEmpty
              ? Container(
                  height: 180,
                  alignment: Alignment.center,
                  child: Text(
                    isArabic
                        ? 'لا توجد بيانات حركة مالية كافية للرسم'
                        : 'No sufficient trend data available yet',
                    style: TextStyle(color: textSecondary),
                  ),
                )
              : SizedBox(
                  height: 220,
                  child: Directionality(
                    textDirection: ui.TextDirection.ltr,
                    child: BarChart(
                      BarChartData(
                        maxY: maxY,
                        barTouchData: BarTouchData(
                          touchTooltipData: BarTouchTooltipData(
                            getTooltipColor: (group) => isDark
                                ? const Color(0xFF1E293B)
                                : const Color(0xFF0F172A),
                            getTooltipItem: (group, groupIndex, rod, rodIndex) {
                              final month =
                                  trendData[group.x.toInt()]['month'] ?? '';
                              return BarTooltipItem(
                                '$month\n${rod.toY.toStringAsFixed(1)} TRY',
                                const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 12,
                                ),
                              );
                            },
                          ),
                        ),
                        titlesData: FlTitlesData(
                          show: true,
                          topTitles: const AxisTitles(
                            sideTitles: SideTitles(showTitles: false),
                          ),
                          rightTitles: const AxisTitles(
                            sideTitles: SideTitles(showTitles: false),
                          ),
                          leftTitles: AxisTitles(
                            sideTitles: SideTitles(
                              showTitles: true,
                              reservedSize: 44,
                              getTitlesWidget: (val, meta) => Text(
                                NumberFormat.compact().format(val),
                                style: TextStyle(
                                  color: textSecondary,
                                  fontSize: 10.5,
                                ),
                              ),
                            ),
                          ),
                          bottomTitles: AxisTitles(
                            sideTitles: SideTitles(
                              showTitles: true,
                              getTitlesWidget: (val, meta) {
                                final idx = val.toInt();
                                if (idx >= 0 && idx < trendData.length) {
                                  final label = (trendData[idx]['month'] ?? '')
                                      .toString();
                                  return Padding(
                                    padding: const EdgeInsets.only(top: 8.0),
                                    child: Text(
                                      label.length > 7
                                          ? label.substring(5)
                                          : label,
                                      style: TextStyle(
                                        color: textSecondary,
                                        fontSize: 11,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                  );
                                }
                                return const SizedBox();
                              },
                            ),
                          ),
                        ),
                        borderData: FlBorderData(show: false),
                        gridData: FlGridData(
                          show: true,
                          drawVerticalLine: false,
                          getDrawingHorizontalLine: (value) => FlLine(
                            color: borderColor.withValues(alpha: 0.7),
                            strokeWidth: 1,
                          ),
                        ),
                        barGroups: List.generate(trendData.length, (i) {
                          final val = ((trendData[i]['total'] ?? 0.0) as num)
                              .toDouble();
                          return BarChartGroupData(
                            x: i,
                            barRods: [
                              BarChartRodData(
                                toY: val,
                                gradient: const LinearGradient(
                                  colors: [
                                    Color(0xFF4F46E5),
                                    Color(0xFF38BDF8),
                                  ],
                                  begin: Alignment.bottomCenter,
                                  end: Alignment.topCenter,
                                ),
                                width: 22,
                                borderRadius: const BorderRadius.vertical(
                                  top: Radius.circular(8),
                                ),
                              ),
                            ],
                          );
                        }),
                      ),
                    ),
                  ),
                ),
        ],
      ),
    );
  }

  Widget _buildTopMerchantsCard(
    Color cardBg,
    Color borderColor,
    Color textPrimary,
    Color textSecondary,
    bool isArabic,
  ) {
    final rawMerchants = _data['top_merchants'] as List<dynamic>? ?? [];
    final List<Map<String, dynamic>> merchants = rawMerchants
        .map((e) => Map<String, dynamic>.from(e as Map))
        .toList();

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: borderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: const Color(0xFF10B981).withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(
                  Icons.storefront_rounded,
                  color: Color(0xFF10B981),
                  size: 20,
                ),
              ),
              const SizedBox(width: 10),
              Text(
                isArabic ? 'أكثر المتاجر إنفاقاً' : 'Top Spending Merchants',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w900,
                  color: textPrimary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          merchants.isEmpty
              ? Container(
                  height: 90,
                  alignment: Alignment.center,
                  child: Text(
                    isArabic
                        ? 'لا توجد بيانات متاجر مسجلة حتى الآن'
                        : 'No merchant transactions recorded yet',
                    style: TextStyle(color: textSecondary),
                  ),
                )
              : ListView.separated(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: min(merchants.length, 5),
                  separatorBuilder: (_, _) =>
                      Divider(height: 20, color: borderColor),
                  itemBuilder: (ctx, i) {
                    final item = merchants[i];
                    final name =
                        (item['merchant_name'] ??
                                (isArabic
                                    ? 'متجر غير معروف'
                                    : 'Unknown Merchant'))
                            .toString();
                    final count = (item['bills_count'] ?? 1) as num;
                    final total = ((item['total_amount'] ?? 0.0) as num)
                        .toDouble();

                    return Row(
                      children: [
                        CircleAvatar(
                          radius: 17,
                          backgroundColor: const Color(
                            0xFF4F46E5,
                          ).withValues(alpha: 0.1),
                          child: Text(
                            '#${i + 1}',
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF4F46E5),
                            ),
                          ),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                name,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  color: textPrimary,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 14,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                isArabic
                                    ? '$count عملية دفع'
                                    : '$count transactions',
                                style: TextStyle(
                                  color: textSecondary,
                                  fontSize: 11.5,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Text(
                          '${total.toStringAsFixed(1)} TRY',
                          style: TextStyle(
                            color: textPrimary,
                            fontWeight: FontWeight.w900,
                            fontSize: 14.5,
                          ),
                        ),
                      ],
                    );
                  },
                ),
        ],
      ),
    );
  }
}
