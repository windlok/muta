import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'core/config/app_config.dart';
import 'core/config/secrets.dart';
import 'core/localization/app_localizations.dart';
import 'core/localization/language_store.dart';
import 'core/routing/app_router.dart';
import 'core/theme/app_theme.dart';
import 'features/notifications/data/push_service.dart';

bool _isMutaAuthCallback(Uri uri) =>
    uri.scheme == 'com.mutalabs.muta' &&
    uri.host == 'login-callback' &&
    (uri.queryParameters.containsKey('code') ||
        uri.queryParameters.containsKey('access_token') ||
        uri.queryParameters.containsKey('error') ||
        uri.fragment.contains('access_token'));

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Tarih/saat biçimleri için İngilizce ve Türkçe yerel veriyi yükle.
  await initializeDateFormatting('en_US');
  await initializeDateFormatting('tr_TR');

  final languageCode = await loadLanguageCode();

  // Supabase yapılandırılmışsa başlat. Değilse uygulama kurulum ekranı gösterir.
  if (AppConfig.isSupabaseConfigured) {
    await Supabase.initialize(
      url: Secrets.supabaseUrl,
      publishableKey: Secrets.supabasePublishableKey,
      authOptions: const FlutterAuthClientOptions(
        // Native deep-link callback'te Google authorization code exchange'i
        // bazı cihazlarda server_error ile sonuçlanabildiği için token'ı
        // callback fragment'inden doğrudan al.
        authFlowType: AuthFlowType.implicit,
        autoRefreshToken: true,
        detectSessionInUri: true,
        detectSessionInUriPredicate: _isMutaAuthCallback,
      ),
    );
    await PushService.init(languageCode: languageCode);
  }

  runApp(
    ProviderScope(
      overrides: [initialLanguageProvider.overrideWithValue(languageCode)],
      child: const MutaApp(),
    ),
  );
}

class MutaApp extends ConsumerWidget {
  const MutaApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(routerProvider);
    final languageCode = ref.watch(appLanguageProvider);

    return MaterialApp.router(
      title: AppConfig.appName,
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      themeMode: ThemeMode.system,
      locale: Locale(languageCode),
      supportedLocales: AppLocalizations.supportedLocales,
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      routerConfig: router,
    );
  }
}
