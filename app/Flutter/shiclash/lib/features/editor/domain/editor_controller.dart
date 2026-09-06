import 'package:flutter/foundation.dart';
import 'package:shiclash/features/catalog/data/catalog_models.dart';

class EditorPlacement {
  const EditorPlacement({
    required this.id,
    required this.buildingTypeId,
    required this.level,
    required this.gridX,
    required this.gridY,
  });

  final int id;
  final int buildingTypeId;
  final int level;
  final int gridX;
  final int gridY;

  EditorPlacement moveTo(int x, int y) => EditorPlacement(
    id: id,
    buildingTypeId: buildingTypeId,
    level: level,
    gridX: x,
    gridY: y,
  );

  EditorPlacement withLevel(int value) => EditorPlacement(
    id: id,
    buildingTypeId: buildingTypeId,
    level: value,
    gridX: gridX,
    gridY: gridY,
  );
}

class EditorDragPreview {
  const EditorDragPreview({
    required this.placement,
    this.sourceId,
    this.grabOffsetX = 0,
    this.grabOffsetY = 0,
  });

  final EditorPlacement placement;

  /// Null means the preview came from the building library rather than an
  /// already-placed object.
  final int? sourceId;
  final int grabOffsetX;
  final int grabOffsetY;
}

class PaletteBuildingDrag {
  const PaletteBuildingDrag({
    required this.buildingTypeId,
    required this.level,
  });

  final int buildingTypeId;
  final int level;
}

class _PlacementCheck {
  const _PlacementCheck(this.message, {this.collidingIds = const {}});

  final String? message;
  final Set<int> collidingIds;
  bool get isValid => message == null;
}

class EditorController extends ChangeNotifier {
  EditorController(this.catalog)
    : scenery = catalog.sceneries.first,
      townHallLevel = _initialTownHall(catalog) {
    _history.add(const []);
  }

  final CatalogBootstrap catalog;
  final List<List<EditorPlacement>> _history = [];
  int _historyIndex = 0;
  int _nextId = 1;

  late Scenery scenery;
  int townHallLevel;
  List<EditorPlacement> placements = const [];
  int? selectedId;
  int? armedBuildingTypeId;
  int? armedLevel;
  bool movingSelection = false;
  // The scenery remains clean by default; the line grid is an opt-in aid.
  bool showGrid = false;
  EditorDragPreview? dragPreview;
  Set<int> invalidPlacementIds = const {};
  String? _dragError;
  String status = 'Pilih bangunan, lalu ketuk petak untuk menempatkan.';

  bool get canUndo => _historyIndex > 0;
  bool get canRedo => _historyIndex < _history.length - 1;

  Map<String, dynamic> toLayout() => {
    'scenery_id': scenery.id,
    'th_level': townHallLevel,
    'data': placements
        .map(
          (item) => {
            'building_type_id': item.buildingTypeId,
            'level': item.level,
            'gx': item.gridX,
            'gy': item.gridY,
          },
        )
        .toList(),
  };

  /// Validate in a separate controller so an invalid draft cannot clear work.
  void restoreLayout(Map<String, dynamic> layout) {
    final scratch = EditorController(catalog);
    try {
      scratch.scenery = catalog.sceneries.firstWhere(
        (item) => item.id == layout['scenery_id'],
      );
      final th = layout['th_level'] as int;
      if (!(catalog.townHall?.levels.any((item) => item.level == th) ??
          false)) {
        throw const FormatException('Town Hall tidak tersedia');
      }
      scratch.townHallLevel = th;
      for (final raw in layout['data'] as List) {
        final row = Map<String, dynamic>.from(raw as Map);
        final type = scratch.typeFor(row['building_type_id'] as int);
        final level = row['level'] as int;
        if (type == null || !type.levels.any((item) => item.level == level)) {
          throw const FormatException('Bangunan atau level tidak tersedia');
        }
        final maxLevel = scratch.maxLevelFor(type);
        if (maxLevel < 1 ||
            (type.isTownHall ? level != maxLevel : level > maxLevel)) {
          throw const FormatException('Bangunan atau level tidak tersedia');
        }
        scratch.arm(type, level: level);
        final count = scratch.placements.length;
        scratch.handleGridTap(row['gx'] as int, row['gy'] as int);
        if (scratch.placements.length != count + 1) {
          throw FormatException(scratch.status);
        }
      }
      scenery = scratch.scenery;
      townHallLevel = th;
      placements = List.unmodifiable(scratch.placements);
      _nextId = scratch._nextId;
      selectedId = null;
      armedBuildingTypeId = null;
      armedLevel = null;
      movingSelection = false;
      _history
        ..clear()
        ..add(placements);
      _historyIndex = 0;
      status = 'Draft dibuka. ${placements.length} objek dipulihkan.';
      notifyListeners();
    } finally {
      scratch.dispose();
    }
  }

