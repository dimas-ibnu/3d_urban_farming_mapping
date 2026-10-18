import 'geometry.dart';

/// What a vertical element along the edge of the space is.
///
/// The distinction matters later for the sun engine (a railing lets light
/// through, a wall does not) and already matters here: wall planters may only
/// be hung on a [BarrierKind.wall].
enum BarrierKind {
  wall,
  railing,
  obstacle;

  static BarrierKind fromName(Object? name) => BarrierKind.values.firstWhere(
    (kind) => kind.name == name,
    orElse: () => BarrierKind.wall,
  );

  /// Whether a wall planter can be mounted on it.
  bool get mountable => this == BarrierKind.wall;
}

/// A wall, railing or obstacle, as a vertical slab over a floor segment.
class Barrier {
  const Barrier({
    required this.id,
    required this.kind,
    required this.start,
    required this.end,
    required this.heightM,
  });

  factory Barrier.fromJson(Map<String, Object?> json) => Barrier(
    id: json['id'] as String? ?? '',
    kind: BarrierKind.fromName(json['kind']),
    start: Vec2.fromJson(_map(json['start'])),
    end: Vec2.fromJson(_map(json['end'])),
    heightM: asDouble(json['heightM']) ?? 1.0,
  );

  final String id;
  final BarrierKind kind;
  final Vec2 start;
  final Vec2 end;
  final double heightM;

  double get lengthM => start.distanceTo(end);

  Barrier copyWith({
    BarrierKind? kind,
    Vec2? start,
    Vec2? end,
    double? heightM,
  }) => Barrier(
    id: id,
    kind: kind ?? this.kind,
    start: start ?? this.start,
    end: end ?? this.end,
    heightM: heightM ?? this.heightM,
  );

  Map<String, Object?> toJson() => {
    'id': id,
    'kind': kind.name,
    'start': start.toJson(),
    'end': end.toJson(),
    'heightM': heightM,
  };
}

/// The space being planned: its floor, its height, where it faces and what
/// stands along its edges.
///
/// The footprint is a simple polygon in metres, ordered around the ring. A
/// plain balcony is the rectangle built by [Space.rectangle]; the grid editor
/// can produce any other simple polygon.
class Space {
  const Space({
    required this.footprint,
    required this.heightM,
    required this.facingDeg,
    this.barriers = const <Barrier>[],
  });

  /// A rectangular balcony, centred on the origin.
  factory Space.rectangle({
    required double widthM,
    required double depthM,
    double heightM = 2.6,
    double facingDeg = 0,
    List<Barrier> barriers = const <Barrier>[],
  }) {
    final halfWidth = widthM / 2;
    final halfDepth = depthM / 2;
    return Space(
      footprint: <Vec2>[
        Vec2(-halfWidth, -halfDepth),
        Vec2(halfWidth, -halfDepth),
        Vec2(halfWidth, halfDepth),
        Vec2(-halfWidth, halfDepth),
      ],
      heightM: heightM,
      facingDeg: facingDeg,
      barriers: barriers,
    );
  }

  factory Space.fromJson(Map<String, Object?> json) => Space(
    footprint: <Vec2>[
      for (final point in json['footprint'] as List? ?? const [])
        Vec2.fromJson(_map(point)),
    ],
    heightM: asDouble(json['heightM']) ?? 2.6,
    facingDeg: asDouble(json['facingDeg']) ?? 0,
    barriers: <Barrier>[
      for (final barrier in json['barriers'] as List? ?? const [])
        Barrier.fromJson(_map(barrier)),
    ],
  );

  /// The floor outline, metres, ordered around the ring.
  final List<Vec2> footprint;

  /// Floor-to-ceiling height. Caps how tall a rack may be.
  final double heightM;

  /// Compass bearing the open side faces: 0 = north, 90 = east.
  final double facingDeg;

  final List<Barrier> barriers;

  double get floorAreaM2 => polygonArea(footprint);

  Bounds2 get bounds => Bounds2.ofPoints(footprint);

  /// The edges of the footprint, as segment pairs.
  Iterable<(Vec2, Vec2)> get edges sync* {
    for (var i = 0; i < footprint.length; i++) {
      yield (footprint[i], footprint[(i + 1) % footprint.length]);
    }
  }

  bool contains(Vec2 point) => polygonContains(footprint, point);

  Barrier? barrierById(String id) {
    for (final barrier in barriers) {
      if (barrier.id == id) return barrier;
    }
    return null;
  }

  /// The mountable barrier nearest to [point], within [maxDistanceM].
  ///
  /// This is what makes a wall planter snap: the editor drags it anywhere and
  /// the model pins it to the closest wall.
  Barrier? nearestMountableBarrier(Vec2 point, {double maxDistanceM = 0.6}) {
    Barrier? best;
    var bestDistance = maxDistanceM;
    for (final barrier in barriers) {
      if (!barrier.kind.mountable) continue;
      final distance = distanceToSegment(point, barrier.start, barrier.end);
      if (distance <= bestDistance) {
        bestDistance = distance;
        best = barrier;
      }
    }
    return best;
  }

  Space copyWith({
    List<Vec2>? footprint,
    double? heightM,
    double? facingDeg,
    List<Barrier>? barriers,
  }) => Space(
    footprint: footprint ?? this.footprint,
    heightM: heightM ?? this.heightM,
    facingDeg: facingDeg ?? this.facingDeg,
    barriers: barriers ?? this.barriers,
  );

  Map<String, Object?> toJson() => {
    'footprint': [for (final point in footprint) point.toJson()],
    'heightM': heightM,
    'facingDeg': facingDeg,
    'barriers': [for (final barrier in barriers) barrier.toJson()],
  };
}

Map<String, Object?> _map(Object? value) =>
    value is Map ? value.cast<String, Object?>() : const <String, Object?>{};
