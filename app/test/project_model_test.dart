import 'package:flutter_test/flutter_test.dart';
import 'package:urban_farming_planner/model/project.dart';

void main() {
  group('geometry', () {
    test('polygon area is the shoelace area, whichever way the ring turns', () {
      const clockwise = <Vec2>[
        Vec2(0, 0),
        Vec2(2, 0),
        Vec2(2, 1.5),
        Vec2(0, 1.5),
      ];
      expect(polygonArea(clockwise), closeTo(3, 1e-9));
      expect(polygonArea(clockwise.reversed.toList()), closeTo(3, 1e-9));
    });

    test('an L-shaped floor is measured correctly', () {
      const ring = <Vec2>[
        Vec2(0, 0),
        Vec2(3, 0),
        Vec2(3, 1),
        Vec2(1, 1),
        Vec2(1, 2),
        Vec2(0, 2),
      ];
      // A 3 × 1 leg plus a 1 × 1 square at its left end.
      expect(polygonArea(ring), closeTo(4, 1e-9));
    });

    test('a point on the edge counts as inside', () {
      final ring = Space.rectangle(widthM: 2, depthM: 2).footprint;
      expect(polygonContains(ring, const Vec2(0, 0)), isTrue);
      expect(polygonContains(ring, const Vec2(1, 0)), isTrue);
      expect(polygonContains(ring, const Vec2(1.01, 0)), isFalse);
    });

    test('touching rectangles do not count as overlapping', () {
      final left = rectangleCorners(const Vec2(0, 0), 1, 1, 0);
      final touching = rectangleCorners(const Vec2(1, 0), 1, 1, 0);
      final overlapping = rectangleCorners(const Vec2(0.9, 0), 1, 1, 0);
      expect(convexPolygonsOverlap(left, touching), isFalse);
      expect(convexPolygonsOverlap(left, overlapping), isTrue);
    });

    test('rotation is picked up by the overlap test', () {
      final straight = rectangleCorners(const Vec2(0, 0), 1, 0.2, 0);
      final turned = rectangleCorners(const Vec2(0.55, 0), 1, 0.2, 90);
      // Side by side when both lie flat, crossing once one is turned.
      expect(
        convexPolygonsOverlap(
          straight,
          rectangleCorners(const Vec2(1.05, 0), 1, 0.2, 0),
        ),
        isFalse,
      );
      expect(convexPolygonsOverlap(straight, turned), isTrue);
    });
  });

  group('growing area', () {
    test('a rack multiplies its footprint by its levels', () {
      final space = Space.rectangle(widthM: 2, depthM: 1);
      final rack = PlacedItem.defaults(id: 'r', type: ItemType.verticalRack);
      final summary = GrowingAreaSummary.of(space, [rack]);

      expect(summary.floorAreaM2, closeTo(2, 1e-9));
      // 0.8 × 0.4 × 4 levels.
      expect(summary.growingAreaM2, closeTo(1.28, 1e-9));
      expect(summary.floorUsedM2, closeTo(0.32, 1e-9));
      expect(summary.freeFloorM2, closeTo(1.68, 1e-9));
    });

    test('hanging and wall planters add area without taking floor', () {
      final space = Space.rectangle(widthM: 2, depthM: 1);
      final items = <PlacedItem>[
        PlacedItem.defaults(id: 'h', type: ItemType.hangingPlanter),
        PlacedItem.defaults(id: 'w', type: ItemType.wallPlanter),
      ];
      final summary = GrowingAreaSummary.of(space, items);

      expect(summary.growingAreaM2, closeTo(0.09 + 0.12, 1e-9));
      expect(summary.floorUsedM2, 0);
    });

    test('the multiplier is zero rather than infinite on an empty floor', () {
      final summary = GrowingAreaSummary.of(
        const Space(footprint: <Vec2>[], heightM: 2.6, facingDeg: 0),
        const <PlacedItem>[],
      );
      expect(summary.multiplier, 0);
    });
  });

  group('json', () {
    test('a full project round-trips unchanged', () {
      final original = Project.empty(name: 'Balkon belakang')
          .copyWith(
            location: const GeoLocation(
              latitude: -6.2088,
              longitude: 106.8456,
              label: 'Jakarta',
            ),
          )
          .upsertItem(
            PlacedItem.defaults(
              id: 'rack-1',
              type: ItemType.verticalRack,
              position: const Vec2(-0.4, 0.1),
            ).copyWith(levels: 5, rotationDeg: 90),
          )
          .upsertItem(
            PlacedItem.defaults(
              id: 'wall-1',
              type: ItemType.wallPlanter,
            ).copyWith(mountHeightM: 1.4, barrierId: 'barrier-wall'),
          );

      final restored = Project.decode(original.encode());

      expect(restored.encode(), original.encode());
      expect(restored.schemaVersion, kProjectSchemaVersion);
      expect(restored.name, 'Balkon belakang');
      expect(restored.location?.label, 'Jakarta');
      expect(restored.space.barriers.map((b) => b.kind), [
        BarrierKind.railing,
        BarrierKind.wall,
      ]);
      expect(restored.itemById('rack-1')?.levels, 5);
      expect(restored.itemById('rack-1')?.rotationDeg, 90);
      expect(restored.itemById('rack-1')?.position, const Vec2(-0.4, 0.1));
      expect(restored.itemById('wall-1')?.barrierId, 'barrier-wall');
      expect(
        restored.growingArea.growingAreaM2,
        original.growingArea.growingAreaM2,
      );
    });

    test('the schema version is written', () {
      expect(Project.empty().toJson()['schemaVersion'], kProjectSchemaVersion);
    });

    test('missing and unknown fields fall back instead of throwing', () {
      final restored = Project.fromJson(const <String, Object?>{
        'name': 'Setengah jadi',
        'items': <Object?>[
          <String, Object?>{'id': 'x', 'type': 'nothingLikeThis'},
        ],
      });

      expect(restored.schemaVersion, kProjectSchemaVersion);
      expect(restored.space.heightM, 2.6);
      expect(restored.location, isNull);
      expect(restored.itemById('x')?.type, ItemType.pot);
    });

    test('numbers that came back as ints are still read as metres', () {
      final restored = Project.fromJson(<String, Object?>{
        'schemaVersion': 1,
        'name': 'Balkon',
        'space': <String, Object?>{
          'footprint': <Object?>[
            <String, Object?>{'x': 0, 'z': 0},
            <String, Object?>{'x': 2, 'z': 0},
            <String, Object?>{'x': 2, 'z': 1},
            <String, Object?>{'x': 0, 'z': 1},
          ],
          'heightM': 3,
          'facingDeg': 90,
          'barriers': <Object?>[],
        },
        'items': <Object?>[],
      });

      expect(restored.space.heightM, 3.0);
      expect(restored.space.floorAreaM2, closeTo(2, 1e-9));
    });
  });

  group('project edits', () {
    test('upsert replaces the item with the same id', () {
      final project = Project.empty()
          .upsertItem(PlacedItem.defaults(id: 'p', type: ItemType.pot))
          .upsertItem(
            PlacedItem.defaults(
              id: 'p',
              type: ItemType.pot,
              position: const Vec2(0.5, 0),
            ),
          );

      expect(project.items, hasLength(1));
      expect(project.itemById('p')?.position, const Vec2(0.5, 0));
    });

    test('removing an item leaves the rest alone', () {
      final project = Project.empty()
          .upsertItem(PlacedItem.defaults(id: 'a', type: ItemType.pot))
          .upsertItem(PlacedItem.defaults(id: 'b', type: ItemType.pot))
          .removeItem('a');

      expect(project.items.map((item) => item.id), ['b']);
    });
  });
}