  EditorPlacement? get selectedPlacement {
    for (final placement in placements) {
      if (placement.id == selectedId) return placement;
    }
    return null;
  }

  bool get dragging => dragPreview != null;
  bool get dragIsInvalid => dragPreview != null && _dragError != null;

  EditorPlacement? placementAt(int x, int y) {
    for (final placement in placements.reversed) {
      final size = footprint(placement);
      if (x >= placement.gridX &&
          x < placement.gridX + size.width &&
          y >= placement.gridY &&
          y < placement.gridY + size.height) {
        return placement;
      }
    }
    return null;
  }

  BuildingType? typeFor(int id) {
    for (final type in catalog.buildingTypes) {
      if (type.id == id) return type;
    }
    return null;
  }

  BuildingLevel? levelFor(EditorPlacement placement) {
    final type = typeFor(placement.buildingTypeId);
    if (type == null) return null;
    for (final level in type.levels) {
      if (level.level == placement.level) return level;
    }
    return type.thumbnailFor(placement.level);
  }

  int maxCountFor(int buildingTypeId) {
    final type = typeFor(buildingTypeId);
    if (type?.isTownHall == true) return 1;
    for (final rule in catalog.unlockRules) {
      if (rule.buildingTypeId == buildingTypeId &&
          rule.thLevel == townHallLevel) {
        return rule.maxCount ?? 999;
      }
    }
    return 0;
  }

  ({int width, int height}) footprint(EditorPlacement placement) {
    final type = typeFor(placement.buildingTypeId);
    final level = levelFor(placement);
    return (
      width: level?.gridWidth ?? type?.defaultGridWidth ?? 1,
      height: level?.gridHeight ?? type?.defaultGridHeight ?? 1,
    );
  }

  void arm(BuildingType type, {int? level}) {
    final maxLevel = maxLevelFor(type);
    if (maxLevel < 1) {
      status = '${type.name} belum tersedia di TH $townHallLevel.';
      notifyListeners();
      return;
    }
    armedBuildingTypeId = type.id;
    // The Town Hall represents the selected base level, rather than an
    // independently upgradeable building.  It must therefore use that exact
    // level even when an older level was passed by a restored draft.
    armedLevel = type.isTownHall
        ? maxLevel
        : (level ?? maxLevel).clamp(1, maxLevel);
    selectedId = null;
    movingSelection = false;
    status = '${type.name} level $armedLevel siap ditempatkan.';
    notifyListeners();
  }

  /// Town Hall is always placeable exactly once at the selected Town Hall
  /// level. Every other building is controlled by its explicit unlock rule.
  int maxLevelFor(BuildingType type) {
    if (!type.isTownHall) {
      return catalog.maxLevelFor(type.id, townHallLevel);
    }

    // A catalog can be incomplete while assets are being calibrated.  Do not
    // arm a Town Hall level unless its matching sprite exists.
    return type.levels.any((item) => item.level == townHallLevel)
        ? townHallLevel
        : 0;
  }

  /// Buildings the current Town Hall can actually place, Town Hall first then
  /// alphabetical. Shared by the portrait library and the landscape dock so both
  /// always offer the same set.
  List<BuildingType> get availableBuildings {
    final buildings =
        catalog.buildingTypes.where((type) {
          final maxLevel = maxLevelFor(type);

          return maxLevel > 0 && type.thumbnailFor(maxLevel) != null;
        }).toList()..sort((a, b) {
          if (a.isTownHall == b.isTownHall) return a.name.compareTo(b.name);

          return a.isTownHall ? -1 : 1;
        });

    return List.unmodifiable(buildings);
  }

