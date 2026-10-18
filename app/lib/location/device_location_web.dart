import 'dart:async';
import 'dart:js_interop';

import 'package:web/web.dart' as web;

import '../model/project.dart';

/// Browser geolocation, the web's answer to the phone's GPS.
const bool deviceLocationSupported = true;

/// How long to wait before giving up and letting the user pick a city.
const Duration _timeout = Duration(seconds: 10);

Future<GeoLocation?> currentDeviceLocation() {
  final completer = Completer<GeoLocation?>();

  void finish(GeoLocation? location) {
    if (!completer.isCompleted) completer.complete(location);
  }

  web.window.navigator.geolocation.getCurrentPosition(
    ((web.GeolocationPosition position) {
      finish(
        GeoLocation(
          latitude: position.coords.latitude,
          longitude: position.coords.longitude,
        ),
      );
    }).toJS,
    // Denied, unavailable, or timed out: all the same to the caller.
    ((web.GeolocationPositionError _) => finish(null)).toJS,
    web.PositionOptions(timeout: _timeout.inMilliseconds),
  );

  return completer.future.timeout(_timeout, onTimeout: () => null);
}
