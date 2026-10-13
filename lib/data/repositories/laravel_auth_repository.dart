import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/services/api_client.dart';

enum AuthSessionStatus { authenticated, unauthenticated, connectionError }

class LaravelAuthRepository {
  LaravelAuthRepository({Dio? dio}) : _dio = dio ?? ApiClient.dio;

  final Dio _dio;

  static const String _tokenKey = 'auth_token';

  // ============================================================
  // Session Management
  // ============================================================

  /// Returns the current authentication state.
  ///
  /// authenticated: Laravel accepted the token.
  /// unauthenticated: No token, or Laravel rejected it.
  /// connectionError: Session could not be verified.
  Future<AuthSessionStatus> checkSession() async {
    final token = await getToken();

    if (token == null || token.trim().isEmpty) {
      return AuthSessionStatus.unauthenticated;
    }

    try {
      final response = await _dio.get<dynamic>(
        '/user',
        options: Options(
          headers: {'Authorization': 'Bearer $token'},
          validateStatus: (status) => status != null && status < 500,
        ),
      );

      final statusCode = response.statusCode;

      if (statusCode == 200) {
        return AuthSessionStatus.authenticated;
      }

      if (statusCode == 401) {
        await _removeTokenIfUnchanged(token);

        if (kDebugMode) {
          debugPrint('Authentication session rejected by server');
        }

        return AuthSessionStatus.unauthenticated;
      }

      if (kDebugMode) {
        debugPrint('Session verification returned status: $statusCode');
      }

      return AuthSessionStatus.connectionError;
    } on DioException {
      if (kDebugMode) {
        debugPrint('Session verification request failed');
      }

      return AuthSessionStatus.connectionError;
    } catch (_) {
      if (kDebugMode) {
        debugPrint('Unexpected session verification failure');
      }

      return AuthSessionStatus.connectionError;
    }
  }

  /// Backward-compatible method.
  ///
  /// A network error does not mean the token is invalid.
  /// Use checkSession() when the UI needs to distinguish errors.
  Future<bool> isAuthenticated() async {
    final status = await checkSession();
    return status == AuthSessionStatus.authenticated;
  }

