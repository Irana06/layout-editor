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

  void cancelTool() {
    armedBuildingTypeId = null;
    armedLevel = null;
    movingSelection = false;
    status = 'Mode pilih aktif.';
    notifyListeners();
  }

  void handleGridTap(int x, int y) {
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
    EditorPlacement? hit;
    for (final placement in placements.reversed) {
      final size = footprint(placement);
      if (x >= placement.gridX &&
          x < placement.gridX + size.width &&
          y >= placement.gridY &&
          y < placement.gridY + size.height) {
        hit = placement;
        break;
      }
    }
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
    final size = footprint(candidate);
    if (candidate.gridX < 0 ||
        candidate.gridY < 0 ||
        candidate.gridX + size.width > scenery.gridSize ||
        candidate.gridY + size.height > scenery.gridSize) {
      status = 'Objek melewati batas map.';
      notifyListeners();
      return false;
    }
    for (final item in placements) {
      if (item.id == ignoringId) continue;
      final other = footprint(item);
      final overlaps =
          candidate.gridX < item.gridX + other.width &&
          candidate.gridX + size.width > item.gridX &&
          candidate.gridY < item.gridY + other.height &&
          candidate.gridY + size.height > item.gridY;
      if (overlaps) {
        status = 'Petak tersebut sudah terisi.';
        notifyListeners();
        return false;
      }
    }
    return true;
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
