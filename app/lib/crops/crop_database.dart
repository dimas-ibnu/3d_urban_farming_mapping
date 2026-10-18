import 'crop.dart';

/// The bundled crop database.
///
/// Kept as Dart constants rather than a JSON asset so it needs no async asset
/// loading and stays usable from pure Dart (tests, isolates). Values are
/// rounded rough guides for container growing in lowland Indonesia; the
/// sources are listed in `docs/CROPS.md`.
const List<Crop> kCrops = [
  Crop(
    id: 'cabai',
    name: LocalizedText(id: 'Cabai', en: 'Chili'),
    minSunHours: 6,
    idealSunHours: 8,
    minPotDepthCm: 25,
    minPotVolumeLiters: 10,
    spacingCm: 50,
    plantsPerPot: 1,
    containers: {ContainerType.pot},
    daysToFirstHarvest: 80,
    yieldGramsPerPlantPerMonth: 150,
    notes: LocalizedText(
      id:
          'Siram pagi dan sore saat kemarau, jaga media lembap tapi tidak '
          'becek. Pasang ajir agar batang tidak rebah saat berbuah.',
      en:
          'Water morning and evening in the dry season; keep the soil moist '
          'but not waterlogged. Stake the plant so it does not fall over '
          'when fruiting.',
    ),
  ),
  Crop(
    id: 'tomat',
    name: LocalizedText(id: 'Tomat', en: 'Tomato'),
    minSunHours: 6,
    idealSunHours: 8,
    minPotDepthCm: 30,
    minPotVolumeLiters: 20,
    spacingCm: 60,
    plantsPerPot: 1,
    containers: {ContainerType.pot},
    daysToFirstHarvest: 75,
    yieldGramsPerPlantPerMonth: 400,
    notes: LocalizedText(
      id:
          'Butuh siraman rutin setiap hari; penyiraman tidak teratur membuat '
          'buah pecah. Pasang ajir atau turus. Varietas cherry lebih tahan '
          'panas dataran rendah.',
      en:
          'Needs regular daily watering; uneven watering makes the fruit '
          'split. Stake or cage it. Cherry varieties cope better with lowland '
          'heat.',
    ),
  ),
  Crop(
    id: 'kangkung',
    name: LocalizedText(id: 'Kangkung', en: 'Water spinach'),
    minSunHours: 4,
    idealSunHours: 6,
    minPotDepthCm: 15,
    minPotVolumeLiters: 3,
    spacingCm: 10,
    plantsPerPot: 5,
    containers: {
      ContainerType.pot,
      ContainerType.rack,
      ContainerType.hanging,
      ContainerType.wall,
    },
    daysToFirstHarvest: 25,
    yieldGramsPerPlantPerMonth: 60,
    notes: LocalizedText(
      id:
          'Suka air: siram dua kali sehari dan jangan biarkan media kering. '
          'Potong batang 5 cm di atas media agar tumbuh tunas baru.',
      en:
          'Loves water: water twice a day and never let the soil dry out. '
          'Cut stems 5 cm above the soil so new shoots grow back.',
    ),
  ),
  Crop(
    id: 'bayam',
    name: LocalizedText(id: 'Bayam', en: 'Amaranth'),
    minSunHours: 4,
    idealSunHours: 6,
    minPotDepthCm: 15,
    minPotVolumeLiters: 3,
    spacingCm: 10,
    plantsPerPot: 4,
    containers: {ContainerType.pot, ContainerType.rack, ContainerType.wall},
    daysToFirstHarvest: 25,
    yieldGramsPerPlantPerMonth: 60,
    notes: LocalizedText(
      id:
          'Siram setiap hari. Panen dengan dicabut umur 3–4 minggu, lalu '
          'semai lagi bertahap agar panen terus berlanjut.',
      en:
          'Water daily. Harvest by pulling at 3–4 weeks, then sow again in '
          'batches for a steady supply.',
    ),
  ),
  Crop(
    id: 'sawi',
    name: LocalizedText(id: 'Sawi / pakcoy', en: 'Mustard greens / pak choi'),
    minSunHours: 4,
    idealSunHours: 6,
    minPotDepthCm: 15,
    minPotVolumeLiters: 3,
    spacingCm: 20,
    plantsPerPot: 1,
    containers: {ContainerType.pot, ContainerType.rack, ContainerType.wall},
    daysToFirstHarvest: 35,
    yieldGramsPerPlantPerMonth: 130,
    notes: LocalizedText(
      id:
          'Siram pagi dan sore. Teduhkan sedikit saat siang yang sangat '
          'terik agar daun tidak layu. Panen seluruh tanaman umur 5–6 minggu.',
      en:
          'Water morning and evening. Give light shade at a scorching midday '
          'so the leaves do not wilt. Harvest the whole plant at 5–6 weeks.',
    ),
  ),
  Crop(
    id: 'selada',
    name: LocalizedText(id: 'Selada', en: 'Lettuce'),
    minSunHours: 3,
    idealSunHours: 5,
    maxSunHours: 6,
    minPotDepthCm: 15,
    minPotVolumeLiters: 2,
    spacingCm: 20,
    plantsPerPot: 1,
    containers: {
      ContainerType.pot,
      ContainerType.rack,
      ContainerType.hanging,
      ContainerType.wall,
    },
    daysToFirstHarvest: 35,
    yieldGramsPerPlantPerMonth: 90,
    notes: LocalizedText(
      id:
          'Lebih suka teduh sebagian di dataran rendah; panas terik membuat '
          'daun pahit dan cepat berbunga. Jaga media tetap lembap.',
      en:
          'Prefers partial shade in the lowlands; harsh heat turns the leaves '
          'bitter and makes it bolt. Keep the soil evenly moist.',
    ),
  ),
  Crop(
    id: 'terong',
    name: LocalizedText(id: 'Terong', en: 'Eggplant'),
    minSunHours: 6,
    idealSunHours: 8,
    minPotDepthCm: 30,
    minPotVolumeLiters: 20,
    spacingCm: 60,
    plantsPerPot: 1,
    containers: {ContainerType.pot},
    daysToFirstHarvest: 70,
    yieldGramsPerPlantPerMonth: 400,
    notes: LocalizedText(
      id:
          'Siram setiap hari, terutama saat berbunga dan berbuah. Pasang ajir '
          'dan petik buah selagi kulitnya masih mengilap.',
      en:
          'Water daily, especially while flowering and fruiting. Stake it and '
          'pick the fruit while the skin is still glossy.',
    ),
  ),
  Crop(
    id: 'kemangi',
    name: LocalizedText(id: 'Kemangi', en: 'Lemon basil'),
    minSunHours: 5,
    idealSunHours: 7,
    minPotDepthCm: 15,
    minPotVolumeLiters: 3,
    spacingCm: 25,
    plantsPerPot: 1,
    containers: {
      ContainerType.pot,
      ContainerType.rack,
      ContainerType.hanging,
      ContainerType.wall,
    },
    daysToFirstHarvest: 30,
    yieldGramsPerPlantPerMonth: 60,
    notes: LocalizedText(
      id:
          'Siram saat permukaan media mulai kering. Petik pucuk dan buang '
          'bunga agar tanaman terus rimbun.',
      en:
          'Water when the soil surface starts to dry. Pinch the tips and '
          'remove flowers to keep it bushy.',
    ),
  ),
  Crop(
    id: 'serai',
    name: LocalizedText(id: 'Serai', en: 'Lemongrass'),
    minSunHours: 6,
    idealSunHours: 8,
    minPotDepthCm: 25,
    minPotVolumeLiters: 10,
    spacingCm: 60,
    plantsPerPot: 1,
    containers: {ContainerType.pot},
    daysToFirstHarvest: 90,
    yieldGramsPerPlantPerMonth: 150,
    notes: LocalizedText(
      id:
          'Tahan kering, siram 2–3 kali seminggu. Tanam dari batang yang '
          'sudah berakar; panen batang terluar.',
      en:
          'Drought-tolerant; water 2–3 times a week. Grow from a rooted '
          'stalk and harvest the outer stalks.',
    ),
  ),
  Crop(
    id: 'daun_bawang',
    name: LocalizedText(id: 'Daun bawang', en: 'Spring onion'),
    minSunHours: 4,
    idealSunHours: 6,
    minPotDepthCm: 15,
    minPotVolumeLiters: 2,
    spacingCm: 10,
    plantsPerPot: 4,
    containers: {
      ContainerType.pot,
      ContainerType.rack,
      ContainerType.hanging,
      ContainerType.wall,
    },
    daysToFirstHarvest: 50,
    yieldGramsPerPlantPerMonth: 40,
    notes: LocalizedText(
      id:
          'Siram setiap hari tanpa membuat becek. Potong daun 3 cm di atas '
          'pangkal, nanti tumbuh lagi.',
      en:
          'Water daily without waterlogging. Cut the leaves 3 cm above the '
          'base and they grow back.',
    ),
  ),
  Crop(
    id: 'seledri',
    name: LocalizedText(id: 'Seledri', en: 'Leaf celery'),
    minSunHours: 3,
    idealSunHours: 5,
    maxSunHours: 6,
    minPotDepthCm: 20,
    minPotVolumeLiters: 3,
    spacingCm: 20,
    plantsPerPot: 1,
    containers: {
      ContainerType.pot,
      ContainerType.rack,
      ContainerType.hanging,
      ContainerType.wall,
    },
    daysToFirstHarvest: 70,
    yieldGramsPerPlantPerMonth: 50,
    notes: LocalizedText(
      id:
          'Suka media lembap dan teduh sebagian. Petik tangkai terluar, '
          'sisakan tunas tengah.',
      en:
          'Likes moist soil and partial shade. Pick the outer stalks and '
          'leave the centre to keep growing.',
    ),
  ),
  Crop(
    id: 'mint',
    name: LocalizedText(id: 'Mint', en: 'Mint'),
    minSunHours: 3,
    idealSunHours: 5,
    minPotDepthCm: 15,
    minPotVolumeLiters: 3,
    spacingCm: 30,
    plantsPerPot: 1,
    containers: {
      ContainerType.pot,
      ContainerType.rack,
      ContainerType.hanging,
      ContainerType.wall,
    },
    daysToFirstHarvest: 40,
    yieldGramsPerPlantPerMonth: 50,
    notes: LocalizedText(
      id:
          'Jaga media lembap. Menjalar cepat, jadi tanam sendiri dalam satu '
          'pot. Petik pucuk secara rutin.',
      en:
          'Keep the soil moist. It spreads fast, so give it a pot of its own. '
          'Pick the tips regularly.',
    ),
  ),
  Crop(
    id: 'stroberi',
    name: LocalizedText(id: 'Stroberi', en: 'Strawberry'),
    minSunHours: 6,
    idealSunHours: 8,
    minPotDepthCm: 15,
    minPotVolumeLiters: 3,
    spacingCm: 30,
    plantsPerPot: 1,
    containers: {
      ContainerType.pot,
      ContainerType.rack,
      ContainerType.hanging,
      ContainerType.wall,
    },
    daysToFirstHarvest: 90,
    yieldGramsPerPlantPerMonth: 80,
    notes: LocalizedText(
      id:
          'Paling cocok di dataran tinggi yang sejuk; di dataran rendah '
          'buahnya sedikit. Siram rutin dan jangan basahi buah.',
      en:
          'Does best in cool highlands; in the lowlands it fruits sparsely. '
          'Water regularly and keep the fruit dry.',
    ),
  ),
  Crop(
    id: 'timun',
    name: LocalizedText(id: 'Timun', en: 'Cucumber'),
    minSunHours: 6,
    idealSunHours: 8,
    minPotDepthCm: 25,
    minPotVolumeLiters: 15,
    spacingCm: 40,
    plantsPerPot: 1,
    containers: {ContainerType.pot},
    daysToFirstHarvest: 40,
    yieldGramsPerPlantPerMonth: 500,
    notes: LocalizedText(
      id:
          'Butuh banyak air, siram pagi dan sore. Beri rambatan atau ajir '
          'setinggi 1,5 m.',
      en:
          'Thirsty: water morning and evening. Give it a trellis or stake '
          '1.5 m tall.',
    ),
  ),
  Crop(
    id: 'buncis',
    name: LocalizedText(id: 'Buncis', en: 'Green beans'),
    minSunHours: 6,
    idealSunHours: 8,
    minPotDepthCm: 20,
    minPotVolumeLiters: 8,
    spacingCm: 15,
    plantsPerPot: 3,
    containers: {ContainerType.pot, ContainerType.rack},
    daysToFirstHarvest: 50,
    yieldGramsPerPlantPerMonth: 100,
    notes: LocalizedText(
      id:
          'Siram setiap hari saat berbunga. Pilih varietas tegak (tanpa '
          'rambatan) untuk pot; petik polong selagi muda.',
      en:
          'Water daily while flowering. Choose bush varieties for pots and '
          'pick the pods while young.',
    ),
  ),
];

/// The crop with [id], or `null` when there is none.
Crop? cropById(String id) {
  for (final crop in kCrops) {
    if (crop.id == id) return crop;
  }
  return null;
}
