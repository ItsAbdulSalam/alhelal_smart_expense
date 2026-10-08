import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../core/services/api_client.dart';

class LaravelAuthRepository {
  final Dio _dio = ApiClient.dio;
  static const String _tokenKey = 'auth_token';

  /// فحص هل المستخدم مسجل دخول حالياً
  Future<bool> isAuthenticated() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString(_tokenKey);
    return token != null && token.isNotEmpty;
  }

  /// جلب التوكن الحالي
  Future<String?> getToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_tokenKey);
  }

  /// تسجيل الدخول وحفظ التوكن تلقائياً
  Future<Map<String, dynamic>> login({
    required String email,
    required String password,
  }) async {
    try {
      final response = await _dio.post(
        '/login',
        data: {'email': email, 'password': password},
      );

      final data = response.data['data'];
      final token = data['token'];

      if (token != null) {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString(_tokenKey, token.toString());
        debugPrint('✅ تم حفظ التوكن الجديد بنجاح');
      }

      return data;
    } catch (e) {
      debugPrint('⚠️ خطأ في تسجيل الدخول: $e');
      rethrow;
    }
  }

  /// إنشاء حساب جديد
  Future<Map<String, dynamic>> register({
    required String name,
    required String email,
    required String password,
    required String passwordConfirmation,
  }) async {
    try {
      final response = await _dio.post(
        '/register',
        data: {
          'name': name,
          'email': email,
          'password': password,
          'password_confirmation': passwordConfirmation,
        },
      );

      final data = response.data['data'];
      final token = data['token'];

      if (token != null) {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString(_tokenKey, token.toString());
        debugPrint('✅ تم حفظ التوكن الجديد بعد التسجيل');
      }

      return data;
    } catch (e) {
      debugPrint('⚠️ خطأ في إنشاء الحساب: $e');
      rethrow;
    }
  }

  /// تسجيل الخروج ومسح التوكن
  Future<void> logout() async {
    try {
      await _dio.post('/logout');
    } catch (e) {
      debugPrint('⚠️ تعذر إشعار السيرفر بتسجيل الخروج: $e');
    } finally {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_tokenKey);
      debugPrint('🗑️ تم مسح التوكن محلياً');
    }
  }
}
