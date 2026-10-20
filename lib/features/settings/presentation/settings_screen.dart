import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/config/app_config.dart';
import '../../../core/localization/app_localizations.dart';
import '../../../core/localization/language_store.dart';
import '../../../core/providers/providers.dart';
import '../../../shared/widgets/section_header.dart';
import '../../notifications/data/push_service.dart';
import '../../price_tracker/domain/platform_specs.dart';
import '../domain/platform_prefs.dart';
import 'settings_view_model.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    final asyncPrefs = ref.watch(settingsViewModelProvider);
    final prefs = asyncPrefs.value ?? const PlatformPrefs();
    final loadingPrefs = asyncPrefs.isLoading;
    final user = ref.watch(authRepositoryProvider).currentUser;
    final languageCode = ref.watch(appLanguageProvider);
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(title: Text(l.settings)),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 40),
        children: [
          SectionHeader(
            title: l.trackedSites,
            subtitle: l.trackedSitesSubtitle,
          ),
          const SizedBox(height: 8),
          if (loadingPrefs)
            const Padding(
              padding: EdgeInsets.only(bottom: 10),
              child: LinearProgressIndicator(minHeight: 3),
            ),
          Card(
            margin: EdgeInsets.zero,
            child: Column(
              children: [
                for (final spec in kPlatformSpecs)
                  SwitchListTile(
                    value: prefs.isEnabled(spec.name),
                    onChanged: loadingPrefs
                        ? null
                        : (value) => ref
                              .read(settingsViewModelProvider.notifier)
                              .togglePlatform(spec.name, value),
                    title: Text(spec.name),
                    subtitle: Text(
                      spec.hosts.first,
                      style: TextStyle(
                        fontSize: 12,
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                for (final custom in prefs.custom)
                  ListTile(
                    leading: Icon(
                      Icons.storefront_outlined,
                      color: scheme.primary,
                    ),
                    title: Text(custom.name),
                    subtitle: Text(custom.domain),
                    trailing: IconButton(
                      tooltip: l.removeTooltip,
                      icon: Icon(Icons.delete_outline, color: scheme.error),
                      onPressed: () => ref
                          .read(settingsViewModelProvider.notifier)
                          .removeCustom(custom.domain),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: () => showDialog<void>(
              context: context,
              builder: (_) => const _AddSiteDialog(),
            ),
            icon: const Icon(Icons.add_business_outlined),
            label: Text(l.addNewSite),
          ),
          const SizedBox(height: 26),
          SectionHeader(title: l.language, subtitle: l.languageSubtitle),
          const SizedBox(height: 8),
          Card(
            margin: EdgeInsets.zero,
            child: Column(
              children: [
                ListTile(
                  leading: const Icon(Icons.translate),
                  title: Text(l.english),
                  trailing: languageCode == 'en'
                      ? Icon(Icons.check, color: scheme.primary)
                      : null,
                  onTap: languageCode == 'en'
                      ? null
                      : () => _changeLanguage(ref, 'en'),
                ),
                ListTile(
                  leading: const Icon(Icons.translate),
                  title: Text(l.turkish),
                  trailing: languageCode == 'tr'
                      ? Icon(Icons.check, color: scheme.primary)
                      : null,
                  onTap: languageCode == 'tr'
                      ? null
                      : () => _changeLanguage(ref, 'tr'),
                ),
              ],
            ),
          ),
          const SizedBox(height: 26),
          SectionHeader(title: l.account),
          const SizedBox(height: 8),
          Card(
            margin: EdgeInsets.zero,
            child: Column(
              children: [
                ListTile(
                  leading: const Icon(Icons.person_outline),
                  title: Text(user?.email ?? l.notSignedIn),
                  subtitle: Text(l.accountEmail),
                ),
                ListTile(
                  leading: Icon(Icons.logout, color: scheme.error),
                  title: Text(l.logout, style: TextStyle(color: scheme.error)),
                  onTap: () async {
                    final ok = await showDialog<bool>(
                      context: context,
                      builder: (ctx) => AlertDialog(
                        title: Text(l.logoutTitle),
                        content: Text(l.logoutConfirm),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.pop(ctx, false),
                            child: Text(l.cancel),
                          ),
                          FilledButton(
                            onPressed: () => Navigator.pop(ctx, true),
                            child: Text(l.logout),
                          ),
                        ],
                      ),
                    );
                    if (ok != true) return;
                    await PushService.unregister();
                    await ref.read(authRepositoryProvider).signOut();
                    if (context.mounted) context.go('/login');
                  },
                ),
              ],
            ),
          ),
          const SizedBox(height: 28),
          Center(
            child: Text(
              '${AppConfig.appName} · ${AppConfig.developerName}',
              style: TextStyle(color: scheme.onSurfaceVariant, fontSize: 12),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _changeLanguage(WidgetRef ref, String code) async {
    await ref.read(appLanguageProvider.notifier).setLanguage(code);
    await PushService.setLanguage(code);
  }
}

class _AddSiteDialog extends ConsumerStatefulWidget {
  const _AddSiteDialog();

  @override
  ConsumerState<_AddSiteDialog> createState() => _AddSiteDialogState();
}

class _AddSiteDialogState extends ConsumerState<_AddSiteDialog> {
  final _name = TextEditingController();
  final _domain = TextEditingController();
  String? _error;
  bool _saving = false;

  @override
  void dispose() {
    _name.dispose();
    _domain.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    setState(() {
      _saving = true;
      _error = null;
    });
    final ok = await ref
        .read(settingsViewModelProvider.notifier)
        .addCustom(_name.text, _domain.text);
    if (!mounted) return;
    if (ok) {
      Navigator.of(context).pop();
    } else {
      setState(() {
        _saving = false;
        _error = AppLocalizations.of(context).invalidSite;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return AlertDialog(
      title: Text(l.addSiteTitle),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: _name,
            textCapitalization: TextCapitalization.words,
            decoration: InputDecoration(
              labelText: l.siteNameLabel,
              hintText: l.siteNameHint,
              prefixIcon: const Icon(Icons.storefront_outlined),
            ),
          ),
          const SizedBox(height: 14),
          TextField(
            controller: _domain,
            keyboardType: TextInputType.url,
            decoration: InputDecoration(
              labelText: l.siteAddressLabel,
              hintText: l.siteAddressHint,
              prefixIcon: const Icon(Icons.language),
            ),
          ),
          if (_error != null) ...[
            const SizedBox(height: 12),
            Text(
              _error!,
              style: TextStyle(
                color: Theme.of(context).colorScheme.error,
                fontSize: 13,
              ),
            ),
          ],
        ],
      ),
      actions: [
        TextButton(
          onPressed: _saving ? null : () => Navigator.of(context).pop(),
          child: Text(l.cancel),
        ),
        FilledButton(onPressed: _saving ? null : _save, child: Text(l.add)),
      ],
    );
  }
}
