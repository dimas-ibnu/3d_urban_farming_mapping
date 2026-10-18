import 'package:flutter/widgets.dart';

import 'web3d_bridge_stub.dart'
    if (dart.library.js_interop) 'web3d_bridge_iframe.dart'
    if (dart.library.io) 'web3d_bridge_webview.dart'
    as impl;
import 'web3d_protocol.dart';

export 'web3d_protocol.dart';

/// One interface over the two ways the app embeds the Three.js scene:
/// an `<iframe>` on Flutter web and an `InAppWebView` on Android.
///
/// Callers only ever see [send], [events] and [view]; everything
/// platform-specific lives behind [Web3dBridge.create].
abstract class Web3dBridge {
  /// Returns the transport for the platform this app was compiled for.
  static Web3dBridge create() => impl.createWeb3dBridge();

  /// Messages coming back from the scene. Broadcast: several widgets may listen.
  Stream<Web3dEvent> get events;

  /// Sends one command to the scene.
  ///
  /// Safe to call before the scene reports [SceneReady]: commands sent early are
  /// queued and flushed in order once the transport is up.
  Future<void> send(Web3dCommand command);

  /// The widget that hosts the scene. Mount it before expecting any event.
  Widget get view;

  Future<void> dispose();
}
