/// The crop model: what a plant needs and what it gives back.
///
/// Pure Dart with no Flutter dependency, so the suggestion logic can be used
/// and tested without a widget tree. Values are rough guides for home growing
/// in lowland Indonesia; `docs/CROPS.md` lists the sources.
library;

/// Where a plant can be grown.
enum ContainerType {
  /// A regular pot or polybag standing on the floor.
  pot,

  /// A pot on a shelf of a vertical rack, which limits its size.
  rack,

  /// A planter hanging from a hook or railing.
  hanging,

  /// A shallow pocket or box fixed to a wall.
  wall,
}

/// A text in both app languages: Bahasa Indonesia first, English second.
class LocalizedText {
  const LocalizedText({required this.id, required this.en});

  /// Bahasa Indonesia, the default.
  final String id;

  /// English.
  final String en;

  /// The text for [languageCode]. Anything other than `en` falls back to
  /// Bahasa Indonesia, the app's default locale.
  String of(String languageCode) => languageCode == 'en' ? en : id;
}

/// One crop in the database.
class Crop {
  const Crop({
    required this.id,
    required this.name,
    required this.minSunHours,
    required this.idealSunHours,
    this.maxSunHours,
    required this.minPotDepthCm,
    required this.minPotVolumeLiters,
    required this.spacingCm,
    required this.plantsPerPot,
    required this.containers,
    required this.daysToFirstHarvest,
    required this.yieldGramsPerPlantPerMonth,
    required this.notes,
  }) : assert(minSunHours <= idealSunHours),
       assert(maxSunHours == null || maxSunHours >= idealSunHours);

  /// Stable key, e.g. `cabai`. Saved in projects, so never rename one.
  final String id;

  final LocalizedText name;

  /// Hours of direct sun per day below which the crop does not grow well.
  final double minSunHours;

  /// Hours of direct sun per day at which the crop does its best.
  final double idealSunHours;

  /// Hours of direct sun per day above which the crop wilts or bolts in the
  /// tropical heat, or `null` when more sun never hurts.
  final double? maxSunHours;

  /// Minimum soil depth of the container, in centimetres.
  final double minPotDepthCm;

  /// Minimum soil volume of the container, in litres.
  final double minPotVolumeLiters;

  /// Distance between two plants, in centimetres.
  final double spacingCm;

  /// How many plants fit in a container of [minPotVolumeLiters].
  final int plantsPerPot;

  /// Containers the crop grows well in.
  final Set<ContainerType> containers;

  /// Days from planting a seedling (or sowing, for crops sown in place) to
  /// the first harvest.
  final int daysToFirstHarvest;

  /// Rough average harvest per plant per month once the crop is producing,
  /// in grams. For crops picked once (bayam, selada, sawi) this assumes the
  /// pot is replanted right away.
  final double yieldGramsPerPlantPerMonth;

  /// Watering and growing tips.
  final LocalizedText notes;
}
