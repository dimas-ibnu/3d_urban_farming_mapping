import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:urban_farming_planner/bridge/web3d_bridge.dart';
import 'package:urban_farming_planner/main.dart';
import 'package:urban_farming_planner/model/project.dart';

import 'fake_web3d_bridge.dart';

void main() {
  late FakeWeb3dBridge bridge;

  setUp(() => bridge = FakeWeb3dBridge());

  /// Pins the locale to Bahasa Indonesia, the app's default, so the assertions
  /// below read the strings an Indonesian user actually sees.
  Future<void> pumpApp(
    WidgetTester tester, {
    Locale locale = const Locale('id'),
    Project? project,
  }) async {
    // Wide enough that the panel sits beside the scene and everything the
    // tests tap is laid out at once.
    tester.view.physicalSize = const Size(1400, 1400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      KebunkuApp(bridge: bridge, locale: locale, project: project),
    );
    await tester.pump();
  }

  String status(WidgetTester tester) =>
      tester.widget<Text>(find.byKey(const Key('scene-status'))).data!;

  String summary(WidgetTester tester) =>
      tester.widget<Text>(find.byKey(const Key('growing-area-summary'))).data!;

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

  testWidgets('pushes the space before the scene answers', (tester) async {
    await pumpApp(tester);

    expect(bridge.sent.map((c) => c.type), [
      'setSpace',
      'setView',
      'setSelection',
      'setInvalidItems',
    ]);
    expect(status(tester), 'Menyambungkan ke adegan 3D…');
  });

  testWidgets('replays the plan once the scene reports ready', (tester) async {
    await pumpApp(
      tester,
      project: Project.empty().upsertItem(
        PlacedItem.defaults(id: 'pot-1', type: ItemType.pot),
      ),
    );
    bridge.sent.clear();

    await emitRaw(
      tester,
      '{"v":2,"type":"ready","protocol":2,"renderer":"ANGLE"}',
    );

    expect(bridge.sent.map((c) => c.type), contains('setSpace'));
    expect(bridge.sent.whereType<UpsertItem>().single.item.id, 'pot-1');
    expect(status(tester), 'Adegan siap');
  });

  testWidgets('adding each item type sends an upsertItem', (tester) async {
    await pumpApp(tester);
    await emit(tester, const SceneReady(protocol: 2, renderer: 'ANGLE'));
    bridge.sent.clear();

    for (final type in ItemType.values) {
      await tester.tap(find.byKey(Key('add-${type.name}')));
      await tester.pump();
    }

    expect(
      bridge.sent.whereType<UpsertItem>().map((c) => c.item.type),
      ItemType.values,
    );
    expect(find.text('4 item'), findsOneWidget);
  });

  testWidgets('the growing-area summary follows the plan', (tester) async {
    await pumpApp(tester);
    // 2 × 1.2 m balcony.
    expect(summary(tester), '2,4 m² lantai → 0,0 m² area tanam');

    await tester.tap(find.byKey(const Key('add-verticalRack')));
    await tester.pump();

    // 0.8 × 0.4 m footprint over four levels.
    expect(summary(tester), '2,4 m² lantai → 1,3 m² area tanam');
  });

  testWidgets('the summary reads in English too', (tester) async {
    await pumpApp(tester, locale: const Locale('en'));
    await tester.tap(find.byKey(const Key('add-verticalRack')));
    await tester.pump();

    expect(summary(tester), '2.4 m² floor → 1.3 m² growing area');
  });

  testWidgets('a drag in the scene moves the item and is echoed back', (
    tester,
  ) async {
    await pumpApp(tester);
    await tester.tap(find.byKey(const Key('add-pot')));
    await tester.pump();
    final id = bridge.sent.whereType<UpsertItem>().last.item.id;
    bridge.sent.clear();

    await emitRaw(
      tester,
      '{"v":2,"type":"itemMoved","id":"$id","position":{"x":0.5,"z":0.2}}',
    );

    final echoed = bridge.sent.whereType<UpsertItem>().last.item;
    expect(echoed.id, id);
    expect(echoed.position, const Vec2(0.5, 0.2));
  });

  testWidgets('an item dragged out of the space is flagged, not refused', (
    tester,
  ) async {
    await pumpApp(tester);
    await tester.tap(find.byKey(const Key('add-pot')));
    await tester.pump();
    final id = bridge.sent.whereType<UpsertItem>().last.item.id;
    bridge.sent.clear();

    await emitRaw(
      tester,
      '{"v":2,"type":"itemMoved","id":"$id","position":{"x":5,"z":5}}',
    );

    expect(
      bridge.sent.whereType<UpsertItem>().last.item.position,
      const Vec2(5, 5),
    );
    expect(bridge.sent.whereType<SetInvalidItems>().last.ids, [id]);
    expect(find.text('Keluar dari batas ruang'), findsWidgets);
  });

  testWidgets('a wall planter snaps to the wall it was dropped near', (
    tester,
  ) async {
    await pumpApp(tester);
    await tester.tap(find.byKey(const Key('add-wallPlanter')));
    await tester.pump();
    final item = bridge.sent.whereType<UpsertItem>().last.item;

    // Project.empty() puts a wall along z = -0.6.
    expect(item.barrierId, 'barrier-wall');
    expect(item.position.z, closeTo(-0.5, 1e-9));
  });

  testWidgets('tapping an item in the scene fills the selection panel', (
    tester,
  ) async {
    await pumpApp(tester);
    await emit(tester, const SceneReady(protocol: 2, renderer: 'ANGLE'));
    await tester.tap(find.byKey(const Key('add-verticalRack')));
    await tester.pump();
    final id = bridge.sent.whereType<UpsertItem>().last.item.id;

    await emitRaw(tester, '{"v":2,"type":"selected","id":null}');
    expect(
      find.text('Ketuk sebuah item di adegan untuk mengubahnya.'),
      findsOneWidget,
    );

    await emitRaw(tester, '{"v":2,"type":"selected","id":"$id"}');
    expect(status(tester), 'Terpilih: Rak vertikal');
    expect(find.text('Jumlah tingkat'), findsOneWidget);
  });

  testWidgets('changing the rack levels updates the growing area', (
    tester,
  ) async {
    await pumpApp(tester);
    await tester.tap(find.byKey(const Key('add-verticalRack')));
    await tester.pump();

    final slider = find.byType(Slider).first;
    tester.widget<Slider>(slider).onChanged!(6);
    await tester.pump();

    // 0.32 m² × 6 levels.
    expect(summary(tester), '2,4 m² lantai → 1,9 m² area tanam');
  });

  testWidgets('removing the selected item takes it out of the scene', (
    tester,
  ) async {
    await pumpApp(tester);
    await tester.tap(find.byKey(const Key('add-pot')));
    await tester.pump();
    final id = bridge.sent.whereType<UpsertItem>().last.item.id;
    bridge.sent.clear();

    await tester.tap(find.byKey(const Key('remove-item')));
    await tester.pump();

    expect(bridge.sent.whereType<RemoveItem>().single.id, id);
    expect(find.text('Belum ada item'), findsOneWidget);
  });

  testWidgets('the 2D/3D toggle tells the scene which camera to use', (
    tester,
  ) async {
    await pumpApp(tester);
    bridge.sent.clear();

    await tester.tap(find.text('2D'));
    await tester.pump();

    expect(bridge.sent.whereType<SetView>().single.view, SceneView.plan2d);
  });

  testWidgets('a scene error explains itself over the canvas', (tester) async {
    await pumpApp(tester);
    await emit(tester, const SceneReady(protocol: 2, renderer: 'ANGLE'));
    await emit(tester, const SceneError('cannot start WebGL: Error'));

    expect(find.byKey(const Key('scene-unavailable')), findsOneWidget);
    expect(find.text('Tampilan 3D tidak tersedia'), findsOneWidget);
    // The plan itself keeps working behind the message.
    expect(summary(tester), '2,4 m² lantai → 0,0 m² area tanam');
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

    expect(bridge.sent.whereType<SetDebugOverlay>().single.visible, isTrue);
  });
}
