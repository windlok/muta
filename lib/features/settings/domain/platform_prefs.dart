import '../../price_tracker/domain/platform_specs.dart';

/// Kullanıcının eklediği özel site (firma).
class CustomPlatform {
  const CustomPlatform({required this.name, required this.domain});

  final String name;
  final String domain;

  PlatformSpec toSpec() => PlatformSpec(name: name, hosts: [domain]);

  Map<String, dynamic> toJson() => {'name': name, 'domain': domain};

  factory CustomPlatform.fromJson(Map<String, dynamic> json) => CustomPlatform(
        name: json['name'] as String? ?? '',
        domain: json['domain'] as String? ?? '',
      );
}

/// Platform tercihleri: kapatılan varsayılan siteler + kullanıcı siteleri.
class PlatformPrefs {
  const PlatformPrefs({
    this.disabled = const <String>{},
    this.custom = const <CustomPlatform>[],
  });

  final Set<String> disabled;
  final List<CustomPlatform> custom;

  bool isEnabled(String name) => !disabled.contains(name);

  List<PlatformSpec> get extraSpecs => [for (final c in custom) c.toSpec()];

  /// Ayarlarda açık olan varsayılanlar + kullanıcının eklediği siteler.
  List<PlatformSpec> get activePlatforms => [
        for (final spec in kPlatformSpecs)
          if (isEnabled(spec.name)) spec,
        ...extraSpecs,
      ];

  PlatformPrefs copyWith({
    Set<String>? disabled,
    List<CustomPlatform>? custom,
  }) =>
      PlatformPrefs(
        disabled: disabled ?? this.disabled,
        custom: custom ?? this.custom,
      );

  Map<String, dynamic> toJson() => {
        'disabled': disabled.toList(),
        'custom': [for (final c in custom) c.toJson()],
      };

  factory PlatformPrefs.fromJson(Map<String, dynamic> json) => PlatformPrefs(
        disabled: {
          for (final e in (json['disabled'] as List? ?? const []))
            e.toString(),
        },
        custom: [
          for (final e in (json['custom'] as List? ?? const []))
            CustomPlatform.fromJson(Map<String, dynamic>.from(e as Map)),
        ],
      );
}

/// "https://www.pazarama.com/urun/..." -> "pazarama.com"
String normalizeDomain(String input) {
  var s = input.trim().toLowerCase();
  s = s.replaceFirst(RegExp(r'^[a-z]+://'), '');
  s = s.split('/').first;
  s = s.replaceFirst(RegExp(r'^www\.'), '');
  return s;
}
