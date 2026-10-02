import 'package:flutter/material.dart';
import 'dashboard_screen.dart';

class DashboardLoader extends StatelessWidget {
  const DashboardLoader({super.key});

  @override
  Widget build(BuildContext context) {
    // عرض شاشة الداشبورد مباشرة بدون حجز المعالج في ترجمة ديناميكية لـ WASM
    return const DashboardScreen();
  }
}
