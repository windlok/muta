import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:logger/logger.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../network/gemini_service.dart';
import '../network/scrape_service.dart';
import '../../features/auth/data/auth_repository.dart';
import '../../features/notifications/data/notifications_repository.dart';
import '../../features/notifications/domain/notification_model.dart';
import '../../features/planner/data/planner_repository.dart';
import '../../features/price_tracker/data/price_repository.dart';
import '../../features/tasks/data/tasks_repository.dart';

/// Tüm provider'ların merkezi kaydı.
///
/// UI bu provider'ları `ref.watch(...)` ile okur. Bağımlılık zinciri sayesinde
/// Supabase istemcisi tek bir yerden yönetilir.

final loggerProvider = Provider<Logger>((ref) => Logger());

final supabaseClientProvider = Provider<SupabaseClient>(
  (ref) => Supabase.instance.client,
);

// --- Repositories ---

final authRepositoryProvider = Provider<AuthRepository>(
  (ref) => AuthRepository(ref.watch(supabaseClientProvider)),
);

final tasksRepositoryProvider = Provider<TasksRepository>(
  (ref) => TasksRepository(ref.watch(supabaseClientProvider)),
);

final priceRepositoryProvider = Provider<PriceRepository>(
  (ref) => PriceRepository(ref.watch(supabaseClientProvider)),
);

final plannerRepositoryProvider = Provider<PlannerRepository>(
  (ref) => PlannerRepository(ref.watch(supabaseClientProvider)),
);

final notificationsRepositoryProvider = Provider<NotificationsRepository>(
  (ref) => NotificationsRepository(ref.watch(supabaseClientProvider)),
);

// --- Services ---

final geminiServiceProvider = Provider<GeminiService>(
  (ref) => GeminiService(
    ref.watch(supabaseClientProvider),
    logger: ref.watch(loggerProvider),
  ),
);

final scrapeServiceProvider = Provider<ScrapeService>(
  (ref) => ScrapeService(
    ref.watch(supabaseClientProvider),
    logger: ref.watch(loggerProvider),
  ),
);

// --- Auth durumu ---

final authStateProvider = StreamProvider<AuthState>(
  (ref) => ref.watch(authRepositoryProvider).onAuthStateChange,
);

/// Aktif kullanıcının kimlik id'si (yoksa null).
///
/// Auth akışını (giriş/çıkış) dinler; böylece kullanıcı değişince
/// önbellekte kalan eski id kullanılmaz.
final currentUserIdProvider = Provider<String?>((ref) {
  final auth = ref.watch(authStateProvider);
  return auth.value?.session?.user.id ??
      ref.watch(authRepositoryProvider).currentUser?.id;
});

/// Bildirimler (Realtime). Auth değişiminde otomatik yeniden abone olur.
final notificationsStreamProvider = StreamProvider<List<AppNotification>>(
  (ref) {
    ref.watch(currentUserIdProvider);
    return ref.watch(notificationsRepositoryProvider).watch();
  },
);
