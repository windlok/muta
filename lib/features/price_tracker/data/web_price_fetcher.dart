import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';

import '../../../core/localization/app_localizations.dart';
import '../../../core/network/scrape_service.dart';

/// Telefonun kendi internetiyle (gizli WebView) fiyat okur.
///
/// Bot korumalı siteler (örn. Trendyol) için kullanılır: sayfa gerçek bir
/// tarayıcı motorunda açıldığı için engellenmez ve ürün bilgileri sayfadan
/// (JSON-LD + DOM) çıkarılır.
class WebPriceFetcher {
  WebPriceFetcher._();

  /// [url] sayfasını açıp fiyat/ürün bilgisini okur.
  /// Okunamazsa hata fırlatır.
  static Future<ScrapeResult> fetch(BuildContext context, String url) async {
    final l = AppLocalizations.of(context);
    final result = await showDialog<ScrapeResult>(
      context: context,
      barrierDismissible: false,
      builder: (_) =>
          _WebPriceDialog(url: url, fallbackName: l.productFallbackName),
    );
    if (result == null) {
      throw StateError(l.priceReadFailed);
    }
    return result;
  }
}

class _WebPriceDialog extends StatefulWidget {
  const _WebPriceDialog({required this.url, required this.fallbackName});

  final String url;
  final String fallbackName;

  @override
  State<_WebPriceDialog> createState() => _WebPriceDialogState();
}

class _WebPriceDialogState extends State<_WebPriceDialog> {
  late final WebViewController _controller;
  Timer? _retryTimer;
  Timer? _timeoutTimer;
  int _attempts = 0;
  bool _done = false;
  String _status = '';

  static const int _maxAttempts = 4;

  @override
  void initState() {
    super.initState();
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(const Color(0x00000000))
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageFinished: (_) => _scheduleExtract(),
          onWebResourceError: (error) {
            if (error.isForMainFrame ?? false) {
              _fail();
            }
          },
        ),
      );

    final uri = Uri.tryParse(widget.url);
    if (uri != null && uri.host.isNotEmpty) {
      _controller.loadRequest(uri);
      _timeoutTimer = Timer(const Duration(seconds: 45), _fail);
    } else {
      _done = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) Navigator.of(context).pop();
      });
    }
  }

  @override
  void dispose() {
    _retryTimer?.cancel();
    _timeoutTimer?.cancel();
    super.dispose();
  }

  void _scheduleExtract() {
    _retryTimer?.cancel();
    _retryTimer = Timer(const Duration(milliseconds: 2500), _extract);
  }

  Future<void> _extract() async {
    if (_done) return;
    _attempts++;
    if (mounted) {
      final l = AppLocalizations.of(context);
      setState(() => _status = l.priceReadingProgress(_attempts, _maxAttempts));
    }
    ScrapeResult? result;
    try {
      final raw = await _controller.runJavaScriptReturningResult(_js);
      result = _parse(raw, widget.fallbackName);
    } catch (_) {
      result = null;
    }
    if (_done) return;

    if (result != null && result.price != null) {
      _finish(result);
      return;
    }
    if (_attempts >= _maxAttempts) {
      if (result != null && result.name.isNotEmpty) {
        _finish(result);
      } else {
        _fail();
      }
      return;
    }
    _retryTimer = Timer(const Duration(milliseconds: 2200), _extract);
  }

  void _finish(ScrapeResult result) {
    if (_done) return;
    _done = true;
    Navigator.of(context).pop(result);
  }

  void _fail() {
    if (_done) return;
    _done = true;
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final scheme = Theme.of(context).colorScheme;
    return PopScope(
      canPop: false,
      child: AlertDialog(
        title: Text(l.readingPriceTitle),
        contentPadding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
        content: SizedBox(
          width: 320,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  const SizedBox(
                    height: 18,
                    width: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      _status.isEmpty ? l.pageOpening : _status,
                      style: TextStyle(
                        fontSize: 13,
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: SizedBox(
                  height: 170,
                  child: WebViewWidget(controller: _controller),
                ),
              ),
              const SizedBox(height: 10),
              Text(
                l.webViewExplanation,
                style: TextStyle(fontSize: 11, color: scheme.onSurfaceVariant),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () {
              _done = true;
              Navigator.of(context).pop();
            },
            child: Text(l.cancel),
          ),
        ],
      ),
    );
  }
}

/// Sayfadan ürün verilerini toplayan JS. JSON string döner.
const String _js = r'''
(function () {
  function text(el) { return el && el.textContent ? el.textContent.trim() : ''; }
  var out = { url: location.href, title: '', ogTitle: '', image: '', ld: [], prices: [] };
  var h1 = document.querySelector('h1');
  out.title = h1 ? text(h1) : (document.title || '');
  var ogt = document.querySelector('meta[property="og:title"]');
  if (ogt && ogt.content) out.ogTitle = ogt.content;
  var ogi = document.querySelector('meta[property="og:image"]');
  if (ogi && ogi.content) out.image = ogi.content;
  var s = document.querySelectorAll('script[type="application/ld+json"]');
  for (var i = 0; i < s.length && i < 12; i++) {
    try { out.ld.push(s[i].textContent || ''); } catch (e) {}
  }
  var nodes = document.querySelectorAll(
    '[itemprop="price"], [data-testid*="price"], [class*="price"], [class*="fiyat"], .prc-dsc, .prc-slg'
  );
  for (var j = 0; j < nodes.length && out.prices.length < 80; j++) {
    var t = text(nodes[j]);
    if (t && t.length <= 60) out.prices.push(t);
  }
  return JSON.stringify(out);
})();
''';

