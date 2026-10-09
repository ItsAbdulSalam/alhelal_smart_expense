import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ApiClient {
  static const String baseUrl = 'https://api.alhelalsmart.com/api';

  static late final Dio dio;

  static void init() {
    dio = Dio(
      BaseOptions(
        baseUrl: baseUrl,
        connectTimeout: const Duration(seconds: 10),
        receiveTimeout: const Duration(seconds: 10),
        headers: {
          'Accept': 'application/json',
          'Content-Type': 'application/json',
        },
      ),
    );

    dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) async {
          final prefs = await SharedPreferences.getInstance();
          final token = prefs.getString('auth_token');

          if (token != null && token.isNotEmpty) {
            options.headers['Authorization'] = 'Bearer $token';
          }

          debugPrint('🚀 Sending Request to: ${options.uri}');
          debugPrint('🔑 Headers: ${options.headers}');

          return handler.next(options);
        },
        onError: (DioException error, handler) {
          debugPrint(
            '⚠️ Dio Error: ${error.response?.statusCode} -> ${error.response?.data}',
          );
          return handler.next(error);
        },
      ),
    );
  }
}
