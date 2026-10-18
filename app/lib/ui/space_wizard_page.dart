import 'package:flutter/material.dart';

import '../l10n/gen/app_localizations.dart';
import '../location/device_location.dart';
import '../model/project.dart';
import 'compass_dial.dart';
import 'formatting.dart';

/// What the wizard hands back: a space, its name and where it is.
class SpaceDraft {
  const SpaceDraft({required this.name, required this.space, this.location});

  final String name;
  final Space space;
  final GeoLocation? location;
}

/// The manual way into a plan, which on the web is the only way (no AR —
/// see the web-vs-app table in `docs/APP_GOAL.md`).
///
/// Four steps: how big the space is, what stands along its sides, which way it
/// faces, and where on earth it is.
class SpaceWizardPage extends StatefulWidget {
  const SpaceWizardPage({super.key, required this.project});

  /// The plan being edited; its current space seeds every field.
  final Project project;

  @override
  State<SpaceWizardPage> createState() => _SpaceWizardPageState();
}

/// Which edge of the rectangle a barrier sits on.
///
/// North is up in the plan view, so the north edge is the one at the smallest
/// `z` — the same convention the 2D camera uses.
enum _Side { north, east, south, west }

class _SpaceWizardPageState extends State<SpaceWizardPage> {
  final _formKey = GlobalKey<FormState>();

  late final TextEditingController _name = TextEditingController(
    text: widget.project.name,
  );
  late final TextEditingController _width;
  late final TextEditingController _depth;
  late final TextEditingController _height;

  final Map<_Side, BarrierKind?> _sides = <_Side, BarrierKind?>{};
  final Map<_Side, double> _sideHeights = <_Side, double>{};

  late double _facingDeg;
  GeoLocation? _location;
  bool _locationDenied = false;
  bool _locatingNow = false;
  int _step = 0;

  @override
  void initState() {
    super.initState();
    final space = widget.project.space;
    final bounds = space.bounds;
    _width = TextEditingController(text: _initialNumber(bounds.width));
    _depth = TextEditingController(text: _initialNumber(bounds.depth));
    _height = TextEditingController(text: _initialNumber(space.heightM));
    _facingDeg = space.facingDeg;
    _location = widget.project.location;

    for (final side in _Side.values) {
      final existing = _barrierOn(space, side);
      _sides[side] = existing?.kind;
      _sideHeights[side] =
          existing?.heightM ?? _defaultHeight(BarrierKind.wall);
    }
  }

  @override
  void dispose() {
    _name.dispose();
    _width.dispose();
    _depth.dispose();
    _height.dispose();
    super.dispose();
  }

  /// Matches an existing barrier back to the edge it lies on, so reopening the
  /// wizard shows what the user set last time instead of resetting it.
  Barrier? _barrierOn(Space space, _Side side) {
    final bounds = space.bounds;
    bool onEdge(Barrier barrier) => switch (side) {
      _Side.north =>
        _close(barrier.start.z, bounds.min.z) &&
            _close(barrier.end.z, bounds.min.z),
      _Side.south =>
        _close(barrier.start.z, bounds.max.z) &&
            _close(barrier.end.z, bounds.max.z),
      _Side.west =>
        _close(barrier.start.x, bounds.min.x) &&
            _close(barrier.end.x, bounds.min.x),
      _Side.east =>
        _close(barrier.start.x, bounds.max.x) &&
            _close(barrier.end.x, bounds.max.x),
    };
    for (final barrier in space.barriers) {
      if (onEdge(barrier)) return barrier;
    }
    return null;
  }

  static bool _close(double a, double b) => (a - b).abs() < 1e-6;

  static String _initialNumber(double value) =>
      value == value.roundToDouble() ? value.toStringAsFixed(0) : '$value';

  static double _defaultHeight(BarrierKind kind) =>
      kind == BarrierKind.railing ? 1.1 : 2.4;

  double? _parse(TextEditingController controller) =>
      double.tryParse(controller.text.trim().replaceAll(',', '.'));

  double get _widthM => _parse(_width) ?? 2;
  double get _depthM => _parse(_depth) ?? 1.2;
  double get _heightM => _parse(_height) ?? 2.6;

