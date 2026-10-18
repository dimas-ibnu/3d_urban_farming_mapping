import 'package:flutter/widgets.dart';

import 'web3d_bridge.dart';

/// Fallback for targets with neither `dart:io` nor `dart:js_interop`.
///
/// Nothing reaches this in practice — the app ships web and Android — but the
/// conditional import needs a default, and an explicit failure beats a
/// compile error in an unfamiliar target.
Web3dBridge createWeb3dBridge() => _UnsupportedWeb3dBridge();

class _UnsupportedWeb3dBridge implements Web3dBridge {
  @override
  Stream<Web3dEvent> get events => const Stream<Web3dEvent>.empty();

  @override
  Future<void> send(Web3dCommand command) async {}

  @override
  Widget get view => const SizedBox.shrink();

  @override
  Future<void> dispose() async {}
}
