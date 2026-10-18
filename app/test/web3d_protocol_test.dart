import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:urban_farming_planner/bridge/web3d_protocol.dart';

void main() {
  group('commands', () {
    test('every command carries the protocol version and its type', () {
      const commands = <Web3dCommand>[
        SetFloor(width: 2, depth: 1.2),
        AddPot(id: 'pot-0', x: 0.1, z: 0.2),
        RemovePot('pot-0'),
        ClearPots(),
        SetDebugOverlay(visible: true),
        Ping(),
      ];

      for (final command in commands) {
        final json = jsonDecode(command.encode()) as Map<String, Object?>;
        expect(
          json['v'],
          kProtocolVersion,
          reason: '${command.type} is missing v',
        );
        expect(json['type'], command.type);
      }
    });

    test('addPot omits an unset colour and keeps the defaults', () {
      final json =
          jsonDecode(const AddPot(id: 'pot-1', x: -0.5, z: 0.4).encode())
              as Map;
      expect(json, containsPair('id', 'pot-1'));
      expect(json, containsPair('radius', 0.16));
      expect(json, containsPair('height', 0.22));
      expect(json.containsKey('color'), isFalse);
    });
  });

  group('decodeWeb3dEvent', () {
    test('parses every event the scene can send', () {
      expect(
        decodeWeb3dEvent(
          '{"v":1,"type":"ready","protocol":1,"renderer":"ANGLE"}',
        ),
        isA<SceneReady>()
            .having((e) => e.protocol, 'protocol', 1)
            .having((e) => e.renderer, 'renderer', 'ANGLE'),
      );
      expect(
        decodeWeb3dEvent('{"v":1,"type":"selected","id":"pot-0"}'),
        isA<PotSelected>().having((e) => e.id, 'id', 'pot-0'),
      );
      expect(
        decodeWeb3dEvent('{"v":1,"type":"selected","id":null}'),
        isA<PotSelected>().having((e) => e.id, 'id', isNull),
      );
      expect(decodeWeb3dEvent('{"v":1,"type":"pong"}'), isA<ScenePong>());
      expect(
        decodeWeb3dEvent('{"v":1,"type":"fps","value":58}'),
        isA<SceneFps>().having((e) => e.value, 'value', 58),
      );
      expect(
        decodeWeb3dEvent('{"v":1,"type":"error","message":"boom"}'),
        isA<SceneError>().having((e) => e.message, 'message', 'boom'),
      );
    });

    test('accepts an already-decoded map as well as a string', () {
      expect(
        decodeWeb3dEvent(<String, Object?>{
          'v': 1,
          'type': 'fps',
          'value': 60.0,
        }),
        isA<SceneFps>().having((e) => e.value, 'value', 60),
      );
    });

    test('drops traffic that is not ours instead of throwing', () {
      expect(decodeWeb3dEvent('not json'), isNull);
      expect(
        decodeWeb3dEvent('{"v":2,"type":"ready"}'),
        isNull,
        reason: 'wrong version',
      );
      expect(decodeWeb3dEvent('{"v":1,"type":"somethingElse"}'), isNull);
      expect(
        decodeWeb3dEvent('{"type":"ready"}'),
        isNull,
        reason: 'no version',
      );
      expect(
        decodeWeb3dEvent('{"v":1,"type":"fps"}'),
        isNull,
        reason: 'no value',
      );
      expect(decodeWeb3dEvent(null), isNull);
      expect(decodeWeb3dEvent(42), isNull);
    });
  });
}
