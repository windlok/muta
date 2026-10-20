import 'secrets.dart';

/// Çalışma anında gereken yapılandırma ayarları.
///
/// Gerçek anahtarlar [Secrets] içinde tutulur. Eğer bunlar henüz
/// doldurulmadıysa uygulama çalışır ama "Kurulum Gerekli" durumunu gösterir.
class AppConfig {
  AppConfig._();

  static const String appName = 'Muta';
  static const String appTagline = 'Kişisel AI Asistanın';
  static const String developerName = 'Muta Labs';

  /// Supabase URL'si doldurulmuş mu?
  static bool get isSupabaseConfigured {
    final url = Secrets.supabaseUrl;
    final key = Secrets.supabasePublishableKey;
    return _isFilled(url) && _isFilled(key);
  }

  static bool _isFilled(String value) =>
      value.isNotEmpty && !value.startsWith('PASTE_');
}
