import 'dart:convert';

/// Versioned JSON message protocol between the Flutter app and the Three.js
/// scene in `web3d/`.
///
/// Keep this file in sync with `web3d/src/protocol.ts`. Bump [kProtocolVersion]
/// on every breaking change: the app ignores envelopes from another version
/// rather than guessing at their shape.
const int kProtocolVersion = 1;

/// Name of the JS handler (Android) and of the global inbox in the scene.
const String kChannelName = 'kebunku';

/// A message the app sends to the scene.
sealed class Web3dCommand {
  const Web3dCommand();

  String get type;

  Map<String, Object?> get payload;

  Map<String, Object?> toJson() => {
    'v': kProtocolVersion,
    'type': type,
    ...payload,
  };

  String encode() => jsonEncode(toJson());
}

class SetFloor extends Web3dCommand {
  const SetFloor({required this.width, required this.depth});

  final double width;
  final double depth;

  @override
  String get type => 'setFloor';

  @override
  Map<String, Object?> get payload => {'width': width, 'depth': depth};
}

class AddPot extends Web3dCommand {
  const AddPot({
    required this.id,
    required this.x,
    required this.z,
    this.radius = 0.16,
    this.height = 0.22,
    this.color,
  });

  final String id;
  final double x;
  final double z;
  final double radius;
  final double height;
  final String? color;

  @override
  String get type => 'addPot';

  @override
  Map<String, Object?> get payload => {
    'id': id,
    'x': x,
    'z': z,
    'radius': radius,
    'height': height,
    if (color != null) 'color': color,
  };
}

class RemovePot extends Web3dCommand {
  const RemovePot(this.id);

  final String id;

  @override
  String get type => 'removePot';

  @override
  Map<String, Object?> get payload => {'id': id};
}

class ClearPots extends Web3dCommand {
  const ClearPots();

  @override
  String get type => 'clearPots';

  @override
  Map<String, Object?> get payload => const {};
}

class SetDebugOverlay extends Web3dCommand {
  const SetDebugOverlay({required this.visible});

  final bool visible;

  @override
  String get type => 'setDebugOverlay';

  @override
  Map<String, Object?> get payload => {'visible': visible};
}

class Ping extends Web3dCommand {
  const Ping();

  @override
  String get type => 'ping';

  @override
  Map<String, Object?> get payload => const {};
}

/// A message the scene sends back to the app.
sealed class Web3dEvent {
  const Web3dEvent();
}

class SceneReady extends Web3dEvent {
  const SceneReady({required this.protocol, required this.renderer});

  final int protocol;

  /// The WebGL renderer string, e.g. `ANGLE (Apple, Apple M1 Pro, ...)`.
  /// Useful for telling hardware from software rendering on cheap devices.
  final String renderer;
}

class PotSelected extends Web3dEvent {
  const PotSelected(this.id);

  /// `null` when the selection was cleared by tapping empty space.
  final String? id;
}

class ScenePong extends Web3dEvent {
  const ScenePong();
}

class SceneFps extends Web3dEvent {
  const SceneFps(this.value);

  final int value;
}

class SceneError extends Web3dEvent {
  const SceneError(this.message);

  final String message;
}

/// Parses one envelope coming from the scene.
///
/// Returns `null` for anything that is not a well-formed message of this
/// protocol version — the transports are shared with browser extensions,
/// Flutter web's own `postMessage` traffic and Vite's HMR during development,
/// so unknown traffic has to be dropped silently rather than thrown on.
Web3dEvent? decodeWeb3dEvent(Object? raw) {
  final Object? decoded;
  if (raw is String) {
    try {
      decoded = jsonDecode(raw);
    } on FormatException {
      return null;
    }
  } else {
    decoded = raw;
  }

  if (decoded is! Map) return null;
  if (decoded['v'] != kProtocolVersion) return null;

  return switch (decoded['type']) {
    'ready' => SceneReady(
      protocol: _asInt(decoded['protocol']) ?? kProtocolVersion,
      renderer: decoded['renderer'] as String? ?? 'unknown',
    ),
    'selected' => PotSelected(decoded['id'] as String?),
    'pong' => const ScenePong(),
    'fps' => switch (_asInt(decoded['value'])) {
      final int value => SceneFps(value),
      null => null,
    },
    'error' => SceneError(decoded['message']?.toString() ?? 'unknown error'),
    _ => null,
  };
}

int? _asInt(Object? value) => switch (value) {
  final int value => value,
  final double value => value.round(),
  final String value => int.tryParse(value),
  _ => null,
};
