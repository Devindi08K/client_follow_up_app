import 'package:supabase_flutter/supabase_flutter.dart';

class AuthService {
  final SupabaseClient _client = Supabase.instance.client;

  static const _redirectUrl = 'com.devindi.clientfollowup://login-callback';

  Future<AuthResponse> signIn({
    required String email,
    required String password,
  }) {
    return _client.auth.signInWithPassword(
      email: email.trim(),
      password: password,
    );
  }

  Future<AuthResponse> signUp({
    required String email,
    required String password,
    String? businessName,
  }) {
    return _client.auth.signUp(
      email: email.trim(),
      password: password,
      emailRedirectTo: _redirectUrl,
      data: businessName != null && businessName.trim().isNotEmpty
          ? {'business_name': businessName.trim()}
          : null,
    );
  }

  Future<void> resendConfirmation({required String email}) {
    return _client.auth.resend(type: OtpType.signup, email: email.trim());
  }

  Future<void> signOut() {
    return _client.auth.signOut();
  }

  Future<void> resetPassword({required String email}) {
    return _client.auth.resetPasswordForEmail(email.trim(), redirectTo: _redirectUrl);
  }

  Future<void> updatePassword({required String newPassword}) {
    return _client.auth.updateUser(UserAttributes(password: newPassword));
  }

  User? get currentUser => _client.auth.currentUser;

  Stream<AuthState> get authStateChanges => _client.auth.onAuthStateChange;
}