import type { PlacedItem, Space, Vec2 } from './protocol';

/**
 * The same floor-plane maths as `app/lib/model/geometry.dart`.
 *
 * The scene duplicates the fit and collision checks so a dragged item can turn
 * red the instant it is in a bad spot, without a round trip. Dart stays the
 * authority: it re-checks every move and answers with `setInvalidItems`.
 */

export function rotate(point: Vec2, degrees: number): Vec2 {
  const radians = (degrees * Math.PI) / 180;
  const cos = Math.cos(radians);
  const sin = Math.sin(radians);
  return { x: point.x * cos + point.z * sin, z: -point.x * sin + point.z * cos };
}

export function distanceToSegment(point: Vec2, a: Vec2, b: Vec2): number {
  const closest = closestPointOnSegment(point, a, b);
  return Math.hypot(point.x - closest.x, point.z - closest.z);
}

export function closestPointOnSegment(point: Vec2, a: Vec2, b: Vec2): Vec2 {
  const abx = b.x - a.x;
  const abz = b.z - a.z;
  const lengthSquared = abx * abx + abz * abz;
  if (lengthSquared === 0) return a;
  const t = Math.min(
    1,
    Math.max(0, ((point.x - a.x) * abx + (point.z - a.z) * abz) / lengthSquared),
  );
  return { x: a.x + abx * t, z: a.z + abz * t };
}

/** Crossing-number test; a point on an edge counts as inside. */
export function polygonContains(ring: Vec2[], point: Vec2, epsilon = 1e-9): boolean {
  if (ring.length < 3) return false;
  let inside = false;
  for (let i = 0, j = ring.length - 1; i < ring.length; j = i++) {
    const a = ring[i]!;
    const b = ring[j]!;
    if (distanceToSegment(point, a, b) <= epsilon) return true;
    const crosses =
      a.z > point.z !== b.z > point.z &&
      point.x < ((b.x - a.x) * (point.z - a.z)) / (b.z - a.z) + a.x;
    if (crosses) inside = !inside;
  }
  return inside;
}

/** The four corners of an item's footprint, rotated into place. */
export function itemFootprint(item: PlacedItem): Vec2[] {
  const halfWidth = item.size.widthM / 2;
  const halfDepth = item.size.depthM / 2;
  return (
    [
      { x: -halfWidth, z: -halfDepth },
      { x: halfWidth, z: -halfDepth },
      { x: halfWidth, z: halfDepth },
      { x: -halfWidth, z: halfDepth },
    ] as Vec2[]
  ).map((corner) => {
    const turned = rotate(corner, item.rotationDeg);
    return { x: item.position.x + turned.x, z: item.position.z + turned.z };
  });
}

/** Separating-axis test. Touching edges do not count as an overlap. */
export function convexPolygonsOverlap(a: Vec2[], b: Vec2[], epsilon = 1e-9): boolean {
  for (const ring of [a, b]) {
    for (let i = 0; i < ring.length; i++) {
      const current = ring[i]!;
      const next = ring[(i + 1) % ring.length]!;
      const axis = { x: -(next.z - current.z), z: next.x - current.x };
      const [minA, maxA] = project(a, axis);
      const [minB, maxB] = project(b, axis);
      if (maxA <= minB + epsilon || maxB <= minA + epsilon) return false;
    }
  }
  return true;
}

function project(ring: Vec2[], axis: Vec2): [number, number] {
  let min = Infinity;
  let max = -Infinity;
  for (const point of ring) {
    const value = point.x * axis.x + point.z * axis.z;
    min = Math.min(min, value);
    max = Math.max(max, value);
  }
  return [min, max];
}

export function occupiesFloor(item: PlacedItem): boolean {
  return item.type === 'pot' || item.type === 'verticalRack';
}

export function isElevated(item: PlacedItem): boolean {
  return item.type === 'hangingPlanter' || item.type === 'wallPlanter';
}

/**
 * The scene's own copy of the layout rules, for instant drag feedback.
 * Mirrors `validateItem` in `app/lib/model/layout_rules.dart`.
 */
export function isPlacementValid(
  space: Space,
  item: PlacedItem,
  others: Iterable<PlacedItem>,
): boolean {
  if (!itemFootprint(item).every((corner) => polygonContains(space.footprint, corner))) {
    return false;
  }
  if (item.mountHeightM + item.size.heightM > space.heightM) return false;
  if (!occupiesFloor(item)) return true;

  const footprint = itemFootprint(item);
  for (const other of others) {
    if (other.id === item.id || !occupiesFloor(other)) continue;
    if (convexPolygonsOverlap(footprint, itemFootprint(other))) return false;
  }
  return true;
}

/** Centroid of the footprint — what the cameras look at. */
export function spaceCentre(space: Space): Vec2 {
  if (space.footprint.length === 0) return { x: 0, z: 0 };
  let x = 0;
  let z = 0;
  for (const point of space.footprint) {
    x += point.x;
    z += point.z;
  }
  return { x: x / space.footprint.length, z: z / space.footprint.length };
}

/** Largest distance across the footprint; sets how far the camera sits back. */
export function spaceExtent(space: Space): number {
  if (space.footprint.length === 0) return 2;
  let minX = Infinity;
  let minZ = Infinity;
  let maxX = -Infinity;
  let maxZ = -Infinity;
  for (const point of space.footprint) {
    minX = Math.min(minX, point.x);
    minZ = Math.min(minZ, point.z);
    maxX = Math.max(maxX, point.x);
    maxZ = Math.max(maxZ, point.z);
  }
  return Math.max(maxX - minX, maxZ - minZ, 1);
}
