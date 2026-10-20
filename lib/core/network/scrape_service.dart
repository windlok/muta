import 'dart:convert';
import 'dart:async';

import 'package:logger/logger.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Scraping sonucu.
class ScrapeResult {
  ScrapeResult({
    required this.name,
    required this.price,
    this.imageUrl,
    this.currency = '₺',
  });

  final String name;
  final double? price;
  final String? imageUrl;
  final String currency;

  bool get hasPrice => price != null;

  String get priceLabel {
    if (price == null) return '-';
    final formatted = price!.toStringAsFixed(2);
    return '$currency$formatted';
  }
}

class ProductSearchResult {
  ProductSearchResult({
    required this.platform,
    required this.name,
    required this.url,
    this.price,
    this.imageUrl,
  });

  final String platform;
  final String name;
  final String url;
  final double? price;
  final String? imageUrl;
}

/// Supabase Edge Function üzerinden fiyat çekme servisi.
///
/// Gerçek scraping sunucu tarafında (Edge Function) yapılır; böylece
/// API anahtarları istemcide sızmaz ve anti-bot stratejileri tek noktadan
/// yönetilir. Bu sınıf sadece function'ı çağırır.
class ScrapeService {
  ScrapeService(this._client, {Logger? logger}) : _logger = logger ?? Logger();

  final SupabaseClient _client;
  final Logger _logger;

  Future<ScrapeResult> scrape(String url) async {
    try {
      final response = await _client.functions.invoke(
        'scrape-price',
        body: {'url': url},
      );
      final data = response.data;
      if (data is String) {
        return _fromJson(jsonDecode(data) as Map<String, dynamic>);
      }
      if (data is Map<String, dynamic>) {
        return _fromJson(data);
      }
      throw StateError('Beklenmeyen scraping yanıtı');
    } catch (e) {
      _logger.w('Scrape hatası: $e');
      rethrow;
    }
  }

  Future<List<ProductSearchResult>> search({
    required String query,
    required List<String> platforms,
  }) async {
    final response = await _client.functions.invoke(
      'search-products',
      body: {'query': query, 'platforms': platforms},
    );
    final data = response.data;
    final decoded = data is String
        ? jsonDecode(data) as Map<String, dynamic>
        : data as Map<String, dynamic>;
    var list = decoded['results'] as List? ?? const [];
    final searchId = decoded['search_id'] as String?;
    if (list.isEmpty && searchId != null) {
      var completed = false;
      for (var attempt = 0; attempt < 12; attempt++) {
        await Future<void>.delayed(const Duration(seconds: 5));
        final statusRow = await _client
            .from('product_searches')
            .select('status')
            .eq('id', searchId)
            .maybeSingle();
        final status = statusRow?['status'] as String?;
        if (status == 'failed') {
          throw StateError('Mağaza arama servisi başarısız oldu');
        }
        final rows = await _client
            .from('product_search_results')
            .select()
            .eq('search_id', searchId);
        list = rows as List;
        if (status == 'completed') {
          completed = true;
          break;
        }
      }
      if (!completed) {
        throw TimeoutException(
          'Mağaza araması zaman aşımına uğradı. GitHub worker sonuç döndürmedi.',
        );
      }
    }
    return [
      for (final item in list)
        ProductSearchResult(
          platform: item['platform'] as String,
          name: item['name'] as String,
          url: item['url'] as String,
          price: (item['price'] as num?)?.toDouble(),
          imageUrl: item['image_url'] as String?,
        ),
    ];
  }

  ScrapeResult _fromJson(Map<String, dynamic> map) => ScrapeResult(
    name: (map['name'] as String?)?.trim() ?? '',
    price: (map['price'] as num?)?.toDouble(),
    imageUrl: map['image_url'] as String?,
    currency: (map['currency'] as String?) ?? '₺',
  );
}
