import 'dart:math' as math;

/// A point on the floor plane, in metres.
///
/// The whole model uses one coordinate system, shared with the Three.js scene:
/// `x` runs right, `z` runs towards the viewer, `y` (height) is only ever a
/// scalar on the objects that need it. Three.js is right-handed with `y` up, so
/// an (x, z) pair here maps straight onto a scene position without conversion.
class Vec2 {
  const Vec2(this.x, this.z);

  factory Vec2.fromJson(Map<String, Object?> json) =>
      Vec2(asDouble(json['x']) ?? 0, asDouble(json['z']) ?? 0);

  final double x;
  final double z;

  Vec2 operator +(Vec2 other) => Vec2(x + other.x, z + other.z);
  Vec2 operator -(Vec2 other) => Vec2(x - other.x, z - other.z);
  Vec2 operator *(double factor) => Vec2(x * factor, z * factor);

  double get length => math.sqrt(x * x + z * z);

  double distanceTo(Vec2 other) => (this - other).length;

  /// Rotates around the origin by [degrees], clockwise seen from above.
  Vec2 rotated(double degrees) {
    final radians = degrees * math.pi / 180;
    final cos = math.cos(radians);
    final sin = math.sin(radians);
    return Vec2(x * cos + z * sin, -x * sin + z * cos);
  }

  Map<String, Object?> toJson() => {'x': x, 'z': z};

  @override
  bool operator ==(Object other) =>
      other is Vec2 && other.x == x && other.z == z;

  @override
  int get hashCode => Object.hash(x, z);

  @override
  String toString() => 'Vec2(${x.toStringAsFixed(3)}, ${z.toStringAsFixed(3)})';
}

/// An axis-aligned bounding box on the floor plane.
class Bounds2 {
  const Bounds2(this.min, this.max);

  factory Bounds2.ofPoints(Iterable<Vec2> points) {
    if (points.isEmpty) return const Bounds2(Vec2(0, 0), Vec2(0, 0));
    var minX = double.infinity;
    var minZ = double.infinity;
    var maxX = double.negativeInfinity;
    var maxZ = double.negativeInfinity;
    for (final point in points) {
      minX = math.min(minX, point.x);
      minZ = math.min(minZ, point.z);
      maxX = math.max(maxX, point.x);
      maxZ = math.max(maxZ, point.z);
    }
    return Bounds2(Vec2(minX, minZ), Vec2(maxX, maxZ));
  }

  final Vec2 min;
  final Vec2 max;

  double get width => max.x - min.x;
  double get depth => max.z - min.z;
  Vec2 get centre => Vec2((min.x + max.x) / 2, (min.z + max.z) / 2);

  bool overlaps(Bounds2 other) =>
      min.x < other.max.x &&
      max.x > other.min.x &&
      min.z < other.max.z &&
      max.z > other.min.z;
}

/// Signed area of a polygon (shoelace). Positive when the ring is clockwise in
/// this coordinate system; [polygonArea] is what callers normally want.
double signedPolygonArea(List<Vec2> ring) {
  if (ring.length < 3) return 0;
  var sum = 0.0;
  for (var i = 0; i < ring.length; i++) {
    final a = ring[i];
    final b = ring[(i + 1) % ring.length];
    sum += a.x * b.z - b.x * a.z;
  }
  return sum / 2;
}

/// Area of a simple polygon in square metres.
double polygonArea(List<Vec2> ring) => signedPolygonArea(ring).abs();

/// Whether [point] lies inside [ring] (crossing-number test).
///
/// Points exactly on an edge are reported as inside, which is what the fit
/// check wants: a pot pushed flush against the balcony wall still fits.
bool polygonContains(List<Vec2> ring, Vec2 point, {double epsilon = 1e-9}) {
  if (ring.length < 3) return false;
  var inside = false;
  for (var i = 0, j = ring.length - 1; i < ring.length; j = i++) {
    final a = ring[i];
    final b = ring[j];
    if (distanceToSegment(point, a, b) <= epsilon) return true;
    final intersects =
        (a.z > point.z) != (b.z > point.z) &&
        point.x < (b.x - a.x) * (point.z - a.z) / (b.z - a.z) + a.x;
    if (intersects) inside = !inside;
  }
  return inside;
}

/// Shortest distance from [point] to the segment [a]–[b].
double distanceToSegment(Vec2 point, Vec2 a, Vec2 b) =>
    point.distanceTo(closestPointOnSegment(point, a, b));

/// The point on segment [a]–[b] closest to [point].
Vec2 closestPointOnSegment(Vec2 point, Vec2 a, Vec2 b) {
  final ab = b - a;
  final lengthSquared = ab.x * ab.x + ab.z * ab.z;
  if (lengthSquared == 0) return a;
  final t = (((point - a).x * ab.x) + ((point - a).z * ab.z)) / lengthSquared;
  final clamped = t.clamp(0.0, 1.0);
  return a + ab * clamped;
}

/// The four corners of a rectangle of [width] × [depth] centred on [centre] and
/// turned [rotationDeg] degrees clockwise.
List<Vec2> rectangleCorners(
  Vec2 centre,
  double width,
  double depth,
  double rotationDeg,
) {
  final halfWidth = width / 2;
  final halfDepth = depth / 2;
  return <Vec2>[
    Vec2(-halfWidth, -halfDepth),
    Vec2(halfWidth, -halfDepth),
    Vec2(halfWidth, halfDepth),
    Vec2(-halfWidth, halfDepth),
  ].map((corner) => centre + corner.rotated(rotationDeg)).toList();
}

/// Whether two convex polygons overlap (separating-axis test).
///
/// Touching edges do not count as an overlap, so two pots side by side with no
/// gap are still a legal layout.
bool convexPolygonsOverlap(
  List<Vec2> a,
  List<Vec2> b, {
  double epsilon = 1e-9,
}) {
  for (final ring in <List<Vec2>>[a, b]) {
    for (var i = 0; i < ring.length; i++) {
      final edge = ring[(i + 1) % ring.length] - ring[i];
      final axis = Vec2(-edge.z, edge.x);
      final (minA, maxA) = _project(a, axis);
      final (minB, maxB) = _project(b, axis);
      if (maxA <= minB + epsilon || maxB <= minA + epsilon) return false;
    }
  }
  return true;
}

(double, double) _project(List<Vec2> ring, Vec2 axis) {
  var min = double.infinity;
  var max = double.negativeInfinity;
  for (final point in ring) {
    final value = point.x * axis.x + point.z * axis.z;
    min = math.min(min, value);
    max = math.max(max, value);
  }
  return (min, max);
}

/// Reads a number that may have arrived as an `int`, a `double` or a string.
///
/// JSON round-trips turn `2.0` into `2`, and the scene's own numbers come back
/// through `JSON.stringify`, so every numeric field has to tolerate both.
double? asDouble(Object? value) => switch (value) {
  final double value => value,
  final int value => value.toDouble(),
  final String value => double.tryParse(value),
  _ => null,
};
