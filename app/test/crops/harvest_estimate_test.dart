import 'package:flutter_test/flutter_test.dart';
import 'package:urban_farming_planner/crops/crops.dart';

Crop _crop(String id, {required int days, required double grams}) => Crop(
  id: id,
  name: LocalizedText(id: id, en: id),
  minSunHours: 4,
  idealSunHours: 6,
  minPotDepthCm: 15,
  minPotVolumeLiters: 3,
  spacingCm: 20,
  plantsPerPot: 1,
  containers: const {ContainerType.pot},
  daysToFirstHarvest: days,
  yieldGramsPerPlantPerMonth: grams,
  notes: const LocalizedText(id: '-', en: '-'),
);

void main() {
  final fast = _crop('fast', days: 15, grams: 100);
  final slow = _crop('slow', days: 75, grams: 300);

  test('steady-state grams per month is plants × yield, summed', () {
    final estimate = estimateHarvest([
      Placement(crop: fast, plants: 4),
      Placement(crop: slow, plants: 2),
    ]);
    expect(estimate.lines.map((l) => l.gramsPerMonth), [400, 600]);
    expect(estimate.gramsPerMonth, 1000);
  });

  test('merges placements of the same crop and drops empty ones', () {
    final estimate = estimateHarvest([
      Placement(crop: fast, plants: 2),
      Placement(crop: slow, plants: 0),
      Placement(crop: fast, plants: 3),
    ]);
    expect(estimate.lines, hasLength(1));
    expect(estimate.lines.single.crop.id, 'fast');
    expect(estimate.lines.single.plants, 5);
  });

  test('an empty plan harvests nothing', () {
    final estimate = estimateHarvest(const []);
    expect(estimate.lines, isEmpty);
    expect(estimate.gramsPerMonth, 0);
    expect(estimate.gramsInMonth(1), 0);
  });

  test('gramsInMonth waits for the first harvest', () {
    final estimate = estimateHarvest([
      Placement(crop: fast, plants: 1), // producing from day 15
      Placement(crop: slow, plants: 1), // producing from day 75
    ]);
    // Month 1 (days 0–30): fast for half the month.
    expect(estimate.gramsInMonth(1), closeTo(50, 1e-9));
    // Month 2 (days 30–60): fast only.
    expect(estimate.gramsInMonth(2), closeTo(100, 1e-9));
    // Month 3 (days 60–90): fast + slow for half the month.
    expect(estimate.gramsInMonth(3), closeTo(250, 1e-9));
    // Month 4: both at full rate.
    expect(estimate.gramsInMonth(4), closeTo(400, 1e-9));
  });

  test('month numbers start at 1', () {
    expect(() => estimateHarvest(const []).gramsInMonth(0), throwsRangeError);
  });

  test('works with crops from the database', () {
    final estimate = estimateHarvest([
      Placement(crop: cropById('kangkung')!, plants: 10),
      Placement(crop: cropById('cabai')!, plants: 2),
    ]);
    expect(estimate.gramsPerMonth, 10 * 60 + 2 * 150);
    // Cabai is not producing in month 1, kangkung starts on day 25.
    expect(estimate.gramsInMonth(1), closeTo(600 * 5 / 30, 1e-9));
  });
}
