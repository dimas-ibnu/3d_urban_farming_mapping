import 'geometry.dart';

/// Where the space is, for the sun calculations that come later.
class GeoLocation {
  const GeoLocation({
    required this.latitude,
    required this.longitude,
    this.label,
  });

  factory GeoLocation.fromJson(Map<String, Object?> json) => GeoLocation(
    latitude: asDouble(json['latitude']) ?? 0,
    longitude: asDouble(json['longitude']) ?? 0,
    label: json['label'] as String?,
  );

  final double latitude;
  final double longitude;

  /// A city name when the user picked one, `null` for a device fix.
  final String? label;

  Map<String, Object?> toJson() => {
    'latitude': latitude,
    'longitude': longitude,
    if (label != null) 'label': label,
  };

  @override
  bool operator ==(Object other) =>
      other is GeoLocation &&
      other.latitude == latitude &&
      other.longitude == longitude &&
      other.label == label;

  @override
  int get hashCode => Object.hash(latitude, longitude, label);
}

/// The city shortlist behind the picker.
///
/// Indonesia first (see `docs/APP_GOAL.md`); enough to cover the v0.1 audience
/// without a geocoding service, and a stand-in until one exists.
const List<GeoLocation> kIndonesianCities = <GeoLocation>[
  GeoLocation(latitude: -6.2088, longitude: 106.8456, label: 'Jakarta'),
  GeoLocation(latitude: -6.9175, longitude: 107.6191, label: 'Bandung'),
  GeoLocation(latitude: -7.2575, longitude: 112.7521, label: 'Surabaya'),
  GeoLocation(latitude: -7.7956, longitude: 110.3695, label: 'Yogyakarta'),
  GeoLocation(latitude: -6.9667, longitude: 110.4167, label: 'Semarang'),
  GeoLocation(latitude: 3.5952, longitude: 98.6722, label: 'Medan'),
  GeoLocation(latitude: -5.1477, longitude: 119.4327, label: 'Makassar'),
  GeoLocation(latitude: -8.6500, longitude: 115.2167, label: 'Denpasar'),
  GeoLocation(latitude: -2.9761, longitude: 104.7754, label: 'Palembang'),
  GeoLocation(latitude: -1.2379, longitude: 116.8529, label: 'Balikpapan'),
];
