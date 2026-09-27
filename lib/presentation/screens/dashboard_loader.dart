import 'package:flutter/material.dart';

import 'dashboard_screen.dart' deferred as dashboard;

class DashboardLoader extends StatefulWidget {
  const DashboardLoader({super.key});

  @override
  State<DashboardLoader> createState() => _DashboardLoaderState();
}

class _DashboardLoaderState extends State<DashboardLoader> {
  late Future<void> _loadFuture;

  @override
  void initState() {
    super.initState();
    _loadFuture = dashboard.loadLibrary();
  }

  void _retry() {
    setState(() {
      _loadFuture = dashboard.loadLibrary();
    });
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<void>(
      future: _loadFuture,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Scaffold(
            body: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.error_outline_rounded,
                    size: 48,
                    color: Colors.red,
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'تعذر تحميل لوحة التحكم',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 12),
                  ElevatedButton(
                    onPressed: _retry,
                    child: const Text('إعادة المحاولة'),
                  ),
                ],
              ),
            ),
          );
        }

        if (snapshot.connectionState == ConnectionState.done) {
          return dashboard.DashboardScreen();
        }

        return const Scaffold(
          backgroundColor: Color(0xFFF1F5F9),
          body: Center(child: CircularProgressIndicator()),
        );
      },
    );
  }
}
