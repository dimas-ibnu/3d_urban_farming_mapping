import 'package:flutter/material.dart';

import '../bridge/web3d_bridge.dart';
import '../l10n/gen/app_localizations.dart';
import '../model/project.dart';
import '../state/project_controller.dart';
import 'formatting.dart';
import 'space_wizard_page.dart';

/// The layout planner: the Three.js scene with a Flutter panel beside it.
///
/// The panel is the only way to add an item; everything after that — moving,
/// selecting — happens in the scene and comes back through the bridge. The
/// controller owns the plan, so both halves always show the same thing.
class EditorPage extends StatefulWidget {
  const EditorPage({super.key, this.bridge, this.project});

  /// Injected by widget tests; production builds pick the platform transport.
  final Web3dBridge? bridge;

  /// Seeds the editor with an existing plan. Defaults to an empty balcony.
  final Project? project;

  @override
  State<EditorPage> createState() => _EditorPageState();
}

class _EditorPageState extends State<EditorPage> {
  late final ProjectController _controller = ProjectController(
    bridge: widget.bridge ?? Web3dBridge.create(),
    project: widget.project,
  );

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _editSpace() async {
    final draft = await Navigator.of(context).push<SpaceDraft>(
      MaterialPageRoute(
        builder: (_) => SpaceWizardPage(project: _controller.project),
      ),
    );
    if (draft == null) return;
    _controller
      ..rename(draft.name)
      ..setSpace(draft.space)
      ..setLocation(draft.location);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        final fps = _controller.fps;
        return Scaffold(
          appBar: AppBar(
            title: Text(_controller.project.name),
            actions: [
              if (fps != null)
                Center(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    child: Text(l10n.fpsLabel(fps)),
                  ),
                ),
              _ViewToggle(
                view: _controller.view,
                onChanged: _controller.setView,
              ),
              IconButton(
                tooltip: l10n.editSpace,
                onPressed: _editSpace,
                icon: const Icon(Icons.straighten),
              ),
            ],
          ),
          body: SafeArea(
            child: LayoutBuilder(
              builder: (context, constraints) {
                final scene = _SceneSurface(controller: _controller);
                final panel = _EditorPanel(
                  controller: _controller,
                  onEditSpace: _editSpace,
                );
                // Side by side where there is room, stacked on a phone.
                return constraints.maxWidth >= 900
                    ? Row(
                        // Stretch, or the panel shrink-wraps its content and
                        // floats in the middle of a tall window.
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Expanded(child: scene),
                          SizedBox(
                            width: 340,
                            child: Material(
                              elevation: 1,
                              child: SingleChildScrollView(child: panel),
                            ),
                          ),
                        ],
                      )
                    : Column(
                        children: [
                          Expanded(flex: 3, child: scene),
                          Expanded(
                            flex: 2,
                            child: SingleChildScrollView(child: panel),
                          ),
                        ],
                      );
              },
            ),
          ),
        );
      },
    );
  }
}

/// The scene, or an explanation when it could not start.
class _SceneSurface extends StatelessWidget {
  const _SceneSurface({required this.controller});

  final ProjectController controller;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final error = controller.sceneError;

    // The canvas stays mounted underneath: a WebGL failure is often a one-off
    // (a tab restored without a GPU process), and remounting the iframe to
    // retry would lose the queued commands.
    return Stack(
      fit: StackFit.expand,
      children: [
        controller.sceneView,
        if (error != null)
          ColoredBox(
            color: Theme.of(context).colorScheme.surface,
            child: Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  key: const Key('scene-unavailable'),
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.view_in_ar_outlined,
                      size: 48,
                      color: Theme.of(context).colorScheme.outline,
                    ),
                    const SizedBox(height: 12),
                    Text(
                      l10n.sceneUnavailableTitle,
                      style: Theme.of(context).textTheme.titleMedium,
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      l10n.sceneUnavailableBody,
                      style: Theme.of(context).textTheme.bodyMedium,
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      l10n.sceneUnavailableDetail(error),
                      style: Theme.of(context).textTheme.bodySmall,
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            ),
          ),
      ],
    );
  }
}

