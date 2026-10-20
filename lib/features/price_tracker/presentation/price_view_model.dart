import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/localization/app_localizations.dart';
import '../../../core/localization/language_store.dart';
import '../../../core/network/scrape_service.dart';
import '../../../core/providers/providers.dart';
import '../../settings/presentation/settings_view_model.dart';
import '../data/price_repository.dart';
import '../domain/platform_specs.dart';
import '../domain/product_model.dart';

/// Yeni ürün ekleme akışının durumu.
class AddProductState {
  AddProductState({
    this.loading = false,
    this.url = '',
    this.name = '',
    this.price,
    this.imageUrl,
    this.platform = '',
    this.manualPlatform,
    this.alertType = PriceAlertType.target,
    this.alertPercent = 10,
    this.error,
    this.step = AddProductStep.url,
  });

  final bool loading;
  final String url;
  final String name;
  final double? price;
  final String? imageUrl;
  final String platform;

  /// Kullanıcı elle bir site seçtiyse adı (null = otomatik algıla).
  final String? manualPlatform;
  final PriceAlertType alertType;
  final double? alertPercent;
  final String? error;
  final AddProductStep step;

  AddProductState copyWith({
    bool? loading,
    String? url,
    String? name,
    double? price,
    bool clearPrice = false,
    String? imageUrl,
    bool clearImage = false,
    String? platform,
    String? manualPlatform,
    bool clearManualPlatform = false,
    PriceAlertType? alertType,
    double? alertPercent,
    String? error,
    bool clearError = false,
    AddProductStep? step,
  }) {
    return AddProductState(
      loading: loading ?? this.loading,
      url: url ?? this.url,
      name: name ?? this.name,
      price: clearPrice ? null : (price ?? this.price),
      imageUrl: clearImage ? null : (imageUrl ?? this.imageUrl),
      platform: platform ?? this.platform,
      manualPlatform: clearManualPlatform
          ? null
          : (manualPlatform ?? this.manualPlatform),
      alertType: alertType ?? this.alertType,
      alertPercent: alertPercent ?? this.alertPercent,
      error: clearError ? null : (error ?? this.error),
      step: step ?? this.step,
    );
  }
}

enum AddProductStep { url, target, saving }

/// Takip edilen ürünlerin listesi.
class ProductsViewModel extends AsyncNotifier<List<TrackedProduct>> {
  late PriceRepository _repo;

  @override
  Future<List<TrackedProduct>> build() async {
    _repo = ref.watch(priceRepositoryProvider);
    ref.listen(authStateProvider, (prev, next) {
      final prevId = prev?.value?.session?.user.id;
      final nextId = next.value?.session?.user.id;
      if (nextId == null) {
        state = const AsyncData([]);
      } else if (prevId != nextId) {
        load();
      }
    });
    return _repo.fetchProducts();
  }

  Future<void> load() async {
    if (!state.hasValue) state = const AsyncLoading();
    state = await AsyncValue.guard(_repo.fetchProducts);
  }

  Future<void> remove(TrackedProduct product) async {
    await _repo.deleteProduct(product.id);
    state = AsyncData(
      (state.value ?? []).where((p) => p.id != product.id).toList(),
    );
  }

  Future<void> setTarget(TrackedProduct product, double target) async {
    final updated = product.copyWith(
      targetPrice: target,
      updatedAt: DateTime.now(),
    );
    await _repo.updateProduct(updated);
    _replace(updated);
  }

  Future<void> toggleActive(TrackedProduct product) async {
    final updated = product.copyWith(
      isActive: !product.isActive,
      updatedAt: DateTime.now(),
    );
    await _repo.updateProduct(updated);
    _replace(updated);
  }

  /// Bildirim türünü günceller (hedef / her düşüş / yüzde).
  Future<void> setAlert(
    TrackedProduct product,
    PriceAlertType type,
    double? percent,
  ) async {
    final updated = product.copyWith(
      alertType: type,
      alertPercent: type == PriceAlertType.percent ? (percent ?? 10) : null,
      clearAlertPercent: type != PriceAlertType.percent,
      updatedAt: DateTime.now(),
    );
    await _repo.updateProduct(updated);
    _replace(updated);
  }

  /// Scraping sonrası fiyatı günceller ve geçmişe ekler.
  Future<void> refreshPrice(TrackedProduct product, double price) async {
    final updated = product.copyWith(
      currentPrice: price,
      updatedAt: DateTime.now(),
    );
    await _repo.updateProduct(updated);
    await _repo.insertPricePoint(
      PricePoint(
        id: '',
        productId: product.id,
        price: price,
        recordedAt: DateTime.now(),
      ),
    );
    _replace(updated);
  }

  void _replace(TrackedProduct updated) {
    state = AsyncData([
      for (final p in state.value ?? [])
        if (p.id == updated.id) updated else p,
    ]);
  }
}

final productsViewModelProvider =
    AsyncNotifierProvider<ProductsViewModel, List<TrackedProduct>>(
      ProductsViewModel.new,
    );

