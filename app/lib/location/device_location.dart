import '../model/project.dart';

import 'device_location_stub.dart'
    if (dart.library.js_interop) 'device_location_web.dart'
    as impl;

/// Reads the device's position where the platform offers one.
///
/// On Flutter web that is the browser's geolocation API, behind the permission
/// prompt. On Android v0.1 there is no location plugin yet — the city picker
/// covers it — so [supported] is false there and the UI hides the button.
abstract final class DeviceLocation {
  /// Whether this build can ask the platform at all.
  static bool get supported => impl.deviceLocationSupported;

  /// Asks for the current position.
  ///
  /// Returns `null` when the user refuses, the platform has no fix, or the
  /// request times out. Callers fall back to the city picker.
  static Future<GeoLocation?> current() => impl.currentDeviceLocation();
}