  /// Returns the locally stored authentication token.
  Future<String?> getToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_tokenKey);
  }

  Future<void> _saveToken(String token) async {
    if (token.trim().isEmpty) {
      throw const FormatException('Authentication token is empty');
    }

    final prefs = await SharedPreferences.getInstance();
    final saved = await prefs.setString(_tokenKey, token);

    if (!saved) {
      throw StateError('Could not persist authentication session');
    }
  }

  /// Avoids deleting a newer token if a previous request finishes late.
  Future<void> _removeTokenIfUnchanged(String expectedToken) async {
    final prefs = await SharedPreferences.getInstance();
    final currentToken = prefs.getString(_tokenKey);

    if (currentToken == expectedToken) {
      await prefs.remove(_tokenKey);
    }
  }

  Map<String, dynamic> _parseResponse(dynamic responseData) {
    if (responseData is Map) {
      return Map<String, dynamic>.from(responseData);
    }

    throw const FormatException('Unexpected API response format');
  }

  String _extractToken(Map<String, dynamic> responseData) {
    final nestedData = responseData['data'];

    final dynamic token =
        responseData['token'] ??
        (nestedData is Map ? nestedData['token'] : null);

    if (token is! String || token.trim().isEmpty) {
      throw const FormatException(
        'Authentication response does not contain a valid token',
      );
    }

    return token;
  }

  /// Removes an old Authorization header from public auth requests.
  ///
  /// ApiClient's interceptor reads the token from SharedPreferences.
  /// Therefore, login/register use a separate Dio instance without
  /// the authentication interceptor.
  Dio _createPublicAuthClient() {
    return Dio(
      BaseOptions(
        baseUrl: _dio.options.baseUrl,
        connectTimeout: _dio.options.connectTimeout,
        receiveTimeout: _dio.options.receiveTimeout,
        sendTimeout: _dio.options.sendTimeout,
        headers: {
          'Accept': 'application/json',
          'Content-Type': 'application/json',
        },
      ),
    );
  }

  // ============================================================
  // Login
  // ============================================================

  Future<Map<String, dynamic>> login({
    required String email,
    required String password,
  }) async {
    final publicDio = _createPublicAuthClient();

    try {
      final response = await publicDio.post<dynamic>(
        '/login',
        data: {'email': email.trim(), 'password': password},
      );

      final responseData = _parseResponse(response.data);
      final token = _extractToken(responseData);

      await _saveToken(token);

      if (kDebugMode) {
        debugPrint('Login successful');
      }

      return responseData;
    } on DioException {
      if (kDebugMode) {
        debugPrint('Login request failed');
      }
      rethrow;
    } finally {
      publicDio.close();
    }
  }

  // ============================================================
  // Registration
  // ============================================================

  Future<Map<String, dynamic>> register({
    required String name,
    required String email,
    required String password,
    required String passwordConfirmation,
  }) async {
    final publicDio = _createPublicAuthClient();

    try {
      final response = await publicDio.post<dynamic>(
        '/register',
        data: {
          'name': name.trim(),
          'email': email.trim(),
          'password': password,
          'password_confirmation': passwordConfirmation,
        },
      );

      final responseData = _parseResponse(response.data);
      final token = _extractToken(responseData);

      await _saveToken(token);

      if (kDebugMode) {
        debugPrint('Registration successful');
      }

      return responseData;
    } on DioException {
      if (kDebugMode) {
        debugPrint('Registration request failed');
      }
      rethrow;
    } finally {
      publicDio.close();
    }
  }

  // ============================================================
  // Avatar Upload
  // ============================================================

  /// File-based upload for platforms supporting dart:io.
  ///
  /// Flutter Web should use MultipartFile.fromBytes instead.
  Future<String?> uploadAvatar(File imageFile) async {
    try {
      final fileName = imageFile.uri.pathSegments.last;

      final formData = FormData.fromMap({
        'avatar': await MultipartFile.fromFile(
          imageFile.path,
          filename: fileName,
        ),
      });

      final response = await _dio.post<dynamic>('/user/avatar', data: formData);

      final responseData = _parseResponse(response.data);
      final nestedData = responseData['data'];

      final dynamic avatarUrl =
          responseData['avatar_url'] ??
          (nestedData is Map ? nestedData['avatar_url'] : null);

      if (kDebugMode) {
        debugPrint('Avatar upload completed');
      }

      return avatarUrl is String && avatarUrl.isNotEmpty ? avatarUrl : null;
    } on DioException {
      if (kDebugMode) {
        debugPrint('Avatar upload request failed');
      }
      rethrow;
    }
  }

  // ============================================================
  // Profile Update
  // ============================================================

  Future<void> updateProfileName(String newName) async {
    final name = newName.trim();

    if (name.isEmpty) {
      throw ArgumentError('Profile name cannot be empty');
    }

    try {
      await _dio.put<dynamic>('/user/profile', data: {'name': name});

      if (kDebugMode) {
        debugPrint('Profile name updated');
      }
    } on DioException {
      if (kDebugMode) {
        debugPrint('Profile update request failed');
      }
      rethrow;
    }
  }

  // ============================================================
  // Logout
  // ============================================================

  /// Attempts to revoke the token on Laravel.
  ///
  /// Local token is cleared even if the server cannot be reached.
  /// A failed server request may leave the remote token valid.
  Future<void> logout() async {
    final token = await getToken();

    try {
      if (token != null && token.isNotEmpty) {
        await _dio.post<dynamic>(
          '/logout',
          options: Options(headers: {'Authorization': 'Bearer $token'}),
        );
      }
    } on DioException {
      if (kDebugMode) {
        debugPrint('Server logout request failed');
      }
    } finally {
      if (token != null) {
        await _removeTokenIfUnchanged(token);
      }

      if (kDebugMode) {
        debugPrint('Local logout completed');
      }
    }
  }
}
