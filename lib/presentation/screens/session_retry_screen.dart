import 'package:flutter/material.dart';

import '../../data/repositories/laravel_auth_repository.dart';
import 'auth_screen.dart';
import 'dashboard_loader.dart';

class SessionRetryScreen extends StatefulWidget {
  const SessionRetryScreen({super.key});

  @override
  State<SessionRetryScreen> createState() => _SessionRetryScreenState();
}

class _SessionRetryScreenState extends State<SessionRetryScreen> {
  final LaravelAuthRepository _authRepository = LaravelAuthRepository();

  bool _isChecking = false;

  Future<void> _retrySession() async {
    if (_isChecking) return;

    setState(() {
      _isChecking = true;
    });

    try {
      final status = await _authRepository.checkSession();

      if (!mounted) return;

      switch (status) {
        case AuthSessionStatus.authenticated:
          _openScreen(const DashboardLoader());
          break;

        case AuthSessionStatus.unauthenticated:
          _openScreen(const AuthScreen());
          break;

        case AuthSessionStatus.connectionError:
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'تعذر الاتصال بالسيرفر. تحقق من الإنترنت وحاول مجددًا.',
              ),
            ),
          );
          break;
      }
    } catch (_) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('حدث خطأ أثناء التحقق من الجلسة. حاول مجددًا.'),
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isChecking = false;
        });
      }
    }
  }

  void _openScreen(Widget screen) {
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute<void>(builder: (_) => screen),
      (route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.wifi_off_rounded,
                    size: 76,
                    color: theme.colorScheme.primary,
                  ),
                  const SizedBox(height: 24),
                  Text(
                    'تعذر التحقق من الاتصال',
                    textAlign: TextAlign.center,
                    style: theme.textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'لم نتمكن من التحقق من جلسة تسجيل الدخول. '
                    'قد يكون الإنترنت مقطوعًا أو السيرفر غير متاح مؤقتًا. '
                    'بيانات تسجيل الدخول المحفوظة لم تُحذف.',
                    textAlign: TextAlign.center,
                    style: theme.textTheme.bodyMedium,
                  ),
                  const SizedBox(height: 28),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      onPressed: _isChecking ? null : _retrySession,
                      icon: _isChecking
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.refresh_rounded),
                      label: Text(
                        _isChecking ? 'جارٍ التحقق...' : 'إعادة المحاولة',
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