class _ViewToggle extends StatelessWidget {
  const _ViewToggle({required this.view, required this.onChanged});

  final SceneView view;
  final ValueChanged<SceneView> onChanged;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
      child: SegmentedButton<SceneView>(
        showSelectedIcon: false,
        segments: <ButtonSegment<SceneView>>[
          ButtonSegment(value: SceneView.plan2d, label: Text(l10n.view2d)),
          ButtonSegment(value: SceneView.orbit3d, label: Text(l10n.view3d)),
        ],
        selected: <SceneView>{view},
        onSelectionChanged: (selection) => onChanged(selection.first),
      ),
    );
  }
}

/// Palette, growing-area summary and the selected item's settings.
class _EditorPanel extends StatelessWidget {
  const _EditorPanel({required this.controller, required this.onEditSpace});

  final ProjectController controller;
  final VoidCallback onEditSpace;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            _statusText(l10n),
            key: const Key('scene-status'),
            style: theme.textTheme.bodySmall,
          ),
          const SizedBox(height: 8),
          _GrowingAreaCard(controller: controller),
          const SizedBox(height: 12),
          Text(l10n.paletteTitle, style: theme.textTheme.titleSmall),
          const SizedBox(height: 6),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final type in ItemType.values)
                ActionChip(
                  key: Key('add-${type.name}'),
                  avatar: Icon(itemTypeIcon(type), size: 18),
                  label: Text(itemTypeName(l10n, type)),
                  onPressed: () => controller.addItem(type),
                ),
            ],
          ),
          const SizedBox(height: 12),
          _IssueSummary(controller: controller),
          const Divider(height: 24),
          _SelectionPanel(controller: controller),
          const Divider(height: 24),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            dense: true,
            title: Text(l10n.toggleOverlay, style: theme.textTheme.bodyMedium),
            value: controller.debugOverlay,
            onChanged: (visible) =>
                controller.setDebugOverlay(visible: visible),
          ),
          OutlinedButton.icon(
            onPressed: onEditSpace,
            icon: const Icon(Icons.straighten),
            label: Text(l10n.editSpace),
          ),
        ],
      ),
    );
  }

  String _statusText(AppLocalizations l10n) {
    final error = controller.sceneError;
    if (error != null) return l10n.statusError(error);
    if (!controller.ready) return l10n.statusConnecting;
    final selected = controller.selectedItem;
    if (selected != null) {
      return l10n.statusSelected(itemTypeName(l10n, selected.type));
    }
    return l10n.statusReady;
  }
}

/// "2 m² lantai → 5,4 m² area tanam" — the number the planner exists for.
class _GrowingAreaCard extends StatelessWidget {
  const _GrowingAreaCard({required this.controller});

  final ProjectController controller;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final summary = controller.growingArea;

    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(l10n.growingAreaTitle, style: theme.textTheme.labelMedium),
            const SizedBox(height: 4),
            Text(
              l10n.growingAreaSummary(
                formatNumber(context, summary.floorAreaM2),
                formatNumber(context, summary.growingAreaM2),
              ),
              key: const Key('growing-area-summary'),
              style: theme.textTheme.titleMedium,
            ),
            const SizedBox(height: 4),
            Text(
              l10n.growingAreaMultiplier(
                formatNumber(context, summary.multiplier),
              ),
              style: theme.textTheme.bodySmall,
            ),
            Text(
              l10n.freeFloor(formatNumber(context, summary.freeFloorM2)),
              style: theme.textTheme.bodySmall,
            ),
            const SizedBox(height: 4),
            Text(
              l10n.itemCount(controller.items.length),
              style: theme.textTheme.bodySmall,
            ),
          ],
        ),
      ),
    );
  }
}

class _IssueSummary extends StatelessWidget {
  const _IssueSummary({required this.controller});