  /// How many more of this building the current Town Hall still allows.
  /// `null` means the rule sets no ceiling.
  int? remainingFor(int buildingTypeId) {
    final limit = maxCountFor(buildingTypeId);
    if (limit >= 999) return null;
    final placed = placements
        .where((item) => item.buildingTypeId == buildingTypeId)
        .length;

    return (limit - placed).clamp(0, limit);
  }

  void cancelTool() {
    armedBuildingTypeId = null;
    armedLevel = null;
    movingSelection = false;
    status = 'Mode pilih aktif.';
    notifyListeners();
  }

  void clearSelection() {
    selectedId = null;
    movingSelection = false;
    status = 'Mode pilih aktif.';
    notifyListeners();
  }

  void handleGridTap(int x, int y) {
    final hit = placementAt(x, y);
    // Selecting a placed object takes priority over an armed palette item.
    // This avoids the confusing "petak sudah terisi" response when the user
    // wants to inspect or drag a second copy of the same building.
    if (hit != null) {
      selectedId = hit.id;
      armedBuildingTypeId = null;
      armedLevel = null;
      movingSelection = false;
      status = '${typeFor(hit.buildingTypeId)?.name ?? 'Objek'} dipilih.';
      notifyListeners();
      return;
    }
    if (movingSelection && selectedPlacement != null) {
      _moveSelected(x, y);
      return;
    }
    if (armedBuildingTypeId != null) {
      _place(x, y);
      return;
    }
    selectAt(x, y);
  }

  void _place(int x, int y) {
    final type = typeFor(armedBuildingTypeId!);
    if (type == null) return;
    final currentCount = placements
        .where((item) => item.buildingTypeId == type.id)
        .length;
    final maxCount = maxCountFor(type.id);
    if (maxCount == 0 || currentCount >= maxCount) {
      status = 'Limit ${type.name} untuk TH $townHallLevel sudah tercapai.';
      notifyListeners();
      return;
    }
    final candidate = EditorPlacement(
      id: _nextId++,
      buildingTypeId: type.id,
      level: armedLevel ?? 1,
      gridX: x,
      gridY: y,
    );
    if (!_canOccupy(candidate)) return;
    _commit([...placements, candidate]);
    selectedId = candidate.id;
    status = '${type.name} ditempatkan di $x, $y.';
    notifyListeners();
  }

  void selectAt(int x, int y) {
    final hit = placementAt(x, y);
    selectedId = hit?.id;
    status = hit == null
        ? 'Tidak ada objek pada petak $x, $y.'
        : '${typeFor(hit.buildingTypeId)?.name ?? 'Objek'} dipilih.';
    notifyListeners();
  }

  void beginMove() {
    if (selectedPlacement == null) return;
    armedBuildingTypeId = null;
    armedLevel = null;
    movingSelection = true;
    status = 'Ketuk petak tujuan untuk memindahkan objek.';
    notifyListeners();
  }

  /// Starts a long-press move. The finger's original offset inside a large
  /// footprint is retained so the building does not jump below the pointer.
  void beginDragAt(int x, int y) {
    final hit = placementAt(x, y);
    if (hit == null) return;
    selectedId = hit.id;
    armedBuildingTypeId = null;
    armedLevel = null;
    movingSelection = false;
    dragPreview = EditorDragPreview(
      placement: hit,
      sourceId: hit.id,
      grabOffsetX: x - hit.gridX,
      grabOffsetY: y - hit.gridY,
    );
    invalidPlacementIds = const {};
    _dragError = null;
    status =
        'Geser ${typeFor(hit.buildingTypeId)?.name ?? 'objek'} ke petak tujuan.';
    notifyListeners();
  }