  Space _buildSpace() {
    final halfWidth = _widthM / 2;
    final halfDepth = _depthM / 2;
    final corners = <_Side, (Vec2, Vec2)>{
      _Side.north: (Vec2(-halfWidth, -halfDepth), Vec2(halfWidth, -halfDepth)),
      _Side.east: (Vec2(halfWidth, -halfDepth), Vec2(halfWidth, halfDepth)),
      _Side.south: (Vec2(halfWidth, halfDepth), Vec2(-halfWidth, halfDepth)),
      _Side.west: (Vec2(-halfWidth, halfDepth), Vec2(-halfWidth, -halfDepth)),
    };

    final barriers = <Barrier>[
      for (final side in _Side.values)
        if (_sides[side] case final BarrierKind kind)
          Barrier(
            id: 'barrier-${side.name}',
            kind: kind,
            start: corners[side]!.$1,
            end: corners[side]!.$2,
            // A barrier can never be taller than the room it stands in.
            heightM: (_sideHeights[side] ?? _defaultHeight(kind)).clamp(
              0.1,
              _heightM,
            ),
          ),
    ];

    return Space.rectangle(
      widthM: _widthM,
      depthM: _depthM,
      heightM: _heightM,
      facingDeg: _facingDeg,
      barriers: barriers,
    );
  }

  Future<void> _useDeviceLocation() async {
    setState(() {
      _locatingNow = true;
      _locationDenied = false;
    });
    final fix = await DeviceLocation.current();
    if (!mounted) return;
    setState(() {
      _locatingNow = false;
      _locationDenied = fix == null;
      if (fix != null) _location = fix;
    });
  }

