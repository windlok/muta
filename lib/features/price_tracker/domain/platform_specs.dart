/// Desteklenen fiyat takip platformlarının spec'leri.
///
/// Yeni bir site/firma eklemek istediğinde bu sınıfa bir kayıt ekle.
/// Platform tanıma işlemi [detectPlatform] ile URL üzerinden yapılır.
class PlatformSpec {
  const PlatformSpec({
    required this.name,
    required this.hosts,
    this.exampleUrl = '',
  });

  /// Görünen ad (UI'da gösterilir).
  final String name;

  /// Eşleşecek alan adları (küçük harf, noktasız).
  final List<String> hosts;

  /// Örnek ürün URL'si (kullanıcıya ipucu vermek için).
  final String exampleUrl;

  bool matches(String url) {
    var value = url.trim().toLowerCase();
    if (!value.contains('://')) value = 'https://$value';
    final host = Uri.tryParse(value)?.host ?? '';
    if (host.isEmpty) return false;
    return hosts.any((h) => host == h || host.endsWith('.$h'));
  }
}

/// Bildirilen tüm platformlar. Yeni firma eklemek = listeye kayıt eklemek.
const List<PlatformSpec> kPlatformSpecs = [
  PlatformSpec(
    name: 'Trendyol',
    hosts: ['trendyol.com', 'tycdn.com'],
    exampleUrl: 'https://www.trendyol.com/magaza/.../p-123456',
  ),
  PlatformSpec(
    name: 'n11',
    hosts: ['n11.com'],
    exampleUrl: 'https://www.n11.com/urun/...',
  ),
  PlatformSpec(
    name: 'Hepsiburada',
    hosts: ['hepsiburada.com'],
    exampleUrl: 'https://www.hepsiburada.com/...',
  ),
  PlatformSpec(
    name: 'Amazon',
    hosts: ['amazon.com.tr', 'amazon.com'],
    exampleUrl: 'https://www.amazon.com.tr/dp/...',
  ),
  PlatformSpec(
    name: 'ÇiçekSepeti',
    hosts: ['ciceksepeti.com'],
    exampleUrl: 'https://www.ciceksepeti.com/...',
  ),
];

/// URL'den platform adını tespit eder. Bulunamazsa 'Diğer' döner.
///
/// [extra] kullanıcının ayarlarda eklediği özel sitelerdir; varsayılanlardan
/// önce kontrol edilir.
String detectPlatform(String url, {List<PlatformSpec> extra = const []}) {
  for (final spec in extra) {
    if (spec.matches(url)) return spec.name;
  }
  for (final spec in kPlatformSpecs) {
    if (spec.matches(url)) return spec.name;
  }
  return 'Diğer';
}
