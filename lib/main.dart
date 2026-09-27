import 'package:alhelal_smart_expense/core/services/local_expense_service.dart';
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
import 'presentation/screens/dashboard_screen.dart';
import 'presentation/screens/splash_screen.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();

  // تشغيل الواجهة مباشرة، ثم تنفيذ عمليات التهيئة داخل MyApp.
  runApp(const MyApp());
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  Locale _locale = const Locale('ar');

  bool _initialized = false;
  Widget? _nextScreen;

  @override
  void initState() {
    super.initState();

    // الاستماع لأي تغيير لغة قادم من LocaleController.
    LocaleController.locale.addListener(_onLocaleChanged);

    // بدء تهيئة التطبيق.
    _initializeApp();
  }

  // ===============================================================
  // Locale Listener
  // ===============================================================

  Future<void> _onLocaleChanged() async {
    final newLocale = LocaleController.locale.value;

    if (!mounted) return;

    // لا نعيد بناء التطبيق إذا كانت اللغة نفسها.
    if (_locale == newLocale) return;

    setState(() {
      _locale = newLocale;
    });

    // حفظ اللغة لاستخدامها عند تشغيل التطبيق مرة أخرى.
    final prefs = await SharedPreferences.getInstance();

    await prefs.setString(
      'language_code',
      newLocale.languageCode,
    );
  }

  // ===============================================================
  // Application Initialization
  // ===============================================================

  Future<void> _initializeApp() async {
    try {
      debugPrint('🚀 App initialization START');

      // -----------------------------------------------------------
      // Environment + Preferences
      // -----------------------------------------------------------

      // تحميل ملف البيئة وSharedPreferences بالتوازي.
      final results = await Future.wait([
        dotenv.load(fileName: '.env'),
        SharedPreferences.getInstance(),
      ]);

      final prefs = results[1] as SharedPreferences;

      final savedLangCode =
          prefs.getString('language_code') ?? 'ar';

      final savedLocale = Locale(savedLangCode);

      // تحديث LocaleController.
      LocaleController.locale.value = savedLocale;

      // تحديث لغة التطبيق الحالية.
      if (mounted && _locale != savedLocale) {
        setState(() {
          _locale = savedLocale;
        });
      }

      debugPrint('✅ Environment + Preferences OK');

      // =========================================================
      // Hive initialization
      // =========================================================

      debugPrint('📦 Hive initialization START');

      await Hive.initFlutter();

      // فتح صندوق المصاريف.
      if (!Hive.isBoxOpen('expenses_box')) {
        await Hive.openBox('expenses_box');
      }

      debugPrint('✅ expenses_box opened');

      // فتح وتهيئة Offline Queue.
      await LocalExpenseService.initQueueBox();

      debugPrint('✅ Offline Queue initialized');
      debugPrint('✅ Hive initialization OK');

      // =========================================================
      // Supabase initialization
      // =========================================================

      final supabaseUrl = dotenv.env['SUPABASE_URL'] ?? '';
      final supabaseAnonKey =
          dotenv.env['SUPABASE_ANON_KEY'] ?? '';

      if (supabaseUrl.isEmpty || supabaseAnonKey.isEmpty) {
        throw Exception(
          'SUPABASE_URL أو SUPABASE_ANON_KEY غير موجود في ملف .env',
        );
      }

      await Supabase.initialize(
        url: supabaseUrl,
        publishableKey: supabaseAnonKey,
      );

      debugPrint('✅ Supabase OK');

      // =========================================================
      // Determine initial screen
      // =========================================================

      final session =
          Supabase.instance.client.auth.currentSession;

      final Widget nextScreen;

      if (session != null) {
        nextScreen = const DashboardScreen();
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

      // اللغة الحالية.
      locale: _locale,

      // اللغات المدعومة.
      supportedLocales: AppLocalizations.supportedLocales,

      // Localization delegates.
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],

      // Theme.
      theme: ThemeData(
        useMaterial3: true,
        fontFamily: 'Cairo',
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF4F46E5),
        ),
      ),

      // =========================================================
      // RTL / LTR + Connectivity Banner
      // =========================================================

      builder: (context, child) {
        final isArabic =
            _locale.languageCode == 'ar';

        return Directionality(
          textDirection:
              isArabic
                  ? TextDirection.rtl
                  : TextDirection.ltr,
          child: ConnectivityBanner(
            child: child ?? const SizedBox(),
          ),
        );
      },

      // =========================================================
      // Initial screen
      // =========================================================

      home: !_initialized
          ? const _StartupScreen()
          : kIsWeb
              ? _nextScreen!
              : SplashScreen(
                  nextScreen: _nextScreen!,
                ),
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
    return const Scaffold(
      backgroundColor: Color(0xFF080E1A),
      body: Center(
        child: CircularProgressIndicator(),
      ),
    );
  }
}