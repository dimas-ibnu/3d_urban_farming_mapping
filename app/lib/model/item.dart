import 'geometry.dart';

/// The four things a user can put in their space.
enum ItemType {
  /// A single pot on the floor.
  pot,

  /// A free-standing shelf unit; [PlacedItem.levels] shelves of growing area.
  verticalRack,

  /// A planter hung from the ceiling or a railing, above the floor.
  hangingPlanter,

  /// A planter fixed to a wall at a given height.
  wallPlanter;

  static ItemType fromName(Object? name) => ItemType.values.firstWhere(
    (type) => type.name == name,
    orElse: () => ItemType.pot,
  );

  /// Whether the item rests on the floor and so competes for floor space.
  bool get occupiesFloor =>
      this == ItemType.pot || this == ItemType.verticalRack;

  /// Whether the item hangs off a wall and snaps to one.
  bool get mountsOnWall => this == ItemType.wallPlanter;

  /// Whether the item hangs in the air at [PlacedItem.mountHeightM].
  bool get isElevated =>
      this == ItemType.hangingPlanter || this == ItemType.wallPlanter;
}

/// The footprint and height of an item, in metres.
class ItemSize {
  const ItemSize({
    required this.widthM,
    required this.depthM,
    required this.heightM,
  });

  factory ItemSize.fromJson(Map<String, Object?> json) => ItemSize(
    widthM: asDouble(json['widthM']) ?? 0.3,
    depthM: asDouble(json['depthM']) ?? 0.3,
    heightM: asDouble(json['heightM']) ?? 0.3,
  );

  final double widthM;
  final double depthM;
  final double heightM;

  double get footprintM2 => widthM * depthM;

  ItemSize copyWith({double? widthM, double? depthM, double? heightM}) =>
      ItemSize(
        widthM: widthM ?? this.widthM,
        depthM: depthM ?? this.depthM,
        heightM: heightM ?? this.heightM,
      );

  Map<String, Object?> toJson() => {
    'widthM': widthM,
    'depthM': depthM,
    'heightM': heightM,
  };

  @override
  bool operator ==(Object other) =>
      other is ItemSize &&
      other.widthM == widthM &&
      other.depthM == depthM &&
      other.heightM == heightM;

  @override
  int get hashCode => Object.hash(widthM, depthM, heightM);
}

/// One pot, rack or planter placed in the space.
class PlacedItem {
  const PlacedItem({
    required this.id,
    required this.type,
    required this.position,
    required this.size,
    this.levels = 1,
    this.rotationDeg = 0,
    this.mountHeightM = 0,
    this.barrierId,
  });

  /// An item of [type] at [position], with this project's default dimensions.
  factory PlacedItem.defaults({
    required String id,
    required ItemType type,
    Vec2 position = const Vec2(0, 0),
  }) => PlacedItem(
    id: id,
    type: type,
    position: position,
    size: defaultSizeFor(type),
    levels: defaultLevelsFor(type),
    mountHeightM: defaultMountHeightFor(type),
  );

  factory PlacedItem.fromJson(Map<String, Object?> json) => PlacedItem(
    id: json['id'] as String? ?? '',
    type: ItemType.fromName(json['type']),
    position: Vec2.fromJson(
      json['position'] is Map
          ? (json['position']! as Map).cast<String, Object?>()
          : const <String, Object?>{},
    ),
    size: ItemSize.fromJson(
      json['size'] is Map
          ? (json['size']! as Map).cast<String, Object?>()
          : const <String, Object?>{},
    ),
    levels: switch (asDouble(json['levels'])) {
      final double levels => levels.round(),
      null => 1,
    },
    rotationDeg: asDouble(json['rotationDeg']) ?? 0,
    mountHeightM: asDouble(json['mountHeightM']) ?? 0,
    barrierId: json['barrierId'] as String?,
  );

  static ItemSize defaultSizeFor(ItemType type) => switch (type) {
    ItemType.pot => const ItemSize(widthM: 0.3, depthM: 0.3, heightM: 0.3),
    ItemType.verticalRack => const ItemSize(
      widthM: 0.8,
      depthM: 0.4,
      heightM: 1.6,
    ),
    ItemType.hangingPlanter => const ItemSize(
      widthM: 0.3,
      depthM: 0.3,
      heightM: 0.25,
    ),
    ItemType.wallPlanter => const ItemSize(
      widthM: 0.6,
      depthM: 0.2,
      heightM: 0.22,
    ),
  };

  static int defaultLevelsFor(ItemType type) =>
      type == ItemType.verticalRack ? 4 : 1;

  static double defaultMountHeightFor(ItemType type) => switch (type) {
    ItemType.hangingPlanter => 1.8,
    ItemType.wallPlanter => 1.2,
    _ => 0,
  };

  final String id;
  final ItemType type;

  /// Centre of the item's footprint, in metres.
  final Vec2 position;

  final ItemSize size;

  /// Shelves of growing area; only a rack has more than one.
  final int levels;

  /// Rotation around the vertical axis, degrees clockwise seen from above.
  final double rotationDeg;

  /// Height of the item's base above the floor. Zero for floor items.
  final double mountHeightM;

  /// The wall a wall planter is mounted on, once it has snapped to one.
  final String? barrierId;

  /// Growing area in m²: every shelf of a rack counts, everything else once.
  double get growingAreaM2 => size.footprintM2 * (levels < 1 ? 1 : levels);

  /// Highest point of the item above the floor.
  double get topHeightM => mountHeightM + size.heightM;

  /// The item's footprint on the floor plane, rotated into place.
  List<Vec2> get footprint =>
      rectangleCorners(position, size.widthM, size.depthM, rotationDeg);

  PlacedItem copyWith({
    Vec2? position,
    ItemSize? size,
    int? levels,
    double? rotationDeg,
    double? mountHeightM,
    String? barrierId,
    bool clearBarrier = false,
  }) => PlacedItem(
    id: id,
    type: type,
    position: position ?? this.position,
    size: size ?? this.size,
    levels: levels ?? this.levels,
    rotationDeg: rotationDeg ?? this.rotationDeg,
    mountHeightM: mountHeightM ?? this.mountHeightM,
    barrierId: clearBarrier ? null : (barrierId ?? this.barrierId),
  );

  Map<String, Object?> toJson() => {
    'id': id,
    'type': type.name,
    'position': position.toJson(),
    'size': size.toJson(),
    'levels': levels,
    'rotationDeg': rotationDeg,
    'mountHeightM': mountHeightM,
    if (barrierId != null) 'barrierId': barrierId,
  };
}
