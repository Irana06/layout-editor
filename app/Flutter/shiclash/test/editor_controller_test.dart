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
                id: 10,
                level: 9,
                imageUrl: '',
                gridWidth: 4,
                gridHeight: 4,
                scale: 1,
                offsetX: 0,
                offsetY: 0,
              ),
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

  test('layout round trip restores coordinates, TH and undo baseline', () {
    controller.arm(controller.typeFor(2)!);
    controller.handleGridTap(4, 6);
    final document = controller.toLayout();
    controller.reset();
    controller.restoreLayout(document);
    expect(controller.toLayout(), document);
    expect(controller.canUndo, isFalse);
    controller.arm(controller.typeFor(2)!);
    controller.handleGridTap(12, 12);
    expect(controller.placements.map((item) => item.id).toSet(), hasLength(2));
    controller.undo();
    expect(controller.toLayout(), document);
  });

  test('Town Hall is available once at the active Town Hall level', () {
    final townHall = controller.typeFor(1)!;

    expect(controller.showGrid, isFalse);
    expect(controller.maxLevelFor(townHall), 10);

    controller.arm(townHall, level: 1);
    expect(controller.armedLevel, 10);
    controller.handleGridTap(4, 6);
    controller.handleGridTap(12, 12);

    expect(controller.placements, hasLength(1));
    expect(controller.placements.single.buildingTypeId, 1);
    expect(controller.placements.single.level, 10);
    expect(controller.status, contains('Limit'));
  });

  test('restored Town Hall must match the selected Town Hall level', () {
    final valid = {
      'scenery_id': 1,
      'th_level': 10,
      'data': [
        {'building_type_id': 1, 'level': 10, 'gx': 4, 'gy': 6},
      ],
    };

    controller.restoreLayout(valid);
    expect(controller.placements, hasLength(1));

    final invalid = {
      ...valid,
      'data': [
        {'building_type_id': 1, 'level': 9, 'gx': 4, 'gy': 6},
      ],
    };
    expect(() => controller.restoreLayout(invalid), throwsFormatException);
    expect(controller.placements, hasLength(1));
  });

  test('invalid draft does not mutate current canvas or history', () {
    controller.arm(controller.typeFor(2)!);
    controller.handleGridTap(4, 6);
    final original = controller.toLayout();
    final invalid = {
      ...original,
      'data': [
        {'building_type_id': 2, 'level': 10, 'gx': 1, 'gy': 1},
        {'building_type_id': 2, 'level': 10, 'gx': 2, 'gy': 2},
      ],
    };
    expect(() => controller.restoreLayout(invalid), throwsFormatException);
    expect(controller.toLayout(), original);
    expect(controller.canUndo, isTrue);
  });

  test('places buildings and rejects overlapping footprints', () {
    controller.arm(controller.typeFor(2)!);
    controller.handleGridTap(3, 3);
    controller.handleGridTap(4, 4);

    expect(controller.placements, hasLength(1));
    expect(controller.selectedId, controller.placements.single.id);
    expect(controller.status, contains('dipilih'));

    controller.arm(controller.typeFor(2)!);
    controller.handleGridTap(8, 8);
    controller.arm(controller.typeFor(2)!);
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

  test('long-press drag previews movement and marks a collision invalid', () {
    final cannon = controller.typeFor(2)!;
    controller.arm(cannon);
    controller.handleGridTap(2, 2);
    final firstId = controller.placements.single.id;

    controller.beginDragAt(2, 2);
    controller.updateDragTarget(8, 8);
    expect(controller.dragPreview?.placement.gridX, 8);
    expect(controller.dragPreview?.placement.gridY, 8);
    expect(controller.dragIsInvalid, isFalse);
    controller.commitDrag();
    expect(controller.placements.single.gridX, 8);

    controller.arm(cannon);
    controller.handleGridTap(16, 16);
    final secondId = controller.placements.last.id;
    controller.beginDragAt(16, 16);
    controller.updateDragTarget(8, 8);

    expect(controller.dragIsInvalid, isTrue);
    expect(controller.invalidPlacementIds, contains(firstId));
    expect(controller.invalidPlacementIds, isNot(contains(secondId)));
    controller.cancelDrag();
    expect(controller.placements.last.gridX, 16);
  });
}
