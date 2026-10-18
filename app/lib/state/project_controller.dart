import 'dart:async';

import 'package:flutter/widgets.dart';

import '../bridge/web3d_bridge.dart';
import '../model/project.dart';

/// Owns the project and keeps the Three.js scene in step with it.
///
/// Everything the editor shows comes from here, and every change goes through
/// here: the scene is a view, never a second source of truth. An `itemMoved`
/// event from the scene is applied, snapped and validated in Dart, then echoed
/// back — so the scene's optimistic position is always corrected by the app's.
class ProjectController extends ChangeNotifier {
  ProjectController({required this.bridge, Project? project})
    : _project = project ?? Project.empty() {
    _subscription = bridge.events.listen(_onEvent);
    _pushProject();
    _revalidate(notify: false);
  }

  /// The transport to the scene. Public so a test can hand in a fake.
  final Web3dBridge bridge;

  late final StreamSubscription<Web3dEvent> _subscription;

  Project _project;
  String? _selectedId;
  SceneView _view = SceneView.orbit3d;
  List<LayoutIssue> _issues = const <LayoutIssue>[];
  bool _ready = false;
  bool _debugOverlay = false;
  int? _fps;
  String? _sceneError;
  int _nextItemNumber = 1;

  Project get project => _project;
  Space get space => _project.space;
  List<PlacedItem> get items => _project.items;
  GrowingAreaSummary get growingArea => _project.growingArea;

  String? get selectedId => _selectedId;
  PlacedItem? get selectedItem =>
      _selectedId == null ? null : _project.itemById(_selectedId!);

  SceneView get view => _view;
  List<LayoutIssue> get issues => _issues;
  bool get ready => _ready;
  bool get debugOverlay => _debugOverlay;
  int? get fps => _fps;

  /// Set when the scene could not start — no WebGL, or a protocol mismatch.
  /// The editor shows an explanation over the canvas instead of a dead frame.
  String? get sceneError => _sceneError;

  /// The widget hosting the scene.
  Widget get sceneView => bridge.view;

  List<LayoutIssue> issuesFor(String itemId) =>
      _issues.where((issue) => issue.itemId == itemId).toList();

  // --- edits -----------------------------------------------------------------

  void setSpace(Space space) {
    _project = _project.copyWith(space: space);
    // Walls may have moved out from under the planters hanging on them.
    _project = _project.copyWith(
      items: [for (final item in _project.items) snapToWall(space, item)],
    );
    unawaited(bridge.send(SetSpace(space)));
    for (final item in _project.items) {
      unawaited(bridge.send(UpsertItem(item)));
    }
    _revalidate();
  }

  void setLocation(GeoLocation? location) {
    _project = location == null
        ? _project.copyWith(clearLocation: true)
        : _project.copyWith(location: location);
    notifyListeners();
  }

  void rename(String name) {
    _project = _project.copyWith(name: name);
    notifyListeners();
  }

  /// Adds an item of [type] at the first free spot, and selects it.
  void addItem(ItemType type) {
    final id = '${type.name}-${_nextItemNumber++}';
    final draft = PlacedItem.defaults(id: id, type: type);
    final placed = snapToWall(
      space,
      draft.copyWith(position: _freeSpotFor(draft)),
    );
    _project = _project.upsertItem(placed);
    unawaited(bridge.send(UpsertItem(placed)));
    _select(placed.id);
    _revalidate();
  }

  void updateItem(PlacedItem item) {
    final snapped = snapToWall(space, item);
    _project = _project.upsertItem(snapped);
    unawaited(bridge.send(UpsertItem(snapped)));
    _revalidate();
  }

  void removeItem(String id) {
    _project = _project.removeItem(id);
    unawaited(bridge.send(RemoveItem(id)));
    if (_selectedId == id) _select(null);
    _revalidate();
  }

