import 'dart:convert';

import '../model/project.dart';

/// Versioned JSON message protocol between the Flutter app and the Three.js
/// scene in `web3d/`.
///
/// Keep this file in sync with `web3d/src/protocol.ts`, and the table in
/// `README.md` in sync with both. Bump [kProtocolVersion] on every breaking
/// change: each side ignores envelopes from another version rather than
/// guessing at their shape.
///
/// v2 replaces the prototype's pot-only messages with commands that mirror the
/// project model: the app pushes the space and the items, and the scene reports
/// what the user touched or dragged. The app stays the single source of truth —
/// an [ItemMoved] event is a *request*, applied only once the app has validated
/// and echoed it back as [UpsertItem].
const int kProtocolVersion = 2;

/// Name of the JS handler (Android) and of the global inbox in the scene.
const String kChannelName = 'kebunku';

/// Which camera the scene renders with.
enum SceneView {
  /// Top-down, orthographic: the plan view for placing things precisely.
  plan2d,

  /// Orbiting perspective camera.
  orbit3d;

  String get wire => this == SceneView.plan2d ? '2d' : '3d';

  static SceneView fromWire(Object? value) =>
      value == '2d' ? SceneView.plan2d : SceneView.orbit3d;
}

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

/// Replaces the whole space: outline, height, facing direction and barriers.
///
/// The scene rebuilds its floor and walls from this and keeps the items it
/// already has, so a space edit does not cost a full resync.
class SetSpace extends Web3dCommand {
  const SetSpace(this.space);

  final Space space;

  @override
  String get type => 'setSpace';

  @override
  Map<String, Object?> get payload => {'space': space.toJson()};
}

/// Adds an item or replaces the one with the same id.
class UpsertItem extends Web3dCommand {
  const UpsertItem(this.item);

  final PlacedItem item;

  @override
  String get type => 'upsertItem';

  @override
  Map<String, Object?> get payload => {'item': item.toJson()};
}

class RemoveItem extends Web3dCommand {
  const RemoveItem(this.id);

  final String id;

  @override
  String get type => 'removeItem';

  @override
  Map<String, Object?> get payload => {'id': id};
}

/// Drops every item. Sent when a plan is replaced wholesale.
class ClearItems extends Web3dCommand {
  const ClearItems();

  @override
  String get type => 'clearItems';

  @override
  Map<String, Object?> get payload => const {};
}

/// Switches between the 2D plan and the 3D orbit camera.
class SetView extends Web3dCommand {
  const SetView(this.view);

  final SceneView view;

  @override
  String get type => 'setView';

  @override
  Map<String, Object?> get payload => {'mode': view.wire};
}

/// Highlights an item, or clears the highlight with a `null` id.
///
/// Selection is app state like everything else: tapping in the scene only
/// *reports* a [ItemSelected], and the highlight follows this command.
class SetSelection extends Web3dCommand {
  const SetSelection(this.id);

  final String? id;

  @override
  String get type => 'setSelection';

  @override
  Map<String, Object?> get payload => {'id': id};
}

/// Marks items the app considers invalid, so the scene can tint them.
///
/// The scene does its own cheap check while dragging for instant feedback;
/// this is the authoritative answer that arrives right after.
class SetInvalidItems extends Web3dCommand {
  const SetInvalidItems(this.ids);

  final List<String> ids;

  @override
  String get type => 'setInvalidItems';

  @override
  Map<String, Object?> get payload => {'ids': ids};
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

/// The user tapped an item, or empty space to clear the selection.
class ItemSelected extends Web3dEvent {
  const ItemSelected(this.id);

  final String? id;
}

/// The user dragged an item to a new spot.
///
/// A request, not a fact: the app validates it, then either echoes the item
/// back with [UpsertItem] or re-sends the old position to snap it back.
class ItemMoved extends Web3dEvent {
  const ItemMoved({
    required this.id,
    required this.position,
    this.mountHeightM,
  });

  final String id;
  final Vec2 position;

  /// Set when the drag changed how high an elevated item hangs.
  final double? mountHeightM;
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
    'selected' => ItemSelected(decoded['id'] as String?),
    'itemMoved' => _decodeItemMoved(decoded),
    'pong' => const ScenePong(),
    'fps' => switch (_asInt(decoded['value'])) {
      final int value => SceneFps(value),
      null => null,
    },
    'error' => SceneError(decoded['message']?.toString() ?? 'unknown error'),
    _ => null,
  };
}

Web3dEvent? _decodeItemMoved(Map<Object?, Object?> decoded) {
  final id = decoded['id'];
  final position = decoded['position'];
  if (id is! String || position is! Map) return null;
  final x = asDouble(position['x']);
  final z = asDouble(position['z']);
  if (x == null || z == null) return null;
  return ItemMoved(
    id: id,
    position: Vec2(x, z),
    mountHeightM: asDouble(decoded['mountHeightM']),
  );
}

int? _asInt(Object? value) => switch (value) {
  final int value => value,
  final double value => value.round(),
  final String value => int.tryParse(value),
  _ => null,
};
