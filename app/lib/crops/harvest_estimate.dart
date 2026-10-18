import 'dart:math' as math;

import 'crop.dart';

/// Days in a month for harvest estimates. Rough on purpose.
const int kDaysPerMonth = 30;

/// Some plants of one crop in a plan.
class Placement {
  const Placement({required this.crop, required this.plants})
    : assert(plants >= 0);

  final Crop crop;

  /// Number of plants (not pots). A pot holds [Crop.plantsPerPot].
  final int plants;
}

/// The expected harvest of one crop across all its placements.
class HarvestLine {
  const HarvestLine({required this.crop, required this.plants});

  final Crop crop;
  final int plants;

  /// Grams per month once the crop is producing.
  double get gramsPerMonth => plants * crop.yieldGramsPerPlantPerMonth;

  /// Grams harvested in [month] after planting, counting from 1, taking the
  /// wait for the first harvest into account.
  double gramsInMonth(int month) {
    final start = (month - 1) * kDaysPerMonth;
    final end = month * kDaysPerMonth;
    final producingDays =
        math.max(0, end - math.max(start, crop.daysToFirstHarvest)) /
        kDaysPerMonth;
    return gramsPerMonth * math.min(1.0, producingDays);
  }
}

/// The expected harvest of a whole plan.
class HarvestEstimate {
  const HarvestEstimate(this.lines);

  /// One line per crop, in the order each crop first appears.
  final List<HarvestLine> lines;

  /// Grams per month once every crop is producing.
  double get gramsPerMonth =>
      lines.fold(0, (sum, line) => sum + line.gramsPerMonth);

  /// Grams harvested in [month] after planting, counting from 1.
  double gramsInMonth(int month) {
    if (month < 1) throw RangeError.value(month, 'month', 'starts at 1');
    return lines.fold(0, (sum, line) => sum + line.gramsInMonth(month));
  }
}

/// Estimates the monthly harvest of [placements], merging placements of the
/// same crop and dropping crops with no plants.
HarvestEstimate estimateHarvest(Iterable<Placement> placements) {
  final crops = <String, Crop>{};
  final plants = <String, int>{};
  for (final placement in placements) {
    if (placement.plants <= 0) continue;
    final id = placement.crop.id;
    crops.putIfAbsent(id, () => placement.crop);
    plants.update(
      id,
      (n) => n + placement.plants,
      ifAbsent: () => placement.plants,
    );
  }
  return HarvestEstimate(
    List.unmodifiable([
      for (final id in crops.keys)
        HarvestLine(crop: crops[id]!, plants: plants[id]!),
    ]),
  );
}
