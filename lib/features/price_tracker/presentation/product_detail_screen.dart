import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/localization/app_localizations.dart';
import '../../../core/providers/providers.dart';
import '../data/web_price_fetcher.dart';
import '../domain/platform_specs.dart';
import '../domain/product_model.dart';
import 'price_view_model.dart';

class ProductDetailScreen extends ConsumerWidget {
  const ProductDetailScreen({super.key, required this.productId});

  final String productId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    final products = ref.watch(productsViewModelProvider).value ?? [];
    final product = products.where((p) => p.id == productId).firstOrNull;

    if (product == null) {
      return Scaffold(
        appBar: AppBar(),
        body: Center(child: Text(l.productNotFound)),
      );
    }

    final history = ref.watch(productHistoryProvider(productId)).value ?? [];
    final offers = ref.watch(productOffersProvider(productId)).value ?? [];
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(title: Text(l.productDetails)),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            if (product.imageUrl != null)
              Center(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(16),
                  child: Image.network(
                    product.imageUrl!,
                    height: 160,
                    fit: BoxFit.cover,
                    errorBuilder: (_, _, _) => const SizedBox(
                      height: 160,
                      child: Icon(Icons.image_outlined, size: 64),
                    ),
                  ),
                ),
              ),
            const SizedBox(height: 16),
            Text(
              product.name,
              style: Theme.of(context).textTheme.titleLarge
                  ?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                _StatChip(
                  label: l.currentLabel,
                  value: l.price(product.currentPrice),
                  color: scheme.primary,
                ),
                const SizedBox(width: 10),
                _StatChip(
                  label: l.targetLabel,
                  value: product.targetPrice == null
                      ? l.notSet
                      : l.price(product.targetPrice),
                  color: product.targetReached
                      ? Colors.green
                      : scheme.secondary,
                ),
              ],
            ),
            const SizedBox(height: 24),
            _comparisonSection(context, ref, product, offers),
            const SizedBox(height: 24),
            Text(
              l.priceHistory,
              style: Theme.of(context).textTheme.titleMedium
                  ?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 12),
            if (history.isEmpty)
              Container(
                height: 180,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: scheme.surfaceContainerHighest.withValues(alpha: 0.4),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Text(l.noHistory),
              )
            else
              SizedBox(
                height: 200,
                child: _PriceChart(history: history, color: scheme.primary),
              ),
            const SizedBox(height: 24),
            if (product.targetPrice != null) _targetBanner(context, product),
            const SizedBox(height: 16),
            _actionButtons(context, ref, product),
          ],
        ),
      ),
    );
  }

  Widget _comparisonSection(
    BuildContext context,
    WidgetRef ref,
    TrackedProduct product,
    List<ProductOffer> offers,
  ) {
    final l = AppLocalizations.of(context);
    final scheme = Theme.of(context).colorScheme;
    final displayOffers = offers.any((offer) => offer.url == product.url)
        ? offers
        : [
            ProductOffer(
              id: 'source-${product.id}',
              productId: product.id,
              platform: product.platform,
              url: product.url,
              price: product.currentPrice,
              checkedAt: product.updatedAt,
            ),
            ...offers,
          ];
    final pricedOffers = displayOffers
        .where((offer) => offer.price != null)
        .toList();
    final cheapest = pricedOffers.isEmpty
        ? null
        : pricedOffers.reduce((a, b) => a.price! <= b.price! ? a : b);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                l.comparePrices,
                style: Theme.of(context).textTheme.titleMedium
                    ?.copyWith(fontWeight: FontWeight.w700),
              ),
            ),
            IconButton(
              tooltip: l.addStoreOffer,
              onPressed: () => _addOffer(context, ref, product),
              icon: const Icon(Icons.add_circle_outline),
            ),
          ],
        ),
        if (displayOffers.isEmpty)
          Text(
            l.addStoreOffer,
            style: TextStyle(color: scheme.onSurfaceVariant),
          )
        else
          Container(
            decoration: BoxDecoration(
              border: Border.all(color: scheme.outlineVariant),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Column(
              children: [
                for (var i = 0; i < displayOffers.length; i++) ...[
                  if (i > 0) Divider(height: 1, color: scheme.outlineVariant),
                  _OfferRow(
                    offer: displayOffers[i],
                    cheapest: cheapest?.id == displayOffers[i].id,
                    difference:
                        cheapest == null || displayOffers[i].price == null
                        ? null
                        : displayOffers[i].price! - cheapest.price!,
                    onTap: () => launchUrl(
                      Uri.parse(displayOffers[i].url),
                      mode: LaunchMode.externalApplication,
                    ),
                  ),
                ],
              ],
            ),
          ),
      ],
    );
  }

  Future<void> _addOffer(
    BuildContext context,
    WidgetRef ref,
    TrackedProduct product,
  ) async {
    final l = AppLocalizations.of(context);
    final controller = TextEditingController();
    final url = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l.addStoreOffer),
        content: TextField(
          controller: controller,
          autofocus: true,
          keyboardType: TextInputType.url,
          decoration: InputDecoration(
            labelText: l.storeProductLink,
            hintText: 'https://www.n11.com/urun/...',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(l.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, controller.text.trim()),
            child: Text(l.save),
          ),
        ],
      ),
    );
    controller.dispose();
    if (url == null || url.isEmpty || !context.mounted) return;

    final uri = Uri.tryParse(url.startsWith('http') ? url : 'https://$url');
    if (uri == null || uri.host.isEmpty) return;
    try {
      final result = await WebPriceFetcher.fetch(context, uri.toString());
      if (!context.mounted) return;
      await ref
          .read(priceRepositoryProvider)
          .saveOffer(
            productId: product.id,
            platform: detectPlatform(uri.toString()),
            url: uri.toString(),
            price: result.price,
          );
      if (!context.mounted) return;
      ref.invalidate(productOffersProvider(product.id));
      if (result.price == null) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(l.offerReadFailed)));
      }
    } catch (_) {
      if (context.mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(l.offerReadFailed)));
      }
    }
  }

  String _alertLabel(AppLocalizations l, TrackedProduct product) =>
      product.alertType == PriceAlertType.percent
      ? l.alertPercentShort(product.alertPercent)
      : l.alertTypeLabel(product.alertType.value);

  Widget _targetBanner(BuildContext context, TrackedProduct product) {
    final l = AppLocalizations.of(context);
    final scheme = Theme.of(context).colorScheme;
    final reached = product.targetReached;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: (reached ? Colors.green : scheme.secondary).withValues(
          alpha: 0.1,
        ),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          Icon(
            reached ? Icons.emoji_events : Icons.trending_down,
            color: reached ? Colors.green : scheme.secondary,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              reached ? l.targetReachedBanner : l.targetTrackingBanner,
              style: TextStyle(
                color: reached ? Colors.green : scheme.onSurface,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _actionButtons(
    BuildContext context,
    WidgetRef ref,
    TrackedProduct product,
  ) {
    final l = AppLocalizations.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        FilledButton.icon(
          onPressed: () => _refreshPrice(context, ref, product),
          icon: const Icon(Icons.refresh),
          label: Text(l.updatePriceNow),
        ),
        const SizedBox(height: 10),
        OutlinedButton.icon(
          onPressed: () async {
            final uri = Uri.tryParse(product.url);
            if (uri == null) return;
            final ok = await launchUrl(
              uri,
              mode: LaunchMode.externalApplication,
            );
            if (!ok && context.mounted) {
              ScaffoldMessenger.of(context)
                  .showSnackBar(SnackBar(content: Text(l.browserOpenFailed)));
            }
          },
          icon: const Icon(Icons.open_in_new),
          label: Text(l.openInBrowser),
        ),
        const SizedBox(height: 10),
        OutlinedButton.icon(
          onPressed: () => _setTarget(context, ref, product),
          icon: const Icon(Icons.flag_outlined),
          label: Text(l.updateTarget),
        ),
        const SizedBox(height: 10),
        OutlinedButton.icon(
          onPressed: () => _setAlert(context, ref, product),
          icon: const Icon(Icons.notifications_active_outlined),
          label: Text('${l.notificationLabel}: ${_alertLabel(l, product)}'),
        ),
        const SizedBox(height: 10),
        TextButton.icon(
          onPressed: () async {
            await ref.read(productsViewModelProvider.notifier).remove(product);
            if (context.mounted) Navigator.of(context).pop();
          },
          icon: Icon(
            Icons.delete_outline,
            color: Theme.of(context).colorScheme.error,
          ),
          label: Text(
            l.stopTracking,
            style: TextStyle(color: Theme.of(context).colorScheme.error),
          ),
        ),
      ],
    );
  }

  Future<void> _setTarget(
    BuildContext context,
    WidgetRef ref,
    TrackedProduct product,
  ) async {
    final l = AppLocalizations.of(context);
    final controller = TextEditingController(
      text: product.targetPrice?.toStringAsFixed(0) ?? '',
    );
    final result = await showDialog<double>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l.targetPriceTitle),
        content: TextField(
          controller: controller,
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
              double.tryParse(controller.text.replaceAll(',', '.')),
            ),
            child: Text(l.save),
          ),
        ],
      ),
    );
    if (result != null && result > 0) {
      await ref
          .read(productsViewModelProvider.notifier)
          .setTarget(product, result);
    }
    controller.dispose();
  }

  /// Telefonun tarayıcısıyla fiyatı şimdi günceller.
  Future<void> _refreshPrice(
    BuildContext context,
    WidgetRef ref,
    TrackedProduct product,
  ) async {
    final l = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);
    try {
      final result = await WebPriceFetcher.fetch(context, product.url);
      if (result.price == null) {
        messenger.showSnackBar(SnackBar(content: Text(l.priceReadFailed)));
        return;
      }
      final price = result.price!;
      await ref
          .read(productsViewModelProvider.notifier)
          .refreshPrice(product, price);
      final reached =
          product.targetPrice != null && price <= product.targetPrice!;
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            reached
                ? l.priceUpdatedReached(l.price(price))
                : l.priceUpdated(l.price(price)),
          ),
        ),
      );
    } catch (_) {
      messenger.showSnackBar(SnackBar(content: Text(l.priceUpdateFailed)));
    }
  }

  /// Bildirim türünü (hedef / her düşüş / yüzde) düzenler.
  Future<void> _setAlert(
    BuildContext context,
    WidgetRef ref,
    TrackedProduct product,
  ) async {
    final l = AppLocalizations.of(context);
    var type = product.alertType;
    final percent = TextEditingController(
      text: (product.alertPercent ?? 10).toStringAsFixed(0),
    );
    final saved = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: Text(l.alertSettingsTitle),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final t in PriceAlertType.values)
                    ChoiceChip(
                      label: Text(l.alertTypeLabel(t.value)),
                      selected: type == t,
                      onSelected: (_) => setDialogState(() => type = t),
                    ),
                ],
              ),
              if (type == PriceAlertType.percent) ...[
                const SizedBox(height: 14),
                TextField(
                  controller: percent,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  decoration: InputDecoration(
                    labelText: l.percentDropLabel,
                    prefixIcon: const Icon(Icons.percent),
                  ),
                ),
              ],
              const SizedBox(height: 12),
              Text(
                l.alertTypeDescription(type.value, product.alertPercent),
                style: TextStyle(
                  fontSize: 12,
                  color: Theme.of(ctx).colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: Text(l.cancel),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: Text(l.save),
            ),
          ],
        ),
      ),
    );
    final percentValue = double.tryParse(percent.text.replaceAll(',', '.'));
    percent.dispose();
    if (saved != true) return;
    if (type == PriceAlertType.target && product.targetPrice == null) {
      if (context.mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(l.setTargetFirst)));
      }
      return;
    }
    await ref
        .read(productsViewModelProvider.notifier)
        .setAlert(product, type, percentValue);
  }
}

