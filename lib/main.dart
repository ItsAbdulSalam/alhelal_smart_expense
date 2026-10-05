import 'package:alhelal_smart_expense/core/services/local_expense_service.dart';
import 'package:alhelal_smart_expense/core/theme/app_theme.dart';
import 'package:alhelal_smart_expense/core/theme/theme_controller.dart';
import 'package:alhelal_smart_expense/core/utils/locale_controller.dart';
import 'package:alhelal_smart_expense/l10n/app_localizations.dart';
import 'package:alhelal_smart_expense/presentation/widgets/connectivity_banner.dart';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'presentation/screens/auth_screen.dart';
import 'presentation/screens/dashboard_loader.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // 1. قراءة متغيرات البيئة
  try {
    await dotenv.load(fileName: '.env');
  } catch (_) {
    debugPrint('ℹ️ .env bypass');
  }

  // 2. قراءة التفضيلات (اللغة والثيم)
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

  // 3. تهيئة Hive
  if (!kIsWeb) {
    await Hive.initFlutter();
    if (!Hive.isBoxOpen('expenses_box')) {
      await Hive.openBox('expenses_box');
    }
    await LocalExpenseService.initQueueBox();
  }

  // 4. تهيئة Supabase
  final supabaseUrl = const String.fromEnvironment('SUPABASE_URL').isNotEmpty
      ? const String.fromEnvironment('SUPABASE_URL')
      : (dotenv.env['SUPABASE_URL'] ?? '');

  final supabaseAnonKey =
      const String.fromEnvironment('SUPABASE_ANON_KEY').isNotEmpty
      ? const String.fromEnvironment('SUPABASE_ANON_KEY')
      : (dotenv.env['SUPABASE_ANON_KEY'] ?? '');

  if (supabaseUrl.isNotEmpty && supabaseAnonKey.isNotEmpty) {
    await Supabase.initialize(url: supabaseUrl, anonKey: supabaseAnonKey);
  }

  // 5. تحديد الشاشة الأولى مباشرة
  final session = Supabase.instance.client.auth.currentSession;
  final Widget initialScreen = session != null
      ? const DashboardLoader()
      : const AuthScreen();

  // تشغيل التطبيق بعد اكتمال كل شيء للانتقال الفوري
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
      // تفتح شاشة التطبيق فوراً بدون أي مرحلة وسيطة
      home: widget.initialScreen,
    );
  }
}
