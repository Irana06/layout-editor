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
);

void main() {
  late EditorController controller;

  setUp(() => controller = EditorController(_catalog));
  tearDown(() => controller.dispose());

  Future<void> pumpLandscape(WidgetTester tester) async {
    tester.view.physicalSize = const Size(880, 400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      MaterialApp(home: LandscapeEditorScreen(controller: controller)),
    );
    await tester.pump();
  }

  testWidgets('dock lists placeable buildings with their remaining allowance', (
    tester,
  ) async {
    await pumpLandscape(tester);

    // Town Hall is always allowed exactly once; Cannon is capped at 2 here.
    expect(find.text('x1'), findsOneWidget);
    expect(find.text('x2'), findsOneWidget);
    expect(find.text('Level 10'), findsNWidgets(2));
  });

  testWidgets('remaining allowance drops after a building is placed', (
    tester,
  ) async {
    await pumpLandscape(tester);

    controller.arm(controller.typeFor(2)!);
    controller.handleGridTap(6, 6);
    await tester.pump();

    expect(controller.placements, hasLength(1));
    expect(find.text('x1'), findsNWidgets(2));
    expect(find.text('x2'), findsNothing);
  });

  testWidgets('dock can be collapsed to uncover the scenery', (tester) async {
    await pumpLandscape(tester);
    expect(find.text('Level 10'), findsNWidgets(2));

    await tester.tap(find.byTooltip('Sembunyikan bangunan'));
    await tester.pump();

    expect(find.text('Level 10'), findsNothing);
    expect(find.byTooltip('Tampilkan bangunan'), findsOneWidget);
  });

  testWidgets('minimize control is available to return to portrait', (
    tester,
  ) async {
    await pumpLandscape(tester);

    expect(find.byTooltip('Kembali ke mode potrait'), findsOneWidget);
  });

  testWidgets('selecting a placement shows the same detail card as portrait', (
    tester,
  ) async {
    await pumpLandscape(tester);

    expect(find.byType(SelectionCard), findsNothing);

    controller.arm(controller.typeFor(2)!);
    controller.handleGridTap(6, 6);
    await tester.pump();

    expect(find.byType(SelectionCard), findsOneWidget);
    expect(find.text('Cannon'), findsWidgets);
    expect(find.byTooltip('Tutup detail'), findsOneWidget);
    expect(find.byTooltip('Naikkan level'), findsOneWidget);
  });

  testWidgets('closing the detail card clears the selection', (tester) async {
    await pumpLandscape(tester);

    controller.arm(controller.typeFor(2)!);
    controller.handleGridTap(6, 6);
    await tester.pump();

    await tester.tap(find.byTooltip('Tutup detail'));
    await tester.pump();

    expect(controller.selectedId, isNull);
    expect(find.byType(SelectionCard), findsNothing);
  });
}
