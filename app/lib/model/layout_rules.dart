import 'dart:math' as math;

import 'geometry.dart';
import 'item.dart';
import 'space.dart';

/// Why a placement is not allowed.
///
/// The UI turns these into localised sentences; the scene only needs to know
/// that something is wrong so it can tint the item.
enum LayoutProblem {
  /// Part of the item sticks out past the floor outline.
  outsideSpace,

  /// It overlaps another item standing on the floor.
  overlapsItem,

  /// It is taller than the space is high.
  tooTall,

  /// A wall planter that is not near any wall to hang on.
  noWallToMountOn,
}

/// One problem with one item.
class LayoutIssue {
  const LayoutIssue(this.itemId, this.problem, {this.otherItemId});

  final String itemId;
  final LayoutProblem problem;

  /// The item that was collided with, for [LayoutProblem.overlapsItem].
  final String? otherItemId;

  @override
  String toString() => 'LayoutIssue($itemId, ${problem.name})';
}

/// How far from a wall a wall planter may sit before it counts as unmounted.
const double kWallSnapDistanceM = 0.6;

/// Checks one item against the space and the items already in it.
///
/// Floor items must sit inside the outline and not overlap each other; nothing
/// may be taller than the ceiling; a wall planter must have a wall to hang on.
/// Elevated items are free to pass over floor items — that is the whole point
/// of hanging them.
List<LayoutIssue> validateItem(
  Space space,
  PlacedItem item,
  Iterable<PlacedItem> others,
) {
  final issues = <LayoutIssue>[];
  final footprint = item.footprint;

  if (!footprint.every(space.contains)) {
    issues.add(LayoutIssue(item.id, LayoutProblem.outsideSpace));
  }

  if (item.topHeightM > space.heightM) {
    issues.add(LayoutIssue(item.id, LayoutProblem.tooTall));
  }

  if (item.type.occupiesFloor) {
    for (final other in others) {
      if (other.id == item.id || !other.type.occupiesFloor) continue;
      if (convexPolygonsOverlap(footprint, other.footprint)) {
        issues.add(
          LayoutIssue(
            item.id,
            LayoutProblem.overlapsItem,
            otherItemId: other.id,
          ),
        );
        break;
      }
    }
  }

  if (item.type.mountsOnWall) {
    final barrier = item.barrierId == null
        ? null
        : space.barrierById(item.barrierId!);
    final mounted =
        barrier != null &&
        barrier.kind.mountable &&
        distanceToSegment(item.position, barrier.start, barrier.end) <=
            kWallSnapDistanceM;
    if (!mounted) {
      issues.add(LayoutIssue(item.id, LayoutProblem.noWallToMountOn));
    }
  }

  return issues;
}

/// Every problem in a whole layout.
List<LayoutIssue> validateLayout(Space space, List<PlacedItem> items) => [
  for (final item in items) ...validateItem(space, item, items),
];

/// Pins a wall planter to the nearest wall, pushing it flush against it.
///
/// Returns the item unchanged when it is not a wall planter or there is no
/// wall within [kWallSnapDistanceM] — [validateItem] then reports it as
/// unmounted and the UI can say so.
PlacedItem snapToWall(Space space, PlacedItem item) {
  if (!item.type.mountsOnWall) return item;
  final barrier = space.nearestMountableBarrier(
    item.position,
    maxDistanceM: kWallSnapDistanceM,
  );
  if (barrier == null) return item.copyWith(clearBarrier: true);

  final onWall = closestPointOnSegment(
    item.position,
    barrier.start,
    barrier.end,
  );
  final along = barrier.end - barrier.start;
  final length = along.length;
  if (length == 0) return item.copyWith(barrierId: barrier.id);

  // Face the planter away from the wall, into the space, and stand it off by
  // half its depth so the box touches the wall instead of sinking into it.
  final normal = Vec2(-along.z / length, along.x / length);
  final inward = space.contains(onWall + normal * 0.01) ? normal : normal * -1;
  final rotationDeg = _bearingDeg(inward);

  return item.copyWith(
    position: onWall + inward * (item.size.depthM / 2),
    rotationDeg: rotationDeg,
    barrierId: barrier.id,
  );
}

/// The rotation that turns the item's local +z towards [direction].
///
/// `Vec2.rotated` turns clockwise seen from above, so the angle is measured the
/// same way and the result drops straight into [PlacedItem.rotationDeg].
double _bearingDeg(Vec2 direction) =>
    math.atan2(direction.x, direction.z) * 180 / math.pi;
