import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/localization/app_localizations.dart';
import '../../../core/providers/providers.dart';
import '../../../shared/widgets/section_header.dart';
import '../../settings/presentation/settings_view_model.dart';
import '../data/web_price_fetcher.dart';
import '../domain/platform_specs.dart';
import '../domain/product_model.dart';
import 'price_view_model.dart';

class AddProductSheet extends ConsumerStatefulWidget {
  const AddProductSheet({super.key});

  @override
  ConsumerState<AddProductSheet> createState() => _AddProductSheetState();
}

class _AddProductSheetState extends ConsumerState<AddProductSheet> {
  final _url = TextEditingController();
  final _target = TextEditingController();
  final _percent = TextEditingController();

  @override
  void initState() {
    super.initState();
    final vm = ref.read(addProductViewModelProvider.notifier);
    _url.text = ref.read(addProductViewModelProvider).url;
    _url.addListener(() => vm.setUrl(_url.text));
    _percent.text = ((ref.read(addProductViewModelProvider).alertPercent) ?? 10)
        .toStringAsFixed(0);
    _percent.addListener(() {
      final value = double.tryParse(_percent.text.replaceAll(',', '.'));
      if (value != null && value > 0) vm.setAlertPercent(value);
    });
  }

  @override
  void dispose() {
    _url.dispose();
    _target.dispose();
    _percent.dispose();
    super.dispose();
  }