  void _save() {
    if (!(_formKey.currentState?.validate() ?? false)) {
      // The invalid field is on the size step; send the user back to it.
      setState(() => _step = 0);
      return;
    }
    Navigator.of(context).pop(
      SpaceDraft(
        name: _name.text.trim().isEmpty
            ? widget.project.name
            : _name.text.trim(),
        space: _buildSpace(),
        location: _location,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    return Scaffold(
      appBar: AppBar(title: Text(l10n.wizardTitle)),
      body: Form(
        key: _formKey,
        child: Stepper(
          currentStep: _step,
          onStepTapped: (step) => setState(() => _step = step),
          onStepContinue: () => _step == _Step.values.length - 1
              ? _save()
              : setState(() => _step += 1),
          onStepCancel: _step == 0 ? null : () => setState(() => _step -= 1),
          // `Stepper` builds the controls for every step, not just the open
          // one, so the label has to come from `details.stepIndex` — keying it
          // off `_step` would put a "save" button under all four.
          controlsBuilder: (context, details) {
            final isLast = details.stepIndex == _Step.values.length - 1;
            return Padding(
              padding: const EdgeInsets.only(top: 12),
              child: Row(
                children: [
                  FilledButton(
                    key: Key('wizard-continue-${details.stepIndex}'),
                    onPressed: details.onStepContinue,
                    child: Text(isLast ? l10n.wizardSave : l10n.wizardNext),
                  ),
                  if (details.stepIndex > 0) ...[
                    const SizedBox(width: 8),
                    TextButton(
                      onPressed: details.onStepCancel,
                      child: Text(l10n.wizardBack),
                    ),
                  ],
                ],
              ),
            );
          },
          steps: <Step>[
            Step(
              title: Text(l10n.wizardStepSize),
              isActive: _step >= 0,
              content: _sizeStep(l10n),
            ),
            Step(
              title: Text(l10n.wizardStepBarriers),
              isActive: _step >= 1,
              content: _barrierStep(l10n),
            ),
            Step(
              title: Text(l10n.wizardStepFacing),
              isActive: _step >= 2,
              content: _facingStep(l10n),
            ),
            Step(
              title: Text(l10n.wizardStepLocation),
              isActive: _step >= 3,
              content: _locationStep(l10n),
            ),
          ],
        ),
      ),
    );
  }

  Widget _sizeStep(AppLocalizations l10n) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TextFormField(
          controller: _name,
          decoration: InputDecoration(labelText: l10n.fieldSpaceName),
          textInputAction: TextInputAction.next,
        ),
        const SizedBox(height: 12),
        _numberField(l10n, _width, l10n.fieldWidth, const Key('field-width')),
        const SizedBox(height: 12),
        _numberField(l10n, _depth, l10n.fieldDepth, const Key('field-depth')),
        const SizedBox(height: 12),
        _numberField(
          l10n,
          _height,
          l10n.fieldCeilingHeight,
          const Key('field-height'),
        ),
        const SizedBox(height: 12),
        Text(
          l10n.floorAreaPreview(formatNumber(context, _widthM * _depthM)),
          key: const Key('wizard-floor-area'),
          style: Theme.of(context).textTheme.bodyMedium,
        ),
      ],
    );
  }

  Widget _numberField(
    AppLocalizations l10n,
    TextEditingController controller,
    String label,
    Key key,
  ) => TextFormField(
    key: key,
    controller: controller,
    decoration: InputDecoration(labelText: label),
    keyboardType: const TextInputType.numberWithOptions(decimal: true),
    onChanged: (_) => setState(() {}),
    validator: (value) {
      final parsed = double.tryParse((value ?? '').trim().replaceAll(',', '.'));
      return parsed == null || parsed <= 0 ? l10n.errorPositiveNumber : null;
    },
  );

  Widget _barrierStep(AppLocalizations l10n) {
    String sideName(_Side side) => switch (side) {
      _Side.north => l10n.barrierSideNorth,
      _Side.east => l10n.barrierSideEast,
      _Side.south => l10n.barrierSideSouth,
      _Side.west => l10n.barrierSideWest,
    };

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(l10n.barrierHint, style: Theme.of(context).textTheme.bodySmall),
        const SizedBox(height: 8),
        for (final side in _Side.values)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Row(
              children: [
                Expanded(flex: 3, child: Text(sideName(side))),
                Expanded(
                  flex: 4,
                  child: DropdownButtonFormField<BarrierKind?>(
                    key: Key('barrier-${side.name}'),
                    initialValue: _sides[side],
                    decoration: const InputDecoration(isDense: true),
                    items: <DropdownMenuItem<BarrierKind?>>[
                      DropdownMenuItem(child: Text(l10n.barrierNone)),
                      for (final kind in BarrierKind.values)
                        DropdownMenuItem(
                          value: kind,
                          child: Text(barrierKindName(l10n, kind)),
                        ),
                    ],
                    onChanged: (kind) => setState(() {
                      _sides[side] = kind;
                      if (kind != null) {
                        _sideHeights[side] = _defaultHeight(kind);
                      }
                    }),
                  ),
                ),
                if (_sides[side] != null) ...[
                  const SizedBox(width: 8),
                  Expanded(
                    flex: 3,
                    child: TextFormField(
                      key: Key('barrier-height-${side.name}'),
                      initialValue: '${_sideHeights[side]}',
                      decoration: InputDecoration(
                        labelText: l10n.fieldBarrierHeight,
                        isDense: true,
                      ),
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      onChanged: (value) {
                        final parsed = double.tryParse(
                          value.trim().replaceAll(',', '.'),
                        );
                        if (parsed != null && parsed > 0) {
                          _sideHeights[side] = parsed;
                        }
                      },
                    ),
                  ),
                ],
              ],
            ),
          ),
      ],
    );
  }

  Widget _facingStep(AppLocalizations l10n) => Column(
    children: [
      Text(l10n.facingHint, style: Theme.of(context).textTheme.bodySmall),
      const SizedBox(height: 12),
      CompassDial(
        bearingDeg: _facingDeg,
        onChanged: (degrees) => setState(() => _facingDeg = degrees),
      ),
      const SizedBox(height: 12),
      Text(
        l10n.facingValue(
          formatNumber(context, _facingDeg, digits: 0),
          compassLabel(l10n, _facingDeg),
        ),
        key: const Key('wizard-facing'),
        style: Theme.of(context).textTheme.titleMedium,
      ),
    ],
  );

  Widget _locationStep(AppLocalizations l10n) {
    final location = _location;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(l10n.locationHint, style: Theme.of(context).textTheme.bodySmall),
        const SizedBox(height: 12),
        DropdownButtonFormField<GeoLocation>(
          key: const Key('city-picker'),
          initialValue: kIndonesianCities.contains(location) ? location : null,
          decoration: InputDecoration(labelText: l10n.locationCity),
          items: [
            for (final city in kIndonesianCities)
              DropdownMenuItem(value: city, child: Text(city.label!)),
          ],
          onChanged: (city) => setState(() {
            _location = city;
            _locationDenied = false;
          }),
        ),
        if (DeviceLocation.supported) ...[
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: _locatingNow ? null : _useDeviceLocation,
            icon: const Icon(Icons.my_location),
            label: Text(l10n.locationUseDevice),
          ),
        ],
        if (_locationDenied)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text(
              l10n.locationDenied,
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
          ),
        const SizedBox(height: 12),
        Text(
          key: const Key('wizard-location'),
          location == null
              ? l10n.locationUnset
              : location.label ??
                    l10n.locationCoordinates(
                      formatNumber(context, location.latitude, digits: 4),
                      formatNumber(context, location.longitude, digits: 4),
                    ),
          style: Theme.of(context).textTheme.titleMedium,
        ),
      ],
    );
  }
}

/// The wizard's steps, in order. Only the count is used, but naming them keeps
/// the "is this the last step?" checks honest when one is added.
enum _Step { size, barriers, facing, location }
