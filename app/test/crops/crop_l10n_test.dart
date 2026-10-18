import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:urban_farming_planner/crops/crop_l10n.dart';
import 'package:urban_farming_planner/crops/crops.dart';
import 'package:urban_farming_planner/l10n/gen/app_localizations.dart';

void main() {
  final id = lookupAppLocalizations(const Locale('id'));
  final en = lookupAppLocalizations(const Locale('en'));

  test('phrases a sun shortfall in both languages', () {
    const reason = NotEnoughSun(requiredHours: 6, actualHours: 4);
    expect(
      describeFitReason(id, reason),
      'Butuh ≥6 jam matahari, tempat ini 4 jam',
    );
    expect(
      describeFitReason(en, reason),
      'Needs ≥6 h of sun, this spot gets 4 h',
    );
  });

  test('formats fractional hours for the locale', () {
    const reason = NotEnoughSun(requiredHours: 6, actualHours: 3.5);
    expect(describeFitReason(id, reason), contains('3,5 jam'));
    expect(describeFitReason(en, reason), contains('3.5 h'));
  });

  test('names the container', () {
    const reason = ContainerNotSuitable(ContainerType.hanging);
    expect(
      describeFitReason(id, reason),
      'Kurang cocok ditanam di pot gantung',
    );
  });

  test('an ideal fit reads as a good fit', () {
    final suggestion = rateCrop(
      cropById('kangkung')!,
      const Spot(sunHours: 6, container: ContainerType.pot),
    );
    expect(describeSuggestion(id, suggestion), ['Cocok untuk tempat ini']);
  });

  test('every reason has a sentence', () {
    const reasons = <FitReason>[
      NotEnoughSun(requiredHours: 6, actualHours: 4),
      BelowIdealSun(idealHours: 8, actualHours: 6),
      TooMuchSun(maxHours: 6, actualHours: 9),
      ContainerNotSuitable(ContainerType.wall),
      PotTooShallow(requiredCm: 30, actualCm: 10),
      PotTooSmall(requiredLiters: 20, actualLiters: 5),
    ];
    for (final l10n in [id, en]) {
      for (final reason in reasons) {
        expect(describeFitReason(l10n, reason), isNotEmpty);
      }
    }
  });
}