  final ProjectController controller;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final issues = controller.issues;

    if (issues.isEmpty) {
      return Text(
        l10n.layoutOk,
        key: const Key('layout-issues'),
        style: theme.textTheme.bodySmall,
      );
    }
    return Column(
      key: const Key('layout-issues'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          l10n.layoutIssueCount(issues.length),
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.error,
          ),
        ),
        for (final issue in issues)
          InkWell(
            onTap: () => controller.select(issue.itemId),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 2),
              child: Text(
                '• ${layoutProblemText(l10n, issue.problem)}',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.error,
                ),
              ),
            ),
          ),
      ],
    );
  }
}

/// Settings for whatever is selected: levels, rotation, mounting height.
class _SelectionPanel extends StatelessWidget {
  const _SelectionPanel({required this.controller});

  final ProjectController controller;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final item = controller.selectedItem;

    if (item == null) {
      return Text(
        l10n.selectionNone,
        key: const Key('selection-panel'),
        style: theme.textTheme.bodySmall,
      );
    }

    return Column(
      key: const Key('selection-panel'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Icon(itemTypeIcon(item.type), size: 18),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                itemTypeName(l10n, item.type),
                style: theme.textTheme.titleSmall,
              ),
            ),
            IconButton(
              key: const Key('remove-item'),
              tooltip: l10n.removeItem,
              onPressed: () => controller.removeItem(item.id),
              icon: const Icon(Icons.delete_outline),
            ),
          ],
        ),
        if (item.type == ItemType.verticalRack)
          _SliderRow(
            label: l10n.fieldLevels,
            value: item.levels.toDouble(),
            min: 1,
            max: 6,
            divisions: 5,
            valueLabel: '${item.levels}',
            onChanged: (value) =>
                controller.updateItem(item.copyWith(levels: value.round())),
          ),
        if (item.type != ItemType.wallPlanter)
          _SliderRow(
            label: l10n.fieldRotation,
            value: item.rotationDeg,
            min: 0,
            max: 345,
            divisions: 23,
            valueLabel: l10n.degreeValue(
              formatNumber(context, item.rotationDeg, digits: 0),
            ),
            onChanged: (value) =>
                controller.updateItem(item.copyWith(rotationDeg: value)),
          ),
        if (item.type.isElevated)
          _SliderRow(
            label: l10n.fieldMountHeight,
            value: item.mountHeightM.clamp(
              0.2,
              controller.space.heightM.clamp(0.4, 4.0),
            ),
            min: 0.2,
            max: controller.space.heightM.clamp(0.4, 4.0),
            divisions: 24,
            valueLabel: l10n.metreValue(
              formatNumber(context, item.mountHeightM, digits: 2),
            ),
            onChanged: (value) =>
                controller.updateItem(item.copyWith(mountHeightM: value)),
          ),
        for (final issue in controller.issuesFor(item.id))
          Text(
            layoutProblemText(l10n, issue.problem),
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.error,
            ),
          ),
      ],
    );
  }
}

class _SliderRow extends StatelessWidget {
  const _SliderRow({
    required this.label,
    required this.value,
    required this.min,
    required this.max,
    required this.divisions,
    required this.valueLabel,
    required this.onChanged,
  });

  final String label;
  final double value;
  final double min;
  final double max;
  final int divisions;
  final String valueLabel;
  final ValueChanged<double> onChanged;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      children: [
        SizedBox(
          width: 108,
          child: Text(label, style: theme.textTheme.bodySmall),
        ),
        Expanded(
          child: Slider(
            value: value.clamp(min, max),
            min: min,
            max: max,
            divisions: divisions,
            label: valueLabel,
            onChanged: onChanged,
          ),
        ),
        SizedBox(
          width: 52,
          child: Text(
            valueLabel,
            style: theme.textTheme.bodySmall,
            textAlign: TextAlign.end,
          ),
        ),
      ],
    );
  }
}
