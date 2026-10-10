import 'dart:io';
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

      // التعامل بمرونة سواء كانت البيانات داخل data أو مباشرة في الجذر
      final resData = response.data is Map<String, dynamic>
          ? response.data
          : {};
      final dynamic token = resData['token'] ?? resData['data']?['token'];

      if (token != null) {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString(_tokenKey, token.toString());
        debugPrint('✅ تم حفظ التوكن بنجاح: $token');
      }

      return Map<String, dynamic>.from(resData);
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

      final resData = response.data is Map<String, dynamic>
          ? response.data
          : {};
      final dynamic token = resData['token'] ?? resData['data']?['token'];

      if (token != null) {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString(_tokenKey, token.toString());
        debugPrint('✅ تم حفظ التوكن الجديد بعد التسجيل: $token');
      }

      return Map<String, dynamic>.from(resData);
    } catch (e) {
      debugPrint('⚠️ خطأ في إنشاء الحساب: $e');
      rethrow;
    }
  }

  /// رفع وتحديث الصورة الشخصية (Avatar)
  Future<String?> uploadAvatar(File imageFile) async {
    try {
      final token = await getToken();
      final fileName = imageFile.path.split(Platform.pathSeparator).last;

      final formData = FormData.fromMap({
        'avatar': await MultipartFile.fromFile(
          imageFile.path,
          filename: fileName,
        ),
      });

      final response = await _dio.post(
        '/user/avatar',
        data: formData,
        options: Options(
          headers: {
            if (token != null) 'Authorization': 'Bearer $token',
            'Accept': 'application/json',
          },
        ),
      );

      final resData = response.data;
      final avatarUrl = resData['avatar_url'] ?? resData['data']?['avatar_url'];
      debugPrint('✅ تم رفع الصورة بنجاح: $avatarUrl');
      return avatarUrl?.toString();
    } catch (e) {
      debugPrint('⚠️ خطأ أثناء رفع الصورة الشخصية: $e');
      rethrow;
    }
  }

  /// تحديث اسم المستخدم
  Future<void> updateProfileName(String newName) async {
    try {
      final token = await getToken();
      await _dio.put(
        '/user/profile',
        data: {'name': newName},
        options: Options(
          headers: {
            if (token != null) 'Authorization': 'Bearer $token',
            'Accept': 'application/json',
          },
        ),
      );
      debugPrint('✅ تم تحديث الاسم بنجاح');
    } catch (e) {
      debugPrint('⚠️ خطأ أثناء تحديث الملف الشخصي: $e');
      rethrow;
    }
  }

  /// تسجيل الخروج ومسح التوكن
  Future<void> logout() async {
    try {
      final token = await getToken();
      await _dio.post(
        '/logout',
        options: Options(
          headers: {if (token != null) 'Authorization': 'Bearer $token'},
        ),
      );
    } catch (e) {
      debugPrint('⚠️ تعذر إشعار السيرفر بتسجيل الخروج: $e');
    } finally {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_tokenKey);
      debugPrint('🗑️ تم مسح التوكن محلياً');
    }
  }
}