/// JS çıktısını [ScrapeResult]'a dönüştürür.
ScrapeResult? _parse(Object? value, String fallbackName) {
  var text = value is String ? value : value.toString();
  if (text.length >= 2 && text.startsWith('"') && text.endsWith('"')) {
    try {
      text = jsonDecode(text) as String;
    } catch (_) {}
  }
  Map<String, dynamic> data;
  try {
    data = jsonDecode(text) as Map<String, dynamic>;
  } catch (_) {
    return null;
  }

  final ldList = (data['ld'] as List?)?.cast<String>() ?? const <String>[];
  var name = '';
  String? image;
  double? price;

  for (final raw in ldList) {
    try {
      final node = jsonDecode(raw);
      final product = _findProduct(node);
      if (product == null) continue;
      if (name.isEmpty) name = (product['name'] as String? ?? '').trim();
      image ??= _imageOf(product);
      final offers = product['offers'];
      if (offers != null) price ??= _priceOf(offers);
      price ??= _ldPrice(product['price']);
    } catch (_) {}
  }

  if (name.isEmpty) {
    name = (data['ogTitle'] as String? ?? '').trim();
    if (name.isEmpty) name = (data['title'] as String? ?? '').trim();
  }
  if (image == null || image.isEmpty) {
    final ogi = (data['image'] as String? ?? '').trim();
    if (ogi.isNotEmpty) image = ogi;
  }
  if (price == null) {
    final candidates = (data['prices'] as List?)?.cast<String>() ?? const [];
    price = _priceFromCandidates(candidates);
  }

  if (name.isEmpty && price == null) return null;
  return ScrapeResult(
    name: name.isEmpty ? fallbackName : name,
    price: price,
    imageUrl: image,
  );
}

Map<String, dynamic>? _findProduct(dynamic node) {
  if (node is List) {
    for (final n in node) {
      final p = _findProduct(n);
      if (p != null) return p;
    }
    return null;
  }
  if (node is! Map) return null;
  final map = Map<String, dynamic>.from(node);
  final type = map['@type'];
  final isProduct =
      type == 'Product' || (type is List && type.contains('Product'));
  if (isProduct) return map;
  final graph = map['@graph'];
  if (graph != null) return _findProduct(graph);
  return null;
}

double? _priceOf(dynamic offers) {
  if (offers is List) {
    for (final o in offers) {
      final p = _priceOf(o);
      if (p != null) return p;
    }
    return null;
  }
  if (offers is Map) {
    final p = _ldPrice(offers['price']) ?? _ldPrice(offers['lowPrice']);
    if (p != null) return p;
    final nested = offers['offers'];
    if (nested != null) return _priceOf(nested);
  }
  return null;
}

String? _imageOf(Map<String, dynamic> product) {
  final img = product['image'];
  if (img is String && img.isNotEmpty) return img;
  if (img is List && img.isNotEmpty) {
    final first = img.first;
    if (first is String) return first;
    if (first is Map && first['url'] is String) return first['url'] as String;
  }
  if (img is Map && img['url'] is String) return img['url'] as String;
  return null;
}

/// JSON-LD fiyatı (genelde nokta ondalıklı: "274.90" ya da 274.9).
double? _ldPrice(dynamic value) {
  if (value is num) return value > 0 ? value.toDouble() : null;
  if (value is String) {
    var s = value
        .replaceAll('₺', '')
        .replaceAll('TL', '')
        .replaceAll('TRY', '')
        .trim();
    if (s.contains(',')) {
      s = s.replaceAll('.', '').replaceAll(',', '.');
    }
    final d = double.tryParse(s);
    if (d != null && d > 0) return d;
  }
  return null;
}

/// DOM metin adaylarından en sık geçen Türkçe biçimli fiyatı seçer.
double? _priceFromCandidates(List<String> candidates) {
  final counts = <double, int>{};
  for (final c in candidates) {
    final v = _parseTurkishPrice(c);
    if (v == null) continue;
    counts[v] = (counts[v] ?? 0) + 1;
  }
  if (counts.isEmpty) return null;
  var best = counts.entries.first;
  for (final e in counts.entries) {
    if (e.value > best.value) best = e;
  }
  return best.key;
}

/// "12.345,67 TL" / "1.299 TL" / "274,90" -> double
double? _parseTurkishPrice(String input) {
  final match = RegExp(r'(\d{1,3}(?:\.\d{3})+(?:,\d{1,2})?|\d+(?:,\d{1,2})?)')
      .firstMatch(input);
  if (match == null) return null;
  var s = match.group(1)!;
  if (s.contains(',')) {
    s = s.replaceAll('.', '').replaceAll(',', '.');
  } else {
    s = s.replaceAll('.', '');
  }
  final v = double.tryParse(s);
  if (v == null || v <= 0 || v > 10000000) return null;
  return v;
}
