import 'dart:async';

import 'package:flutter/material.dart';

import 'bridge/web3d_bridge.dart';
import 'l10n/gen/app_localizations.dart';

/// The bridge prototype: a Three.js balcony with pots, driven from Dart.
///
/// This page exists to prove the round trip end to end — Flutter sends
/// `addPot`, the scene renders it, and the scene answers with `ready` and
/// `selected`. The real editor (work item #4) replaces it.
class ScenePage extends StatefulWidget {
  const ScenePage({super.key, this.bridge});

  final Web3dBridge? bridge;

  @override
  State<ScenePage> createState() => _ScenePageState();
}

class _ScenePageState extends State<ScenePage> {
  static const double _floorWidth = 2.0;
  static const double _floorDepth = 1.2;

  late final Web3dBridge _bridge = widget.bridge ?? Web3dBridge.create();
  late final StreamSubscription<Web3dEvent> _subscription;

  final List<String> _potIds = <String>[];

  bool _ready = false;
  bool _overlayVisible = false;
  int _protocol = kProtocolVersion;
  int? _fps;
  String? _selectedId;
  String? _error;
  int _nextPotId = 0;

  @override
  void initState() {
    super.initState();
    _subscription = _bridge.events.listen(_onEvent);

    // Queued by the bridge until the scene is up, so no handshake wait here.
    unawaited(
      _bridge.send(const SetFloor(width: _floorWidth, depth: _floorDepth)),
    );
    _addPot();
  }

  @override
  void dispose() {
    unawaited(_subscription.cancel());
    unawaited(_bridge.dispose());
    super.dispose();
  }

  void _onEvent(Web3dEvent event) {
    if (!mounted) return;
    setState(() {
      switch (event) {
        case SceneReady(:final protocol):
          _ready = true;
          _protocol = protocol;
          _error = null;
        case PotSelected(:final id):
          _selectedId = id;
        case SceneFps(:final value):
          _fps = value;
        case SceneError(:final message):
          _error = message;
        case ScenePong():
          break;
      }
    });
  }

  void _addPot() {
    final id = 'pot-${_nextPotId++}';
    // Lay pots out along the balcony rail, wrapping into a second row.
    final index = _potIds.length;
    const perRow = 5;
    final x = -_floorWidth / 2 + 0.3 + (index % perRow) * 0.35;
    final z = -_floorDepth / 2 + 0.3 + (index ~/ perRow) * 0.4;

    _potIds.add(id);
    unawaited(_bridge.send(AddPot(id: id, x: x, z: z)));
    setState(() {});
  }

  void _clearPots() {
    _potIds.clear();
    _selectedId = null;
    unawaited(_bridge.send(const ClearPots()));
    setState(() {});
  }

  void _toggleOverlay(bool visible) {
    _overlayVisible = visible;
    unawaited(_bridge.send(SetDebugOverlay(visible: visible)));
    setState(() {});
  }

  String _statusText(AppLocalizations l10n) {
    final error = _error;
    if (error != null) return l10n.statusError(error);
    if (!_ready) return l10n.statusConnecting;
    final selected = _selectedId;
    if (selected != null) return l10n.statusSelected(selected);
    return l10n.statusReady(_protocol);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final fps = _fps;

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.sceneTabTitle),
        actions: [
          if (fps != null)
            Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: Text(l10n.fpsLabel(fps)),
              ),
            ),
        ],
      ),
      body: Column(
        children: [
          Expanded(child: _bridge.view),
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    _statusText(l10n),
                    key: const Key('scene-status'),
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                  const SizedBox(height: 4),
                  Text(l10n.potCount(_potIds.length)),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text(l10n.toggleOverlay),
                    value: _overlayVisible,
                    onChanged: _toggleOverlay,
                  ),
                  Row(
                    children: [
                      Expanded(
                        child: FilledButton.icon(
                          onPressed: _addPot,
                          icon: const Icon(Icons.add),
                          label: Text(l10n.addPot),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: _potIds.isEmpty ? null : _clearPots,
                          icon: const Icon(Icons.delete_outline),
                          label: Text(l10n.clearPots),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
