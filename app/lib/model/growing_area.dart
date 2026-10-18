import 'item.dart';
import 'space.dart';

/// Floor area against the growing area a layout actually yields.
///
/// This is the number the planner exists to improve: stacking a rack four
/// levels high turns 0.32 m² of floor into 1.28 m² of growing area.
class GrowingAreaSummary {
  const GrowingAreaSummary({
    required this.floorAreaM2,
    required this.growingAreaM2,
    required this.floorUsedM2,
  });

  factory GrowingAreaSummary.of(Space space, Iterable<PlacedItem> items) {
    var growing = 0.0;
    var used = 0.0;
    for (final item in items) {
      growing += item.growingAreaM2;
      if (item.type.occupiesFloor) used += item.size.footprintM2;
    }
    return GrowingAreaSummary(
      floorAreaM2: space.floorAreaM2,
      growingAreaM2: growing,
      floorUsedM2: used,
    );
  }

  /// The space's own floor area.
  final double floorAreaM2;

  /// Total growing area, counting every rack level and every planter.
  final double growingAreaM2;

  /// Floor taken up by items standing on it.
  final double floorUsedM2;

  /// How many times over the floor area the layout grows, `0` for an empty
  /// floor plan with no area to multiply.
  double get multiplier => floorAreaM2 <= 0 ? 0 : growingAreaM2 / floorAreaM2;

  double get freeFloorM2 {
    final free = floorAreaM2 - floorUsedM2;
    return free < 0 ? 0 : free;
  }
}
