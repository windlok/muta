import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:muta/core/localization/app_localizations.dart';
import 'package:muta/core/providers/providers.dart';
import 'package:muta/features/home/presentation/home_shell.dart';
import 'package:muta/features/notifications/domain/notification_model.dart';
import 'package:muta/features/planner/data/planner_repository.dart';
import 'package:muta/features/planner/domain/calendar_event_model.dart';
import 'package:muta/features/planner/presentation/planner_screen.dart';

class _FakePlannerRepository extends PlannerRepository {
  _FakePlannerRepository()
    : super(
        SupabaseClient(
          'https://example.supabase.co',
          'test-key',
          authOptions: const AuthClientOptions(autoRefreshToken: false),
        ),
      );

  final added = <CalendarEvent>[];

  @override
  Future<List<CalendarEvent>> fetchEvents() async => const [];

  @override
  Future<CalendarEvent> addEvent(CalendarEvent event) async {
    final saved = CalendarEvent(
      id: 'event-${added.length + 1}',
      userId: 'user-1',
      title: event.title,
      description: event.description,
      start: event.start,
      end: event.end,
      type: event.type,
      createdAt: DateTime.now(),
    );
    added.add(saved);
    return saved;
  }
}

void main() {
  setUpAll(() async {
    await initializeDateFormatting('tr_TR');
    await initializeDateFormatting('en_US');
  });

  testWidgets('Plan sekmesi: etkinlik ekle ve boşluğa dokun', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final router = GoRouter(
      initialLocation: '/',
      routes: [
        ShellRoute(
          builder: (_, _, child) => HomeShell(child: child),
          routes: [
            GoRoute(
              path: '/',
              builder: (_, _) => const Scaffold(body: Text('Görevler')),
            ),
            GoRoute(
              path: '/prices',
              builder: (_, _) => const Scaffold(body: Text('Fiyatlar')),
            ),
            GoRoute(path: '/planner', builder: (_, _) => const PlannerScreen()),
          ],
        ),
      ],
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          plannerRepositoryProvider.overrideWith(
            (ref) => _FakePlannerRepository(),
          ),
          authStateProvider.overrideWith(
            (ref) => const Stream<AuthState>.empty(),
          ),
          notificationsStreamProvider.overrideWith(
            (ref) => Stream.value(const <AppNotification>[]),
          ),
        ],
        child: MaterialApp.router(
          routerConfig: router,
          locale: const Locale('tr'),
          supportedLocales: AppLocalizations.supportedLocales,
          localizationsDelegates: const [
            AppLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Plan'));
    await tester.pumpAndSettle();
    expect(find.text('AI Plan'), findsOneWidget);
    expect(tester.takeException(), isNull);

    await tester.tap(find.text('Etkinlik Ekle'));
    await tester.pumpAndSettle();
    expect(find.text('Yeni Etkinlik'), findsOneWidget);

    await tester.enterText(find.byType(TextField), 'Diş randevusu');
    await tester.tap(find.text('Kaydet'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(find.text('Diş randevusu'), findsOneWidget);

    await tester.tap(find.text('Etkinlik Ekle'));
    await tester.pumpAndSettle();
    await tester.tapAt(const Offset(20, 100));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });
}
