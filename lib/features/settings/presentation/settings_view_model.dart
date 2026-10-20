import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../price_tracker/domain/platform_specs.dart';
import '../domain/platform_prefs.dart';

/// Platform tercihlerini (açık/kapalı siteler + özel siteler) yönetir.
/// Cihazda saklanır (shared_preferences).
class SettingsViewModel extends AsyncNotifier<PlatformPrefs> {
  static const _storageKey = 'platform_prefs_v1';

  @override
  Future<PlatformPrefs> build() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_storageKey);
    if (raw == null) return const PlatformPrefs();
    try {
      return PlatformPrefs.fromJson(jsonDecode(raw) as Map<String, dynamic>);
    } catch (_) {
      return const PlatformPrefs();
    }
  }

  Future<void> _persist(PlatformPrefs updated) async {
    state = AsyncData(updated);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_storageKey, jsonEncode(updated.toJson()));
  }

  Future<void> togglePlatform(String name, bool enabled) async {
    final current = state.value ?? const PlatformPrefs();
    final disabled = {...current.disabled};
    if (enabled) {
      disabled.remove(name);
    } else {
      disabled.add(name);
    }
    await _persist(current.copyWith(disabled: disabled));
  }

  /// Yeni site ekler. Geçersiz ya da zaten varsa false döner.
  Future<bool> addCustom(String name, String domainInput) async {
    final trimmedName = name.trim();
    final domain = normalizeDomain(domainInput);
    if (trimmedName.isEmpty || domain.isEmpty || !domain.contains('.')) {
      return false;
    }
    final current = state.value ?? const PlatformPrefs();
    final exists = kPlatformSpecs.any((s) => s.hosts.contains(domain)) ||
        current.custom.any((c) => c.domain == domain);
    if (exists) return false;
    await _persist(current.copyWith(
      custom: [
        ...current.custom,
        CustomPlatform(name: trimmedName, domain: domain),
      ],
    ));
    return true;
  }

  Future<void> removeCustom(String domain) async {
    final current = state.value ?? const PlatformPrefs();
    await _persist(current.copyWith(
      custom: [
        for (final c in current.custom)
          if (c.domain != domain) c,
      ],
    ));
  }
}

final settingsViewModelProvider =
    AsyncNotifierProvider<SettingsViewModel, PlatformPrefs>(
        SettingsViewModel.new);
