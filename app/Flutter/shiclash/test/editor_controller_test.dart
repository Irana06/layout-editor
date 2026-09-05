import 'package:flutter_test/flutter_test.dart';
import 'package:shiclash/features/catalog/data/catalog_models.dart';
import 'package:shiclash/features/editor/domain/editor_controller.dart';

void main() {
  late EditorController controller;

  setUp(() {
    controller = EditorController(
      const CatalogBootstrap(
        sceneries: [
          Scenery(
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
          ),
        ],
        buildingTypes: [
          BuildingType(
            id: 1,
            name: 'Town Hall',
            category: 'town_hall',
            isTownHall: true,
            defaultGridWidth: 4,
            defaultGridHeight: 4,
            levels: [
              BuildingLevel(
                id: 1,
                level: 10,
                imageUrl: '',
                gridWidth: 4,
                gridHeight: 4,
                scale: 1,
                offsetX: 0,
                offsetY: 0,
              ),
            ],
          ),
          BuildingType(
            id: 2,
            name: 'Cannon',
            category: 'defense',
            isTownHall: false,
            defaultGridWidth: 3,
            defaultGridHeight: 3,
            levels: [
              BuildingLevel(
                id: 2,
                level: 10,
                imageUrl: '',
                gridWidth: 3,
                gridHeight: 3,
                scale: 1,
                offsetX: 0,
                offsetY: 0,
              ),
            ],
          ),
        ],
        unlockRules: [
          BuildingUnlockRule(
            buildingTypeId: 2,
            thLevel: 10,
            maxBuildingLevel: 10,
            maxCount: 2,
          ),
        ],
      ),
    );
  });

  tearDown(() => controller.dispose());

  test('places buildings and rejects overlapping footprints', () {
    controller.arm(controller.typeFor(2)!);
    controller.handleGridTap(3, 3);
    controller.handleGridTap(4, 4);

    expect(controller.placements, hasLength(1));
    expect(controller.status, contains('sudah terisi'));

    controller.handleGridTap(8, 8);
    controller.handleGridTap(14, 14);

    expect(controller.placements, hasLength(2));
    expect(controller.status, contains('Limit'));
  });

  test('moves, deletes, undo and redo placements', () {
    controller.arm(controller.typeFor(2)!);
    controller.handleGridTap(2, 2);
    controller.cancelTool();
    controller.selectAt(2, 2);
    controller.beginMove();
    controller.handleGridTap(10, 10);

    expect(controller.placements.single.gridX, 10);
    expect(controller.canUndo, isTrue);

    controller.deleteSelected();
    expect(controller.placements, isEmpty);

    controller.undo();
    expect(controller.placements.single.gridX, 10);
    controller.undo();
    expect(controller.placements.single.gridX, 2);
    controller.redo();
    expect(controller.placements.single.gridX, 10);
  });
}
