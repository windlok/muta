import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'dart:async';

import '../../../core/localization/app_localizations.dart';
import '../../../core/network/scrape_service.dart';
import '../../../core/providers/providers.dart';
import '../../settings/presentation/settings_view_model.dart';
import '../domain/product_model.dart';
import 'price_view_model.dart';

class ProductSearchSheet extends ConsumerStatefulWidget {
  const ProductSearchSheet({super.key});

  @override
  ConsumerState<ProductSearchSheet> createState() => _ProductSearchSheetState();
}

class _ProductSearchSheetState extends ConsumerState<ProductSearchSheet> {
  final _query = TextEditingController();
  List<ProductSearchResult> _results = [];
  final _selected = <String>{};
  bool _loading = false;
  Timer? _progressTimer;
  int _elapsedSeconds = 0;

  @override
  void dispose() {
    _progressTimer?.cancel();
    _query.dispose();
    super.dispose();
  }

  Future<void> _search() async {
    final query = _query.text.trim();
    if (query.isEmpty) return;
    _progressTimer?.cancel();
    setState(() {
      _loading = true;
      _elapsedSeconds = 0;
    });
    _progressTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() => _elapsedSeconds++);
    });
    try {
      final prefs = ref.read(settingsViewModelProvider).value;
      final platforms = (prefs?.activePlatforms ?? const [])
          .map((platform) => platform.name)
          .toList();
      final results = await ref
          .read(scrapeServiceProvider)
          .search(query: query, platforms: platforms);
      if (mounted) {
        setState(() {
          _results = results;
          _selected.clear();
        });
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              AppLocalizations.of(context).searchError(error.toString()),
            ),
            duration: const Duration(seconds: 8),
          ),
        );
      }
    } finally {
      _progressTimer?.cancel();
      _progressTimer = null;
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _trackSelected() async {
    final l = AppLocalizations.of(context);
    final selected = [
      for (final result in _results)
        if (_selected.contains(result.url)) result,
    ];
    if (selected.isEmpty) return;
    final targetController = TextEditingController();
    final target = await showDialog<double>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l.targetPriceTitle),
        content: TextField(
          controller: targetController,
          autofocus: true,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: InputDecoration(labelText: l.newTargetLabel),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(l.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(
              ctx,
              double.tryParse(targetController.text.replaceAll(',', '.')),
            ),
            child: Text(l.save),
          ),
        ],
      ),
    );
    targetController.dispose();
    if (target == null || target <= 0 || !mounted) return;

    final uid = ref.read(currentUserIdProvider);
    if (uid == null) return;
    final repo = ref.read(priceRepositoryProvider);
    final now = DateTime.now();
    try {
      for (final result in selected) {
        final product = await repo.addProduct(
          TrackedProduct(
            id: '',
            userId: uid,
            name: result.name,
            url: result.url,
            platform: result.platform,
            currentPrice: result.price,
            targetPrice: target,
            imageUrl: result.imageUrl,
            createdAt: now,
            updatedAt: now,
          ),
        );
        await repo.saveOffer(
          productId: product.id,
          platform: result.platform,
          url: result.url,
          price: result.price,
        );
        if (result.price != null) {
          await repo.insertPricePoint(
            PricePoint(
              id: '',
              productId: product.id,
              price: result.price!,
              recordedAt: now,
            ),
          );
        }
      }
      ref.invalidate(productsViewModelProvider);
      if (mounted) Navigator.pop(context);
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(l.productSaveFailed(''))));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final scheme = Theme.of(context).colorScheme;
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          20,
          8,
          20,
          MediaQuery.of(context).viewInsets.bottom + 20,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              l.searchByProductName,
              style: Theme.of(context).textTheme.titleLarge
                  ?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 14),
            TextField(
              controller: _query,
              textInputAction: TextInputAction.search,
              onSubmitted: (_) => _search(),
              decoration: InputDecoration(
                labelText: l.productNameSearchHint,
                suffixIcon: IconButton(
                  onPressed: _loading ? null : _search,
                  icon: _loading
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.search),
                ),
              ),
            ),
            const SizedBox(height: 12),
            if (_loading)
              _SearchProgressCard(elapsedSeconds: _elapsedSeconds)
            else if (_results.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 20),
                child: Text(
                  l.noSearchResults,
                  textAlign: TextAlign.center,
                  style: TextStyle(color: scheme.onSurfaceVariant),
                ),
              )
            else
              Flexible(
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: _results.length,
                  itemBuilder: (_, index) {
                    final result = _results[index];
                    final selected = _selected.contains(result.url);
                    return CheckboxListTile(
                      value: selected,
                      onChanged: (value) => setState(() {
                        if (value == true) {
                          _selected.add(result.url);
                        } else {
                          _selected.remove(result.url);
                        }
                      }),
                      title: Text(
                        result.name,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      subtitle: Text(
                        '${result.platform} · ${l.price(result.price)}',
                      ),
                      secondary: result.imageUrl == null
                          ? const Icon(Icons.storefront_outlined)
                          : Image.network(
                              result.imageUrl!,
                              width: 48,
                              height: 48,
                              fit: BoxFit.cover,
                            ),
                    );
                  },
                ),
              ),
            if (_selected.isNotEmpty) ...[
              const SizedBox(height: 10),
              FilledButton.icon(
                onPressed: _trackSelected,
                icon: const Icon(Icons.notifications_active_outlined),
                label: Text(
                  '${l.trackSelectedOffers} · ${l.selectedOfferCount(_selected.length)}',
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _SearchProgressCard extends StatelessWidget {
  const _SearchProgressCard({required this.elapsedSeconds});

  final int elapsedSeconds;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final scheme = Theme.of(context).colorScheme;
    return Container(
      margin: const EdgeInsets.only(top: 8, bottom: 12),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: scheme.primaryContainer.withValues(alpha: 0.55),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: scheme.primary.withValues(alpha: 0.25)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.travel_explore, color: scheme.primary),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  l.searchInProgressTitle,
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
              ),
              Text(
                '${elapsedSeconds}s',
                style: TextStyle(color: scheme.onSurfaceVariant),
              ),
            ],
          ),
          const SizedBox(height: 14),
          const LinearProgressIndicator(),
          const SizedBox(height: 10),
          Text(l.searchInProgressMessage(elapsedSeconds)),
          const SizedBox(height: 4),
          Text(
            l.searchInProgressHint,
            style: TextStyle(color: scheme.onSurfaceVariant, fontSize: 12),
          ),
        ],
      ),
    );
  }
}