  void select(String? id) {
    if (_selectedId == id) return;
    _select(id);
    unawaited(bridge.send(SetSelection(id)));
    notifyListeners();
  }

  void setView(SceneView view) {
    if (_view == view) return;
    _view = view;
    unawaited(bridge.send(SetView(view)));
    notifyListeners();
  }

  void setDebugOverlay({required bool visible}) {
    _debugOverlay = visible;
    if (!visible) _fps = null;
    unawaited(bridge.send(SetDebugOverlay(visible: visible)));
    notifyListeners();
  }

  /// Replaces the whole plan — what the space wizard hands back.
  void replaceProject(Project project) {
    _project = project;
    _selectedId = null;
    unawaited(bridge.send(const ClearItems()));
    _pushProject();
    _revalidate();
  }

  @override
  void dispose() {
    unawaited(_subscription.cancel());
    unawaited(bridge.dispose());
    super.dispose();
  }

  // --- scene events ----------------------------------------------------------

  void _onEvent(Web3dEvent event) {
    switch (event) {
      case SceneReady(:final protocol):
        _ready = true;
        _sceneError = protocol == kProtocolVersion
            ? null
            : 'protocol v$protocol != v$kProtocolVersion';
        // The scene starts empty on a reload; replay the plan into it.
        _pushProject();
        _revalidate();
      case ItemSelected(:final id):
        _select(id);
        notifyListeners();
      case ItemMoved(:final id, :final position, :final mountHeightM):
        _applyMove(id, position, mountHeightM);
      case SceneFps(:final value):
        _fps = value;
        notifyListeners();
      case SceneError(:final message):
        _sceneError = message;
        notifyListeners();
      case ScenePong():
        break;
    }
  }

  /// The scene asks; Dart decides.
  ///
  /// The move is accepted even when it breaks a rule — the user is mid-thought
  /// and an item that snaps back is maddening — but it is snapped to a wall if
  /// it is a wall planter, and flagged so both sides show it in red.
  void _applyMove(String id, Vec2 position, double? mountHeightM) {
    final item = _project.itemById(id);
    if (item == null) return;
    final moved = snapToWall(
      space,
      item.copyWith(
        position: position,
        mountHeightM: mountHeightM ?? item.mountHeightM,
      ),
    );
    _project = _project.upsertItem(moved);
    // Always echo: the scene moved it optimistically and only this tells it
    // where the item really ended up.
    unawaited(bridge.send(UpsertItem(moved)));
    _select(id);
    _revalidate();
  }

  // --- plumbing --------------------------------------------------------------

  void _select(String? id) => _selectedId = id;

  void _pushProject() {
    unawaited(bridge.send(SetSpace(space)));
    for (final item in _project.items) {
      unawaited(bridge.send(UpsertItem(item)));
    }
    unawaited(bridge.send(SetView(_view)));
    unawaited(bridge.send(SetSelection(_selectedId)));
  }

  void _revalidate({bool notify = true}) {
    _issues = validateLayout(space, _project.items);
    unawaited(
      bridge.send(
        SetInvalidItems(_issues.map((issue) => issue.itemId).toSet().toList()),
      ),
    );
    if (notify) notifyListeners();
  }

  /// Scans the floor on a 10 cm grid for the first spot where [item] fits.
  ///
  /// Falls back to the centre of the space when the floor is full: the item is
  /// then flagged as overlapping, which is clearer than silently refusing to
  /// add it.
  Vec2 _freeSpotFor(PlacedItem item) {
    final bounds = space.bounds;
    const step = 0.1;
    for (var z = bounds.min.z; z <= bounds.max.z; z += step) {
      for (var x = bounds.min.x; x <= bounds.max.x; x += step) {
        final candidate = item.copyWith(position: Vec2(x, z));
        final snapped = snapToWall(space, candidate);
        if (validateItem(space, snapped, _project.items).isEmpty) {
          return snapped.position;
        }
      }
    }
    return bounds.centre;
  }
}
