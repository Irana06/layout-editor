import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shiclash/features/catalog/data/catalog_models.dart';
import 'package:shiclash/features/editor/domain/editor_controller.dart';
import 'package:shiclash/features/editor/presentation/landscape_editor_screen.dart';
import 'package:shiclash/features/editor/presentation/selection_card.dart';

const _catalog = CatalogBootstrap(
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
      category: 'defensive',
      isTownHall: false,
      defaultGridWidth: 3,
      defaultGridHeight: 3,
      attackRangeMax: 9,
      levels: [
        BuildingLevel(
          id: 2,
          level: 9,
          imageUrl: '',
          gridWidth: 3,
          gridHeight: 3,
          scale: 1,
          offsetX: 0,
          offsetY: 0,
        ),
        BuildingLevel(
          id: 3,
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
);

void main() {
  late EditorController controller;

  setUp(() {
    controller = EditorController(_catalog);
    controller.arm(controller.typeFor(2)!);
    controller.handleGridTap(6, 6);
    controller.cancelTool();
  });
  tearDown(() => controller.dispose());

  Future<void> pump(WidgetTester tester, {required bool readOnly}) async {
    tester.view.physicalSize = const Size(880, 400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      MaterialApp(
        home: LandscapeEditorScreen(controller: controller, readOnly: readOnly),
      ),
    );
    await tester.pump();
  }

  testWidgets('read-only landscape hides the building dock and editing tools', (
    tester,
  ) async {
    await pump(tester, readOnly: true);

    expect(find.byTooltip('Sembunyikan bangunan'), findsNothing);
    expect(find.byTooltip('Hapus objek terpilih'), findsNothing);
    expect(find.byTooltip('Undo'), findsNothing);
    // The way back to portrait is the one control that stays.
    expect(find.byTooltip('Kembali ke mode potrait'), findsOneWidget);
  });

  testWidgets('the editing landscape still offers its full toolbar', (
    tester,
  ) async {
    await pump(tester, readOnly: false);

    expect(find.byTooltip('Sembunyikan bangunan'), findsOneWidget);
    expect(find.byTooltip('Undo'), findsOneWidget);
  });

  testWidgets('a selected building reports itself but cannot be re-levelled', (
    tester,
  ) async {
    controller.selectAt(6, 6);
    await pump(tester, readOnly: true);

    expect(find.byType(SelectionCard), findsOneWidget);
    expect(find.text('Cannon'), findsOneWidget);
    // Reading is fine; changing someone else's layout is not.
    expect(find.byTooltip('Naikkan level'), findsNothing);
    expect(find.byTooltip('Turunkan level'), findsNothing);
  });
}
