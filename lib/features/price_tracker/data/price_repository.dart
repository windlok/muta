import 'package:supabase_flutter/supabase_flutter.dart';

import '../domain/product_model.dart';

/// Fiyat takibi için Supabase veri erişimi.
class PriceRepository {
  PriceRepository(this._client);

  final SupabaseClient _client;

  String? get _uid => _client.auth.currentUser?.id;

  Future<List<TrackedProduct>> fetchProducts() async {
    final uid = _uid;
    if (uid == null) return [];
    final data = await _client
        .from('tracked_products')
        .select()
        .eq('user_id', uid)
        .order('created_at', ascending: false);
    return (data as List)
        .map((e) => TrackedProduct.fromMap(e as Map<String, dynamic>))
        .toList();
  }

  Future<TrackedProduct> addProduct(TrackedProduct product) async {
    final uid = _uid;
    if (uid == null) throw StateError('Oturum bulunamadı.');
    final row = await _client
        .from('tracked_products')
        .insert({...product.toInsertMap(), 'user_id': uid})
        .select()
        .single();
    return TrackedProduct.fromMap(row);
  }

  Future<void> updateProduct(TrackedProduct product) async {
    await _client
        .from('tracked_products')
        .update({
          'name': product.name,
          'current_price': product.currentPrice,
          'target_price': product.targetPrice,
          'image_url': product.imageUrl,
          'category': product.category,
          'is_active': product.isActive,
          'notify_on_drop': product.notifyOnDrop,
          'alert_type': product.alertType.value,
          'alert_percent': product.alertPercent,
          'updated_at': DateTime.now().toUtc().toIso8601String(),
        })
        .eq('id', product.id);
  }

  Future<void> deleteProduct(String id) async {
    await _client.from('tracked_products').delete().eq('id', id);
  }

  /// Fiyat geçmişini getirir (en yeniden eskiye).
  Future<List<PricePoint>> fetchPriceHistory(String productId) async {
    final data = await _client
        .from('price_history')
        .select()
        .eq('product_id', productId)
        .order('recorded_at', ascending: false)
        .limit(60);
    return (data as List)
        .map((e) => PricePoint.fromMap(e as Map<String, dynamic>))
        .toList();
  }

  /// Fiyat geçmişine yeni nokta ekler.
  Future<void> insertPricePoint(PricePoint point) async {
    await _client.from('price_history').insert({
      'product_id': point.productId,
      'price': point.price,
      'recorded_at': point.recordedAt.toUtc().toIso8601String(),
    });
  }

  Future<List<ProductOffer>> fetchOffers(String productId) async {
    final data = await _client
        .from('product_offers')
        .select()
        .eq('product_id', productId)
        .order('price', ascending: true, nullsFirst: false);
    return (data as List)
        .map((e) => ProductOffer.fromMap(e as Map<String, dynamic>))
        .toList();
  }

  Future<ProductOffer> saveOffer({
    required String productId,
    required String platform,
    required String url,
    required double? price,
  }) async {
    final row = await _client
        .from('product_offers')
        .upsert({
          'product_id': productId,
          'platform': platform,
          'url': url,
          'price': price,
          'checked_at': DateTime.now().toUtc().toIso8601String(),
        }, onConflict: 'product_id,url')
        .select()
        .single();
    return ProductOffer.fromMap(row);
  }
}
