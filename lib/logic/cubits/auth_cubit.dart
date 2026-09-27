import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

// حالات المصادقة (Auth States)
abstract class AuthState {}

class AuthInitial extends AuthState {}
class AuthLoading extends AuthState {}
class AuthAuthenticated extends AuthState {}
class AuthUnauthenticated extends AuthState {}
class AuthError extends AuthState {
  final String message;
  AuthError(this.message);
}

// الـ Cubit المسؤول عن إدارة حالة تسجيل الدخول والخروج
class AuthCubit extends Cubit<AuthState> {
  final SupabaseClient _supabase = Supabase.instance.client;

  AuthCubit() : super(AuthInitial()) {
    // التحقق من حالة المستخدم الحالية عند بدء التطبيق
    _checkCurrentUser();
  }

  // التحقق هل المستخدم مسجل دخوله مسبقاً أم لا
  void _checkCurrentUser() {
    final session = _supabase.auth.currentSession;
    if (session != null) {
      emit(AuthAuthenticated());
    } else {
      emit(AuthUnauthenticated());
    }
  }

  // دالة تسجيل الدخول
  Future<void> signIn({required String email, required String password}) async {
    try {
      emit(AuthLoading());
      await _supabase.auth.signInWithPassword(
        email: email,
        password: password,
      );
      emit(AuthAuthenticated());
    } catch (e) {
      emit(AuthError(e.toString()));
    }
  }

  // دالة تسجيل الخروج (المعدلة والآمنة)
  Future<void> signOut() async {
    try {
      emit(AuthLoading());
      await _supabase.auth.signOut();
      // إصدار حالة عدم المصادقة لتتولى واجهة التطبيق الانتقال لشاشة تسجيل الدخول تلقائياً
      emit(AuthUnauthenticated());
    } catch (e) {
      emit(AuthError(e.toString()));
    }
  }
}