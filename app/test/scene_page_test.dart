import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:urban_farming_planner/bridge/web3d_bridge.dart';
import 'package:urban_farming_planner/main.dart';

import 'fake_web3d_bridge.dart';

void main() {
  late FakeWeb3dBridge bridge;

  setUp(() => bridge = FakeWeb3dBridge());

  /// Pins the locale to Bahasa Indonesia, the app's default, so the assertions
  /// below read the strings an Indonesian user actually sees.
  Future<void> pumpApp(
    WidgetTester tester, {
    Locale locale = const Locale('id'),
  }) async {
    await tester.pumpWidget(KebunkuApp(bridge: bridge, locale: locale));
    await tester.pump();
  }

  String status(WidgetTester tester) =>
      tester.widget<Text>(find.byKey(const Key('scene-status'))).data!;

  /// Pushes an event from the scene and settles the frame it triggers.
  /// The scene's events arrive outside a frame, so the `setState` they cause
  /// is only painted by the frame after the one `pump` is already building.
  Future<void> emit(WidgetTester tester, Web3dEvent event) async {
    bridge.emit(event);
    await tester.pump();
    await tester.pump();
  }

  Future<void> emitRaw(WidgetTester tester, String json) async {
    bridge.emitRaw(json);
    await tester.pump();
    await tester.pump();
  }

  testWidgets('sets up the balcony and one pot before the scene answers', (
    tester,
  ) async {
    await pumpApp(tester);

    expect(bridge.sent.map((c) => c.type), ['setFloor', 'addPot']);
    expect(status(tester), 'Menyambungkan ke adegan 3D…');
  });

  testWidgets('round trip: ready then selected drive the status line', (
    tester,
  ) async {
    await pumpApp(tester);

    await emitRaw(
      tester,
      '{"v":1,"type":"ready","protocol":1,"renderer":"ANGLE"}',
    );
    expect(status(tester), 'Adegan siap (protokol v1)');

    await emitRaw(tester, '{"v":1,"type":"selected","id":"pot-0"}');
    expect(status(tester), 'Pot terpilih: pot-0');

    await emitRaw(tester, '{"v":1,"type":"selected","id":null}');
    expect(status(tester), 'Adegan siap (protokol v1)');
  });

  testWidgets('a scene error wins over the ready state', (tester) async {
    await pumpApp(tester);
    await emit(tester, const SceneReady(protocol: 1, renderer: 'ANGLE'));
    await emit(tester, const SceneError('unknown message type "wat"'));

    expect(status(tester), 'Kesalahan adegan: unknown message type "wat"');
  });

  testWidgets('adding and clearing pots sends the matching commands', (
    tester,
  ) async {
    await pumpApp(tester);
    bridge.sent.clear();

    await tester.tap(find.text('Tambah pot'));
    await tester.pump();
    expect(
      bridge.sent.single,
      isA<AddPot>().having((c) => c.id, 'id', 'pot-1'),
    );
    expect(find.text('2 pot'), findsOneWidget);

    await tester.tap(find.text('Kosongkan'));
    await tester.pump();
    expect(bridge.sent.last, isA<ClearPots>());
    expect(find.text('Belum ada pot'), findsOneWidget);
  });

  testWidgets('the FPS reading from the scene reaches the app bar', (
    tester,
  ) async {
    await pumpApp(tester);
    await emit(tester, const SceneFps(58));

    expect(find.text('58 fps'), findsOneWidget);
  });

  testWidgets('the overlay switch forwards the new value', (tester) async {
    await pumpApp(tester);
    bridge.sent.clear();

    await tester.tap(find.byType(Switch));
    await tester.pump();

    expect(
      bridge.sent.single,
      isA<SetDebugOverlay>().having((c) => c.visible, 'visible', isTrue),
    );
  });
}
