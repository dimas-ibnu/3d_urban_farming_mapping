import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../l10n/gen/app_localizations.dart';

/// A compass the user drags to set which way the space faces.
///
/// The web has no magnetometer (see the web-vs-app table in
/// `docs/APP_GOAL.md`), so this dial is how a browser user answers the one
/// question the sun engine cannot do without.
///
/// [bearingDeg] is a compass bearing: 0 is north, 90 east, clockwise.
class CompassDial extends StatelessWidget {
  const CompassDial({
    super.key,
    required this.bearingDeg,
    required this.onChanged,
    this.size = 200,
  });

  final double bearingDeg;
  final ValueChanged<double> onChanged;
  final double size;

  void _handle(Offset localPosition) {
    final centre = Offset(size / 2, size / 2);
    final delta = localPosition - centre;
    if (delta.distance < 8) return; // Too close to the pivot to mean anything.
    // Screen y grows downwards and north is up, so the bearing is measured
    // from -y towards +x.
    final degrees = math.atan2(delta.dx, -delta.dy) * 180 / math.pi;
    onChanged((degrees + 360) % 360);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final scheme = Theme.of(context).colorScheme;

    return Semantics(
      slider: true,
      label: l10n.wizardStepFacing,
      value: compassLabel(l10n, bearingDeg),
      child: GestureDetector(
        onPanDown: (details) => _handle(details.localPosition),
        onPanUpdate: (details) => _handle(details.localPosition),
        onTapDown: (details) => _handle(details.localPosition),
        child: CustomPaint(
          size: Size.square(size),
          painter: _CompassPainter(
            bearingDeg: bearingDeg,
            labels: <String>[
              l10n.compassN,
              l10n.compassE,
              l10n.compassS,
              l10n.compassW,
            ],
            dialColor: scheme.surfaceContainerHighest,
            markColor: scheme.outline,
            needleColor: scheme.primary,
            textStyle: TextStyle(
              color: scheme.onSurface,
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ),
    );
  }
}

/// The eight-point compass name for [bearingDeg], e.g. `TL` / `NE`.
String compassLabel(AppLocalizations l10n, double bearingDeg) {
  final names = <String>[
    l10n.compassN,
    l10n.compassNE,
    l10n.compassE,
    l10n.compassSE,
    l10n.compassS,
    l10n.compassSW,
    l10n.compassW,
    l10n.compassNW,
  ];
  final index = (((bearingDeg % 360) + 360) % 360 / 45).round() % 8;
  return names[index];
}

class _CompassPainter extends CustomPainter {
  _CompassPainter({
    required this.bearingDeg,
    required this.labels,
    required this.dialColor,
    required this.markColor,
    required this.needleColor,
    required this.textStyle,
  });

  final double bearingDeg;

  /// North, east, south, west — in that order.
  final List<String> labels;
  final Color dialColor;
  final Color markColor;
  final Color needleColor;
  final TextStyle textStyle;

  @override
  void paint(Canvas canvas, Size size) {
    final centre = size.center(Offset.zero);
    final radius = size.shortestSide / 2;

    canvas.drawCircle(centre, radius, Paint()..color = dialColor);
    canvas.drawCircle(
      centre,
      radius - 1,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..color = markColor,
    );

    // A tick every 15°, longer on the eight named points.
    for (var degrees = 0; degrees < 360; degrees += 15) {
      final major = degrees % 45 == 0;
      final angle = (degrees - 90) * math.pi / 180;
      final direction = Offset(math.cos(angle), math.sin(angle));
      canvas.drawLine(
        centre + direction * (radius - (major ? 14 : 8)),
        centre + direction * (radius - 3),
        Paint()
          ..color = markColor
          ..strokeWidth = major ? 2 : 1,
      );
    }

    for (var quarter = 0; quarter < 4; quarter++) {
      final angle = (quarter * 90 - 90) * math.pi / 180;
      final painter = TextPainter(
        text: TextSpan(text: labels[quarter], style: textStyle),
        textDirection: TextDirection.ltr,
      )..layout();
      final anchor =
          centre + Offset(math.cos(angle), math.sin(angle)) * (radius - 30);
      painter.paint(
        canvas,
        anchor - Offset(painter.width / 2, painter.height / 2),
      );
    }

    final angle = (bearingDeg - 90) * math.pi / 180;
    final direction = Offset(math.cos(angle), math.sin(angle));
    final tip = centre + direction * (radius - 24);
    final side = Offset(-direction.dy, direction.dx) * 10;
    final tail = centre - direction * 12;

    canvas.drawPath(
      Path()
        ..moveTo(tip.dx, tip.dy)
        ..lineTo((tail + side).dx, (tail + side).dy)
        ..lineTo((tail - side).dx, (tail - side).dy)
        ..close(),
      Paint()..color = needleColor,
    );
    canvas.drawCircle(centre, 5, Paint()..color = needleColor);
  }

  @override
  bool shouldRepaint(_CompassPainter oldDelegate) =>
      oldDelegate.bearingDeg != bearingDeg ||
      oldDelegate.labels != labels ||
      oldDelegate.needleColor != needleColor;
}
