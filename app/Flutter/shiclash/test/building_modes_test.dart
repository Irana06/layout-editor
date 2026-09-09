import 'package:flutter_test/flutter_test.dart';
import 'package:shiclash/features/catalog/data/catalog_models.dart';
import 'package:shiclash/features/editor/domain/editor_controller.dart';

BuildingLevel level(int id, int number, {String? variant}) => BuildingLevel(
  id: id,
  level: number,
  variant: variant,
  imageUrl: '',
  gridWidth: 2,
  gridHeight: 2,
  scale: 1,
  offsetX: 0,
  offsetY: 0,
);

const _scenery = Scenery(
  id: 1,
  name: 'Test Village',
  imageUrl: '',
  imageWidth: 1000,
  imageHeight: 800,
  tileWidth: 50,
  tileHeight: 25,
  originX: 500,
  originY: 100,
  gridSize: 44,
);

CatalogBootstrap catalog() => CatalogBootstrap(
  sceneries: const [_scenery],
  buildingTypes: [
    BuildingType(
      id: 1,
      name: 'Town Hall',
      category: 'resource',
      isTownHall: true,
      defaultGridWidth: 4,
      defaultGridHeight: 4,
      levels: [level(1, 10)],
    ),
    BuildingType(
      id: 2,
      name: 'Inferno Tower',
      category: 'defensive',
      subfolder: 'inferno-tower',
      isTownHall: false,
      defaultGridWidth: 2,
      defaultGridHeight: 2,
      modes: const {'single': 'Single', 'multi': 'Multi'},
      levels: [
        level(2, 10, variant: 'single'),
        level(3, 10, variant: 'multi'),
      ],
    ),
    BuildingType(
      id: 3,
      name: 'Cannon',
      category: 'defensive',
      subfolder: 'cannon',
      isTownHall: false,
      defaultGridWidth: 3,
      defaultGridHeight: 3,
      levels: [level(4, 10)],
    ),
  ],
  unlockRules: const [
    BuildingUnlockRule(
      buildingTypeId: 2,
      thLevel: 10,
      maxBuildingLevel: 10,
      maxCount: 3,
    ),
    BuildingUnlockRule(
      buildingTypeId: 3,
      thLevel: 10,
      maxBuildingLevel: 10,
      maxCount: 3,
    ),
  ],
);

void main() {
  late EditorController controller;

  setUp(() => controller = EditorController(catalog()));
  tearDown(() => controller.dispose());

  EditorPlacement place(int typeId, int x, int y) {
    controller.arm(controller.typeFor(typeId)!);
    controller.handleGridTap(x, y);

    return controller.placements.last;
  }

  test('a building with modes starts in the first one offered', () {
    final inferno = place(2, 4, 4);

    expect(inferno.variant, 'single');
    expect(controller.levelFor(inferno)!.id, 2);
  });

  test(
    'a building without modes carries none, and its layout stays unchanged',
    () {
      place(3, 10, 10);

      final row = (controller.toLayout()['data'] as List).single as Map;
      expect(row.containsKey('variant'), isFalse);
    },
  );

  test('switching mode changes the artwork and is undoable', () {
    place(2, 4, 4);
    controller.selectAt(4, 4);

    controller.setSelectedVariant('multi');
    expect(controller.selectedPlacement!.variant, 'multi');
    expect(controller.levelFor(controller.selectedPlacement!)!.id, 3);

    controller.undo();
    expect(controller.placements.single.variant, 'single');
  });

  test('only modes the level has artwork for are offered', () {
    final inferno = place(2, 4, 4);
    final cannon = place(3, 12, 12);

    expect(controller.variantsFor(inferno).map((e) => e.key), [
      'single',
      'multi',
    ]);
    // A building with no modes offers none rather than an empty toggle.
    expect(controller.variantsFor(cannon), isEmpty);
  });

  test('a mode survives a save and reopen', () {
    place(2, 4, 4);
    controller.selectAt(4, 4);
    controller.setSelectedVariant('multi');
    final document = controller.toLayout();

    expect((document['data'] as List).single['variant'], 'multi');

    final reopened = EditorController(catalog())..restoreLayout(document);
    addTearDown(reopened.dispose);
    expect(reopened.placements.single.variant, 'multi');
  });

  test('a retired mode falls back instead of rejecting the whole draft', () {
    place(2, 4, 4);
    final document = controller.toLayout();
    (document['data'] as List).single['variant'] = 'plasma';

    final reopened = EditorController(catalog())..restoreLayout(document);
    addTearDown(reopened.dispose);

    // The building is still there, drawn in the default mode.
    expect(reopened.placements, hasLength(1));
    expect(reopened.placements.single.variant, 'single');
  });
}
