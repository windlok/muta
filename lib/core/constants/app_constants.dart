/// Uygulama genelinde kullanılan sabitler.
class AppConstants {
  AppConstants._();

  static const String appName = 'Muta';

  /// Desteklenen fiyat takip platformları.
  /// Yeni firmalar eklenirken bu listeye ve
  /// `lib/features/price_tracker/domain/platform_specs.dart` dosyasına ekle.
  static const List<String> supportedPlatforms = [
    'Trendyol',
    'n11',
    'Hepsiburada',
    'Amazon',
    'ÇiçekSepeti',
    'Diğer',
  ];

  /// Fiyat geçmişi grafiğinde gösterilecek maksimum nokta sayısı.
  static const int maxPriceHistoryPoints = 60;

  /// AI görev öncelik skalası (1 = düşük, 5 = çok yüksek).
  static const int minPriority = 1;
  static const int maxPriority = 5;
}
