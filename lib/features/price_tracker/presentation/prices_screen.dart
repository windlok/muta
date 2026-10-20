import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/localization/app_localizations.dart';
import '../../../shared/widgets/empty_state.dart';
import '../../../shared/widgets/section_header.dart';
import '../../notifications/presentation/notification_bell.dart';
import '../domain/product_model.dart';
import 'add_product_sheet.dart';
import 'price_view_model.dart';
import 'product_detail_screen.dart';
import 'product_search_sheet.dart';

class PricesScreen extends ConsumerWidget {
  const PricesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    final asyncProducts = ref.watch(productsViewModelProvider);
    final products = asyncProducts.value ?? [];

    return Scaffold(
      appBar: AppBar(
        title: Text(l.pricesTitle),
        actions: [
          const NotificationBell(),
          IconButton(
            tooltip: l.searchByProductName,
            icon: const Icon(Icons.search),
            onPressed: () => showModalBottomSheet(
              context: context,
              isScrollControlled: true,
              showDragHandle: true,
              builder: (_) => const ProductSearchSheet(),
            ),
          ),
          IconButton(
            tooltip: l.settings,
            icon: const Icon(Icons.settings_outlined),
            onPressed: () => context.push('/settings'),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => showModalBottomSheet(
          context: context,
          isScrollControlled: true,
          showDragHandle: true,
          builder: (_) => const AddProductSheet(),
        ),
        icon: const Icon(Icons.add_link),
        label: Text(l.trackProduct),
      ),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: () => ref.read(productsViewModelProvider.notifier).load(),
          child: asyncProducts.isLoading && products.isEmpty
              ? const Center(child: CircularProgressIndicator())
              : ListView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 100),
                  children: [
                    if (products.isEmpty) ...[
                      const SizedBox(height: 60),
                      EmptyState(
                        icon: Icons.sell_outlined,
                        title: l.noProductsTitle,
                        message: l.noProductsMessage,
                      ),
                    ] else ...[
                      SectionHeader(
                        title: l.trackedTitle,
                        subtitle: l.trackedSubtitle(products.length),
                      ),
                      const SizedBox(height: 12),
                      _SummaryRow(products: products),
                      const SizedBox(height: 16),
                      ...products.map((p) => _ProductCard(product: p)),
                    ],
                  ],
                ),
        ),
      ),
    );
  }
}

class _SummaryRow extends StatelessWidget {
  const _SummaryRow({required this.products});

  final List<TrackedProduct> products;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final scheme = Theme.of(context).colorScheme;
    final reached = products.where((p) => p.targetReached).length;
    final active = products.where((p) => p.isActive).length;

    return Row(
      children: [
        _SummaryTile(
          icon: Icons.inventory_2_outlined,
          value: '${products.length}',
          label: l.productsLabel,
          color: scheme.primary,
        ),
        const SizedBox(width: 10),
        _SummaryTile(
          icon: Icons.flag_outlined,
          value: '$reached',
          label: l.atTargetLabel,
          color: Colors.green,
        ),
        const SizedBox(width: 10),
        _SummaryTile(
          icon: Icons.notifications_active_outlined,
          value: '$active',
          label: l.activeLabel,
          color: scheme.secondary,
        ),
      ],
    );
  }
}

class _SummaryTile extends StatelessWidget {
  const _SummaryTile({
    required this.icon,
    required this.value,
    required this.label,
    required this.color,
  });

  final IconData icon;
  final String value;
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: scheme.surfaceContainerHighest.withValues(alpha: 0.45),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, size: 18, color: color),
            const SizedBox(height: 8),
            Text(
              value,
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
            ),
            Text(
              label,
              style: TextStyle(fontSize: 11, color: scheme.onSurfaceVariant),
            ),
          ],
        ),
      ),
    );
  }
}

class _ProductCard extends ConsumerWidget {
  const _ProductCard({required this.product});

  final TrackedProduct product;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    final scheme = Theme.of(context).colorScheme;

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Card(
        child: InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: () => Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => ProductDetailScreen(productId: product.id),
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Row(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: product.imageUrl != null
                      ? Image.network(
                          product.imageUrl!,
                          width: 56,
                          height: 56,
                          fit: BoxFit.cover,
                          errorBuilder: (_, _, _) => _imageFallback(scheme),
                        )
                      : _imageFallback(scheme),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        product.name,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 15,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 3,
                            ),
                            decoration: BoxDecoration(
                              color: scheme.secondaryContainer,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              l.platformName(product.platform),
                              style: TextStyle(
                                fontSize: 11,
                                color: scheme.onSecondaryContainer,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            l.price(product.currentPrice),
                            style: TextStyle(
                              fontWeight: FontWeight.w700,
                              color: scheme.primary,
                            ),
                          ),
                        ],
                      ),
                      if (product.targetPrice != null) ...[
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            Icon(
                              product.targetReached
                                  ? Icons.check_circle
                                  : Icons.flag_outlined,
                              size: 14,
                              color: product.targetReached
                                  ? Colors.green
                                  : scheme.onSurfaceVariant,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              l.targetLine(l.price(product.targetPrice)),
                              style: TextStyle(
                                fontSize: 12,
                                color: product.targetReached
                                    ? Colors.green
                                    : scheme.onSurfaceVariant,
                              ),
                            ),
                          ],
                        ),
                      ],
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          Icon(
                            Icons.notifications_outlined,
                            size: 13,
                            color: scheme.onSurfaceVariant,
                          ),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              l.notificationLine(
                                _alertLabel(
                                  l,
                                  product.alertType,
                                  product.alertPercent,
                                ),
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 11,
                                color: scheme.onSurfaceVariant,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const Icon(Icons.chevron_right),
              ],
            ),
          ),
        ),
      ),
    );
  }

  String _alertLabel(
    AppLocalizations l,
    PriceAlertType type,
    double? percent,
  ) => type == PriceAlertType.percent
      ? l.alertPercentShort(percent)
      : l.alertTypeLabel(type.value);

  Widget _imageFallback(ColorScheme scheme) => Container(
    width: 56,
    height: 56,
    color: scheme.surfaceContainerHighest,
    child: Icon(Icons.image_outlined, color: scheme.onSurfaceVariant),
  );
}
