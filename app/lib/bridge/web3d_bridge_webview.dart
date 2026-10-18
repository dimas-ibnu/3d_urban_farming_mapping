import 'dart:async';
import 'dart:convert';

import 'package:flutter/widgets.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';

import 'web3d_bridge.dart';

Web3dBridge createWeb3dBridge() => WebViewWeb3dBridge();

/// Android transport: `flutter_inappwebview` plus a JS handler.
///
/// The scene is loaded straight from the Flutter asset bundle
/// (`file:///android_asset/flutter_assets/...`), which is why the `web3d` build
/// inlines everything into one HTML file — a `file://` document has an opaque
/// origin and could not fetch a separate script.
class WebViewWeb3dBridge implements Web3dBridge {
  final StreamController<Web3dEvent> _events =
      StreamController<Web3dEvent>.broadcast();
  final List<Web3dCommand> _queued = <Web3dCommand>[];

  InAppWebViewController? _controller;
  bool _loaded = false;
  bool _disposed = false;

  @override
  Stream<Web3dEvent> get events => _events.stream;

  @override
  Future<void> send(Web3dCommand command) async {
    final controller = _controller;
    if (controller == null || !_loaded) {
      // `window.kebunku` only exists once the page has run; hold on to the
      // command instead of evaluating into a document that cannot receive it.
      _queued.add(command);
      return;
    }
    await _evaluate(controller, command);
  }

  @override
  Widget get view => InAppWebView(
    initialFile: 'assets/web3d/index.html',
    initialSettings: InAppWebViewSettings(
      transparentBackground: true,
      // The scene owns all gestures; the page itself must never scroll or zoom.
      disableVerticalScroll: true,
      disableHorizontalScroll: true,
      supportZoom: false,
      // Required so the one-file bundle can run off file://.
      allowFileAccessFromFileURLs: true,
      allowUniversalAccessFromFileURLs: true,
      javaScriptEnabled: true,
    ),
    onWebViewCreated: _onWebViewCreated,
    onLoadStop: (controller, _) => _flush(controller),
  );

  @override
  Future<void> dispose() async {
    _disposed = true;
    _loaded = false;
    _controller = null;
    await _events.close();
  }

  void _onWebViewCreated(InAppWebViewController controller) {
    if (_disposed) return;
    _controller = controller;
    controller.addJavaScriptHandler(
      handlerName: kChannelName,
      callback: (args) {
        for (final arg in args) {
          final event = decodeWeb3dEvent(arg);
          if (event != null && !_events.isClosed) _events.add(event);
        }
        return null;
      },
    );
  }

  /// Called once the document has run: replays everything queued, in order.
  void _flush(InAppWebViewController controller) {
    if (_disposed) return;
    _loaded = true;
    final pending = List<Web3dCommand>.of(_queued);
    _queued.clear();
    for (final command in pending) {
      unawaited(_evaluate(controller, command));
    }
  }

  Future<void> _evaluate(
    InAppWebViewController controller,
    Web3dCommand command,
  ) {
    // jsonEncode of the already-encoded JSON yields a safely quoted JS string
    // literal, so no payload can break out of the call.
    return controller.evaluateJavascript(
      source:
          'window.$kChannelName && window.$kChannelName.receive(${jsonEncode(command.encode())})',
    );
  }
}
