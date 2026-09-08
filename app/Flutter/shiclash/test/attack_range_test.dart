import 'package:flutter_test/flutter_test.dart';
import 'package:shiclash/features/catalog/data/catalog_models.dart';

BuildingType typeOfSize(int size) => BuildingType(
  id: 1,
  name: 'Mortar',
  category: 'defensive',
  isTownHall: false,
  defaultGridWidth: size,
  defaultGridHeight: size,
  levels: const [],
);

void main() {
  test('range is the radius from the centre, whatever the footprint', () {
    // A 1x1 building: range 1 reaches the ring of tiles touching it.
    expect(typeOfSize(1).ringRadius(1), 1);
    expect(typeOfSize(1).ringRadius(7), 7);

    // Footprint must not widen the ring. A Mortar of 11 reaches 11 tiles from
    // its middle, the same as any other building with that range.
    expect(typeOfSize(3).ringRadius(11), 11);
    expect(typeOfSize(3).ringRadius(4), 4);
    expect(typeOfSize(4).ringRadius(4), 4);
    expect(typeOfSize(1).ringRadius(4), 4);
  });

  test('attack range survives a copy and defaults to none', () {
    final plain = typeOfSize(3);
    expect(plain.attackRangeMin, 0);
    expect(plain.attackRangeMax, 0);

    final mortar = plain.withAttackRange(min: 4, max: 11);
    expect(mortar.attackRangeMin, 4);
    expect(mortar.attackRangeMax, 11);

    // Unrelated edits must not quietly drop the range.
    expect(mortar.withDeploymentRing(false).attackRangeMax, 11);
    expect(mortar.withSharedFootprint(4).attackRangeMin, 4);
  });

  test('range is read from the catalog payload', () {
    final type = BuildingType.fromJson(const {
      'id': 5,
      'name': 'Mortar',
      'category': 'defensive',
      'default_grid_width': 3,
      'default_grid_height': 3,
      'attack_range_min': 4,
      'attack_range_max': 11,
      'levels': [],
    });

    expect(type.attackRangeMin, 4);
    expect(type.attackRangeMax, 11);
    expect(type.ringRadius(type.attackRangeMax), 11);
  });
}
