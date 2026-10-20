import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/localization/app_localizations.dart';

/// Alt gezinme çubuğunu sağlayan kabuk ekran.
class HomeShell extends ConsumerWidget {
  const HomeShell({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final location = GoRouterState.of(context).matchedLocation;
    final scheme = Theme.of(context).colorScheme;
    final l = AppLocalizations.of(context);
    final index = switch (location) {
      '/prices' => 1,
      '/planner' => 2,
      _ => 0,
    };

    return Scaffold(
      body: child,
      bottomNavigationBar: DecoratedBox(
        decoration: BoxDecoration(
          border: Border(
            top: BorderSide(
              color: scheme.outlineVariant.withValues(alpha: 0.4),
            ),
          ),
        ),
        child: NavigationBar(
          selectedIndex: index,
          onDestinationSelected: (i) => switch (i) {
            1 => context.go('/prices'),
            2 => context.go('/planner'),
            _ => context.go('/'),
          },
          destinations: [
            NavigationDestination(
              icon: const Icon(Icons.checklist_outlined),
              selectedIcon: const Icon(Icons.checklist),
              label: l.tasksTab,
            ),
            NavigationDestination(
              icon: const Icon(Icons.price_change_outlined),
              selectedIcon: const Icon(Icons.price_change),
              label: l.pricesTab,
            ),
            NavigationDestination(
              icon: const Icon(Icons.calendar_month_outlined),
              selectedIcon: const Icon(Icons.calendar_month),
              label: l.planTab,
            ),
          ],
        ),
      ),
    );
  }
}
