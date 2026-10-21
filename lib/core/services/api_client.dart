import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ApiClient {
  static const String baseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'https://api.alhelalsmart.com/api',
  );

  static late final Dio dio;

  /// Timeouts for slow AI endpoints (receipt scan, financial advisor).
  /// The server may wait for Gemini for up to ~70 seconds.
  static const Duration aiReceiveTimeout = Duration(seconds: 120);
  static const Duration aiSendTimeout = Duration(seconds: 60);

  /// Called once when the server rejects the saved token (HTTP 401),
  /// for example after it expired. The app uses it to return to login.
  static VoidCallback? onUnauthorized;
  static bool _handlingUnauthorized = false;

  static void init() {
    dio = Dio(
      BaseOptions(
        baseUrl: baseUrl,
        connectTimeout: const Duration(seconds: 15),
        receiveTimeout: const Duration(seconds: 30),
        sendTimeout: const Duration(seconds: 30),
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

          if (token != null && token.trim().isNotEmpty) {
            options.headers['Authorization'] = 'Bearer $token';
          }

          if (kDebugMode) {
            debugPrint('API Request: ${options.method} ${options.path}');
          }

          return handler.next(options);
        },
        onError: (DioException error, handler) async {
          if (error.response?.statusCode == 401 &&
              error.requestOptions.headers['Authorization'] != null &&
              !_handlingUnauthorized) {
            _handlingUnauthorized = true;
            try {
              final prefs = await SharedPreferences.getInstance();
              await prefs.remove('auth_token');
              onUnauthorized?.call();
            } finally {
              _handlingUnauthorized = false;
            }
          }

          if (kDebugMode) {
            debugPrint(
              'API Error: ${error.response?.statusCode ?? 'No response'}',
            );
          }

          return handler.next(error);
        },
      ),
    );
  }

  static Future<String> _getAuthToken() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('auth_token');

    if (token == null || token.trim().isEmpty) {
      throw StateError('Authentication token is missing');
    }

    return token;
  }

  static Future<Uint8List> fetchReceiptImage(String expenseId) async {
    final token = await _getAuthToken();

    final response = await dio.get<List<int>>(
      '/expenses/${Uri.encodeComponent(expenseId)}/receipt',
      options: Options(
        responseType: ResponseType.bytes,
        headers: {
          'Accept': 'image/*, application/pdf',
          'Authorization': 'Bearer $token',
        },
      ),
    );

    final bytes = response.data;

    if (bytes == null || bytes.isEmpty) {
      throw StateError('Receipt image is empty');
    }

    return Uint8List.fromList(bytes);
  }

  static Future<Uint8List> fetchAvatarImage() async {
    final token = await _getAuthToken();

    final response = await dio.get<List<int>>(
      '/user/avatar',
      options: Options(
        responseType: ResponseType.bytes,
        headers: {'Accept': 'image/*', 'Authorization': 'Bearer $token'},
      ),
    );

    final bytes = response.data;

    if (bytes == null || bytes.isEmpty) {
      throw StateError('Avatar image is empty');
    }

    return Uint8List.fromList(bytes);
  }
}