class _OfferRow extends StatelessWidget {
  const _OfferRow({
    required this.offer,
    required this.cheapest,
    required this.difference,
    required this.onTap,
  });

  final ProductOffer offer;
  final bool cheapest;
  final double? difference;
  final Future<bool> Function() onTap;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final color = cheapest ? Colors.green : null;
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        child: Row(
          children: [
            Expanded(
              child: Text(
                offer.platform,
                style: TextStyle(fontWeight: FontWeight.w600, color: color),
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  offer.price == null
                      ? l.offerPriceNotFound
                      : l.price(offer.price),
                  style: TextStyle(fontWeight: FontWeight.w700, color: color),
                ),
                if (!cheapest && difference != null && difference! > 0)
                  Text(
                    '+${l.price(difference)}',
                    style: TextStyle(
                      fontSize: 11,
                      color: Theme.of(context).colorScheme.error,
                    ),
                  ),
              ],
            ),
            const SizedBox(width: 8),
            Icon(
              cheapest ? Icons.check_circle : Icons.open_in_new,
              size: 18,
              color: color,
            ),
          ],
        ),
      ),
    );
  }
}

class _StatChip extends StatelessWidget {
  const _StatChip({
    required this.label,
    required this.value,
    required this.color,
  });

  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              value,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PriceChart extends StatelessWidget {
  const _PriceChart({required this.history, required this.color});

  final List<PricePoint> history;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final sorted = history.reversed.toList();
    final prices = sorted.map((p) => p.price).toList();
    final minY = (prices.reduce((a, b) => a < b ? a : b) * 0.98);
    final maxY = (prices.reduce((a, b) => a > b ? a : b) * 1.02);

    return LineChart(
      LineChartData(
        minY: minY,
        maxY: maxY,
        gridData: FlGridData(
          show: true,
          drawVerticalLine: false,
          getDrawingHorizontalLine: (v) => FlLine(
            color: Theme.of(context).colorScheme.outlineVariant
                .withValues(alpha: 0.4),
            strokeWidth: 1,
          ),
        ),
        titlesData: FlTitlesData(
          topTitles: const AxisTitles(
            sideTitles: SideTitles(showTitles: false),
          ),
          rightTitles: const AxisTitles(
            sideTitles: SideTitles(showTitles: false),
          ),
          leftTitles: const AxisTitles(
            sideTitles: SideTitles(showTitles: false),
          ),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 26,
              interval: (sorted.length / 4).ceilToDouble().clamp(1, 100),
              getTitlesWidget: (value, meta) {
                final idx = value.toInt();
                if (idx < 0 || idx >= sorted.length) return const SizedBox();
                final d = sorted[idx].recordedAt;
                return Text(
                  l.compactDate(d),
                  style: const TextStyle(fontSize: 10),
                );
              },
            ),
          ),
        ),
        lineBarsData: [
          LineChartBarData(
            spots: [
              for (var i = 0; i < sorted.length; i++)
                FlSpot(i.toDouble(), sorted[i].price),
            ],
            isCurved: true,
            color: color,
            barWidth: 2.5,
            dotData: const FlDotData(show: false),
            belowBarData: BarAreaData(
              show: true,
              color: color.withValues(alpha: 0.12),
            ),
          ),
        ],
      ),
    );
  }
}
