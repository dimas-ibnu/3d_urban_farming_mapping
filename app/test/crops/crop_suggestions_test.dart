import 'package:flutter_test/flutter_test.dart';
import 'package:urban_farming_planner/crops/crops.dart';

Crop _crop(
  String id, {
  double minSun = 4,
  double idealSun = 6,
  double? maxSun,
  double depth = 15,
  double volume = 3,
  Set<ContainerType> containers = const {ContainerType.pot},
}) => Crop(
  id: id,
  name: LocalizedText(id: id, en: id),
  minSunHours: minSun,
  idealSunHours: idealSun,
  maxSunHours: maxSun,
  minPotDepthCm: depth,
  minPotVolumeLiters: volume,
  spacingCm: 20,
  plantsPerPot: 1,
  containers: containers,
  daysToFirstHarvest: 30,
  yieldGramsPerPlantPerMonth: 100,
  notes: const LocalizedText(id: '-', en: '-'),
);

List<String> _ids(List<CropSuggestion> suggestions) => [
  for (final s in suggestions) s.crop.id,
];

void main() {
  group('rateCrop', () {
    final crop = _crop('x', minSun: 4, idealSun: 6);

    test('an ideal spot has no reasons and a full score', () {
      final s = rateCrop(
        crop,
        const Spot(
          sunHours: 7,
          container: ContainerType.pot,
          potDepthCm: 20,
          potVolumeLiters: 5,
        ),
      );
      expect(s.reasons, isEmpty);
      expect(s.isSuitable, isTrue);
      expect(s.score, 1);
    });

    test('less sun than the minimum blocks and reports the numbers', () {
      final s = rateCrop(
        _crop('cabai', minSun: 6, idealSun: 8),
        const Spot(sunHours: 4, container: ContainerType.pot),
      );
      expect(s.isSuitable, isFalse);
      final reason = s.reasons.single as NotEnoughSun;
      expect(reason.requiredHours, 6);
      expect(reason.actualHours, 4);
    });

    test('sun between minimum and ideal is a warning, not a blocker', () {
      final s = rateCrop(
        crop,
        const Spot(sunHours: 5, container: ContainerType.pot),
      );
      expect(s.isSuitable, isTrue);
      expect(s.reasons.single, isA<BelowIdealSun>());
      expect(s.score, closeTo(0.85, 1e-9));
    });

    test('0 sun hours scores 0 and is not suitable', () {
      final s = rateCrop(
        crop,
        const Spot(sunHours: 0, container: ContainerType.pot),
      );
      expect(s.score, 0);
      expect(s.isSuitable, isFalse);
    });

    test('too much sun for a shade lover is a warning', () {
      final s = rateCrop(
        _crop('selada', minSun: 3, idealSun: 5, maxSun: 6),
        const Spot(sunHours: 9, container: ContainerType.pot),
      );
      expect(s.isSuitable, isTrue);
      expect(s.reasons.single, isA<TooMuchSun>());
      expect(s.score, lessThan(1));
    });

    test('an unsuitable container blocks', () {
      final s = rateCrop(
        crop,
        const Spot(sunHours: 8, container: ContainerType.hanging),
      );
      expect(s.isSuitable, isFalse);
      expect(
        (s.reasons.single as ContainerNotSuitable).container,
        ContainerType.hanging,
      );
    });

    test('a very shallow pot blocks and scales the score down', () {
      final s = rateCrop(
        _crop('x', depth: 30),
        const Spot(sunHours: 8, container: ContainerType.pot, potDepthCm: 3),
      );
      expect(s.isSuitable, isFalse);
      final reason = s.reasons.single as PotTooShallow;
      expect(reason.requiredCm, 30);
      expect(reason.actualCm, 3);
      expect(s.score, closeTo(0.05, 1e-9));
    });

    test('a zero-depth pot scores 0', () {
      final s = rateCrop(
        crop,
        const Spot(sunHours: 8, container: ContainerType.pot, potDepthCm: 0),
      );
      expect(s.score, 0);
    });

    test('a too small pot blocks', () {
      final s = rateCrop(
        _crop('x', volume: 20),
        const Spot(
          sunHours: 8,
          container: ContainerType.pot,
          potVolumeLiters: 5,
        ),
      );
      expect(s.reasons.single, isA<PotTooSmall>());
      expect(s.isSuitable, isFalse);
    });

    test('an unknown pot size is not checked', () {
      final s = rateCrop(
        _crop('x', depth: 100, volume: 100),
        const Spot(sunHours: 8, container: ContainerType.pot),
      );
      expect(s.reasons, isEmpty);
    });

    test('collects every problem at once', () {
      final s = rateCrop(
        _crop('x', minSun: 6, depth: 30, volume: 20),
        const Spot(
          sunHours: 2,
          container: ContainerType.wall,
          potDepthCm: 10,
          potVolumeLiters: 1,
        ),
      );
      expect(s.reasons.map((r) => r.runtimeType), [
        NotEnoughSun,
        ContainerNotSuitable,
        PotTooShallow,
        PotTooSmall,
      ]);
    });
  });

  group('suggestCrops', () {
    test('ranks suitable crops above unsuitable ones, then by score', () {
      final crops = [
        _crop('sun_lover', minSun: 6, idealSun: 8),
        _crop('ideal', minSun: 2, idealSun: 4),
        _crop('ok', minSun: 3, idealSun: 6),
        _crop('wrong_container', containers: {ContainerType.wall}),
      ];
      final ranked = suggestCrops(
        const Spot(sunHours: 4, container: ContainerType.pot),
        crops: crops,
      );
      expect(_ids(ranked), ['ideal', 'ok', 'wrong_container', 'sun_lover']);
      expect(ranked.take(2).every((s) => s.isSuitable), isTrue);
      expect(ranked.skip(2).any((s) => s.isSuitable), isFalse);
    });

    test('a suitable crop outranks an unsuitable one with a higher score', () {
      final ranked = suggestCrops(
        const Spot(sunHours: 4, container: ContainerType.pot, potDepthCm: 28),
        crops: [
          // Suitable but far below its ideal sun: score 0.7.
          _crop('meh', minSun: 4, idealSun: 10),
          // Pot just too shallow: score 0.5 * 28/30 ≈ 0.47 but blocking.
          _crop('deep', minSun: 1, idealSun: 2, depth: 30),
        ],
      );
      expect(_ids(ranked), ['meh', 'deep']);
    });

    test('equal scores keep a stable order by id', () {
      final ranked = suggestCrops(
        const Spot(sunHours: 8, container: ContainerType.pot),
        crops: [_crop('b'), _crop('c'), _crop('a')],
      );
      expect(_ids(ranked), ['a', 'b', 'c']);
    });

    test('with no sun nothing in the database is suitable', () {
      final ranked = suggestCrops(
        const Spot(sunHours: 0, container: ContainerType.pot),
      );
      expect(ranked, hasLength(kCrops.length));
      expect(ranked.any((s) => s.isSuitable), isFalse);
    });

    test('a shady hanging planter suggests leafy greens and herbs, not '
        'fruiting crops', () {
      final ranked = suggestCrops(
        const Spot(
          sunHours: 4,
          container: ContainerType.hanging,
          potDepthCm: 15,
          potVolumeLiters: 3,
        ),
      );
      final suitable = {
        for (final s in ranked)
          if (s.isSuitable) s.crop.id,
      };
      expect(suitable, containsAll(['kangkung', 'selada', 'mint']));
      expect(suitable, isNot(contains('cabai')));
      expect(suitable, isNot(contains('tomat')));
      expect(ranked.first.isSuitable, isTrue);
    });

    test('a sunny big pot puts fruiting crops at the top', () {
      final ranked = suggestCrops(
        const Spot(
          sunHours: 8,
          container: ContainerType.pot,
          potDepthCm: 35,
          potVolumeLiters: 25,
        ),
      );
      final top = ranked.where((s) => s.score == 1).map((s) => s.crop.id);
      expect(top, containsAll(['cabai', 'tomat', 'terong', 'timun']));
      // Shade lovers get a warning in full sun and rank below.
      final selada = ranked.firstWhere((s) => s.crop.id == 'selada');
      expect(selada.reasons.single, isA<TooMuchSun>());
    });

    test('a very shallow pot rules out the deep-rooted crops', () {
      final ranked = suggestCrops(
        const Spot(sunHours: 8, container: ContainerType.pot, potDepthCm: 5),
      );
      expect(ranked.any((s) => s.isSuitable), isFalse);
      for (final s in ranked) {
        expect(s.reasons.whereType<PotTooShallow>(), hasLength(1));
      }
    });
  });
}
