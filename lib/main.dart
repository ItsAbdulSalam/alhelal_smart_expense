import 'package:alhelal_smart_expense/core/services/local_expense_service.dart';
import 'package:alhelal_smart_expense/presentation/widgets/connectivity_banner.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:alhelal_smart_expense/l10n/app_localizations.dart';

import 'presentation/screens/auth_screen.dart';
import 'presentation/screens/dashboard_screen.dart';
import 'presentation/screens/splash_screen.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();

  // لا ننتظر Supabase أو SharedPreferences هنا.
  runApp(const MyApp());
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  static void setLocale(BuildContext context, Locale newLocale) {
    final state = context.findAncestorStateOfType<_MyAppState>();
    state?.setLocale(newLocale);
  }

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
    _initializeApp();
  }

  Future<void> _initializeApp() async {
    try {
      debugPrint('🚀 App initialization START');

      // تحميل ملف البيئة وقراءة اللغة بالتوازي.
      final results = await Future.wait([
        dotenv.load(fileName: '.env'),
        SharedPreferences.getInstance(),
      ]);

      final prefs = results[1] as SharedPreferences;

      final savedLangCode = prefs.getString('language_code') ?? 'ar';

      if (mounted) {
        setState(() {
          _locale = Locale(savedLangCode);
        });
      }

      debugPrint('✅ Environment + Preferences OK');

      // =========================================================
      // Hive initialization
      // =========================================================

      debugPrint('📦 Hive initialization START');

      // تهيئة Hive.
      await Hive.initFlutter();

      // فتح صندوق المصاريف إذا لم يكن مفتوحاً.
      if (!Hive.isBoxOpen('expenses_box')) {
        await Hive.openBox('expenses_box');
      }

      debugPrint('✅ expenses_box opened');

      // تهيئة صندوق العمليات المؤجلة Offline Queue.
      await LocalExpenseService.initQueueBox();

      debugPrint('✅ Offline Queue initialized');
      debugPrint('✅ Hive initialization OK');

      // =========================================================
      // Supabase initialization
      // =========================================================

      await Supabase.initialize(
        url: dotenv.env['SUPABASE_URL'] ?? '',
        publishableKey: dotenv.env['SUPABASE_ANON_KEY'] ?? '',
      );

      debugPrint('✅ Supabase OK');

      // =========================================================
      // Determine initial screen
      // =========================================================

      final session = Supabase.instance.client.auth.currentSession;

      final nextScreen = session != null
          ? const DashboardScreen()
          : const AuthScreen();

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

  Future<void> setLocale(Locale locale) async {
    setState(() {
      _locale = locale;
    });

    final prefs = await SharedPreferences.getInstance();

    await prefs.setString('language_code', locale.languageCode);
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Alhelal Smart Expense',
      debugShowCheckedModeBanner: false,

      // اللغة الحالية
      locale: _locale,

      // اللغات المدعومة
      supportedLocales: AppLocalizations.supportedLocales,

      // Localization delegates
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],

      // Theme
      theme: ThemeData(
        useMaterial3: true,
        fontFamily: 'Cairo',
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF4F46E5)),
      ),

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
      // Initial screen
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
    return const Scaffold(
      backgroundColor: Color(0xFF080E1A),
      body: Center(child: CircularProgressIndicator()),
    );
  }
}
