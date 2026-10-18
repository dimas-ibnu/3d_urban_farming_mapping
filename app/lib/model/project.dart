import 'dart:convert';

import 'geometry.dart';
import 'growing_area.dart';
import 'item.dart';
import 'location.dart';
import 'space.dart';

export 'geometry.dart';
export 'growing_area.dart';
export 'item.dart';
export 'layout_rules.dart';
export 'location.dart';
export 'space.dart';

/// Version of the JSON this file writes.
///
/// The storage ticket persists exactly [Project.toJson], so every change to the
/// shape of that map bumps this and gains a migration in [Project.fromJson].
const int kProjectSchemaVersion = 1;

/// One plan: a space, where it is, and what the user put in it.
///
/// This is the single source of truth of the whole app. The Three.js scene
/// renders a copy of it and reports back what the user dragged; it never keeps
/// state of its own (see `docs/APP_GOAL.md`, "Responsibilities").
class Project {
  const Project({
    required this.name,
    required this.space,
    this.items = const <PlacedItem>[],
    this.location,
    this.schemaVersion = kProjectSchemaVersion,
  });

  /// A fresh, empty plan: a 2 × 1.2 m balcony with a railing on its open side.
  factory Project.empty({String name = 'Balkon'}) {
    const widthM = 2.0;
    const depthM = 1.2;
    return Project(
      name: name,
      space: Space.rectangle(
        widthM: widthM,
        depthM: depthM,
        barriers: <Barrier>[
          const Barrier(
            id: 'barrier-rail',
            kind: BarrierKind.railing,
            start: Vec2(-widthM / 2, depthM / 2),
            end: Vec2(widthM / 2, depthM / 2),
            heightM: 1.1,
          ),
          const Barrier(
            id: 'barrier-wall',
            kind: BarrierKind.wall,
            start: Vec2(-widthM / 2, -depthM / 2),
            end: Vec2(widthM / 2, -depthM / 2),
            heightM: 2.6,
          ),
        ],
      ),
    );
  }

  /// Reads a plan back. Unknown or missing fields fall back to the defaults
  /// rather than throwing: a plan half-written by an older build still opens.
  factory Project.fromJson(Map<String, Object?> json) => Project(
    schemaVersion: switch (asDouble(json['schemaVersion'])) {
      final double version => version.round(),
      null => kProjectSchemaVersion,
    },
    name: json['name'] as String? ?? 'Kebunku',
    space: Space.fromJson(
      json['space'] is Map
          ? (json['space']! as Map).cast<String, Object?>()
          : const <String, Object?>{},
    ),
    items: <PlacedItem>[
      for (final item in json['items'] as List? ?? const [])
        if (item is Map) PlacedItem.fromJson(item.cast<String, Object?>()),
    ],
    location: json['location'] is Map
        ? GeoLocation.fromJson(
            (json['location']! as Map).cast<String, Object?>(),
          )
        : null,
  );

  static Project decode(String source) =>
      Project.fromJson(jsonDecode(source) as Map<String, Object?>);

  final int schemaVersion;
  final String name;
  final Space space;
  final List<PlacedItem> items;
  final GeoLocation? location;

  GrowingAreaSummary get growingArea => GrowingAreaSummary.of(space, items);

  PlacedItem? itemById(String id) {
    for (final item in items) {
      if (item.id == id) return item;
    }
    return null;
  }

  /// Adds [item], or replaces the one that already has its id.
  Project upsertItem(PlacedItem item) {
    final next = List<PlacedItem>.of(items);
    final index = next.indexWhere((candidate) => candidate.id == item.id);
    if (index < 0) {
      next.add(item);
    } else {
      next[index] = item;
    }
    return copyWith(items: next);
  }

  Project removeItem(String id) =>
      copyWith(items: items.where((item) => item.id != id).toList());

  Project copyWith({
    String? name,
    Space? space,
    List<PlacedItem>? items,
    GeoLocation? location,
    bool clearLocation = false,
  }) => Project(
    schemaVersion: schemaVersion,
    name: name ?? this.name,
    space: space ?? this.space,
    items: items ?? this.items,
    location: clearLocation ? null : (location ?? this.location),
  );

  Map<String, Object?> toJson() => {
    'schemaVersion': schemaVersion,
    'name': name,
    'space': space.toJson(),
    'items': [for (final item in items) item.toJson()],
    if (location != null) 'location': location!.toJson(),
  };

  String encode() => jsonEncode(toJson());
}
