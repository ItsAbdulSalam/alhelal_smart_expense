import 'package:flutter/material.dart';
// استورد مكتبة التحقق من الاتصال التي تستخدمها، مثل connectivity_plus
import 'package:connectivity_plus/connectivity_plus.dart';

class ConnectivityBanner extends StatelessWidget {
  final Widget child;

  const ConnectivityBanner({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    // يمكنك هنا استخدام الـ Stream أو القيمة الفعلية لحالة الاتصال لديك
    // كمثال افتراضي سنعتمد على StreamBuilder أو فحص الاتصال
    return StreamBuilder<List<ConnectivityResult>>(
      stream: Connectivity().onConnectivityChanged,
      builder: (context, snapshot) {
        // التحقق هل هناك اتصال أم لا
        final connectivityResults = snapshot.data;
        final bool isOffline =
            connectivityResults != null &&
            connectivityResults.contains(ConnectivityResult.none);

        return Material(
          child: Column(
            children: [
              // إظهار الشريط فقط في حالة عدم وجود إنترنت
              if (isOffline)
                Container(
                  width: double.infinity,
                  // استخدام لون تحذيري جذاب مثل البرتقالي الداكن أو الأحمر المريح
                  color: const Color(0xFFD97706),
                  padding: EdgeInsets.only(
                    // إضافة مساحة علوية تتناسب مع شريط النظام (Status Bar) لتجنب التداخل
                    top: MediaQuery.of(context).padding.top + 6,
                    bottom: 8,
                    left: 16,
                    right: 16,
                  ),
                  child: const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.cloud_off, color: Colors.white, size: 16),
                      SizedBox(width: 8),
                      Text(
                        'أنت تعمل حالياً بوضع عدم الاتصال (Offline)',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              // باقي محتوى التطبيق
              Expanded(child: child),
            ],
          ),
        );
      },
    );
  }
}
