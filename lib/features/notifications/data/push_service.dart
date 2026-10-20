import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Firebase Cloud Messaging kurulumu ve cihaz token'ının Supabase'e kaydı.
///
/// Sunucu (check-prices) yeni bildirim yazdığında `device_tokens` tablosundaki
/// token'lara FCM push gönderir; uygulama kapalıyken de sistem bildirimi düşer.
class PushService {
  PushService._();

  static const _channelId = 'price_alerts';

  static String _languageCode = 'en';

  static String get _channelName =>
      _languageCode == 'tr' ? 'Fiyat Bildirimleri' : 'Price alerts';

  static String get _channelDescription => _languageCode == 'tr'
      ? 'Takip edilen ürünlerin fiyat düşüşleri'
      : 'Price drops for tracked products';

  static final FlutterLocalNotificationsPlugin _local =
      FlutterLocalNotificationsPlugin();

  static bool _started = false;

  /// Uygulama açılışında bir kez çağrılır. Firebase yapılandırılmamışsa
  /// sessizce devam eder (uygulama bildirimsiz çalışır).
  ///
  /// Bildirim izni yalnızca giriş yapılmışsa istenir; böylece kullanıcı
  /// daha hesabına girmeden izin diyaloğuyla karşılaşmaz.
  static Future<void> init({String languageCode = 'en'}) async {
    if (_started) {
      await setLanguage(languageCode);
      return;
    }
    _started = true;
    _languageCode = languageCode == 'tr' ? 'tr' : 'en';
    try {
      await Firebase.initializeApp();

      await _local.initialize(
        settings: const InitializationSettings(
          android: AndroidInitializationSettings('@mipmap/ic_launcher'),
        ),
      );
      await _createChannel();

      // Uygulama açıkken gelen push'u yerel bildirim olarak göster.
      FirebaseMessaging.onMessage.listen(_showForeground);
      // ignore: deprecated_member_use
      FirebaseMessaging.instance.onTokenRefresh.listen(_saveToken);
      Supabase.instance.client.auth.onAuthStateChange.listen((state) {
        if (state.event == AuthChangeEvent.signedIn ||
            state.event == AuthChangeEvent.userUpdated ||
            state.event == AuthChangeEvent.initialSession) {
          _onSignedIn();
        }
      });

      if (Supabase.instance.client.auth.currentUser != null) {
        await _onSignedIn();
      }
    } catch (_) {
      // google-services yoksa / platform desteklemiyorsa yoksay.
    }
  }

  static Future<void> _createChannel() async {
    await _local
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(
          AndroidNotificationChannel(
            _channelId,
            _channelName,
            description: _channelDescription,
            importance: Importance.high,
          ),
        );
  }

  /// Dil değişince sistem bildirim kanalının adını ve kayıtlı cihaz dilini
  /// günceller.
  static Future<void> setLanguage(String languageCode) async {
    final next = languageCode == 'tr' ? 'tr' : 'en';
    if (_languageCode == next) return;
    _languageCode = next;
    try {
      await _createChannel();
      await _saveToken();
    } catch (_) {}
  }

  static Future<void> _onSignedIn() async {
    try {
      await FirebaseMessaging.instance.requestPermission();
    } catch (_) {}
    await _saveToken();
  }

  static Future<void> _saveToken([String? token]) async {
    try {
      // ignore: deprecated_member_use
      token ??= await FirebaseMessaging.instance.getToken();
      if (token == null) return;
      if (Supabase.instance.client.auth.currentUser == null) return;

      // RPC: aynı token başka bir hesapta kayıtlıysa bu hesaba taşır.
      await Supabase.instance.client.rpc('register_device_token', params: {
        'p_token': token,
        'p_platform': 'android',
        'p_language': _languageCode,
      });
    } catch (_) {}
  }

  /// Çıkışta cihazı bu hesabın bildirimlerinden ayırır.
  static Future<void> unregister() async {
    try {
      // ignore: deprecated_member_use
      final token = await FirebaseMessaging.instance.getToken();
      if (token != null) {
        await Supabase.instance.client
            .from('device_tokens')
            .delete()
            .eq('token', token);
      }
      // ignore: deprecated_member_use
      await FirebaseMessaging.instance.deleteToken();
    } catch (_) {}
  }

  static Future<void> _showForeground(RemoteMessage message) async {
    final notification = message.notification;
    if (notification == null) return;
    try {
      await _local.show(
        id: notification.hashCode,
        title: notification.title,
        body: notification.body,
        notificationDetails: NotificationDetails(
          android: AndroidNotificationDetails(
            _channelId,
            _channelName,
            importance: Importance.high,
            priority: Priority.high,
          ),
        ),
      );
    } catch (_) {}
  }
}
