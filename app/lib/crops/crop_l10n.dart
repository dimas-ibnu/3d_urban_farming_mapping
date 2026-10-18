import '../l10n/gen/app_localizations.dart';
import 'crop.dart';
import 'crop_suggestions.dart';

/// The name of [container] in the user's language.
String containerName(AppLocalizations l10n, ContainerType container) =>
    switch (container) {
      ContainerType.pot => l10n.containerPot,
      ContainerType.rack => l10n.containerRack,
      ContainerType.hanging => l10n.containerHanging,
      ContainerType.wall => l10n.containerWall,
    };

/// [reason] as a sentence in the user's language, e.g.
/// "Butuh ≥6 jam matahari, tempat ini 4 jam".
String describeFitReason(AppLocalizations l10n, FitReason reason) =>
    switch (reason) {
      NotEnoughSun(:final requiredHours, :final actualHours) =>
        l10n.cropReasonNotEnoughSun(requiredHours, actualHours),
      BelowIdealSun(:final idealHours, :final actualHours) =>
        l10n.cropReasonBelowIdealSun(idealHours, actualHours),
      TooMuchSun(:final maxHours, :final actualHours) =>
        l10n.cropReasonTooMuchSun(maxHours, actualHours),
      ContainerNotSuitable(:final container) =>
        l10n.cropReasonContainerNotSuitable(containerName(l10n, container)),
      PotTooShallow(:final requiredCm, :final actualCm) =>
        l10n.cropReasonPotTooShallow(requiredCm, actualCm),
      PotTooSmall(:final requiredLiters, :final actualLiters) =>
        l10n.cropReasonPotTooSmall(requiredLiters, actualLiters),
    };

/// Every reason of [suggestion] as a sentence, or a single "good fit"
/// sentence when there is nothing to report.
List<String> describeSuggestion(
  AppLocalizations l10n,
  CropSuggestion suggestion,
) => suggestion.reasons.isEmpty
    ? [l10n.cropReasonGoodFit]
    : [for (final r in suggestion.reasons) describeFitReason(l10n, r)];
