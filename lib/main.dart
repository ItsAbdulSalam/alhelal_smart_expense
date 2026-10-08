import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'core/services/api_client.dart';
import 'core/services/local_expense_service.dart';
import 'core/theme/app_theme.dart';
import 'core/theme/theme_controller.dart';
import 'core/utils/locale_controller.dart';
import 'data/datasources/expense_laravel_remote_data_source.dart';
import 'data/repositories/laravel_auth_repository.dart';
import 'data/repositories/laravel_expense_repository.dart';
import 'l10n/app_localizations.dart';
import 'presentation/screens/auth_screen.dart';
import 'presentation/screens/dashboard_loader.dart';
import 'presentation/widgets/connectivity_banner.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // 1. قراءة متغيرات البيئة
  try {
    await dotenv.load(fileName: '.env');
  } catch (_) {
    debugPrint('ℹ️ .env bypass');
  }

  // 2. تهيئة ApiClient الخاص بسيرفر Laravel
  ApiClient.init();

  // 3. قراءة تفضيلات اللغة والمظهر
  final prefs = await SharedPreferences.getInstance();

  final savedLangCode = prefs.getString('language_code') ?? 'ar';
  final initialLocale = Locale(savedLangCode);
  LocaleController.locale.value = initialLocale;

  final savedTheme = prefs.getString('theme_mode');
  final initialThemeMode = switch (savedTheme) {
    'light' => ThemeMode.light,
    'dark' => ThemeMode.dark,
    _ => ThemeMode.system,
  };
  ThemeController.themeMode.value = initialThemeMode;

  // 4. تهيئة التخزين المحلي عبر Hive
  if (!kIsWeb) {
    await Hive.initFlutter();
    if (!Hive.isBoxOpen('expenses_box')) {
      await Hive.openBox('expenses_box');
    }
    await LocalExpenseService.initQueueBox();
  }

  // 5. اختبار الاتصال وجلب البيانات من Laravel
  try {
    final laravelRepo = LaravelExpenseRepository(
      ExpenseLaravelRemoteDataSource(dio: ApiClient.dio),
    );
    final expenses = await laravelRepo.getExpenses();
    debugPrint(
      '🎉 LARAVEL API SUCCESS: تم جلب ${expenses.length} مصاريف بنجاح!',
    );
  } catch (e) {
    debugPrint('❌ LARAVEL API ERROR: $e');
  }

  // 6. تحديد الشاشة الأولى بناءً على توكن مصادقة Laravel
  final authRepo = LaravelAuthRepository();
  final bool isLoggedIn = await authRepo.isAuthenticated();

  final Widget initialScreen = isLoggedIn
      ? const DashboardLoader()
      : const AuthScreen();

  runApp(
    MyApp(
      initialScreen: initialScreen,
      initialLocale: initialLocale,
      initialThemeMode: initialThemeMode,
    ),
  );
}

class MyApp extends StatefulWidget {
  final Widget initialScreen;
  final Locale initialLocale;
  final ThemeMode initialThemeMode;

  const MyApp({
    super.key,
    required this.initialScreen,
    required this.initialLocale,
    required this.initialThemeMode,
  });

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  late Locale _locale;
  late ThemeMode _themeMode;

  @override
  void initState() {
    super.initState();
    _locale = widget.initialLocale;
    _themeMode = widget.initialThemeMode;

    LocaleController.locale.addListener(_onLocaleChanged);
    ThemeController.themeMode.addListener(_onThemeChanged);
  }

  Future<void> _onLocaleChanged() async {
    final newLocale = LocaleController.locale.value;
    if (!mounted || _locale == newLocale) return;
    setState(() => _locale = newLocale);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('language_code', newLocale.languageCode);
  }

  void _onThemeChanged() {
    final newThemeMode = ThemeController.themeMode.value;
    if (!mounted || _themeMode == newThemeMode) return;
    setState(() => _themeMode = newThemeMode);
  }

  @override
  void dispose() {
    LocaleController.locale.removeListener(_onLocaleChanged);
    ThemeController.themeMode.removeListener(_onThemeChanged);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Alhelal Smart Expense',
      debugShowCheckedModeBanner: false,
      locale: _locale,
      supportedLocales: AppLocalizations.supportedLocales,
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: _themeMode,
      builder: (context, child) {
        final isArabic = _locale.languageCode == 'ar';
        return Directionality(
          textDirection: isArabic ? TextDirection.rtl : TextDirection.ltr,
          child: ConnectivityBanner(child: child ?? const SizedBox()),
        );
      },
      home: widget.initialScreen,
    );
  }
}
