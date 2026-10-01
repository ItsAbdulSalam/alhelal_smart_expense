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
import 'presentation/screens/splash_screen.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();

  runApp(const MyApp());
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  Locale _locale = const Locale('ar');
  ThemeMode _themeMode = ThemeMode.system;

  bool _initialized = false;
  Widget? _nextScreen;

  @override
  void initState() {
    super.initState();

    // الاستماع لتغيير اللغة.
    LocaleController.locale.addListener(_onLocaleChanged);

    // الاستماع لتغيير الثيم.
    ThemeController.themeMode.addListener(_onThemeChanged);

    // بدء تهيئة التطبيق.
    _initializeApp();
  }

  // ===============================================================
  // Locale
  // ===============================================================

  Future<void> _onLocaleChanged() async {
    final newLocale = LocaleController.locale.value;

    if (!mounted) return;

    if (_locale == newLocale) return;

    setState(() {
      _locale = newLocale;
    });

    final prefs = await SharedPreferences.getInstance();

    await prefs.setString('language_code', newLocale.languageCode);
  }

  // ===============================================================
  // Theme
  // ===============================================================

  void _onThemeChanged() {
    final newThemeMode = ThemeController.themeMode.value;

    if (!mounted) return;

    if (_themeMode == newThemeMode) return;

    setState(() {
      _themeMode = newThemeMode;
    });
  }

  // ===============================================================
  // Application Initialization
  // ===============================================================

  Future<void> _initializeApp() async {
    try {
      debugPrint('🚀 App initialization START');

      // =========================================================
      // Environment + Preferences (Safe Hybrid Loading)
      // =========================================================

      // محاولة تحميل .env محلياً فقط إن وُجد، وتجاهله تماماً في بيئة الويب دون إيقاف التطبيق
      try {
        await dotenv.load(fileName: '.env');
      } catch (_) {
        debugPrint(
          'ℹ️ .env file not found or running on Web, relying on build-time env vars.',
        );
      }

      final prefs = await SharedPreferences.getInstance();

      // ---------------------------------------------------------
      // Language
      // ---------------------------------------------------------

      final savedLangCode = prefs.getString('language_code') ?? 'ar';

      final savedLocale = Locale(savedLangCode);

      LocaleController.locale.value = savedLocale;

      // ---------------------------------------------------------
      // Theme
      // ---------------------------------------------------------

      final savedTheme = prefs.getString('theme_mode');

      final savedThemeMode = switch (savedTheme) {
        'light' => ThemeMode.light,
        'dark' => ThemeMode.dark,
        _ => ThemeMode.system,
      };

      ThemeController.themeMode.value = savedThemeMode;

      // ---------------------------------------------------------
      // Update local state once
      // ---------------------------------------------------------

      if (mounted) {
        setState(() {
          _locale = savedLocale;
          _themeMode = savedThemeMode;
        });
      }

      debugPrint('✅ Environment + Preferences OK');
      debugPrint('🎨 Theme mode: ${savedThemeMode.name}');

      // =========================================================
      // Hive initialization
      // =========================================================

      // =========================================================
      // Hive initialization (Web & Native Safe)
      // =========================================================

      // =========================================================
      // Hive initialization (Safe for Web)
      // =========================================================
      if (!kIsWeb) {
        debugPrint('📦 Hive initialization START');
        await Hive.initFlutter();
        if (!Hive.isBoxOpen('expenses_box')) {
          await Hive.openBox('expenses_box');
        }
        await LocalExpenseService.initQueueBox();
        debugPrint('✅ Hive initialization OK');
      } else {
        debugPrint('🌐 Web detected: Skipping Native Hive filesystem');
      }
      // =========================================================
      // Supabase initialization (Dart-Define First with .env Fallback)
      // =========================================================

      final supabaseUrl =
          const String.fromEnvironment('SUPABASE_URL').isNotEmpty
          ? const String.fromEnvironment('SUPABASE_URL')
          : (dotenv.env['SUPABASE_URL'] ?? '');

      final supabaseAnonKey =
          const String.fromEnvironment('SUPABASE_ANON_KEY').isNotEmpty
          ? const String.fromEnvironment('SUPABASE_ANON_KEY')
          : (dotenv.env['SUPABASE_ANON_KEY'] ?? '');

      if (supabaseUrl.isEmpty || supabaseAnonKey.isEmpty) {
        throw Exception(
          'SUPABASE_URL أو SUPABASE_ANON_KEY غير موجودة عبر dart-define أو .env',
        );
      }

      await Supabase.initialize(url: supabaseUrl, anonKey: supabaseAnonKey);

      debugPrint('✅ Supabase OK');

      // =========================================================
      // Determine initial screen
      // =========================================================

      final session = Supabase.instance.client.auth.currentSession;

      final Widget nextScreen;

      if (session != null) {
        nextScreen = const DashboardLoader();
      } else {
        nextScreen = const AuthScreen();
      }

      if (!mounted) return;

      setState(() {
        _nextScreen = nextScreen;
        _initialized = true;
      });

      debugPrint('✅ Initialization completed');
    } catch (e, stackTrace) {
      debugPrint('❌ STARTUP ERROR: $e');
      debugPrint('$stackTrace');

      if (!mounted) return;

      setState(() {
        _nextScreen = const AuthScreen();
        _initialized = true;
      });
    }
  }

  // ===============================================================
  // Dispose
  // ===============================================================

  @override
  void dispose() {
    LocaleController.locale.removeListener(_onLocaleChanged);
    ThemeController.themeMode.removeListener(_onThemeChanged);

    super.dispose();
  }

  // ===============================================================
  // Build
  // ===============================================================

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Alhelal Smart Expense',
      debugShowCheckedModeBanner: false,

      // =========================================================
      // Localization
      // =========================================================
      locale: _locale,

      supportedLocales: AppLocalizations.supportedLocales,

      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],

      // =========================================================
      // Theme
      // =========================================================
      theme: AppTheme.lightTheme,

      darkTheme: AppTheme.darkTheme,

      themeMode: _themeMode,

      // =========================================================
      // RTL / LTR + Connectivity Banner
      // =========================================================
      builder: (context, child) {
        final isArabic = _locale.languageCode == 'ar';

        return Directionality(
          textDirection: isArabic ? TextDirection.rtl : TextDirection.ltr,
          child: ConnectivityBanner(child: child ?? const SizedBox()),
        );
      },

      // =========================================================
      // Initial Screen
      // =========================================================
      home: !_initialized
          ? const _StartupScreen()
          : kIsWeb
          ? _nextScreen!
          : SplashScreen(nextScreen: _nextScreen!),
    );
  }
}

// ===============================================================
// Startup Screen
// ===============================================================

class _StartupScreen extends StatelessWidget {
  const _StartupScreen();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: Center(
        child: CircularProgressIndicator(
          color: Theme.of(context).colorScheme.primary,
        ),
      ),
    );
  }
}
