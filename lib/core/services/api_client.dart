// ignore: unnecessary_import
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ApiClient {
  static const String baseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'https://api.alhelalsmart.com/api',
  );
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
          if (kDebugMode) {
            debugPrint('🚀 API Request: ${options.method} ${options.path}');
          }
          return handler.next(options);
        },
        onError: (DioException error, handler) {
          if (kDebugMode) {
            debugPrint(
              '⚠️ API Error: ${error.response?.statusCode ?? 'No response'}',
            );
          }
          return handler.next(error);
        },
      ),
    );
  }

  static Future<Uint8List> fetchReceiptImage(String expenseId) async {
    final response = await dio.get<List<int>>(
      '/expenses/${Uri.encodeComponent(expenseId)}/receipt',
      options: Options(
        responseType: ResponseType.bytes,
        headers: {'Accept': 'image/*, application/pdf'},
      ),
    );
    final bytes = response.data;
    if (bytes == null || bytes.isEmpty) {
      throw StateError('Receipt image is empty');
    }
    return Uint8List.fromList(bytes);
  }

  static Future<Uint8List> fetchAvatarImage() async {
    final response = await dio.get<List<int>>(
      '/user/avatar',
      options: Options(
        responseType: ResponseType.bytes,
        headers: {'Accept': 'image/*'},
      ),
    );
    final bytes = response.data;
    if (bytes == null || bytes.isEmpty) {
      throw StateError('Avatar image is empty');
    }
    return Uint8List.fromList(bytes);
  }
}
