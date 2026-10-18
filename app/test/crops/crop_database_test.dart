import 'package:flutter_test/flutter_test.dart';
import 'package:urban_farming_planner/crops/crops.dart';

void main() {
  test('has the crops the MVP promises', () {
    const required = [
      'cabai',
      'tomat',
      'kangkung',
      'bayam',
      'sawi',
      'selada',
      'terong',
      'kemangi',
      'serai',
      'daun_bawang',
      'seledri',
      'mint',
      'stroberi',
      'timun',
      'buncis',
    ];
    for (final id in required) {
      expect(cropById(id), isNotNull, reason: '$id is missing');
    }
  });

  test('ids are unique', () {
    final ids = kCrops.map((c) => c.id).toList();
    expect(ids.toSet(), hasLength(ids.length));
  });

  test('every crop has consistent, complete values', () {
    for (final crop in kCrops) {
      final reason = crop.id;
      expect(crop.name.id, isNotEmpty, reason: reason);
      expect(crop.name.en, isNotEmpty, reason: reason);
      expect(crop.notes.id, isNotEmpty, reason: reason);
      expect(crop.notes.en, isNotEmpty, reason: reason);
      expect(crop.minSunHours, greaterThan(0), reason: reason);
      expect(crop.idealSunHours, inInclusiveRange(crop.minSunHours, 12));
      if (crop.maxSunHours != null) {
        expect(crop.maxSunHours, greaterThanOrEqualTo(crop.idealSunHours));
      }
      expect(crop.minPotDepthCm, greaterThan(0), reason: reason);
      expect(crop.minPotVolumeLiters, greaterThan(0), reason: reason);
      expect(crop.spacingCm, greaterThan(0), reason: reason);
      expect(crop.plantsPerPot, greaterThan(0), reason: reason);
      expect(crop.containers, isNotEmpty, reason: reason);
      expect(crop.containers, contains(ContainerType.pot), reason: reason);
      expect(crop.daysToFirstHarvest, greaterThan(0), reason: reason);
      expect(crop.yieldGramsPerPlantPerMonth, greaterThan(0), reason: reason);
    }
  });

  test('cropById returns null for an unknown id', () {
    expect(cropById('durian'), isNull);
  });

  test('LocalizedText falls back to Bahasa Indonesia', () {
    final cabai = cropById('cabai')!;
    expect(cabai.name.of('en'), 'Chili');
    expect(cabai.name.of('id'), 'Cabai');
    expect(cabai.name.of('jv'), 'Cabai');
  });
}
