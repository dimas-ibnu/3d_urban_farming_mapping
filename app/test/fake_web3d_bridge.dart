import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:urban_farming_planner/bridge/web3d_bridge.dart';

/// An in-memory stand-in for a real WebView: records what the app sent and lets
/// a test push scene events back, so the round trip can be asserted without a
/// browser.
class FakeWeb3dBridge implements Web3dBridge {
  final StreamController<Web3dEvent> _events =
      StreamController<Web3dEvent>.broadcast();
  final List<Web3dCommand> sent = <Web3dCommand>[];

  bool disposed = false;

  @override
  Stream<Web3dEvent> get events => _events.stream;

  @override
  Future<void> send(Web3dCommand command) async => sent.add(command);

  @override
  Widget get view => const SizedBox.expand(key: Key('fake-scene'));

  @override
  Future<void> dispose() async {
    disposed = true;
    await _events.close();
  }

  /// Simulates the scene answering.
  void emit(Web3dEvent event) => _events.add(event);

  /// Simulates a raw envelope arriving over the transport.
  void emitRaw(String json) {
    final event = decodeWeb3dEvent(json);
    if (event != null) _events.add(event);
  }
}
