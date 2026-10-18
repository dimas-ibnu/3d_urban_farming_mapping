import '../model/project.dart';

/// Platforms with no location source in v0.1 — Android for now.
const bool deviceLocationSupported = false;

Future<GeoLocation?> currentDeviceLocation() async => null;
