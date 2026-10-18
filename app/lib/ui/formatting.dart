import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../l10n/gen/app_localizations.dart';
import '../model/project.dart';

/// Number and name formatting shared by the editor and the wizard.
///
/// Everything numeric goes through the locale's own formatter, so an
/// Indonesian user reads "5,4 m²" and an English one "5.4 m²" from the same
/// double.

String formatNumber(BuildContext context, double value, {int digits = 1}) =>
    NumberFormat.decimalPatternDigits(
      locale: Localizations.localeOf(context).toLanguageTag(),
      decimalDigits: digits,
    ).format(value);

/// The localised name of an item type.
String itemTypeName(AppLocalizations l10n, ItemType type) => switch (type) {
  ItemType.pot => l10n.itemPot,
  ItemType.verticalRack => l10n.itemVerticalRack,
  ItemType.hangingPlanter => l10n.itemHangingPlanter,
  ItemType.wallPlanter => l10n.itemWallPlanter,
};

/// The localised sentence for a placement problem.
String layoutProblemText(AppLocalizations l10n, LayoutProblem problem) =>
    switch (problem) {
      LayoutProblem.outsideSpace => l10n.issueOutsideSpace,
      LayoutProblem.overlapsItem => l10n.issueOverlapsItem,
      LayoutProblem.tooTall => l10n.issueTooTall,
      LayoutProblem.noWallToMountOn => l10n.issueNoWallToMountOn,
    };

/// The localised name of a barrier kind.
String barrierKindName(AppLocalizations l10n, BarrierKind kind) =>
    switch (kind) {
      BarrierKind.wall => l10n.barrierWall,
      BarrierKind.railing => l10n.barrierRailing,
      BarrierKind.obstacle => l10n.barrierObstacle,
    };

/// The icon used for an item type in the palette and the selection panel.
IconData itemTypeIcon(ItemType type) => switch (type) {
  ItemType.pot => Icons.local_florist,
  ItemType.verticalRack => Icons.shelves,
  ItemType.hangingPlanter => Icons.spa,
  ItemType.wallPlanter => Icons.view_sidebar,
};
