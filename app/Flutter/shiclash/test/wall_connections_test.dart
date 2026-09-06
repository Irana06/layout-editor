import 'package:flutter_test/flutter_test.dart';
import 'package:shiclash/features/catalog/data/catalog_models.dart';
import 'package:shiclash/features/editor/domain/editor_controller.dart';
import 'package:shiclash/features/editor/domain/wall_connections.dart';

void main() {
  const wall = BuildingType(
    id: 1,
    name: 'Wall',
    category: 'defensive',
    subfolder: 'wall',
    isTownHall: false,
    defaultGridWidth: 1,
    defaultGridHeight: 1,
    levels: [],
  );
  const cannon = BuildingType(
    id: 2,
    name: 'Cannon',
    category: 'defensive',
    subfolder: 'cannon',
    isTownHall: false,
    defaultGridWidth: 3,
    defaultGridHeight: 3,
    levels: [],
  );
  final catalog = {1: wall, 2: cannon};

  WallConnectionIndex indexFor(List<EditorPlacement> placements) =>
      WallConnectionIndex(placements, (id) => catalog[id]);

  test('links all four cardinal neighbours at the same wall level', () {
    const center = EditorPlacement(
      id: 1,
      buildingTypeId: 1,
      level: 13,
      gridX: 10,
      gridY: 10,
    );
    final index = indexFor([
      center,
      const EditorPlacement(
        id: 2,
        buildingTypeId: 1,
        level: 13,
        gridX: 10,
        gridY: 9,
      ),
      const EditorPlacement(
        id: 3,
        buildingTypeId: 1,
        level: 13,
        gridX: 11,
        gridY: 10,
      ),
      const EditorPlacement(
        id: 4,
        buildingTypeId: 1,
        level: 13,
        gridX: 10,
        gridY: 11,
      ),
      const EditorPlacement(
        id: 5,
        buildingTypeId: 1,
        level: 13,
        gridX: 9,
        gridY: 10,
      ),
    ]);

    final mask = index.connectionsFor(center);
    expect(mask.north, isTrue);
    expect(mask.east, isTrue);
    expect(mask.south, isTrue);
    expect(mask.west, isTrue);
    expect(mask.hasAny, isTrue);
    expect(index.forwardConnections, hasLength(4));
  });

  test('does not bridge a different wall level or diagonal tile', () {
    const source = EditorPlacement(
      id: 1,
      buildingTypeId: 1,
      level: 13,
      gridX: 4,
      gridY: 4,
    );
    final index = indexFor([
      source,
      const EditorPlacement(
        id: 2,
        buildingTypeId: 1,
        level: 12,
        gridX: 5,
        gridY: 4,
      ),
      const EditorPlacement(
        id: 3,
        buildingTypeId: 1,
        level: 13,
        gridX: 5,
        gridY: 5,
      ),
    ]);

    expect(index.connectionsFor(source).hasAny, isFalse);
    expect(index.forwardConnections, isEmpty);
  });

  test('ignores non-wall buildings', () {
    const placement = EditorPlacement(
      id: 1,
      buildingTypeId: 2,
      level: 1,
      gridX: 4,
      gridY: 4,
    );
    final index = indexFor([placement]);

    expect(index.isWall(placement), isFalse);
    expect(index.connectionsFor(placement).hasAny, isFalse);
  });
}