/// Tek bir ürünün fiyat geçmişi.
final productHistoryProvider = FutureProvider.family<List<PricePoint>, String>((
  ref,
  productId,
) {
  return ref.watch(priceRepositoryProvider).fetchPriceHistory(productId);
});

final productOffersProvider = FutureProvider.family<List<ProductOffer>, String>(
  (ref, productId) {
    return ref.watch(priceRepositoryProvider).fetchOffers(productId);
  },
);

/// Yeni ürün ekleme akışı (URL -> scraping -> hedef fiyat).
class AddProductViewModel extends Notifier<AddProductState> {
  @override
  AddProductState build() => AddProductState();

  AppLocalizations get _l =>
      AppLocalizations.forLanguageCode(ref.read(appLanguageProvider));

  String? get error => state.error;

  List<PlatformSpec> _customSpecs() =>
      ref.read(settingsViewModelProvider).value?.extraSpecs ?? const [];

  String _resultName(String name) =>
      name.trim().isEmpty ? _l.productFallbackName : name;

  void setUrl(String url) {
    if (state.manualPlatform == null) {
      state = state.copyWith(
        url: url,
        platform: detectPlatform(url, extra: _customSpecs()),
        clearError: true,
      );
    } else {
      state = state.copyWith(url: url, clearError: true);
    }
  }

  /// Kullanıcı siteyi elle seçti (null = otomatik algılamaya dön).
  void setPlatform(String? name) {
    if (name == null) {
      state = state.copyWith(
        platform: detectPlatform(state.url, extra: _customSpecs()),
        clearManualPlatform: true,
      );
    } else {
      state = state.copyWith(platform: name, manualPlatform: name);
    }
  }

  void setAlertType(PriceAlertType type) {
    state = state.copyWith(alertType: type);
  }

  void setAlertPercent(double? percent) {
    if (percent == null) return;
    state = state.copyWith(alertPercent: percent);
  }

  /// WebView (telefon tarayıcısı) sonucunu akışa uygular.
  void applyWebResult(ScrapeResult result) {
    state = state.copyWith(
      loading: false,
      name: _resultName(result.name),
      price: result.price,
      imageUrl: result.imageUrl,
      clearError: true,
      step: AddProductStep.target,
    );
  }

  /// URL'den ürün bilgilerini çeker.
  Future<bool> fetchDetails() async {
    if (state.url.trim().isEmpty) {
      state = state.copyWith(error: _l.productLinkRequired);
      return false;
    }
    state = state.copyWith(loading: true, clearError: true);
    try {
      final service = ref.read(scrapeServiceProvider);
      final result = await service.scrape(state.url.trim());
      state = state.copyWith(
        loading: false,
        name: _resultName(result.name),
        price: result.price,
        imageUrl: result.imageUrl,
        step: AddProductStep.target,
      );
      return true;
    } catch (e) {
      state = state.copyWith(loading: false, error: _l.productFetchFailed);
      return false;
    }
  }

  /// Ürünü hedef fiyatıyla kaydeder.
  Future<bool> save({double? targetPrice}) async {
    if (state.alertType == PriceAlertType.target &&
        (targetPrice == null || targetPrice <= 0)) {
      state = state.copyWith(error: _l.targetPriceRequired);
      return false;
    }
    final uid = ref.read(currentUserIdProvider);
    if (uid == null) {
      state = state.copyWith(error: _l.sessionRequired);
      return false;
    }
    state = state.copyWith(
      loading: true,
      clearError: true,
      step: AddProductStep.saving,
    );
    try {
      final repo = ref.read(priceRepositoryProvider);
      final now = DateTime.now();
      final product = await repo.addProduct(
        TrackedProduct(
          id: '',
          userId: uid,
          name: state.name,
          url: state.url.trim(),
          platform: state.platform.isEmpty
              ? detectPlatform(state.url, extra: _customSpecs())
              : state.platform,
          currentPrice: state.price,
          targetPrice: targetPrice,
          imageUrl: state.imageUrl,
          alertType: state.alertType,
          alertPercent: state.alertType == PriceAlertType.percent
              ? (state.alertPercent ?? 10)
              : null,
          createdAt: now,
          updatedAt: now,
        ),
      );
      if (state.price != null) {
        await repo.insertPricePoint(
          PricePoint(
            id: '',
            productId: product.id,
            price: state.price!,
            recordedAt: now,
          ),
        );
      }
      await repo.saveOffer(
        productId: product.id,
        platform: product.platform,
        url: product.url,
        price: state.price,
      );
      await ref.read(productsViewModelProvider.notifier).load();
      return true;
    } catch (e) {
      state = state.copyWith(loading: false, error: _l.productSaveFailed(e));
      return false;
    }
  }

  void reset() => state = AddProductState();
}

final addProductViewModelProvider =
    NotifierProvider<AddProductViewModel, AddProductState>(
      AddProductViewModel.new,
    );
