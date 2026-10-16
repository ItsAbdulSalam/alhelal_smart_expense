import 'dart:math';
import 'dart:ui' as ui;
import 'package:flutter/services.dart';
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
  bool _aiExpanded = false;
  bool _insightsExpanded = false;
  String? _errorMessage;
  Map<String, dynamic> _data = {};

  bool _isLoadingBudget = true;
  String? _budgetError;
  Map<String, dynamic>? _generalBudget;

  bool _isLoadingAiAdvice = false;
  Map<String, dynamic>? _aiAdviceData;
  String? _currentLoadedLocale;
  String? _aiAdviceError;
  bool _hasLoadedAnalytics = false;
  bool _analyticsStarted = false;
  int _analyticsRequestId = 0;
  int _aiRequestId = 0;
  int _budgetRequestId = 0;
  bool _isRefreshingAnalytics = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final currentLocale = Localizations.localeOf(context).languageCode;
    if (_currentLoadedLocale != currentLocale) {
      _currentLoadedLocale = currentLocale;
      if (!_analyticsStarted) {
        _analyticsStarted = true;
        _fetchAnalytics();
      }
      _fetchAiAdvice(currentLocale);
    }
  }

  // Only the summary controls the page-level loading/error state.
  // Budget and AI failures stay local to their respective cards.
  Future<void> _fetchAnalytics() async {
    final requestId = ++_analyticsRequestId;
    setState(() {
      _isLoading = !_hasLoadedAnalytics;
      _isRefreshingAnalytics = _hasLoadedAnalytics;
      _errorMessage = null;
    });

    try {
      dynamic raw;
      for (var attempt = 0; attempt < 2; attempt++) {
        try {
          final res = await ApiClient.dio.get('/analytics/summary');
          raw = res.data;
          if (raw is! Map || raw['status'] != true || raw['data'] is! Map) {
            throw const FormatException('Invalid analytics response');
          }
          break;
        } catch (error) {
          // A single short retry for transient failures; never retry malformed data.
          if (error is FormatException || attempt == 1) rethrow;
          if (!mounted || requestId != _analyticsRequestId) return;
          await Future<void>.delayed(const Duration(milliseconds: 650));
        }
      }
      if (!mounted || requestId != _analyticsRequestId) return;
      setState(() {
        _data = Map<String, dynamic>.from(raw['data'] as Map);
        _isLoading = false;
        _isRefreshingAnalytics = false;
        _hasLoadedAnalytics = true;
      });
      // The budget is independent and must never block the summary.
      _fetchBudget();
    } catch (error) {
      if (!mounted || requestId != _analyticsRequestId) return;
      debugPrint('Analytics summary failed: $error');
      setState(() {
        _errorMessage = _hasLoadedAnalytics
            ? null
            : (Localizations.localeOf(context).languageCode == 'ar'
                  ? 'تعذر تحميل الإحصائيات، تأكد من الاتصال بالسيرفر'
                  : 'Failed to load analytics. Please check server connection.');
        _isLoading = false;
        _isRefreshingAnalytics = false;
      });
      if (_hasLoadedAnalytics) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              Localizations.localeOf(context).languageCode == 'ar'
                  ? 'تعذر تحديث البيانات، يتم عرض آخر بيانات محمّلة.'
                  : 'Could not refresh. Showing previously loaded data.',
            ),
          ),
        );
      }
    }
  }

  Future<void> _fetchBudget() async {
    final requestId = ++_budgetRequestId;
    if (!mounted) return;
    setState(() {
      _isLoadingBudget = true;
      _budgetError = null;
    });
    try {
      final month =
          (_data['current_month'] ??
                  DateFormat('yyyy-MM').format(DateTime.now()))
              .toString();
      final response = await ApiClient.dio.get(
        '/budgets',
        queryParameters: {'month_year': month},
      );
      final raw = response.data;
      if (raw is! Map || raw['status'] != true || raw['data'] is! List) {
        throw const FormatException('Invalid budgets response');
      }
      final budgets = (raw['data'] as List)
          .whereType<Map>()
          .map((item) => Map<String, dynamic>.from(item))
          .toList();
      final currency = (_data['currency'] ?? 'TRY').toString();
      Map<String, dynamic>? general;
      for (final budget in budgets) {
        if (budget['category']?.toString().toLowerCase() == 'general' &&
            budget['currency']?.toString().toUpperCase() ==
                currency.toUpperCase()) {
          general = budget;
          break;
        }
      }
      if (mounted && requestId == _budgetRequestId) {
        setState(() {
          _generalBudget = general;
          _isLoadingBudget = false;
        });
      }
    } catch (_) {
      if (mounted && requestId == _budgetRequestId) {
        setState(() {
          _generalBudget = null;
          _isLoadingBudget = false;
          _budgetError = 'unavailable';
        });
      }
    }
  }

  Future<void> _fetchAiAdvice([String? langCode]) async {
    final locale = langCode ?? Localizations.localeOf(context).languageCode;
    final requestId = ++_aiRequestId;
    setState(() {
      _isLoadingAiAdvice = true;
      _aiAdviceError = null;
    });

    try {
      final res = await ApiClient.dio.get(
        '/analytics/ai-advice',

        queryParameters: {'locale': locale},
      );
      debugPrint(
        'AI ADVISOR CACHED: ${res.data is Map ? res.data['cached'] : 'unknown'}',
      );

      if (mounted &&
          requestId == _aiRequestId &&
          locale == _currentLoadedLocale) {
        final raw = res.data;
        setState(() {
          _aiAdviceData = (raw is Map && raw['data'] != null)
              ? Map<String, dynamic>.from(raw['data'])
              : null;
          _isLoadingAiAdvice = false;
        });
      }
    } catch (_) {
      if (mounted &&
          requestId == _aiRequestId &&
          locale == _currentLoadedLocale) {
        setState(() {
          _aiAdviceError = locale == 'ar'
              ? 'تعذر تحديث التحليل. تحقق من الاتصال وحاول مجدداً.'
              : 'Unable to update insights. Check your connection and retry.';
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
      child: AnnotatedRegion<SystemUiOverlayStyle>(
        value: isDark ? SystemUiOverlayStyle.light : SystemUiOverlayStyle.dark,
        child: Scaffold(
          backgroundColor: bg,
          appBar: AppBar(
            systemOverlayStyle: isDark
                ? SystemUiOverlayStyle.light
                : SystemUiOverlayStyle.dark,
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
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
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
                  onPressed: _isRefreshingAnalytics
                      ? null
                      : () {
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
                    await Future.wait([_fetchAnalytics(), _fetchAiAdvice()]);
                  },
                  child: SingleChildScrollView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 10,
                    ),
                    child: Center(
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 1040),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            _buildHeroOverviewCard(isArabic),
                            const SizedBox(height: 12),
                            _buildKpiGrid(
                              cardBg,
                              borderColor,
                              textPrimary,
                              textSecondary,
                              isArabic,
                            ),
                            const SizedBox(height: 12),
                            _buildBudgetHealthCard(
                              isDark,
                              cardBg,
                              borderColor,
                              textPrimary,
                              textSecondary,
                              isArabic,
                            ),
                            const SizedBox(height: 12),
                            _buildSpendingInsightsCard(
                              isDark,
                              cardBg,
                              borderColor,
                              textPrimary,
                              textSecondary,
                              isArabic,
                            ),
                            const SizedBox(height: 12),
                            _buildSmartAlertsCard(
                              isDark,
                              cardBg,
                              borderColor,
                              textPrimary,
                              textSecondary,
                              isArabic,
                            ),
                            const SizedBox(height: 12),
                            _buildAiAdvisorCard(
                              isDark,
                              cardBg,
                              borderColor,
                              textPrimary,
                              textSecondary,
                              isArabic,
                            ),
                            const SizedBox(height: 12),
                            _buildMonthlyTrendChart(
                              isDark,
                              cardBg,
                              borderColor,
                              textPrimary,
                              textSecondary,
                              isArabic,
                            ),
                            const SizedBox(height: 12),
                            _buildTopMerchantsCard(
                              cardBg,
                              borderColor,
                              textPrimary,
                              textSecondary,
                              isArabic,
                            ),
                            const SizedBox(height: 16),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
        ),
      ),
    );
  }

  Widget _buildHeroOverviewCard(bool isArabic) {
    final current = (_data['current_month_total'] as num?) ?? 0;
    final previous = (_data['last_month_total'] as num?) ?? 0;
    final currency = (_data['currency'] ?? 'TRY').toString();
    final difference = current - previous;
    final hasComparison = previous > 0;
    final isUp = difference > 0;
    final isFlat = difference == 0;
    final percent = hasComparison ? (difference.abs() / previous * 100) : 0.0;
    final changeText = !hasComparison
        ? (isArabic ? 'لا توجد بيانات للمقارنة' : 'No previous month data')
        : isFlat
        ? (isArabic ? 'دون تغيير عن الشهر الماضي' : 'Unchanged from last month')
        : isArabic
        ? '${isUp ? 'ارتفاع' : 'انخفاض'} ${percent.toStringAsFixed(1)}% عن الشهر الماضي'
        : '${isUp ? 'Up' : 'Down'} ${percent.toStringAsFixed(1)}% vs last month';
    final trendColor = !hasComparison || isFlat
        ? Colors.white
        : isUp
        ? const Color(0xFFFFC5C5)
        : const Color(0xFFA7F3D0);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(22),
        gradient: const LinearGradient(
          begin: Alignment.topRight,
          end: Alignment.bottomLeft,
          colors: [Color(0xFF29256C), Color(0xFF4338CA), Color(0xFF5B4CF2)],
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF4338CA).withValues(alpha: 0.18),
            blurRadius: 28,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(9),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.13),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.account_balance_wallet_outlined,
                  color: Colors.white,
                  size: 20,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  isArabic ? 'إنفاق الشهر الحالي' : 'This month’s spending',
                  style: const TextStyle(
                    color: Colors.white70,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: AlignmentDirectional.centerStart,
            child: Directionality(
              textDirection: ui.TextDirection.ltr,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.baseline,
                textBaseline: TextBaseline.alphabetic,
                children: [
                  Text(
                    NumberFormat('#,##0.00').format(current),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 34,
                      height: 1.1,
                      fontWeight: FontWeight.w900,
                      letterSpacing: -1,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Text(
                    currency,
                    style: const TextStyle(
                      color: Color(0xFFDDD9FF),
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.white.withValues(alpha: 0.13)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  !hasComparison || isFlat
                      ? Icons.remove_rounded
                      : isUp
                      ? Icons.trending_up_rounded
                      : Icons.trending_down_rounded,
                  color: trendColor,
                  size: 18,
                ),
                const SizedBox(width: 8),
                Flexible(
                  child: Text(
                    changeText,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 9),
          Text(
            isArabic
                ? 'الشهر السابق: ${NumberFormat('#,##0.00').format(previous)} $currency'
                : 'Previous month: ${NumberFormat('#,##0.00').format(previous)} $currency',
            style: const TextStyle(color: Color(0xFFDCD9FA), fontSize: 12.5),
          ),
        ],
      ),
    );
  }

  Widget _buildBudgetHealthCard(
    bool isDark,
    Color cardBg,
    Color borderColor,
    Color textPrimary,
    Color textSecondary,
    bool isArabic,
  ) {
    const accent = Color(0xFF6366F1);
    final budget = _generalBudget;
    final limit = (budget?['amount'] as num?)?.toDouble() ?? 0;
    final spent = (budget?['spent'] as num?)?.toDouble() ?? 0;
    final remaining = (limit - spent).clamp(0.0, double.infinity).toDouble();
    final percent = limit > 0 ? spent / limit * 100 : 0.0;
    final currency =
        budget?['currency']?.toString() ??
        (_data['currency'] ?? 'TRY').toString();
    final month =
        (_data['current_month'] ?? DateFormat('yyyy-MM').format(DateTime.now()))
            .toString();
    final now = DateTime.now();
    final currentMonth = DateFormat('yyyy-MM').format(now) == month;
    final elapsed = now.day / DateTime(now.year, now.month + 1, 0).day * 100;
    final isOver = percent >= 100;
    final isWarning = percent >= 80;
    final statusColor = isOver
        ? const Color(0xFFDC2626)
        : isWarning
        ? const Color(0xFFD97706)
        : const Color(0xFF059669);
    final status = isOver
        ? (isArabic ? 'تجاوزت الميزانية' : 'Over budget')
        : isWarning
        ? (isArabic ? 'قريب من الحد' : 'Near the limit')
        : (isArabic ? 'ضمن الميزانية' : 'Within budget');
    String money(double value) =>
        '${NumberFormat('#,##0.##').format(value)} $currency';

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: borderColor),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.12 : 0.035),
            blurRadius: 20,
            offset: const Offset(0, 7),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: accent.withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(11),
                ),
                child: const Icon(
                  Icons.health_and_safety_outlined,
                  color: accent,
                  size: 20,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  isArabic ? 'صحة الميزانية' : 'Budget Health',
                  style: TextStyle(
                    color: textPrimary,
                    fontSize: 16,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              if (budget != null && limit > 0)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 9,
                    vertical: 5,
                  ),
                  decoration: BoxDecoration(
                    color: statusColor.withValues(alpha: 0.10),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    status,
                    style: TextStyle(
                      color: statusColor,
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 13),
          if (_isLoadingBudget)
            const LinearProgressIndicator(color: accent, minHeight: 3)
          else if (_budgetError != null)
            Row(
              children: [
                Expanded(
                  child: Text(
                    isArabic
                        ? 'تعذر تحميل الميزانية من الخادم.'
                        : 'Could not load budget from server.',
                    style: TextStyle(color: textSecondary, fontSize: 12),
                  ),
                ),
                TextButton(
                  onPressed: _fetchBudget,
                  child: Text(isArabic ? 'إعادة المحاولة' : 'Retry'),
                ),
              ],
            )
          else if (budget == null || limit <= 0)
            Text(
              isArabic
                  ? 'لا توجد ميزانية عامة لهذا الشهر. يمكنك إعدادها من لوحة التحكم.'
                  : 'No general budget for this month. Set one from the dashboard.',
              style: TextStyle(color: textSecondary, fontSize: 12.5),
            )
          else ...[
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    isArabic
                        ? 'المصروف: ${money(spent)}'
                        : 'Spent: ${money(spent)}',
                    style: TextStyle(
                      color: textPrimary,
                      fontWeight: FontWeight.w700,
                      fontSize: 12,
                    ),
                  ),
                ),
                Text(
                  '${percent.toStringAsFixed(1)}%',
                  style: TextStyle(
                    color: statusColor,
                    fontWeight: FontWeight.w900,
                    fontSize: 16,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 9),
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: LinearProgressIndicator(
                value: (percent / 100).clamp(0.0, 1.0).toDouble(),
                minHeight: 9,
                backgroundColor: borderColor,
                valueColor: AlwaysStoppedAnimation<Color>(statusColor),
              ),
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: Text(
                    isArabic
                        ? 'المتبقي: ${money(remaining)}'
                        : 'Remaining: ${money(remaining)}',
                    style: TextStyle(color: textSecondary, fontSize: 12),
                  ),
                ),
                if (isOver)
                  Text(
                    isArabic
                        ? 'التجاوز: ${money(spent - limit)}'
                        : 'Over by: ${money(spent - limit)}',
                    style: const TextStyle(
                      color: Color(0xFFDC2626),
                      fontWeight: FontWeight.w700,
                      fontSize: 11,
                    ),
                  ),
              ],
            ),
            if (currentMonth) ...[
              const SizedBox(height: 9),
              Text(
                isArabic
                    ? 'انقضى ${elapsed.toStringAsFixed(0)}% من الشهر، واستهلكت ${percent.toStringAsFixed(1)}% من الميزانية.'
                    : '${elapsed.toStringAsFixed(0)}% of the month has passed; ${percent.toStringAsFixed(1)}% of your budget is used.',
                style: TextStyle(color: textSecondary, fontSize: 11.5),
              ),
            ],
          ],
        ],
      ),
    );
  }

  Widget _buildSpendingInsightsCard(
    bool isDark,
    Color cardBg,
    Color borderColor,
    Color textPrimary,
    Color textSecondary,
    bool isArabic,
  ) {
    const accent = Color(0xFF6366F1);
    const palette = [
      Color(0xFF6366F1),
      Color(0xFF06B6D4),
      Color(0xFF10B981),
      Color(0xFFF59E0B),
      Color(0xFFEC4899),
      Color(0xFF8B5CF6),
    ];
    final raw = _data['spending_categories'];
    final categories = raw is List
        ? raw.whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList()
        : <Map<String, dynamic>>[];
    final total = (_data['current_month_total'] as num?)?.toDouble() ?? 0;
    final currency = (_data['currency'] ?? 'TRY').toString();
    final visible = _insightsExpanded
        ? categories
        : categories.take(3).toList();
    final moneyFormat = NumberFormat('#,##0.##');

    String nameFor(String name) {
      if (name.trim().isEmpty || name == 'Uncategorized') {
        return isArabic ? 'غير مصنف' : 'Uncategorized';
      }
      return name;
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: borderColor),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.12 : 0.035),
            blurRadius: 20,
            offset: const Offset(0, 7),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(9),
                decoration: BoxDecoration(
                  color: accent.withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.donut_small_rounded,
                  color: accent,
                  size: 21,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      isArabic ? 'رؤى الإنفاق' : 'Spending Insights',
                      style: TextStyle(
                        color: textPrimary,
                        fontSize: 16,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      isArabic
                          ? 'توزيع المصروفات حسب التصنيف'
                          : 'Where your money goes',
                      style: TextStyle(color: textSecondary, fontSize: 11.5),
                    ),
                  ],
                ),
              ),
              if (categories.isNotEmpty)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 9,
                    vertical: 5,
                  ),
                  decoration: BoxDecoration(
                    color: accent.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    '${categories.length} ${isArabic ? 'تصنيفات' : 'categories'}',
                    style: const TextStyle(
                      color: accent,
                      fontSize: 10.5,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 16),
          if (raw == null)
            Text(
              isArabic
                  ? 'بيانات التصنيفات غير متاحة. حدّث Laravel للحصول على رؤى الإنفاق.'
                  : 'Category data unavailable. Update Laravel to enable insights.',
              style: TextStyle(color: textSecondary, fontSize: 12.5),
            )
          else if (categories.isEmpty || total <= 0)
            Text(
              isArabic
                  ? 'لا توجد مصروفات مصنفة لهذا الشهر بعد.'
                  : 'No spending categories recorded this month yet.',
              style: TextStyle(color: textSecondary, fontSize: 12.5),
            )
          else ...[
            ...visible.asMap().entries.map((entry) {
              final index = entry.key;
              final item = entry.value;
              final amount = (item['total'] as num?)?.toDouble() ?? 0;
              final share = (amount / total * 100).clamp(0.0, 100.0).toDouble();
              final previous =
                  (item['previous_month_total'] as num?)?.toDouble() ?? 0;
              final color = palette[index % palette.length];
              final category = nameFor((item['category'] ?? '').toString());
              return Padding(
                padding: const EdgeInsets.only(bottom: 15),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 8,
                          height: 8,
                          decoration: BoxDecoration(
                            color: color,
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            category,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: textPrimary,
                              fontWeight: FontWeight.w700,
                              fontSize: 12.5,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          '${moneyFormat.format(amount)} $currency',
                          textDirection: ui.TextDirection.ltr,
                          style: TextStyle(
                            color: textPrimary,
                            fontWeight: FontWeight.w800,
                            fontSize: 12.5,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: LinearProgressIndicator(
                        value: share / 100,
                        minHeight: 7,
                        backgroundColor: borderColor,
                        valueColor: AlwaysStoppedAnimation<Color>(color),
                      ),
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            '${share.toStringAsFixed(1)}% ${isArabic ? 'من إجمالي الإنفاق' : 'of monthly spending'}',
                            style: TextStyle(
                              color: textSecondary,
                              fontSize: 11,
                            ),
                          ),
                        ),
                        if (previous > 0)
                          Text(
                            '${amount >= previous ? '+' : ''}${((amount - previous) / previous * 100).toStringAsFixed(1)}% ${isArabic ? 'عن السابق' : 'vs prev.'}',
                            style: TextStyle(
                              color: amount > previous
                                  ? const Color(0xFFDC2626)
                                  : amount < previous
                                  ? const Color(0xFF059669)
                                  : textSecondary,
                              fontSize: 10.5,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                      ],
                    ),
                  ],
                ),
              );
            }),
            if (categories.length > 3)
              Align(
                alignment: AlignmentDirectional.centerStart,
                child: TextButton.icon(
                  onPressed: () =>
                      setState(() => _insightsExpanded = !_insightsExpanded),
                  icon: Icon(
                    _insightsExpanded
                        ? Icons.keyboard_arrow_up_rounded
                        : Icons.keyboard_arrow_down_rounded,
                    size: 19,
                  ),
                  label: Text(
                    _insightsExpanded
                        ? (isArabic ? 'عرض أقل' : 'Show less')
                        : (isArabic
                              ? 'عرض جميع التصنيفات'
                              : 'View all categories'),
                  ),
                  style: TextButton.styleFrom(
                    foregroundColor: accent,
                    textStyle: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: accent.withValues(alpha: isDark ? 0.14 : 0.055),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(
                    Icons.lightbulb_outline_rounded,
                    color: accent,
                    size: 19,
                  ),
                  const SizedBox(width: 9),
                  Expanded(
                    child: Text(
                      isArabic
                          ? 'أعلى تصنيف هو ${nameFor((categories.first['category'] ?? '').toString())} ويمثل ${(((categories.first['total'] as num?)?.toDouble() ?? 0) / total * 100).toStringAsFixed(1)}% من إنفاق هذا الشهر.'
                          : 'Your top category is ${nameFor((categories.first['category'] ?? '').toString())}, accounting for ${((((categories.first['total'] as num?)?.toDouble() ?? 0) / total) * 100).toStringAsFixed(1)}% of this month’s spending.',
                      style: TextStyle(
                        color: textPrimary,
                        fontSize: 12,
                        height: 1.5,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildSmartAlertsCard(
    bool isDark,
    Color cardBg,
    Color borderColor,
    Color textPrimary,
    Color textSecondary,
    bool isArabic,
  ) {
    final alerts =
        <({IconData icon, Color color, String title, String detail})>[];
    final budget = _generalBudget;
    final month = (_data['current_month'] ?? '').toString();
    final now = DateTime.now();
    final isCurrentMonth = month == DateFormat('yyyy-MM').format(now);
    final currency = (_data['currency'] ?? 'TRY').toString();
    final amountFormat = NumberFormat('#,##0.##');
    final spent = (budget?['spent'] as num?)?.toDouble() ?? 0;
    final limit = (budget?['amount'] as num?)?.toDouble() ?? 0;

    if (budget != null && limit > 0) {
      final percent = spent / limit * 100;
      if (percent >= 100) {
        final over = spent - limit;
        alerts.add((
          icon: Icons.error_outline_rounded,
          color: const Color(0xFFDC2626),
          title: isArabic ? 'تجاوزت الميزانية' : 'Budget exceeded',
          detail: isArabic
              ? 'تجاوزت الحد الشهري بمقدار ${amountFormat.format(over)} $currency.'
              : 'You exceeded the monthly limit by ${amountFormat.format(over)} $currency.',
        ));
      } else if (percent >= 80) {
        alerts.add((
          icon: Icons.warning_amber_rounded,
          color: const Color(0xFFD97706),
          title: isArabic
              ? 'اقتربت من حد الميزانية'
              : 'Approaching your budget',
          detail: isArabic
              ? 'استهلكت ${percent.toStringAsFixed(1)}% من الميزانية، والمتبقي ${amountFormat.format(limit - spent)} $currency.'
              : 'You used ${percent.toStringAsFixed(1)}% of your budget; ${amountFormat.format(limit - spent)} $currency remains.',
        ));
      } else if (isCurrentMonth && now.day >= 7) {
        final daysInMonth = DateTime(now.year, now.month + 1, 0).day;
        final timeShare = now.day / daysInMonth;
        final spendingShare = spent / limit;
        // Compare spending pace with elapsed time, not just the 80% threshold.
        if (spendingShare > timeShare * 1.3 &&
            spendingShare - timeShare >= 0.10) {
          alerts.add((
            icon: Icons.speed_rounded,
            color: const Color(0xFFD97706),
            title: isArabic
                ? 'الإنفاق أسرع من وتيرة الشهر'
                : 'Spending ahead of pace',
            detail: isArabic
                ? 'استهلكت ${percent.toStringAsFixed(1)}% من الميزانية بعد انقضاء ${(timeShare * 100).toStringAsFixed(0)}% من الشهر.'
                : 'You used ${percent.toStringAsFixed(1)}% of the budget with ${(timeShare * 100).toStringAsFixed(0)}% of the month elapsed.',
          ));
        }
      }
    }

    final rawCategories = _data['spending_categories'];
    if (rawCategories is List) {
      final categories = rawCategories.whereType<Map>();
      for (final item in categories) {
        final current = (item['total'] as num?)?.toDouble() ?? 0;
        final previous =
            (item['previous_month_total'] as num?)?.toDouble() ?? 0;
        // Require meaningful history and absolute growth to reduce noise.
        if (previous < 100 ||
            current - previous < 100 ||
            current < previous * 1.5) {
          continue;
        }
        final name = (item['category'] ?? '').toString().trim();
        final displayName = name.isEmpty || name == 'Uncategorized'
            ? (isArabic ? 'غير مصنف' : 'Uncategorized')
            : name;
        final increase = (current - previous) / previous * 100;
        alerts.add((
          icon: Icons.trending_up_rounded,
          color: const Color(0xFFD97706),
          title: isArabic
              ? 'ارتفاع إنفاق $displayName'
              : '$displayName spending increased',
          detail: isArabic
              ? 'ارتفع الإنفاق في هذا التصنيف ${increase.toStringAsFixed(0)}% مقارنة بالشهر السابق.'
              : 'Spending in this category is up ${increase.toStringAsFixed(0)}% compared with last month.',
        ));
        if (alerts.length >= 3) {
          break;
        }
      }
    }

    if (alerts.isEmpty && budget != null && limit > 0 && spent < limit) {
      alerts.add((
        icon: Icons.check_circle_outline_rounded,
        color: const Color(0xFF059669),
        title: isArabic ? 'لا توجد تنبيهات مهمة' : 'No important alerts',
        detail: isArabic
            ? 'إنفاقك الحالي ضمن الميزانية، ولم نرصد ارتفاعات كبيرة في التصنيفات التي تتوفر لها بيانات مقارنة.'
            : 'You are within budget, with no major increases in categories that have comparison data.',
      ));
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: borderColor),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.12 : 0.035),
            blurRadius: 20,
            offset: const Offset(0, 7),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(9),
                decoration: BoxDecoration(
                  color: const Color(0xFF6366F1).withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.notifications_active_outlined,
                  color: Color(0xFF6366F1),
                  size: 21,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  isArabic ? 'التنبيهات الذكية' : 'Smart Alerts',
                  style: TextStyle(
                    color: textPrimary,
                    fontSize: 16,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              if (alerts.isNotEmpty &&
                  !(alerts.length == 1 &&
                      alerts.first.icon == Icons.check_circle_outline_rounded))
                Text(
                  '${alerts.length}',
                  style: const TextStyle(
                    color: Color(0xFF6366F1),
                    fontWeight: FontWeight.w800,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 12),
          if (alerts.isEmpty)
            Text(
              isArabic
                  ? 'لا تتوفر بيانات كافية لإصدار تنبيهات مالية حاليًا.'
                  : 'Not enough data for financial alerts yet.',
              style: TextStyle(color: textSecondary, fontSize: 12.5),
            )
          else
            ...alerts
                .take(3)
                .map(
                  (alert) => Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: alert.color.withValues(
                          alpha: isDark ? 0.12 : 0.06,
                        ),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(alert.icon, color: alert.color, size: 20),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  alert.title,
                                  style: TextStyle(
                                    color: textPrimary,
                                    fontWeight: FontWeight.w800,
                                    fontSize: 12.5,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  alert.detail,
                                  style: TextStyle(
                                    color: textSecondary,
                                    height: 1.45,
                                    fontSize: 11.5,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
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
    const accent = Color(0xFF6366F1);
    final headline = _aiAdviceData?['headline']?.toString().trim() ?? '';
    final analysis = _aiAdviceData?['analysis']?.toString().trim() ?? '';
    final tips = (_aiAdviceData?['tips'] is List)
        ? List<dynamic>.from(
            _aiAdviceData!['tips'] as List,
          ).map((e) => e.toString().trim()).where((e) => e.isNotEmpty).toList()
        : <String>[];

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: borderColor),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.12 : 0.035),
            blurRadius: 22,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF4F46E5), Color(0xFF8B5CF6)],
                  ),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Icon(
                  Icons.auto_awesome_rounded,
                  color: Colors.white,
                  size: 22,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      isArabic
                          ? 'المستشار المالي الذكي'
                          : 'AI Financial Advisor',
                      maxLines: 2,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        height: 1.3,
                        color: textPrimary,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      isArabic
                          ? 'رؤى وتوصيات مدعومة بالذكاء الاصطناعي'
                          : 'AI-powered spending insights',
                      maxLines: 2,
                      style: TextStyle(
                        fontSize: 11.5,
                        height: 1.35,
                        color: textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              SizedBox(
                width: 44,
                height: 44,
                child: IconButton(
                  tooltip: isArabic ? 'تحديث التحليل' : 'Refresh insights',
                  onPressed: _isLoadingAiAdvice ? null : _fetchAiAdvice,
                  style: IconButton.styleFrom(
                    backgroundColor: accent.withValues(alpha: 0.09),
                    disabledBackgroundColor: accent.withValues(alpha: 0.05),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(13),
                    ),
                  ),
                  icon: _isLoadingAiAdvice
                      ? const SizedBox(
                          width: 19,
                          height: 19,
                          child: CircularProgressIndicator(
                            strokeWidth: 2.2,
                            color: accent,
                          ),
                        )
                      : const Icon(
                          Icons.refresh_rounded,
                          color: accent,
                          size: 22,
                        ),
                ),
              ),
            ],
          ),
          if (_isLoadingAiAdvice) ...[
            const SizedBox(height: 16),
            LinearProgressIndicator(
              minHeight: 3,
              borderRadius: BorderRadius.circular(8),
              backgroundColor: accent.withValues(alpha: 0.10),
              color: accent,
            ),
            const SizedBox(height: 10),
            Text(
              isArabic
                  ? 'جارٍ تحديث التحليل المالي…'
                  : 'Updating financial insights…',
              style: TextStyle(fontSize: 12, color: textSecondary),
            ),
          ],
          if (_aiAdviceError != null) ...[
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFEF4444).withValues(alpha: 0.07),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.error_outline_rounded,
                    color: Color(0xFFDC2626),
                    size: 20,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      _aiAdviceError!,
                      style: TextStyle(color: textPrimary, fontSize: 12.5),
                    ),
                  ),
                ],
              ),
            ),
          ],
          if (headline.isNotEmpty ||
              analysis.isNotEmpty ||
              tips.isNotEmpty) ...[
            const SizedBox(height: 12),
            if (headline.isNotEmpty) ...[
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 12,
                ),
                decoration: BoxDecoration(
                  color: accent.withValues(alpha: isDark ? 0.16 : 0.07),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Text(
                  headline,
                  style: TextStyle(
                    color: isDark
                        ? const Color(0xFFC7D2FE)
                        : const Color(0xFF4338CA),
                    fontSize: 14,
                    height: 1.55,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              const SizedBox(height: 8),
            ],
            if (analysis.isNotEmpty)
              Text(
                analysis,
                maxLines: _aiExpanded ? null : 2,
                overflow: _aiExpanded ? null : TextOverflow.ellipsis,
                style: TextStyle(
                  color: textPrimary,
                  fontSize: 13,
                  height: 1.55,
                  fontWeight: FontWeight.w400,
                ),
              ),
            if (_aiExpanded && tips.isNotEmpty) ...[
              const SizedBox(height: 14),
              Divider(height: 1, color: borderColor),
              const SizedBox(height: 18),
              Text(
                isArabic ? 'توصيات قابلة للتنفيذ' : 'Recommended next steps',
                style: TextStyle(
                  color: textPrimary,
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 12),
              ...tips.asMap().entries.map(
                (entry) => Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        width: 28,
                        height: 28,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: const Color(
                            0xFF10B981,
                          ).withValues(alpha: 0.11),
                          borderRadius: BorderRadius.circular(9),
                        ),
                        child: const Icon(
                          Icons.check_rounded,
                          color: Color(0xFF059669),
                          size: 17,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Padding(
                          padding: const EdgeInsets.only(top: 2),
                          child: Text(
                            entry.value,
                            style: TextStyle(
                              color: textSecondary,
                              fontSize: 13,
                              height: 1.7,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
            if (analysis.isNotEmpty || tips.isNotEmpty) ...[
              const SizedBox(height: 6),
              Align(
                alignment: AlignmentDirectional.centerStart,
                child: TextButton.icon(
                  onPressed: () => setState(() => _aiExpanded = !_aiExpanded),
                  icon: Icon(
                    _aiExpanded
                        ? Icons.keyboard_arrow_up_rounded
                        : Icons.keyboard_arrow_down_rounded,
                    size: 19,
                  ),
                  label: Text(
                    _aiExpanded
                        ? (isArabic ? 'عرض أقل' : 'Show less')
                        : (isArabic
                              ? 'عرض التحليل والتوصيات بالكامل'
                              : 'View full analysis & recommendations'),
                  ),
                  style: TextButton.styleFrom(
                    foregroundColor: accent,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 4,
                      vertical: 5,
                    ),
                    textStyle: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ),
            ],
          ] else if (!_isLoadingAiAdvice && _aiAdviceError == null) ...[
            const SizedBox(height: 18),
            Text(
              isArabic
                  ? 'أضف فواتيرك للحصول على تحليل مالي وتوصيات مخصصة.'
                  : 'Add receipts to unlock personalized financial insights.',
              style: TextStyle(color: textSecondary, fontSize: 13, height: 1.6),
            ),
          ],
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
    final dailyAvg = (_data['daily_average'] as num?) ?? 0;
    final totalReceipts =
        (_data['total_receipts_count'] as num?) ??
        (_data['total_count'] as num?) ??
        0;
    final highest = (_data['highest_expense_amount'] as num?) ?? 0;
    final currency = (_data['currency'] ?? 'TRY').toString();
    return LayoutBuilder(
      builder: (context, constraints) {
        // Always keep the three metrics in one row on phones.
        final isCompact = constraints.maxWidth < 500;
        final gap = isCompact ? 7.0 : 12.0;
        final width = (constraints.maxWidth - gap * 2) / 3;
        final metrics = [
          (
            isArabic ? 'المعدل اليومي' : 'Daily average',
            NumberFormat('#,##0.#').format(dailyAvg),
            Icons.calendar_today_rounded,
            const Color(0xFF0284C7),
            true,
          ),
          (
            isArabic ? 'عدد الفواتير' : 'Receipts',
            NumberFormat.decimalPattern().format(totalReceipts),
            Icons.receipt_long_rounded,
            const Color(0xFF059669),
            false,
          ),
          (
            isArabic ? 'أعلى فاتورة' : 'Highest bill',
            NumberFormat('#,##0').format(highest),
            Icons.star_outline_rounded,
            const Color(0xFFD97706),
            true,
          ),
        ];
        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            for (var i = 0; i < metrics.length; i++) ...[
              if (i > 0) SizedBox(width: gap),
              SizedBox(
                width: width,
                child: _buildMetricTile(
                  title: metrics[i].$1,
                  value: metrics[i].$2,
                  currency: metrics[i].$5 ? currency : null,
                  icon: metrics[i].$3,
                  iconColor: metrics[i].$4,
                  cardBg: cardBg,
                  borderColor: borderColor,
                  textPrimary: textPrimary,
                  textSecondary: textSecondary,
                  compact: isCompact,
                ),
              ),
            ],
          ],
        );
      },
    );
  }

  Widget _buildMetricTile({
    required String title,
    required String value,
    required String? currency,
    required IconData icon,
    required Color iconColor,
    required Color cardBg,
    required Color borderColor,
    required Color textPrimary,
    required Color textSecondary,
    required bool compact,
  }) {
    return Container(
      constraints: const BoxConstraints(minHeight: 116),
      padding: EdgeInsets.symmetric(horizontal: compact ? 9 : 16, vertical: 12),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(17),
        border: Border.all(color: borderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: iconColor.withValues(alpha: 0.10),
              borderRadius: BorderRadius.circular(9),
            ),
            child: Icon(icon, color: iconColor, size: 17),
          ),
          const SizedBox(height: 9),
          Text(
            title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: textSecondary,
              fontSize: compact ? 10 : 12,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 5),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: AlignmentDirectional.centerStart,
            child: Directionality(
              textDirection: ui.TextDirection.ltr,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    value,
                    style: TextStyle(
                      color: textPrimary,
                      fontSize: compact ? 17 : 20,
                      fontWeight: FontWeight.w900,
                      fontFeatures: const [ui.FontFeature.tabularFigures()],
                    ),
                  ),
                  if (currency != null) ...[
                    const SizedBox(width: 3),
                    Text(
                      currency,
                      style: TextStyle(
                        color: textSecondary,
                        fontSize: compact ? 9 : 11,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // Always normalize to a contiguous six-month window. A year is part of
  // each key, so Oct 2025 and Oct 2026 never collapse into one bucket.
  List<({String month, double total})> _normalizedMonthlyTrend() {
    final raw = _data['monthly_trend'];
    final totals = <String, double>{};
    if (raw is List) {
      for (final entry in raw) {
        if (entry is! Map) continue;
        final key = (entry['month'] ?? '').toString();
        if (!RegExp(r'^\d{4}-(0[1-9]|1[0-2])$').hasMatch(key)) continue;
        final amount = entry['total'];
        if (amount is num && amount.isFinite) {
          totals[key] = (totals[key] ?? 0) + amount.toDouble();
        }
      }
    }
    final key = (_data['current_month'] ?? '').toString();
    final match = RegExp(r'^(\d{4})-(0[1-9]|1[0-2])$').firstMatch(key);
    final end = match == null
        ? DateTime(DateTime.now().year, DateTime.now().month)
        : DateTime(int.parse(match.group(1)!), int.parse(match.group(2)!));
    return List.generate(6, (i) {
      final date = DateTime(end.year, end.month - 5 + i);
      final month = DateFormat('yyyy-MM').format(date);
      return (month: month, total: max(0.0, totals[month] ?? 0.0));
    });
  }

  Widget _buildMonthlyTrendChart(
    bool isDark,
    Color cardBg,
    Color borderColor,
    Color textPrimary,
    Color textSecondary,
    bool isArabic,
  ) {
    final months = _normalizedMonthlyTrend();
    final largest = months.fold<double>(0, (m, e) => max(m, e.total));
    final hasData = largest > 0;
    // Four readable grid intervals and a little headroom.
    final magnitude = largest <= 0
        ? 1.0
        : pow(10, (log(largest / 4) / ln10).floor()).toDouble();
    final target = largest / 4 / magnitude;
    final nice = target <= 1
        ? 1.0
        : target <= 2
        ? 2.0
        : target <= 2.5
        ? 2.5
        : target <= 5
        ? 5.0
        : 10.0;
    final interval = max(1.0, nice * magnitude);
    final maxY = max(
      4 * interval,
      (largest / interval).ceil() * interval,
    ).toDouble();
    final currency = (_data['currency'] ?? 'TRY').toString();

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 14),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: borderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFF4F46E5).withValues(alpha: .10),
                  borderRadius: BorderRadius.circular(11),
                ),
                child: const Icon(
                  Icons.bar_chart_rounded,
                  color: Color(0xFF4F46E5),
                  size: 20,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      isArabic
                          ? 'مسار الإنفاق الشهري'
                          : 'Monthly Spending Trend',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w900,
                        color: textPrimary,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      isArabic
                          ? 'آخر 6 أشهر • $currency'
                          : 'Last 6 months • $currency',
                      style: TextStyle(fontSize: 11, color: textSecondary),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 22),
          if (!hasData)
            SizedBox(
              height: 130,
              child: Center(
                child: Text(
                  isArabic
                      ? 'لا توجد مصروفات خلال الأشهر الستة الأخيرة'
                      : 'No spending in the last six months',
                  style: TextStyle(color: textSecondary, fontSize: 12),
                ),
              ),
            )
          else
            LayoutBuilder(
              builder: (context, constraints) {
                final compact = constraints.maxWidth < 480;
                return SizedBox(
                  height: compact ? 196 : 225,
                  child: Directionality(
                    textDirection: ui.TextDirection.ltr,
                    child: BarChart(
                      BarChartData(
                        minY: 0,
                        maxY: maxY,
                        alignment: BarChartAlignment.spaceEvenly,
                        groupsSpace: compact ? 12 : 26,
                        barTouchData: BarTouchData(
                          enabled: true,
                          touchTooltipData: BarTouchTooltipData(
                            getTooltipColor: (_) => const Color(0xFF0F172A),
                            getTooltipItem: (group, groupIndex, rod, rodIndex) {
                              if (group.x < 0 || group.x >= months.length) {
                                return null;
                              }
                              final item = months[group.x];
                              final date = DateTime.parse('${item.month}-01');
                              final label = DateFormat.yMMMM(
                                isArabic ? 'ar' : 'en',
                              ).format(date);
                              return BarTooltipItem(
                                '$label\n${NumberFormat('#,##0.##').format(item.total)} $currency',
                                const TextStyle(
                                  color: Colors.white,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                  height: 1.5,
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
                              reservedSize: compact ? 43 : 52,
                              interval: interval,
                              getTitlesWidget: (value, meta) {
                                // Don't print a second label at the upper boundary.
                                if (value < 0 ||
                                    value > maxY ||
                                    (value - maxY).abs() < 0.00001) {
                                  return const SizedBox.shrink();
                                }
                                return SideTitleWidget(
                                  meta: meta,
                                  space: 6,
                                  child: Text(
                                    NumberFormat.compact(
                                      locale: 'en',
                                    ).format(value),
                                    maxLines: 1,
                                    style: TextStyle(
                                      color: textSecondary,
                                      fontSize: compact ? 9 : 10,
                                    ),
                                  ),
                                );
                              },
                            ),
                          ),
                          bottomTitles: AxisTitles(
                            sideTitles: SideTitles(
                              showTitles: true,
                              reservedSize: 40,
                              interval: 1,
                              getTitlesWidget: (value, meta) {
                                final i = value.toInt();
                                if (i < 0 ||
                                    i >= months.length ||
                                    value != i.toDouble()) {
                                  return const SizedBox.shrink();
                                }
                                final date = DateTime.parse(
                                  '${months[i].month}-01',
                                );
                                final label = DateFormat.MMM(
                                  isArabic ? 'ar' : 'en',
                                ).format(date);
                                final isCurrent = i == months.length - 1;
                                final showYear = date.month == 1;
                                return SideTitleWidget(
                                  meta: meta,
                                  space: 8,
                                  child: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Text(
                                        label,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: TextStyle(
                                          color: isCurrent
                                              ? const Color(0xFF6366F1)
                                              : textSecondary,
                                          fontSize: compact ? 9 : 11,
                                          fontWeight: isCurrent
                                              ? FontWeight.w900
                                              : FontWeight.w600,
                                        ),
                                      ),
                                      if (showYear)
                                        Text(
                                          '${date.year}',
                                          style: TextStyle(
                                            color: textSecondary,
                                            fontSize: 8,
                                          ),
                                        ),
                                    ],
                                  ),
                                );
                              },
                            ),
                          ),
                        ),
                        gridData: FlGridData(
                          show: true,
                          drawVerticalLine: false,
                          horizontalInterval: interval,
                          getDrawingHorizontalLine: (value) => FlLine(
                            color: borderColor.withValues(
                              alpha: isDark ? .5 : .8,
                            ),
                            strokeWidth: 1,
                            dashArray: [4, 4],
                          ),
                        ),
                        borderData: FlBorderData(show: false),
                        barGroups: List.generate(months.length, (i) {
                          final value = months[i].total;
                          return BarChartGroupData(
                            x: i,
                            barsSpace: 0,
                            barRods: [
                              BarChartRodData(
                                toY: value,
                                width: compact ? 17 : 25,
                                borderRadius: const BorderRadius.vertical(
                                  top: Radius.circular(6),
                                ),
                                gradient: const LinearGradient(
                                  begin: Alignment.bottomCenter,
                                  end: Alignment.topCenter,
                                  colors: [
                                    Color(0xFF4F46E5),
                                    Color(0xFF38BDF8),
                                  ],
                                ),
                              ),
                            ],
                          );
                        }),
                      ),
                    ),
                  ),
                );
              },
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
      padding: const EdgeInsets.all(16),
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
          const SizedBox(height: 12),
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
                      Divider(height: 14, color: borderColor),
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
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  color: textPrimary,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 14,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                '${NumberFormat('#,##0.##').format(total)} ${_data['currency'] ?? 'TRY'}',
                                style: TextStyle(
                                  color: textPrimary,
                                  fontSize: 13.5,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                              const SizedBox(height: 3),
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
                      ],
                    );
                  },
                ),
        ],
      ),
    );
  }
}
