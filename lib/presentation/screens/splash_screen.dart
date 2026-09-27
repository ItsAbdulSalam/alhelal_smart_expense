import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';

class SplashScreen extends StatefulWidget {
  final Widget nextScreen;

  const SplashScreen({super.key, required this.nextScreen});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    Future.delayed(const Duration(milliseconds: 600), () {
      if (mounted) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => widget.nextScreen),
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0B132B), // لون خلفية داكن وموحد
      body: kIsWeb
          ?
            // 🌐 إذا كان العرض على المتصفح (الويب): نعرض واجهة سبلاش نظيفة ومرتبة بدون تمدد الصورة
            const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.account_balance_wallet_rounded,
                    size: 64,
                    color: Color(0xFF6366F1),
                  ),
                  SizedBox(height: 20),
                  Text(
                    'Alhelal Smart Expense',
                    style: TextStyle(
                      fontSize: 26,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                      fontFamily: 'Cairo',
                    ),
                  ),
                  SizedBox(height: 30),
                  CircularProgressIndicator(
                    valueColor: AlwaysStoppedAnimation<Color>(
                      Color(0xFF6366F1),
                    ),
                  ),
                ],
              ),
            )
          :
            // 📱 إذا كان التشغيل على الموبايل: تظهر صورتك الكاملة والمصممة خصيصاً للموبايل بملء الشاشة
            SizedBox.expand(
              child: Image.asset(
                'assets/icon/alhelal_splash_background_full.png',
                fit: BoxFit.cover,
              ),
            ),
    );
  }
}
