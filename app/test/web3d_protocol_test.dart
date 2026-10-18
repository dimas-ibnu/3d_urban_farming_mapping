import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:urban_farming_planner/bridge/web3d_protocol.dart';
import 'package:urban_farming_planner/model/project.dart';

void main() {
  group('commands', () {
    test('every command carries the protocol version and its type', () {
      final commands = <Web3dCommand>[
        SetSpace(Space.rectangle(widthM: 2, depthM: 1.2)),
        UpsertItem(PlacedItem.defaults(id: 'pot-1', type: ItemType.pot)),
        const RemoveItem('pot-1'),
        const ClearItems(),
        const SetView(SceneView.plan2d),
        const SetSelection('pot-1'),
        const SetInvalidItems(<String>['pot-1']),
        const SetDebugOverlay(visible: true),
        const Ping(),
      ];

      for (final command in commands) {
        final json = jsonDecode(command.encode()) as Map<String, Object?>;
        expect(json['v'], kProtocolVersion, reason: '${command.type} has no v');
        expect(json['type'], command.type);
      }
    });

    test('the version is 2 — v1 spoke about pots, v2 about the model', () {
      expect(kProtocolVersion, 2);
    });

    test('setSpace carries the outline, the height and the barriers', () {
      final space = Space.rectangle(
        widthM: 2,
        depthM: 1,
        heightM: 2.4,
        facingDeg: 135,
        barriers: <Barrier>[
          const Barrier(
            id: 'w',
            kind: BarrierKind.wall,
            start: Vec2(-1, -0.5),
            end: Vec2(1, -0.5),
            heightM: 2.4,
          ),
        ],
      );
      final json = jsonDecode(SetSpace(space).encode()) as Map<String, Object?>;
      final payload = json['space']! as Map<String, Object?>;

      expect((payload['footprint']! as List), hasLength(4));
      expect(payload['heightM'], 2.4);
      expect(payload['facingDeg'], 135);
      expect(((payload['barriers']! as List).single as Map)['kind'], 'wall');
    });

    test('upsertItem sends exactly the item JSON the model persists', () {
      final item = PlacedItem.defaults(
        id: 'rack-1',
        type: ItemType.verticalRack,
        position: const Vec2(0.25, -0.1),
      ).copyWith(levels: 3, rotationDeg: 45);
      final json =
          jsonDecode(UpsertItem(item).encode()) as Map<String, Object?>;

      expect(json['item'], item.toJson());
    });

    test('setView uses the short wire names', () {
      expect(
        jsonDecode(const SetView(SceneView.plan2d).encode()),
        containsPair('mode', '2d'),
      );
      expect(
        jsonDecode(const SetView(SceneView.orbit3d).encode()),
        containsPair('mode', '3d'),
      );
    });

    test('a null selection clears the highlight', () {
      expect(
        jsonDecode(const SetSelection(null).encode()),
        containsPair('id', null),
      );
    });
  });

  group('decodeWeb3dEvent', () {
    test('parses every event the scene can send', () {
      expect(
        decodeWeb3dEvent(
          '{"v":2,"type":"ready","protocol":2,"renderer":"ANGLE"}',
        ),
        isA<SceneReady>()
            .having((e) => e.protocol, 'protocol', 2)
            .having((e) => e.renderer, 'renderer', 'ANGLE'),
      );
      expect(
        decodeWeb3dEvent('{"v":2,"type":"selected","id":"pot-1"}'),
        isA<ItemSelected>().having((e) => e.id, 'id', 'pot-1'),
      );
      expect(
        decodeWeb3dEvent('{"v":2,"type":"selected","id":null}'),
        isA<ItemSelected>().having((e) => e.id, 'id', isNull),
      );
      expect(decodeWeb3dEvent('{"v":2,"type":"pong"}'), isA<ScenePong>());
      expect(
        decodeWeb3dEvent('{"v":2,"type":"fps","value":58}'),
        isA<SceneFps>().having((e) => e.value, 'value', 58),
      );
      expect(
        decodeWeb3dEvent('{"v":2,"type":"error","message":"no WebGL"}'),
        isA<SceneError>().having((e) => e.message, 'message', 'no WebGL'),
      );
    });

    test('itemMoved brings the new position back', () {
      final event = decodeWeb3dEvent(
        '{"v":2,"type":"itemMoved","id":"pot-1","position":{"x":0.4,"z":-0.2}}',
      );
      expect(
        event,
        isA<ItemMoved>()
            .having((e) => e.id, 'id', 'pot-1')
            .having((e) => e.position, 'position', const Vec2(0.4, -0.2))
            .having((e) => e.mountHeightM, 'mountHeightM', isNull),
      );
    });

    test('itemMoved carries the mounting height for elevated items', () {
      final event = decodeWeb3dEvent(
        '{"v":2,"type":"itemMoved","id":"h","position":{"x":0,"z":0},"mountHeightM":1.75}',
      );
      expect(
        event,
        isA<ItemMoved>().having((e) => e.mountHeightM, 'height', 1.75),
      );
    });

    test('whole numbers survive JSON.stringify dropping the decimal', () {
      final event = decodeWeb3dEvent(
        '{"v":2,"type":"itemMoved","id":"p","position":{"x":1,"z":0}}',
      );
      expect(
        event,
        isA<ItemMoved>().having(
          (e) => e.position,
          'position',
          const Vec2(1, 0),
        ),
      );
    });

    test('an itemMoved without a usable position is dropped', () {
      expect(decodeWeb3dEvent('{"v":2,"type":"itemMoved","id":"p"}'), isNull);
      expect(
        decodeWeb3dEvent(
          '{"v":2,"type":"itemMoved","id":"p","position":{"x":"here"}}',
        ),
        isNull,
      );
    });

    test('traffic from another protocol version is ignored', () {
      expect(decodeWeb3dEvent('{"v":1,"type":"ready","protocol":1}'), isNull);
      expect(decodeWeb3dEvent('{"type":"ready"}'), isNull);
    });

    test('anything that is not one of our messages is ignored', () {
      expect(decodeWeb3dEvent('not json at all'), isNull);
      expect(decodeWeb3dEvent('{"v":2,"type":"somethingElse"}'), isNull);
      expect(decodeWeb3dEvent(null), isNull);
      expect(decodeWeb3dEvent(42), isNull);
    });

    test(
      'an already-decoded map works too — the Android handler sends one',
      () {
        expect(
          decodeWeb3dEvent(<String, Object?>{
            'v': kProtocolVersion,
            'type': 'selected',
            'id': 'pot-2',
          }),
          isA<ItemSelected>().having((e) => e.id, 'id', 'pot-2'),
        );
      },
    );
  });
}