  /// Called when a library card enters the board's drag target.
  void beginPaletteDrag(BuildingType type, {int? level}) {
    final maxLevel = maxLevelFor(type);
    if (maxLevel < 1) return;
    final chosenLevel = type.isTownHall
        ? maxLevel
        : (level ?? maxLevel).clamp(1, maxLevel);
    dragPreview = EditorDragPreview(
      placement: EditorPlacement(
        id: -1,
        buildingTypeId: type.id,
        level: chosenLevel,
        gridX: 0,
        gridY: 0,
      ),
    );
    invalidPlacementIds = const {};
    _dragError = null;
    selectedId = null;
    armedBuildingTypeId = null;
    armedLevel = null;
    movingSelection = false;
    status = 'Taruh ${type.name} pada petak kosong.';
    notifyListeners();
  }

  void updateDragTarget(int x, int y) {
    final preview = dragPreview;
    if (preview == null) return;
    final candidate = preview.placement.moveTo(
      x - preview.grabOffsetX,
      y - preview.grabOffsetY,
    );
    final check = _checkPlacement(candidate, ignoringId: preview.sourceId);
    dragPreview = EditorDragPreview(
      placement: candidate,
      sourceId: preview.sourceId,
      grabOffsetX: preview.grabOffsetX,
      grabOffsetY: preview.grabOffsetY,
    );
    invalidPlacementIds = check.collidingIds;
    _dragError = check.message;
    notifyListeners();
  }

  void commitDrag() {
    final preview = dragPreview;
    if (preview == null) return;
    final check = _checkPlacement(
      preview.placement,
      ignoringId: preview.sourceId,
    );
    if (!check.isValid) {
      status = check.message!;
      _clearDrag();
      notifyListeners();
      return;
    }
    if (preview.sourceId == null) {
      final placed = EditorPlacement(
        id: _nextId++,
        buildingTypeId: preview.placement.buildingTypeId,
        level: preview.placement.level,
        gridX: preview.placement.gridX,
        gridY: preview.placement.gridY,
      );
      _commit([...placements, placed]);
      selectedId = placed.id;
      status =
          '${typeFor(placed.buildingTypeId)?.name ?? 'Objek'} ditempatkan di ${placed.gridX}, ${placed.gridY}.';
    } else {
      _commit([
        for (final item in placements)
          if (item.id == preview.sourceId) preview.placement else item,
      ]);
      selectedId = preview.sourceId;
      status =
          'Objek dipindahkan ke ${preview.placement.gridX}, ${preview.placement.gridY}.';
    }
    _clearDrag();
    notifyListeners();
  }

  void cancelDrag() {
    if (dragPreview == null) return;
    _clearDrag();
    status = 'Pemindahan dibatalkan.';
    notifyListeners();
  }

  void increaseSelectedLevel() => _changeSelectedLevel(1);
  void decreaseSelectedLevel() => _changeSelectedLevel(-1);

  void _changeSelectedLevel(int direction) {
    final selected = selectedPlacement;
    if (selected == null) return;
    final type = typeFor(selected.buildingTypeId);
    if (type == null || type.isTownHall) return;
    final available =
        type.levels
            .map((item) => item.level)
            .where((level) => level <= maxLevelFor(type))
            .toSet()
            .toList()
          ..sort();
    if (available.isEmpty) return;
    final index = available.indexOf(selected.level);
    if (index < 0) return;
    final nextIndex = (index + direction).clamp(0, available.length - 1);
    if (nextIndex == index) return;
    final candidate = selected.withLevel(available[nextIndex]);
    final check = _checkPlacement(candidate, ignoringId: selected.id);
    if (!check.isValid) {
      status = check.message!;
      notifyListeners();
      return;
    }
    _commit([
      for (final item in placements)
        if (item.id == selected.id) candidate else item,
    ]);
    status = '${type.name} diubah ke level ${candidate.level}.';
    notifyListeners();
  }

  void _moveSelected(int x, int y) {
    final selected = selectedPlacement;
    if (selected == null) return;
    final moved = selected.moveTo(x, y);
    if (!_canOccupy(moved, ignoringId: selected.id)) return;
    _commit([
      for (final item in placements)
        if (item.id == selected.id) moved else item,
    ]);
    movingSelection = false;
    status = 'Objek dipindahkan ke $x, $y.';
    notifyListeners();
  }

