import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:muta/core/localization/app_localizations.dart';
import 'package:muta/features/auth/presentation/setup_screen.dart';

void main() {
  testWidgets('Kurulum ekranı uygulama adını gösterir', (tester) async {
    await tester.pumpWidget(
      const ProviderScope(
        child: MaterialApp(
          locale: Locale('tr'),
          supportedLocales: AppLocalizations.supportedLocales,
          localizationsDelegates: [
            AppLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          home: SetupScreen(),
        ),
      ),
    );

    expect(find.text('Muta'), findsOneWidget);
    expect(find.text('Tekrar Dene'), findsOneWidget);
  });
}
