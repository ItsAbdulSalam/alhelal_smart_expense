import 'dart:ui' as ui;

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';

import '../../core/utils/locale_controller.dart';
import '../../data/repositories/laravel_auth_repository.dart';
import '../../l10n/app_localizations.dart';
import 'dashboard_loader.dart';

class AuthScreen extends StatefulWidget {
  const AuthScreen({super.key});

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  final LaravelAuthRepository _authRepo = LaravelAuthRepository();

  bool _isSignUp = false;
  bool _isLoading = false;
  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  void _showNotification(String message, {bool isError = true}) {
    if (!mounted) return;

    final isArabic = Localizations.localeOf(context).languageCode == 'ar';

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Directionality(
          textDirection: isArabic ? ui.TextDirection.rtl : ui.TextDirection.ltr,
          child: Row(
            children: [
              Icon(
                isError
                    ? Icons.error_outline_rounded
                    : Icons.check_circle_rounded,
                color: Colors.white,
                size: 20,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  message,
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 13.5,
                  ),
                ),
              ),
            ],
          ),
        ),
        backgroundColor: isError
            ? const Color(0xFFE11D48)
            : const Color(0xFF059669),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.all(16),
        duration: const Duration(seconds: 4),
      ),
    );
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    final loc = AppLocalizations.of(context)!;
    final isArabic = Localizations.localeOf(context).languageCode == 'ar';

    setState(() => _isLoading = true);

    try {
      final email = _emailController.text.trim();
      final password = _passwordController.text.trim();

      if (_isSignUp) {
        final name = _nameController.text.trim();
        final confirmPassword = _confirmPasswordController.text.trim();

        await _authRepo.register(
          name: name,
          email: email,
          password: password,
          passwordConfirmation: confirmPassword,
        );

        _showNotification(
          isArabic
              ? 'تم إنشاء الحساب بنجاح! جاري الدخول...'
              : 'Account created successfully! Logging in...',
          isError: false,
        );
      } else {
        await _authRepo.login(email: email, password: password);
      }

      if (!mounted) return;

      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const DashboardLoader()),
        );
      });
    } on DioException catch (e) {
      String msg = isArabic
          ? 'تعذر الاتصال بالسيرفر، يرجى المحاولة لاحقاً'
          : 'Failed to connect to server, please try again';

      final responseData = e.response?.data;
      if (responseData is Map && responseData['message'] != null) {
        final serverMsg = responseData['message'].toString();
        if (serverMsg.contains('Invalid') || e.response?.statusCode == 401) {
          msg = loc.invalidCredentials;
        } else if (serverMsg.contains('taken') ||
            serverMsg.contains('already')) {
          msg = isArabic
              ? 'هذا البريد مسجل بالفعل، يرجى تسجيل الدخول'
              : 'Email already registered, please login';
        } else {
          msg = serverMsg;
        }
      }

      _showNotification(msg, isError: true);
    } catch (_) {
      _showNotification(
        isArabic
            ? 'حدث خطأ غير متوقع، يرجى المحاولة لاحقاً'
            : 'An unexpected error occurred, please try again',
        isError: true,
      );
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  // ===============================================================
  // Language Menu
  // ===============================================================

  void _showLanguageMenu(BuildContext context) async {
    final RenderBox renderBox = context.findRenderObject() as RenderBox;

    final size = renderBox.size;
    final position = renderBox.localToGlobal(Offset.zero);

    final selectedLocale = await showMenu<Locale>(
      context: context,
      position: RelativeRect.fromRect(
        Rect.fromLTWH(
          position.dx,
          position.dy + size.height + 8,
          size.width,
          size.height,
        ),
        Offset.zero &
            View.of(context).physicalSize / View.of(context).devicePixelRatio,
      ),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      color: const Color(0xFF131B2E),
      elevation: 8,
      items: [
        PopupMenuItem(
          value: const Locale('ar'),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'العربية',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
              if (Localizations.localeOf(context).languageCode == 'ar')
                const Icon(
                  Icons.check_rounded,
                  color: Color(0xFF818CF8),
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
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
              if (Localizations.localeOf(context).languageCode != 'ar')
                const Icon(
                  Icons.check_rounded,
                  color: Color(0xFF818CF8),
                  size: 18,
                ),
            ],
          ),
        ),
      ],
    );

    if (selectedLocale != null && mounted) {
      LocaleController.setLocale(selectedLocale);
    }
  }

  // ===============================================================
  // Build
  // ===============================================================

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final isDesktop = size.width > 900;
    final isArabic = Localizations.localeOf(context).languageCode == 'ar';

    return Directionality(
      textDirection: isArabic ? ui.TextDirection.rtl : ui.TextDirection.ltr,
      child: Scaffold(
        backgroundColor: const Color(0xFF0B0F19),
        body: Stack(
          children: [
            Positioned(
              top: -120,
              left: isArabic ? null : -100,
              right: isArabic ? -100 : null,
              child: Container(
                width: 480,
                height: 480,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [
                      const Color(0xFF06B6D4).withValues(alpha: 0.16),
                      Colors.transparent,
                    ],
                  ),
                ),
              ),
            ),
            Positioned(
              bottom: -150,
              right: isArabic ? null : -100,
              left: isArabic ? -100 : null,
              child: Container(
                width: 520,
                height: 520,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [
                      const Color(0xFF4F46E5).withValues(alpha: 0.25),
                      Colors.transparent,
                    ],
                  ),
                ),
              ),
            ),
            SafeArea(
              child: Center(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24,
                    vertical: 24,
                  ),
                  child: ConstrainedBox(
                    constraints: BoxConstraints(
                      maxWidth: isDesktop ? 980 : 460,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Align(
                          alignment: isArabic
                              ? Alignment.topLeft
                              : Alignment.topRight,
                          child: Builder(
                            builder: (menuContext) => GestureDetector(
                              onTap: () => _showLanguageMenu(menuContext),
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 14,
                                  vertical: 8,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.white.withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(20),
                                  border: Border.all(
                                    color: Colors.white.withValues(alpha: 0.2),
                                  ),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Icon(
                                      Icons.language_rounded,
                                      size: 18,
                                      color: Colors.white,
                                    ),
                                    const SizedBox(width: 8),
                                    Text(
                                      isArabic ? 'العربية' : 'English',
                                      style: const TextStyle(
                                        fontSize: 13,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.white,
                                      ),
                                    ),
                                    const SizedBox(width: 4),
                                    const Icon(
                                      Icons.arrow_drop_down_rounded,
                                      size: 18,
                                      color: Colors.white70,
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),
                        isDesktop
                            ? Row(
                                crossAxisAlignment: CrossAxisAlignment.center,
                                children: [
                                  Expanded(child: _buildBrandingHero(isArabic)),
                                  const SizedBox(width: 56),
                                  Expanded(child: _buildAuthCard(isArabic)),
                                ],
                              )
                            : Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  _buildMobileHeader(isArabic),
                                  const SizedBox(height: 28),
                                  _buildAuthCard(isArabic),
                                ],
                              ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ===============================================================
  // Branding Hero
  // ===============================================================

  Widget _buildBrandingHero(bool isArabic) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.06),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
          ),
          child: const Icon(
            Icons.account_balance_wallet_rounded,
            size: 38,
            color: Color(0xFF818CF8),
          ),
        ),
        const SizedBox(height: 24),
        const Text(
          'Alhelal Smart Expense',
          style: TextStyle(
            color: Colors.white,
            fontSize: 32,
            fontWeight: FontWeight.w900,
            letterSpacing: -0.5,
          ),
        ),
        const SizedBox(height: 12),
        SizedBox(
          width: double.infinity,
          child: Text(
            isArabic
                ? 'رفيقك المالي الذكي لإدارة وتحليل النفقات بدقة متناهية، مدعوم بأحدث تقنيات الذكاء الاصطناعي لتحويل إيصالاتك وفواتيرك إلى رؤى مالية فورية.\u200F'
                : 'Your smart financial companion to seamlessly manage and analyze expenses, powered by advanced AI to turn receipts into instant financial insights.',
            textAlign: isArabic ? TextAlign.right : TextAlign.left,
            style: const TextStyle(
              color: Color(0xFF94A3B8),
              fontSize: 15,
              height: 1.6,
            ),
          ),
        ),
        const SizedBox(height: 36),
        _buildFeatureItem(
          Icons.auto_awesome_rounded,
          isArabic
              ? 'قراءة آلية دقيقة للفواتير والمتاجر والعملات'
              : 'Accurate automated receipt parsing',
          isArabic
              ? 'استخراج بيانات الإيصالات والمتجر والعملة بذكاء لحظي وتصنيفها آلياً.'
              : 'Instantly extract receipt data, store names, and currencies using AI.',
          const Color(0xFF818CF8),
          isArabic,
        ),
        const SizedBox(height: 18),
        _buildFeatureItem(
          Icons.pie_chart_outline_rounded,
          isArabic
              ? 'لوحة تحكم وتحليلات مالية متقدمة'
              : 'Advanced financial dashboard',
          isArabic
              ? 'رسوم بيانية تفاعلية ومؤشرات أداء لحظية لمراقبة الميزانية الشهرية.'
              : 'Interactive charts and real-time KPIs to monitor your monthly budget.',
          const Color(0xFF34D399),
          isArabic,
        ),
        const SizedBox(height: 18),
        _buildFeatureItem(
          Icons.shield_outlined,
          isArabic
              ? 'تخزين سحابي آمن ومشفر'
              : 'Secure and encrypted cloud storage',
          isArabic
              ? 'حماية فائقة لبياناتك المالية وفواتيرك عبر بنية تحتية سحابية مستقلة ومؤمنة.\u200E'
              : 'Ultimate protection for your financial data backed by secure cloud infrastructure.',
          const Color(0xFF38BDF8),
          isArabic,
        ),
      ],
    );
  }

  Widget _buildFeatureItem(
    IconData icon,
    String title,
    String desc,
    Color color,
    bool isArabic,
  ) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.03),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: color, size: 24),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    fontFamily: 'Cairo',
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  desc,
                  style: const TextStyle(
                    color: Color(0xFF94A3B8),
                    fontSize: 13,
                    fontFamily: 'Cairo',
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ===============================================================
  // Mobile Header
  // ===============================================================

  Widget _buildMobileHeader(bool isArabic) {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.08),
            shape: BoxShape.circle,
            border: Border.all(color: Colors.white.withValues(alpha: 0.15)),
          ),
          child: const Icon(
            Icons.account_balance_wallet_rounded,
            size: 34,
            color: Color(0xFF818CF8),
          ),
        ),
        const SizedBox(height: 14),
        const Text(
          'Alhelal Smart Expense',
          style: TextStyle(
            color: Colors.white,
            fontSize: 22,
            fontWeight: FontWeight.w900,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          isArabic
              ? 'إدارة المصاريف الذكية وتحليل الفواتير'
              : 'Smart Expense Management & Analysis',
          textAlign: TextAlign.center,
          style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 13),
        ),
      ],
    );
  }

  // ===============================================================
  // Authentication Card
  // ===============================================================

  Widget _buildAuthCard(bool isArabic) {
    final loc = AppLocalizations.of(context)!;

    return Container(
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(
        color: const Color(0xFF131B2E).withValues(alpha: 0.85),
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.4),
            blurRadius: 36,
            offset: const Offset(0, 16),
          ),
        ],
      ),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: const Color(0xFF0F172A),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: _buildToggleTab(
                      title: loc.login,
                      isSelected: !_isSignUp,
                      onTap: () {
                        if (_isSignUp) {
                          setState(() => _isSignUp = false);
                          WidgetsBinding.instance.addPostFrameCallback((_) {
                            _formKey.currentState?.reset();
                          });
                        }
                      },
                    ),
                  ),
                  Expanded(
                    child: _buildToggleTab(
                      title: loc.signup,
                      isSelected: _isSignUp,
                      onTap: () {
                        if (!_isSignUp) {
                          setState(() => _isSignUp = true);
                          WidgetsBinding.instance.addPostFrameCallback((_) {
                            _formKey.currentState?.reset();
                          });
                        }
                      },
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 28),
            Text(
              _isSignUp
                  ? (isArabic ? 'إنشاء حساب جديد' : 'Create New Account')
                  : loc.welcome,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              _isSignUp
                  ? (isArabic
                        ? 'أنشئ حسابك الآن وابدأ رحلة التحكم المالي الذكي بدقة متناهية'
                        : 'Create your account now and start your smart financial journey')
                  : loc.enterDetails,
              style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 13),
            ),
            const SizedBox(height: 24),
            if (_isSignUp) ...[
              _buildInputField(
                controller: _nameController,
                label: isArabic ? 'الاسم الكامل' : 'Full Name',
                hint: isArabic ? 'عبد السلام' : 'AbdulSalam',
                icon: Icons.person_outline_rounded,
                textDirection: isArabic
                    ? ui.TextDirection.rtl
                    : ui.TextDirection.ltr,
                onFieldSubmitted: (_) => FocusScope.of(context).nextFocus(),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return isArabic
                        ? 'يرجى إدخال الاسم'
                        : 'Please enter your name';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 18),
            ],
            _buildInputField(
              controller: _emailController,
              label: loc.email,
              hint: 'alhelal@example.com',
              icon: Icons.alternate_email_rounded,
              keyboardType: TextInputType.emailAddress,
              textDirection: ui.TextDirection.ltr,
              onFieldSubmitted: (_) => FocusScope.of(context).nextFocus(),
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return loc.emailRequired;
                }
                final emailRegex = RegExp(
                  r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$',
                );
                if (!emailRegex.hasMatch(value.trim())) {
                  return isArabic
                      ? 'يرجى إدخال صيغة بريد إلكتروني صحيحة'
                      : 'Please enter a valid email format';
                }
                return null;
              },
            ),
            const SizedBox(height: 18),
            _buildInputField(
              controller: _passwordController,
              label: loc.password,
              hint: '••••••••••••',
              icon: Icons.lock_outline_rounded,
              obscureText: _obscurePassword,
              textDirection: ui.TextDirection.ltr,
              onFieldSubmitted: (_) {
                if (_isSignUp) {
                  FocusScope.of(context).nextFocus();
                } else {
                  if (!_isLoading) _submit();
                }
              },
              suffixIcon: IconButton(
                icon: Icon(
                  _obscurePassword
                      ? Icons.visibility_off_outlined
                      : Icons.visibility_outlined,
                  color: Colors.grey.shade400,
                  size: 20,
                ),
                onPressed: () {
                  setState(() => _obscurePassword = !_obscurePassword);
                },
              ),
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return loc.passwordRequired;
                }
                if (value.trim().length < 6) {
                  return isArabic
                      ? 'كلمة المرور يجب ألا تقل عن 6 أحرف أو أرقام'
                      : 'Password must be at least 6 characters';
                }
                return null;
              },
            ),
            if (_isSignUp) ...[
              const SizedBox(height: 18),
              _buildInputField(
                controller: _confirmPasswordController,
                label: isArabic ? 'تأكيد كلمة المرور' : 'Confirm Password',
                hint: '••••••••',
                icon: Icons.lock_reset_rounded,
                obscureText: _obscureConfirmPassword,
                textDirection: ui.TextDirection.ltr,
                onFieldSubmitted: (_) {
                  if (!_isLoading) _submit();
                },
                suffixIcon: IconButton(
                  icon: Icon(
                    _obscureConfirmPassword
                        ? Icons.visibility_off_outlined
                        : Icons.visibility_outlined,
                    color: Colors.grey.shade400,
                    size: 20,
                  ),
                  onPressed: () {
                    setState(() {
                      _obscureConfirmPassword = !_obscureConfirmPassword;
                    });
                  },
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return isArabic
                        ? 'يرجى تأكيد كلمة المرور'
                        : 'Please confirm your password';
                  }
                  if (value.trim() != _passwordController.text.trim()) {
                    return isArabic
                        ? 'كلمتا المرور غير متطابقتين'
                        : 'Passwords do not match';
                  }
                  return null;
                },
              ),
            ],
            const SizedBox(height: 28),
            ElevatedButton(
              onPressed: _isLoading ? null : _submit,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF4F46E5),
                foregroundColor: Colors.white,
                elevation: 0,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              child: _isLoading
                  ? const SizedBox(
                      height: 22,
                      width: 22,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.2,
                        color: Colors.white,
                      ),
                    )
                  : Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          _isSignUp
                              ? (isArabic
                                    ? 'إنشاء حساب جديد'
                                    : 'Create Free Account')
                              : (isArabic
                                    ? 'تسجيل الدخول للمنصة'
                                    : 'Login to Dashboard'),
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 0.3,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Icon(
                          isArabic
                              ? Icons.arrow_back_rounded
                              : Icons.arrow_forward_rounded,
                          size: 18,
                        ),
                      ],
                    ),
            ),
            const SizedBox(height: 20),
            Center(
              child: GestureDetector(
                onTap: () {
                  setState(() => _isSignUp = !_isSignUp);
                  WidgetsBinding.instance.addPostFrameCallback((_) {
                    _formKey.currentState?.reset();
                  });
                },
                child: RichText(
                  text: TextSpan(
                    style: const TextStyle(
                      color: Color(0xFF94A3B8),
                      fontSize: 13,
                    ),
                    children: [
                      TextSpan(
                        text: _isSignUp
                            ? (isArabic
                                  ? 'لديك حساب بالفعل؟ '
                                  : 'Already have an account? ')
                            : (isArabic
                                  ? 'ليس لديك حساب حتى الآن؟ '
                                  : 'Don\'t have an account yet? '),
                      ),
                      TextSpan(
                        text: _isSignUp
                            ? loc.login
                            : (isArabic
                                  ? 'إنشاء حساب مجاني'
                                  : 'Create Free Account'),
                        style: const TextStyle(
                          color: Color(0xFF818CF8),
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ===============================================================
  // Toggle Tab
  // ===============================================================

  Widget _buildToggleTab({
    required String title,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(vertical: 10),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFF4F46E5) : Colors.transparent,
          borderRadius: BorderRadius.circular(10),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: const Color(0xFF4F46E5).withValues(alpha: 0.35),
                    blurRadius: 10,
                    offset: const Offset(0, 3),
                  ),
                ]
              : null,
        ),
        child: Text(
          title,
          style: TextStyle(
            color: isSelected ? Colors.white : Colors.grey.shade400,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
            fontSize: 13.5,
          ),
        ),
      ),
    );
  }

  // ===============================================================
  // Input Field
  // ===============================================================

  Widget _buildInputField({
    required TextEditingController controller,
    required String label,
    required String hint,
    required IconData icon,
    bool obscureText = false,
    Widget? suffixIcon,
    TextInputType? keyboardType,
    ui.TextDirection? textDirection,
    String? Function(String?)? validator,
    void Function(String)? onFieldSubmitted,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            color: Color(0xFFCBD5E1),
            fontWeight: FontWeight.w600,
            fontSize: 13,
          ),
        ),
        const SizedBox(height: 8),
        TextFormField(
          controller: controller,
          obscureText: obscureText,
          keyboardType: keyboardType,
          textDirection: textDirection,
          style: const TextStyle(color: Colors.white, fontSize: 14),
          validator: validator,
          onFieldSubmitted: onFieldSubmitted,
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: TextStyle(color: Colors.grey.shade600, fontSize: 13),
            hintTextDirection: textDirection,
            prefixIcon: Icon(icon, color: const Color(0xFF818CF8), size: 20),
            suffixIcon: suffixIcon,
            filled: true,
            fillColor: const Color(0xFF0F172A),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 14,
            ),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: BorderSide(
                color: Colors.white.withValues(alpha: 0.1),
              ),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: BorderSide(
                color: Colors.white.withValues(alpha: 0.1),
              ),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: const BorderSide(
                color: Color(0xFF6366F1),
                width: 1.6,
              ),
            ),
            errorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: const BorderSide(
                color: Color(0xFFF43F5E),
                width: 1.2,
              ),
            ),
            focusedErrorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: const BorderSide(
                color: Color(0xFFF43F5E),
                width: 1.6,
              ),
            ),
            errorStyle: const TextStyle(
              color: Color(0xFFFB7185),
              fontSize: 11.5,
            ),
          ),
        ),
      ],
    );
  }
}
