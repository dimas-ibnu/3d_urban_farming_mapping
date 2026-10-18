import 'dart:math' as math;

import 'crop.dart';
import 'crop_database.dart';

/// A place where something could be planted, described with plain values so
/// it does not depend on the editor's model.
class Spot {
  const Spot({
    required this.sunHours,
    required this.container,
    this.potDepthCm,
    this.potVolumeLiters,
  }) : assert(sunHours >= 0);

  /// Hours of direct sun per day, e.g. from the sun map.
  final double sunHours;

  final ContainerType container;

  /// Soil depth of the container in centimetres, or `null` when unknown.
  /// An unknown size is not checked.
  final double? potDepthCm;

  /// Soil volume of the container in litres, or `null` when unknown.
  final double? potVolumeLiters;
}

/// Why a crop fits a spot less than perfectly.
///
/// Carries the numbers rather than text so the UI can phrase it in the
/// user's language; see `describeFitReason` in `crop_l10n.dart`.
sealed class FitReason {
  const FitReason();

  /// Whether the crop is not expected to grow at the spot at all, as
  /// opposed to growing less well.
  bool get isBlocking;
}

/// The spot gets less sun than the crop's minimum.
class NotEnoughSun extends FitReason {
  const NotEnoughSun({required this.requiredHours, required this.actualHours});

  final double requiredHours;
  final double actualHours;

  @override
  bool get isBlocking => true;
}

/// The spot gets enough sun to grow the crop, but less than it likes.
class BelowIdealSun extends FitReason {
  const BelowIdealSun({required this.idealHours, required this.actualHours});

  final double idealHours;
  final double actualHours;

  @override
  bool get isBlocking => false;
}

/// The spot gets more sun than the crop tolerates in the tropical heat.
class TooMuchSun extends FitReason {
  const TooMuchSun({required this.maxHours, required this.actualHours});

  final double maxHours;
  final double actualHours;

  @override
  bool get isBlocking => false;
}

/// The crop does not grow well in this kind of container.
class ContainerNotSuitable extends FitReason {
  const ContainerNotSuitable(this.container);

  final ContainerType container;

  @override
  bool get isBlocking => true;
}

/// The container is shallower than the crop's roots need.
class PotTooShallow extends FitReason {
  const PotTooShallow({required this.requiredCm, required this.actualCm});

  final double requiredCm;
  final double actualCm;

  @override
  bool get isBlocking => true;
}

/// The container holds less soil than the crop needs.
class PotTooSmall extends FitReason {
  const PotTooSmall({required this.requiredLiters, required this.actualLiters});

  final double requiredLiters;
  final double actualLiters;

  @override
  bool get isBlocking => true;
}

/// How well one crop fits a spot.
class CropSuggestion {
  const CropSuggestion({
    required this.crop,
    required this.score,
    required this.reasons,
  });

  final Crop crop;

  /// Fit from 0 (hopeless) to 1 (ideal). Only meaningful for ranking.
  final double score;

  /// Everything that keeps the fit from being ideal; empty for an ideal fit.
  final List<FitReason> reasons;

  /// Whether the crop is expected to grow at the spot.
  bool get isSuitable => !reasons.any((r) => r.isBlocking);
}

/// Rates how well [crop] fits [spot].
CropSuggestion rateCrop(Crop crop, Spot spot) {
  final reasons = <FitReason>[];
  final sun = spot.sunHours;

  double score;
  if (sun < crop.minSunHours) {
    reasons.add(
      NotEnoughSun(requiredHours: crop.minSunHours, actualHours: sun),
    );
    score = 0.5 * sun / crop.minSunHours;
  } else if (sun < crop.idealSunHours) {
    reasons.add(
      BelowIdealSun(idealHours: crop.idealSunHours, actualHours: sun),
    );
    score =
        0.7 +
        0.3 *
            (sun - crop.minSunHours) /
            (crop.idealSunHours - crop.minSunHours);
  } else {
    score = 1;
  }

  final maxSun = crop.maxSunHours;
  if (maxSun != null && sun > maxSun) {
    reasons.add(TooMuchSun(maxHours: maxSun, actualHours: sun));
    score *= 0.8;
  }

  if (!crop.containers.contains(spot.container)) {
    reasons.add(ContainerNotSuitable(spot.container));
    score *= 0.5;
  }

  final depth = spot.potDepthCm;
  if (depth != null && depth < crop.minPotDepthCm) {
    reasons.add(PotTooShallow(requiredCm: crop.minPotDepthCm, actualCm: depth));
    score *= 0.5 * math.max(0, depth) / crop.minPotDepthCm;
  }

  final volume = spot.potVolumeLiters;
  if (volume != null && volume < crop.minPotVolumeLiters) {
    reasons.add(
      PotTooSmall(
        requiredLiters: crop.minPotVolumeLiters,
        actualLiters: volume,
      ),
    );
    score *= 0.5 * math.max(0, volume) / crop.minPotVolumeLiters;
  }

  return CropSuggestion(
    crop: crop,
    score: score,
    reasons: List.unmodifiable(reasons),
  );
}

/// Every crop in [crops] (the whole database by default) rated for [spot],
/// best fit first.
///
/// Crops expected to grow at the spot always rank above those that are not;
/// within each group a higher score ranks first, and ties keep a stable
/// order by crop id.
List<CropSuggestion> suggestCrops(Spot spot, {List<Crop> crops = kCrops}) {
  final suggestions = [for (final crop in crops) rateCrop(crop, spot)];
  suggestions.sort((a, b) {
    if (a.isSuitable != b.isSuitable) return a.isSuitable ? -1 : 1;
    final byScore = b.score.compareTo(a.score);
    if (byScore != 0) return byScore;
    return a.crop.id.compareTo(b.crop.id);
  });
  return suggestions;
}
