/// Fiyat bildirim türü.
enum PriceAlertType {
  target('target', 'Hedefe düşünce'),
  drop('drop', 'Her düşüşte'),
  percent('percent', 'Yüzde düşüşte');

  const PriceAlertType(this.value, this.label);

  final String value;
  final String label;

  static PriceAlertType fromValue(String? value) => values.firstWhere(
    (t) => t.value == value,
    orElse: () => PriceAlertType.target,
  );

  String describe(double? percent) => switch (this) {
    PriceAlertType.target => 'Hedefe düşünce',
    PriceAlertType.drop => 'Her düşüşte',
    PriceAlertType.percent => '%${(percent ?? 10).toStringAsFixed(0)} düşüşte',
  };
}

/// Takip edilen bir ürün.
class TrackedProduct {
  TrackedProduct({
    required this.id,
    required this.userId,
    required this.name,
    required this.url,
    required this.platform,
    this.currentPrice,
    this.targetPrice,
    this.imageUrl,
    this.category,
    this.isActive = true,
    this.notifyOnDrop = true,
    this.alertType = PriceAlertType.target,
    this.alertPercent,
    required this.createdAt,
    required this.updatedAt,
  });

  final String id;
  final String userId;
  final String name;
  final String url;
  final String platform;
  final double? currentPrice;
  final double? targetPrice;
  final String? imageUrl;
  final String? category;
  final bool isActive;
  final bool notifyOnDrop;
  final PriceAlertType alertType;
  final double? alertPercent;
  final DateTime createdAt;
  final DateTime updatedAt;

  /// Hedef fiyata ulaşıldı mı? (targetPrice >= currentPrice)
  bool get targetReached =>
      targetPrice != null &&
      currentPrice != null &&
      currentPrice! <= targetPrice!;

  double? get discountPercent {
    if (targetPrice == null || currentPrice == null) return null;
    if (targetPrice == 0) return null;
    final diff = targetPrice! - currentPrice!;
    return (diff / targetPrice!) * 100;
  }

  TrackedProduct copyWith({
    String? name,
    double? currentPrice,
    double? targetPrice,
    bool clearTargetPrice = false,
    String? imageUrl,
    bool clearImage = false,
    String? category,
    bool? isActive,
    bool? notifyOnDrop,
    PriceAlertType? alertType,
    double? alertPercent,
    bool clearAlertPercent = false,
    DateTime? updatedAt,
  }) {
    return TrackedProduct(
      id: id,
      userId: userId,
      name: name ?? this.name,
      url: url,
      platform: platform,
      currentPrice: currentPrice ?? this.currentPrice,
      targetPrice: clearTargetPrice ? null : (targetPrice ?? this.targetPrice),
      imageUrl: clearImage ? null : (imageUrl ?? this.imageUrl),
      category: category ?? this.category,
      isActive: isActive ?? this.isActive,
      notifyOnDrop: notifyOnDrop ?? this.notifyOnDrop,
      alertType: alertType ?? this.alertType,
      alertPercent: clearAlertPercent
          ? null
          : (alertPercent ?? this.alertPercent),
      createdAt: createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  Map<String, dynamic> toInsertMap() => {
    'user_id': userId,
    'name': name,
    'url': url,
    'platform': platform,
    'current_price': currentPrice,
    'target_price': targetPrice,
    'image_url': imageUrl,
    'category': category,
    'is_active': isActive,
    'notify_on_drop': notifyOnDrop,
    'alert_type': alertType.value,
    'alert_percent': alertPercent,
  };

  factory TrackedProduct.fromMap(Map<String, dynamic> map) => TrackedProduct(
    id: map['id'] as String,
    userId: map['user_id'] as String,
    name: map['name'] as String,
    url: map['url'] as String,
    platform: (map['platform'] as String?) ?? 'Diğer',
    currentPrice: (map['current_price'] as num?)?.toDouble(),
    targetPrice: (map['target_price'] as num?)?.toDouble(),
    imageUrl: map['image_url'] as String?,
    category: map['category'] as String?,
    isActive: (map['is_active'] as bool?) ?? true,
    notifyOnDrop: (map['notify_on_drop'] as bool?) ?? true,
    alertType: PriceAlertType.fromValue(map['alert_type'] as String?),
    alertPercent: (map['alert_percent'] as num?)?.toDouble(),
    createdAt: DateTime.parse(map['created_at'] as String).toLocal(),
    updatedAt: DateTime.parse(map['updated_at'] as String).toLocal(),
  );
}

/// Fiyat geçmişi noktası.
class PricePoint {
  PricePoint({
    required this.id,
    required this.productId,
    required this.price,
    required this.recordedAt,
  });

  final String id;
  final String productId;
  final double price;
  final DateTime recordedAt;

  factory PricePoint.fromMap(Map<String, dynamic> map) => PricePoint(
    id: map['id'] as String,
    productId: map['product_id'] as String,
    price: (map['price'] as num).toDouble(),
    recordedAt: DateTime.parse(map['recorded_at'] as String).toLocal(),
  );
}

/// Aynı ürünün farklı mağazalardaki teklifi.
class ProductOffer {
  ProductOffer({
    required this.id,
    required this.productId,
    required this.platform,
    required this.url,
    this.price,
    required this.checkedAt,
  });

  final String id;
  final String productId;
  final String platform;
  final String url;
  final double? price;
  final DateTime checkedAt;

  factory ProductOffer.fromMap(Map<String, dynamic> map) => ProductOffer(
    id: map['id'] as String,
    productId: map['product_id'] as String,
    platform: map['platform'] as String,
    url: map['url'] as String,
    price: (map['price'] as num?)?.toDouble(),
    checkedAt: DateTime.parse(map['checked_at'] as String).toLocal(),
  );
}

/// Ürünün yorum analizi özeti (AI ile doldurulur).
class ReviewSummary {
  ReviewSummary({
    required this.productId,
    required this.pros,
    required this.cons,
    this.rating,
    required this.analyzedAt,
  });

  final String productId;
  final List<String> pros;
  final List<String> cons;
  final double? rating;
  final DateTime analyzedAt;

  factory ReviewSummary.fromMap(Map<String, dynamic> map) => ReviewSummary(
    productId: map['product_id'] as String,
    pros: ((map['pros'] as List?) ?? const []).cast<String>(),
    cons: ((map['cons'] as List?) ?? const []).cast<String>(),
    rating: (map['rating'] as num?)?.toDouble(),
    analyzedAt: DateTime.parse(map['analyzed_at'] as String).toLocal(),
  );
}
