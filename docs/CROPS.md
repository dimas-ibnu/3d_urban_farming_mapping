# Crop database and suggestions

The crop database and the logic that matches crops to a spot live in
`app/lib/crops/`, in pure Dart with no Flutter dependency. Import
`package:urban_farming_planner/crops/crops.dart`.

| File | What it holds |
|---|---|
| `crop.dart` | `Crop`, `ContainerType`, `LocalizedText` (ID/EN) |
| `crop_database.dart` | `kCrops` (the bundled data) and `cropById` |
| `crop_suggestions.dart` | `Spot`, `rateCrop`, `suggestCrops`, the `FitReason` types |
| `harvest_estimate.dart` | `Placement`, `estimateHarvest`, `HarvestEstimate` |
| `crop_l10n.dart` | `describeFitReason`, `containerName` — the only Flutter-dependent part, it turns reasons into ARB strings |

The data is Dart constants rather than a JSON asset: no async asset loading,
the compiler checks every field, and tests use it directly.

## Using it

```dart
final ranked = suggestCrops(const Spot(
  sunHours: 4,                     // from the sun map
  container: ContainerType.hanging,
  potDepthCm: 15,                  // optional; unknown sizes are not checked
  potVolumeLiters: 3,
));
for (final s in ranked) {
  print('${s.crop.name.of('id')}: ${s.isSuitable} '
      '${describeSuggestion(l10n, s)}');
}

final harvest = estimateHarvest([
  Placement(crop: cropById('kangkung')!, plants: 10),
  Placement(crop: cropById('cabai')!, plants: 2),
]);
harvest.gramsPerMonth;   // once everything is producing
harvest.gramsInMonth(1); // month 1 after planting, waiting for first harvest
```

## How suggestions are ranked

`rateCrop` scores a crop from 0 to 1 for a spot and lists the reasons the fit
is not ideal. A reason is either **blocking** (the crop is not expected to grow
there) or a **warning** (it grows, but less well).

| Check | Reason | Kind | Effect on score |
|---|---|---|---|
| sun < minimum | `NotEnoughSun` | blocking | `0.5 × sun / min` |
| minimum ≤ sun < ideal | `BelowIdealSun` | warning | `0.7` at minimum up to `1` at ideal |
| sun > maximum (shade lovers only) | `TooMuchSun` | warning | × 0.8 |
| container not in the crop's list | `ContainerNotSuitable` | blocking | × 0.5 |
| pot depth < minimum | `PotTooShallow` | blocking | × `0.5 × depth / min` |
| pot volume < minimum | `PotTooSmall` | blocking | × `0.5 × volume / min` |

`suggestCrops` puts every suitable crop (no blocking reason) above every
unsuitable one, then sorts by score, then by id so ties are stable.

## Harvest estimate

Each line is `plants × yieldGramsPerPlantPerMonth` once producing.
`gramsInMonth(n)` counts 30-day months from planting and only counts the days
after `daysToFirstHarvest`. For crops picked once (bayam, sawi, selada) the
monthly yield assumes the pot is replanted straight away. These are rough
figures for a planning card, not agronomic predictions.

## The data

All values are rounded rough guides for **container growing in lowland
Indonesia** (hot, humid, about 12 h of daylight all year), from a home
grower's point of view.

| id | Sun min / ideal (max) h | Pot depth cm / volume L | Spacing cm, plants per pot | Containers | Days to 1st harvest | g / plant / month |
|---|---|---|---|---|---|---|
| cabai | 6 / 8 | 25 / 10 | 50, 1 | pot | 80 | 150 |
| tomat | 6 / 8 | 30 / 20 | 60, 1 | pot | 75 | 400 |
| kangkung | 4 / 6 | 15 / 3 | 10, 5 | pot, rack, hanging, wall | 25 | 60 |
| bayam | 4 / 6 | 15 / 3 | 10, 4 | pot, rack, wall | 25 | 60 |
| sawi | 4 / 6 | 15 / 3 | 20, 1 | pot, rack, wall | 35 | 130 |
| selada | 3 / 5 (6) | 15 / 2 | 20, 1 | pot, rack, hanging, wall | 35 | 90 |
| terong | 6 / 8 | 30 / 20 | 60, 1 | pot | 70 | 400 |
| kemangi | 5 / 7 | 15 / 3 | 25, 1 | pot, rack, hanging, wall | 30 | 60 |
| serai | 6 / 8 | 25 / 10 | 60, 1 | pot | 90 | 150 |
| daun_bawang | 4 / 6 | 15 / 2 | 10, 4 | pot, rack, hanging, wall | 50 | 40 |
| seledri | 3 / 5 (6) | 20 / 3 | 20, 1 | pot, rack, hanging, wall | 70 | 50 |
| mint | 3 / 5 | 15 / 3 | 30, 1 | pot, rack, hanging, wall | 40 | 50 |
| stroberi | 6 / 8 | 15 / 3 | 30, 1 | pot, rack, hanging, wall | 90 | 80 |
| timun | 6 / 8 | 25 / 15 | 40, 1 | pot | 40 | 500 |
| buncis | 6 / 8 | 20 / 8 | 15, 3 | pot, rack | 50 | 100 |

Conventions:

- **Sun:** hours of *direct* sun per day. Fruiting crops (cabai, tomat, terong,
  timun, buncis, stroberi) need full sun (6 h+). Leafy greens and most herbs
  manage with 3–4 h. Selada and seledri get a maximum because full tropical sun
  makes them bitter and bolt.
- **Days to first harvest:** from transplanting a seedling, or from sowing for
  crops sown in place (kangkung, bayam, buncis).
- **Yield:** container-grown, home-garden level, averaged over the producing
  period. Stroberi is deliberately low because it fruits poorly in the lowlands.

### Sources

The figures were consolidated and rounded from general public gardening
guidance; none comes from a single source.

- Kementerian Pertanian — Cyber Extension (cybex.pertanian.go.id): budidaya
  guides for cabai, tomat, kangkung, bayam, sawi, terong, buncis, timun.
- Balai Penelitian Tanaman Sayuran (Balitsa), Lembang: vegetable growing
  guides for highland and lowland Indonesia.
- University of Minnesota Extension and Penn State Extension, vegetable and
  container gardening guides: sun needs, pot sizes, spacing, days to harvest.
- Royal Horticultural Society (rhs.org.uk), "Grow your own" pages: herbs (mint,
  basil, lemongrass), lettuce, strawberries.

Before changing a value, keep the id stable (projects store it) and run
`flutter test` — `test/crops/` checks the data stays consistent.