  void deleteSelected() {
    final selected = selectedPlacement;
    if (selected == null) return;
    _commit(placements.where((item) => item.id != selected.id).toList());
    selectedId = null;
    movingSelection = false;
    status = 'Objek dihapus.';
    notifyListeners();
  }

  void undo() {
    if (!canUndo) return;
    _historyIndex--;
    placements = List.unmodifiable(_history[_historyIndex]);
    selectedId = null;
    movingSelection = false;
    status = 'Undo.';
    notifyListeners();
  }

  void redo() {
    if (!canRedo) return;
    _historyIndex++;
    placements = List.unmodifiable(_history[_historyIndex]);
    selectedId = null;
    movingSelection = false;
    status = 'Redo.';
    notifyListeners();
  }

  void reset() {
    if (placements.isEmpty) return;
    _commit(const []);
    selectedId = null;
    movingSelection = false;
    status = 'Canvas dikosongkan.';
    notifyListeners();
  }

  void setTownHall(int level) {
    townHallLevel = level;
    placements = const [];
    selectedId = null;
    armedBuildingTypeId = null;
    movingSelection = false;
    _restartHistory();
    status = 'Town Hall $level aktif. Canvas dikosongkan.';
    notifyListeners();
  }

  void setScenery(Scenery value) {
    scenery = value;
    placements = const [];
    selectedId = null;
    armedBuildingTypeId = null;
    movingSelection = false;
    _restartHistory();
    status = '${value.name} aktif. Canvas dikosongkan.';
    notifyListeners();
  }

  void toggleGrid() {
    showGrid = !showGrid;
    notifyListeners();
  }

  bool _canOccupy(EditorPlacement candidate, {int? ignoringId}) {
    final check = _checkPlacement(candidate, ignoringId: ignoringId);
    if (check.isValid) return true;
    status = check.message!;
    notifyListeners();
    return false;
  }

  _PlacementCheck _checkPlacement(
    EditorPlacement candidate, {
    int? ignoringId,
  }) {
    final type = typeFor(candidate.buildingTypeId);
    if (type == null) return const _PlacementCheck('Building tidak tersedia.');
    final size = footprint(candidate);
    if (candidate.gridX < 0 ||
        candidate.gridY < 0 ||
        candidate.gridX + size.width > scenery.gridSize ||
        candidate.gridY + size.height > scenery.gridSize) {
      return const _PlacementCheck('Objek melewati batas map.');
    }
    if (ignoringId == null) {
      final currentCount = placements
          .where((item) => item.buildingTypeId == candidate.buildingTypeId)
          .length;
      final maxCount = maxCountFor(candidate.buildingTypeId);
      if (maxCount == 0 || currentCount >= maxCount) {
        return _PlacementCheck(
          'Limit ${type.name} untuk TH $townHallLevel sudah tercapai.',
        );
      }
    }
    final collisions = <int>{};
    for (final item in placements) {
      if (item.id == ignoringId) continue;
      final other = footprint(item);
      final overlaps =
          candidate.gridX < item.gridX + other.width &&
          candidate.gridX + size.width > item.gridX &&
          candidate.gridY < item.gridY + other.height &&
          candidate.gridY + size.height > item.gridY;
      if (overlaps) collisions.add(item.id);
    }
    if (collisions.isNotEmpty) {
      return _PlacementCheck(
        'Petak tersebut sudah terisi.',
        collidingIds: Set.unmodifiable(collisions),
      );
    }
    return const _PlacementCheck(null);
  }

  void _clearDrag() {
    dragPreview = null;
    invalidPlacementIds = const {};
    _dragError = null;
  }

  void _commit(List<EditorPlacement> next) {
    if (_historyIndex < _history.length - 1) {
      _history.removeRange(_historyIndex + 1, _history.length);
    }
    placements = List.unmodifiable(next);
    _history.add(placements);
    _historyIndex = _history.length - 1;
  }

  void _restartHistory() {
    _history
      ..clear()
      ..add(const []);
    _historyIndex = 0;
  }

  static int _initialTownHall(CatalogBootstrap catalog) {
    final levels = catalog.townHall?.levels.map((item) => item.level).toList();
    if (levels == null || levels.isEmpty) return 1;
    levels.sort();
    return levels.last;
  }
}