  Future<void> _fetch() async {
    final l = AppLocalizations.of(context);
    final vm = ref.read(addProductViewModelProvider.notifier);
    final rawUrl = ref.read(addProductViewModelProvider).url.trim();

    final url = _normalizeUrl(rawUrl);
    if (url == null) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(l.invalidProductLink)));
      return;
    }
    if (url != rawUrl) {
      _url.text = url;
    }

    final cloudOk = await vm.fetchDetails();
    if (!mounted) return;
    final state = ref.read(addProductViewModelProvider);
    if (cloudOk && state.price != null) return;

    // Bulut scraping başarısız olduysa (bot koruması) telefonun kendi
    // tarayıcısıyla (WebView) dene — Trendyol bu yöntemle çalışır.
    try {
      final result = await WebPriceFetcher.fetch(context, url);
      if (!mounted) return;
      vm.applyWebResult(result);
      if (result.price == null) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(l.priceFetchFailedManual)));
      }
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(state.error ?? l.productFetchFailed)),
      );
    }
  }

  String? _normalizeUrl(String input) {
    var value = input.trim();
    if (value.isEmpty || value.contains(' ')) return null;
    if (!RegExp(r'^https?://', caseSensitive: false).hasMatch(value)) {
      value = 'https://$value';
    }
    final uri = Uri.tryParse(value);
    if (uri == null || uri.host.isEmpty || !uri.host.contains('.')) {
      return null;
    }
    return value;
  }

  Future<void> _save() async {
    final l = AppLocalizations.of(context);
    final target = double.tryParse(_target.text.replaceAll(',', '.'));
    final alertType = ref.read(addProductViewModelProvider).alertType;
    final messenger = ScaffoldMessenger.of(context);
    if (alertType == PriceAlertType.target && (target == null || target <= 0)) {
      messenger.showSnackBar(SnackBar(content: Text(l.targetPriceRequired)));
      return;
    }

    // Önce kapat, sonra kaydet: ürün listesi yeniden yüklenirken modal
    // açık kalırsa Flutter element yaşam döngüsü assert'i tetiklenebiliyor.
    final viewModel = ref.read(addProductViewModelProvider.notifier);
    Navigator.of(context).pop();
    final ok = await viewModel.save(targetPrice: target);
    if (!ok) {
      messenger.showSnackBar(
        SnackBar(content: Text(viewModel.error ?? l.saveFailed)),
      );
    }
    viewModel.reset();
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final state = ref.watch(addProductViewModelProvider);
    final scheme = Theme.of(context).colorScheme;
    final logger = ref.read(loggerProvider);
    logger.t('AddProductSheet: step=${state.step}');

    return Padding(
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 8,
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SectionHeader(title: l.addProductTitle),
          const SizedBox(height: 18),
          TextField(
            controller: _url,
            keyboardType: TextInputType.url,
            decoration: InputDecoration(
              labelText: l.productLinkLabel,
              hintText: 'https://www.trendyol.com/...',
              prefixIcon: const Icon(Icons.link),
            ),
          ),
          const SizedBox(height: 14),
          if (state.step == AddProductStep.url) ...[
            _PlatformChips(
              selected: state.manualPlatform,
              detected: state.platform,
              onChanged: (name) => ref
                  .read(addProductViewModelProvider.notifier)
                  .setPlatform(name),
            ),
            const SizedBox(height: 14),
            FilledButton.icon(
              onPressed: state.loading ? null : _fetch,
              icon: state.loading
                  ? const SizedBox(
                      height: 18,
                      width: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.search),
              label: Text(l.getPrice),
            ),
          ],
          if (state.step != AddProductStep.url) ...[
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: scheme.surfaceContainerHighest.withValues(alpha: 0.5),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Row(
                children: [
                  if (state.imageUrl != null)
                    ClipRRect(
                      borderRadius: BorderRadius.circular(10),
                      child: Image.network(
                        state.imageUrl!,
                        width: 52,
                        height: 52,
                        fit: BoxFit.cover,
                        errorBuilder: (_, _, _) => const SizedBox(
                          width: 52,
                          height: 52,
                          child: Icon(Icons.image_outlined),
                        ),
                      ),
                    ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          state.name,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        ),
                        if (state.price != null)
                          Text(
                            '${l.currentPriceLineLabel}: ${l.price(state.price)}',
                            style: TextStyle(color: scheme.primary),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),
            TextField(
              controller: _target,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              decoration: InputDecoration(
                labelText: l.targetPriceInputLabel,
                hintText: l.targetPriceHint,
                prefixIcon: const Icon(Icons.flag_outlined),
              ),
            ),
            const SizedBox(height: 14),
            Text(
              l.notificationLabel,
              style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant),
            ),
            const SizedBox(height: 6),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final type in PriceAlertType.values)
                  ChoiceChip(
                    label: Text(l.alertTypeLabel(type.value)),
                    selected: state.alertType == type,
                    onSelected: (_) => ref
                        .read(addProductViewModelProvider.notifier)
                        .setAlertType(type),
                  ),
              ],
            ),
            if (state.alertType == PriceAlertType.percent) ...[
              const SizedBox(height: 10),
              TextField(
                controller: _percent,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                decoration: InputDecoration(
                  labelText: l.percentDropLabel,
                  hintText: l.percentHint,
                  prefixIcon: const Icon(Icons.percent),
                ),
              ),
            ],
            const SizedBox(height: 16),
            FilledButton(
              onPressed: state.loading ? null : _save,
              child: state.loading
                  ? const SizedBox(
                      height: 22,
                      width: 22,
                      child: CircularProgressIndicator(strokeWidth: 2.4),
                    )
                  : Text(l.trackButton),
            ),
          ],
        ],
      ),
    );
  }
}

/// Site seçim çipleri: "Otomatik" + ayarlardaki aktif siteler.
class _PlatformChips extends ConsumerWidget {
  const _PlatformChips({
    required this.selected,
    required this.detected,
    required this.onChanged,
  });

  final String? selected;
  final String detected;
  final ValueChanged<String?> onChanged;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    final scheme = Theme.of(context).colorScheme;
    final prefs = ref.watch(settingsViewModelProvider).value;
    final platforms = prefs?.activePlatforms ?? kPlatformSpecs;
    final autoLabel = l.automaticPlatform(detected);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          l.siteLabel,
          style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant),
        ),
        const SizedBox(height: 6),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            ChoiceChip(
              label: Text(autoLabel),
              selected: selected == null,
              onSelected: (_) => onChanged(null),
            ),
            for (final spec in platforms)
              ChoiceChip(
                label: Text(spec.name),
                selected: selected == spec.name,
                onSelected: (_) => onChanged(spec.name),
              ),
          ],
        ),
      ],
    );
  }
}
