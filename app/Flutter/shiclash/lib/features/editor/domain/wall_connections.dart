import 'package:shiclash/features/catalog/data/catalog_models.dart';
import 'package:shiclash/features/editor/domain/editor_controller.dart';

/// A wall is stored as an ordinary one-tile placement.  The visual links are
/// derived at render time, so moving, undoing, or deleting one tile always
/// updates the whole run without a second source of truth.
bool isWallBuilding(BuildingType? type) =>
    type?.subfolder?.toLowerCase() == 'wall';

class WallConnectionMask {
  const WallConnectionMask({
    this.north = false,
    this.east = false,
    this.south = false,
    this.west = false,
  });

  final bool north;
  final bool east;
  final bool south;
  final bool west;

  bool get hasAny => north || east || south || west;
}

class WallConnection {
  const WallConnection({required this.from, required this.to});

  final EditorPlacement from;
  final EditorPlacement to;
}

/// Fast lookup for a render pass. A ring connects every adjacent piece in the
/// same wall family, including mixed upgrade levels: the placement boundary is
/// still continuous even when the pillar artwork differs.
class WallConnectionIndex {
  WallConnectionIndex(
    Iterable<EditorPlacement> placements,
    BuildingType? Function(int buildingTypeId) typeFor,
  ) {
    for (final placement in placements) {
      if (isWallBuilding(typeFor(placement.buildingTypeId))) {
        _walls[_key(
              placement.buildingTypeId,
              placement.gridX,
              placement.gridY,
            )] =
            placement;
      }
    }
  }

  final Map<String, EditorPlacement> _walls = {};

  bool isWall(EditorPlacement placement) => _walls.containsKey(
    _key(placement.buildingTypeId, placement.gridX, placement.gridY),
  );

  WallConnectionMask connectionsFor(EditorPlacement placement) {
    if (!isWall(placement)) return const WallConnectionMask();

    final typeId = placement.buildingTypeId;
    final x = placement.gridX;
    final y = placement.gridY;
    return WallConnectionMask(
      north: _at(typeId, x, y - 1) != null,
      east: _at(typeId, x + 1, y) != null,
      south: _at(typeId, x, y + 1) != null,
      west: _at(typeId, x - 1, y) != null,
    );
  }

  /// Only yields forward links.  This avoids painting the same segment twice
  /// while still producing corners, T-junctions, and long continuous runs.
  Iterable<WallConnection> get forwardConnections sync* {
    for (final wall in _walls.values) {
      final east = _at(wall.buildingTypeId, wall.gridX + 1, wall.gridY);
      if (east != null) yield WallConnection(from: wall, to: east);

      final south = _at(wall.buildingTypeId, wall.gridX, wall.gridY + 1);
      if (south != null) yield WallConnection(from: wall, to: south);
    }
  }

  EditorPlacement? _at(int typeId, int x, int y) => _walls[_key(typeId, x, y)];

  static String _key(int typeId, int x, int y) => '$typeId:$x:$y';
}
