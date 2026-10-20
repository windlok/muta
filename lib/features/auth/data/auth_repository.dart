import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter/foundation.dart';

/// Supabase Auth sarmalayıcısı.
class AuthRepository {
  AuthRepository(this._client);

  static const oauthRedirectUri = 'com.mutalabs.muta://login-callback';

  final SupabaseClient _client;

  User? get currentUser => _client.auth.currentUser;
  Session? get currentSession => _client.auth.currentSession;

  Stream<AuthState> get onAuthStateChange => _client.auth.onAuthStateChange;

  Future<AuthResponse> signIn({
    required String email,
    required String password,
  }) {
    return _client.auth.signInWithPassword(email: email, password: password);
  }

  Future<AuthResponse> signUp({
    required String email,
    required String password,
  }) {
    return _client.auth.signUp(email: email, password: password);
  }

  /// Google ile giriş. Not: OAuth için Supabase'te redirect URL ve
  /// AndroidManifest / Info.plist deep link ayarları gerekir.
  Future<bool> signInWithGoogle() {
    return _client.auth.signInWithOAuth(
      OAuthProvider.google,
      redirectTo: kIsWeb ? null : oauthRedirectUri,
    );
  }

  Future<void> signOut() => _client.auth.signOut();
}
