import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shiclash/core/theme/app_theme.dart';
import 'package:shiclash/features/account/data/google_account_controller.dart';
import 'package:shiclash/features/calibration/data/calibration_api.dart';
import 'package:shiclash/features/calibration/presentation/calibration_screen.dart';
import 'package:shiclash/features/catalog/data/catalog_api.dart';
import 'package:shiclash/features/catalog/data/catalog_models.dart';

class FakeCalibrationApi extends CalibrationApi {
  FakeCalibrationApi({this.admin = true}) : super(idToken: () async => 'test');
  final bool admin;
  bool failSave = false;
  Map<String, dynamic>? saved;
  String? savedPath;
  final scenery = <String, dynamic>{
    'id': 1,
    'name': 'Classic',
    'image_url': 'https://example.com/classic.png',
    'image_width': 1600,
    'image_height': 1200,
    'tile_w': 56,
    'tile_h': 42,
    'origin_x': 800,
    'origin_y': 100,
    'grid_n': 44,
    'calibrated': true,
    'locked': false,
  };
  @override
  Future<bool> isAdmin() async => admin;
  @override
  Future<CatalogBootstrap> load() async => CatalogBootstrap.fromJson({
    'data': {
      'sceneries': [scenery],
      'building_types': [
        {
          'id': 9,
          'name': 'Town Hall',
          'category': 'town_hall',
          'is_town_hall': true,
          'default_grid_width': 4,
          'default_grid_height': 4,
          'levels': [
            {
              'id': 9,
              'level': 1,
              'image_url': 'https://example.com/town-hall.png',
              'scale': 1,
              'offset_x': 0,
              'offset_y': 0,
            },
          ],
        },
        {
          'id': 1,
          'name': 'Cannon',
          'category': 'defensive',
          'default_grid_width': 3,
          'default_grid_height': 3,
          'levels': [
            {
              'id': 1,
              'level': 1,
              'image_url': 'https://example.com/cannon.png',
              'scale': 1,
              'offset_x': 0,
              'offset_y': 0,
            },
          ],
        },
      ],
      'unlock_rules': [],
    },
  });
  @override
  Future<Map<String, dynamic>> request(
    String path, {
    Map<String, dynamic>? body,
  }) async {
    if (failSave) throw const CalibrationException('Tidak dapat terhubung.', 0);
    savedPath = path;
    saved = body;
    if (path == 'admin/unlock-rules') {
      return {
        'unlockRules': [
          for (final rule in body?['rules'] as List? ?? const [])
            {
              ...Map<String, dynamic>.from(rule as Map),
              'th_level': body?['th_level'],
            },
        ],
      };
    }
    return {
      'scenery': {...scenery, ...?body},
    };
  }
}

void main() {
  Future<void> open(WidgetTester tester, FakeCalibrationApi api) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final account = GoogleAccountController(enabled: false);
    final repository = CatalogRepository(CatalogApi());
    addTearDown(account.dispose);
    addTearDown(repository.dispose);
    addTearDown(api.close);
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.dark,
        home: CalibrationScreen(
          account: account,
          repository: repository,
          api: api,
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('non-admin has no calibration controls', (tester) async {
    await open(tester, FakeCalibrationApi(admin: false));
    expect(find.text('Akun ini belum memiliki akses admin.'), findsOneWidget);
    expect(find.text('Simpan kalibrasi'), findsNothing);
  });

  testWidgets(
    'phone supports precision edit, dirty protection, retry and saved baseline',
    (tester) async {
      final api = FakeCalibrationApi();
      await open(tester, api);
      await tester.scrollUntilVisible(
        find.text('Lebar tile (px)'),
        250,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.drag(find.byType(ListView).first, const Offset(0, -150));
      await tester.pumpAndSettle();
      await tester.tap(
        find
            .ancestor(
              of: find.text('Lebar tile (px)'),
              matching: find.byType(InkWell),
            )
            .first,
      );
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextFormField), '57.5');
      await tester.tap(find.text('Terapkan'));
      await tester.pumpAndSettle();
      expect(find.text('Ada perubahan belum disimpan'), findsOneWidget);
      await tester.tap(find.text('Building'));
      await tester.pumpAndSettle();
      expect(find.text('Perubahan belum disimpan'), findsOneWidget);
      await tester.tap(find.text('Tetap di sini'));
      await tester.pumpAndSettle();
      api.failSave = true;
      await tester.tap(find.text('Simpan kalibrasi'));
      await tester.pumpAndSettle();
      expect(find.text('Ada perubahan belum disimpan'), findsOneWidget);
      api.failSave = false;
      await tester.tap(find.text('Simpan kalibrasi'));
      await tester.pumpAndSettle();
      expect(api.saved?['tile_w'], 57.5);
      expect(find.text('Ada perubahan belum disimpan'), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('admin configures availability, max level and count per TH', (
    tester,
  ) async {
    final api = FakeCalibrationApi();
    await open(tester, api);
    await tester.tap(find.text('Aturan TH'));
    await tester.pumpAndSettle();
    expect(find.text('TH 1 · 0 jenis building'), findsOneWidget);
    await tester.tap(find.text('Defensive'));
    await tester.pumpAndSettle();
    await tester.tap(find.byType(Switch).first);
    await tester.pumpAndSettle();
    expect(find.text('Level maks.'), findsOneWidget);
    expect(find.text('Jumlah maks.'), findsOneWidget);
    await tester.scrollUntilVisible(
      find.text('Simpan aturan TH'),
      250,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(find.text('Simpan aturan TH'));
    await tester.pumpAndSettle();
    expect(api.savedPath, 'admin/unlock-rules');
    expect(api.saved?['th_level'], 1);
    expect((api.saved?['rules'] as List).single['max_building_level'], 1);
    expect((api.saved?['rules'] as List).single['max_count'], 1);
  });

  testWidgets('building picker groups assets and selects a named level', (
    tester,
  ) async {
    final api = FakeCalibrationApi();
    await open(tester, api);
    await tester.tap(find.text('Building'));
    await tester.pumpAndSettle();
    await tester.tap(
      find
          .ancestor(
            of: find.text('Aset building & level'),
            matching: find.byType(InkWell),
          )
          .first,
    );
    await tester.pumpAndSettle();
    expect(find.text('Pilih aset building'), findsOneWidget);
    await tester.tap(find.text('Defensive'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Cannon').first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Cannon · Level 1'));
    await tester.pumpAndSettle();
    expect(find.text('Cannon · Level 1'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
