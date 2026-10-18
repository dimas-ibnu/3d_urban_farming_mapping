import 'package:flutter_test/flutter_test.dart';
import 'package:urban_farming_planner/model/project.dart';

void main() {
  final space = Space.rectangle(
    widthM: 2,
    depthM: 1.2,
    heightM: 2.5,
    barriers: <Barrier>[
      const Barrier(
        id: 'wall-north',
        kind: BarrierKind.wall,
        start: Vec2(-1, -0.6),
        end: Vec2(1, -0.6),
        heightM: 2.5,
      ),
      const Barrier(
        id: 'rail-south',
        kind: BarrierKind.railing,
        start: Vec2(-1, 0.6),
        end: Vec2(1, 0.6),
        heightM: 1.1,
      ),
    ],
  );

  List<LayoutProblem> problems(PlacedItem item, [List<PlacedItem>? others]) =>
      validateItem(
        space,
        item,
        others ?? <PlacedItem>[item],
      ).map((issue) => issue.problem).toList();

  group('fit', () {
    test('a pot in the middle of the floor is fine', () {
      expect(problems(PlacedItem.defaults(id: 'p', type: ItemType.pot)), []);
    });

    test('a pot hanging over the edge is flagged', () {
      final item = PlacedItem.defaults(
        id: 'p',
        type: ItemType.pot,
        position: const Vec2(0.95, 0),
      );
      expect(problems(item), [LayoutProblem.outsideSpace]);
    });

    test('a pot flush against the wall still fits', () {
      final item = PlacedItem.defaults(
        id: 'p',
        type: ItemType.pot,
        position: const Vec2(0.85, 0),
      );
      expect(problems(item), isEmpty);
    });

    test('a rack taller than the ceiling is flagged', () {
      final item = PlacedItem.defaults(
        id: 'r',
        type: ItemType.verticalRack,
      ).copyWith(size: const ItemSize(widthM: 0.8, depthM: 0.4, heightM: 3));
      expect(problems(item), contains(LayoutProblem.tooTall));
    });

    test('a hanging planter hung above the ceiling is flagged', () {
      final item = PlacedItem.defaults(
        id: 'h',
        type: ItemType.hangingPlanter,
      ).copyWith(mountHeightM: 2.4);
      expect(problems(item), contains(LayoutProblem.tooTall));
    });
  });

  group('collision', () {
    test('two pots on the same spot collide', () {
      final a = PlacedItem.defaults(id: 'a', type: ItemType.pot);
      final b = PlacedItem.defaults(id: 'b', type: ItemType.pot);
      expect(problems(a, [a, b]), [LayoutProblem.overlapsItem]);
    });

    test('pots side by side do not', () {
      final a = PlacedItem.defaults(
        id: 'a',
        type: ItemType.pot,
        position: const Vec2(-0.2, 0),
      );
      final b = PlacedItem.defaults(
        id: 'b',
        type: ItemType.pot,
        position: const Vec2(0.2, 0),
      );
      expect(problems(a, [a, b]), isEmpty);
    });

    test('a hanging planter may hang over a pot', () {
      final pot = PlacedItem.defaults(id: 'p', type: ItemType.pot);
      final hanging = PlacedItem.defaults(
        id: 'h',
        type: ItemType.hangingPlanter,
      );
      expect(problems(hanging, [pot, hanging]), isEmpty);
    });

    test('the offending item is named in the issue', () {
      final a = PlacedItem.defaults(id: 'a', type: ItemType.pot);
      final b = PlacedItem.defaults(id: 'b', type: ItemType.pot);
      final issue = validateItem(space, a, [a, b]).single;
      expect(issue.itemId, 'a');
      expect(issue.otherItemId, 'b');
    });
  });

  group('wall planters', () {
    test(
      'snapping pins the planter to the nearest wall and faces it inward',
      () {
        final draft = PlacedItem.defaults(
          id: 'w',
          type: ItemType.wallPlanter,
          position: const Vec2(0.2, -0.5),
        );
        final snapped = snapToWall(space, draft);

        expect(snapped.barrierId, 'wall-north');
        // Pushed off the wall by half its depth, into the space.
        expect(snapped.position.z, closeTo(-0.6 + 0.1, 1e-9));
        expect(snapped.position.x, closeTo(0.2, 1e-9));
        expect(validateItem(space, snapped, [snapped]), isEmpty);
      },
    );

    test('a railing is not something to hang a planter on', () {
      final draft = PlacedItem.defaults(
        id: 'w',
        type: ItemType.wallPlanter,
        position: const Vec2(0, 0.55),
      );
      final snapped = snapToWall(space, draft);

      expect(snapped.barrierId, isNull);
      expect(problems(snapped), contains(LayoutProblem.noWallToMountOn));
    });

    test('a planter dragged into the open loses its wall', () {
      final mounted = snapToWall(
        space,
        PlacedItem.defaults(
          id: 'w',
          type: ItemType.wallPlanter,
          position: const Vec2(0, -0.55),
        ),
      );
      final adrift = snapToWall(
        space,
        mounted.copyWith(position: const Vec2(0, 0.3)),
      );

      expect(mounted.barrierId, 'wall-north');
      expect(adrift.barrierId, isNull);
    });

    test('snapping leaves other item types alone', () {
      final pot = PlacedItem.defaults(
        id: 'p',
        type: ItemType.pot,
        position: const Vec2(0, -0.55),
      );
      expect(snapToWall(space, pot).position, pot.position);
      expect(snapToWall(space, pot).barrierId, isNull);
    });
  });

  test('validateLayout reports every item at once', () {
    final outside = PlacedItem.defaults(
      id: 'out',
      type: ItemType.pot,
      position: const Vec2(2, 0),
    );
    final fine = PlacedItem.defaults(id: 'ok', type: ItemType.pot);
    final issues = validateLayout(space, [outside, fine]);

    expect(issues.map((issue) => issue.itemId), ['out']);
  });
}
