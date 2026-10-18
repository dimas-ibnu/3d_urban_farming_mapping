import 'dart:async';
import 'dart:js_interop';
import 'dart:ui_web' as ui_web;

import 'package:flutter/widgets.dart';
import 'package:web/web.dart' as web;

import 'web3d_bridge.dart';

Web3dBridge createWeb3dBridge() => IframeWeb3dBridge();

/// Flutter web transport: an `<iframe>` mounted through [HtmlElementView],
/// talking over `window.postMessage`.
///
/// The scene is a declared Flutter asset, so the browser serves it from the
/// app's own origin and it stays available offline through the service worker.
class IframeWeb3dBridge implements Web3dBridge {
  IframeWeb3dBridge() {
    _viewType = 'kebunku-web3d-${_nextViewId++}';
    ui_web.platformViewRegistry.registerViewFactory(
      _viewType,
      (int _) => _iframe,
    );
    _listener = _onWindowMessage.toJS;
    web.window.addEventListener('message', _listener);
  }

  /// Flutter web asset URLs are prefixed with `assets/`, so the pubspec path
  /// `assets/web3d/index.html` is served from `assets/assets/web3d/index.html`.
  static const String scenePath = 'assets/assets/web3d/index.html';

  static int _nextViewId = 0;

  final StreamController<Web3dEvent> _events =
      StreamController<Web3dEvent>.broadcast();
  final List<Web3dCommand> _queued = <Web3dCommand>[];

  late final String _viewType;
  late final JSFunction _listener;

  final web.HTMLIFrameElement _iframe = web.HTMLIFrameElement()
    ..src = scenePath
    ..style.border = 'none'
    ..style.width = '100%'
    ..style.height = '100%'
    ..allow = 'accelerometer; gyroscope';

  bool _loaded = false;

  @override
  Stream<Web3dEvent> get events => _events.stream;

  @override
  Future<void> send(Web3dCommand command) async {
    if (!_loaded) {
      // Posting into an iframe that has not run its script yet is a silent
      // no-op, so queue until the scene says hello.
      _queued.add(command);
      return;
    }
    _post(command);
  }

  @override
  Widget get view => HtmlElementView(viewType: _viewType);

  @override
  Future<void> dispose() async {
    web.window.removeEventListener('message', _listener);
    _iframe.remove();
    await _events.close();
  }

  void _post(Web3dCommand command) {
    // `*` because the scene also runs from an opaque `file://` origin on
    // Android; the scene validates the envelope instead of trusting the origin.
    _iframe.contentWindow?.postMessage(command.encode().toJS, '*'.toJS);
  }

  void _onWindowMessage(web.MessageEvent message) {
    // The whole page shares this event target, so ignore anything that did not
    // come from our own iframe.
    if (message.source != _iframe.contentWindow) return;

    final data = message.data;
    if (data == null || !data.isA<JSString>()) return;

    final event = decodeWeb3dEvent((data as JSString).toDart);
    if (event == null || _events.isClosed) return;

    if (event is SceneReady && !_loaded) {
      _loaded = true;
      final pending = List<Web3dCommand>.of(_queued);
      _queued.clear();
      for (final command in pending) {
        _post(command);
      }
    }
    _events.add(event);
  }
}
