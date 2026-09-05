class CatalogBootstrap {
  const CatalogBootstrap({
    required this.sceneries,
    required this.buildingTypes,
    required this.unlockRules,
  });

  factory CatalogBootstrap.fromJson(Map<String, dynamic> json) {
    final data = json['data'] as Map<String, dynamic>? ?? const {};

    return CatalogBootstrap(
      sceneries: _list(data['sceneries'])
          .map((item) => Scenery.fromJson(item))
          .toList(growable: false),
      buildingTypes: _list(data['building_types'])
          .map((item) => BuildingType.fromJson(item))
          .toList(growable: false),
      unlockRules: _list(data['unlock_rules'])
          .map((item) => BuildingUnlockRule.fromJson(item))
          .toList(growable: false),
    );
  }

  final List<Scenery> sceneries;
  final List<BuildingType> buildingTypes;
  final List<BuildingUnlockRule> unlockRules;

  BuildingType? get townHall {
    for (final type in buildingTypes) {
      if (type.isTownHall) return type;
    }

    return null;
  }

  int maxLevelFor(int buildingTypeId, int thLevel) {
    for (final rule in unlockRules) {
      if (rule.buildingTypeId == buildingTypeId && rule.thLevel == thLevel) {
        return rule.maxBuildingLevel;
      }
    }

    return 0;
  }
}

class Scenery {
  const Scenery({
    required this.id,
    required this.name,
    required this.imageUrl,
    required this.imageWidth,
    required this.imageHeight,
    required this.tileWidth,
    required this.tileHeight,
    required this.originX,
    required this.originY,
    required this.gridSize,
  });

  factory Scenery.fromJson(Map<String, dynamic> json) => Scenery(
    id: _int(json['id']),
    name: json['name'] as String? ?? 'Untitled scenery',
    imageUrl: json['image_url'] as String? ?? '',
    imageWidth: _double(json['image_width']),
    imageHeight: _double(json['image_height']),
    tileWidth: _double(json['tile_w'], fallback: 56),
    tileHeight: _double(json['tile_h'], fallback: 42),
    originX: _double(json['origin_x']),
    originY: _double(json['origin_y']),
    gridSize: _int(json['grid_n']),
  );

  final int id;
  final String name;
  final String imageUrl;
  final double imageWidth;
  final double imageHeight;
  final double tileWidth;
  final double tileHeight;
  final double originX;
  final double originY;
  final int gridSize;
}

class BuildingType {
  const BuildingType({
    required this.id,
    required this.name,
    required this.category,
    required this.isTownHall,
    required this.defaultGridWidth,
    required this.defaultGridHeight,
    required this.levels,
  });

  factory BuildingType.fromJson(Map<String, dynamic> json) => BuildingType(
    id: _int(json['id']),
    name: json['name'] as String? ?? 'Unknown building',
    category: json['category'] as String? ?? 'other',
    isTownHall: json['is_town_hall'] == true || json['is_town_hall'] == 1,
    defaultGridWidth: _int(json['default_grid_width'], fallback: 1),
    defaultGridHeight: _int(json['default_grid_height'], fallback: 1),
    levels: _list(json['levels'])
        .map((item) => BuildingLevel.fromJson(item))
        .toList(growable: false),
  );

  final int id;
  final String name;
  final String category;
  final bool isTownHall;
  final int defaultGridWidth;
  final int defaultGridHeight;
  final List<BuildingLevel> levels;

  BuildingLevel? thumbnailFor(int maxLevel) {
    BuildingLevel? result;

    for (final level in levels) {
      if (level.level <= maxLevel &&
          (result == null || level.level > result.level)) {
        result = level;
      }
    }

    return result;
  }
}

class BuildingLevel {
  const BuildingLevel({
    required this.id,
    required this.level,
    required this.imageUrl,
    required this.gridWidth,
    required this.gridHeight,
    required this.scale,
    required this.offsetX,
    required this.offsetY,
  });

  factory BuildingLevel.fromJson(Map<String, dynamic> json) => BuildingLevel(
    id: _int(json['id']),
    level: _int(json['level']),
    imageUrl: json['image_url'] as String? ?? '',
    gridWidth: json['grid_width'] == null ? null : _int(json['grid_width']),
    gridHeight: json['grid_height'] == null ? null : _int(json['grid_height']),
    scale: _double(json['scale'], fallback: 1),
    offsetX: _double(json['offset_x']),
    offsetY: _double(json['offset_y']),
  );

  final int id;
  final int level;
  final String imageUrl;
  final int? gridWidth;
  final int? gridHeight;
  final double scale;
  final double offsetX;
  final double offsetY;
}

class BuildingUnlockRule {
  const BuildingUnlockRule({
    required this.buildingTypeId,
    required this.thLevel,
    required this.maxBuildingLevel,
    this.maxCount,
  });

  factory BuildingUnlockRule.fromJson(Map<String, dynamic> json) =>
      BuildingUnlockRule(
        buildingTypeId: _int(json['building_type_id']),
        thLevel: _int(json['th_level']),
        maxBuildingLevel: _int(json['max_building_level']),
        maxCount: json['max_count'] == null ? null : _int(json['max_count']),
      );

  final int buildingTypeId;
  final int thLevel;
  final int maxBuildingLevel;
  final int? maxCount;
}

List<Map<String, dynamic>> _list(Object? value) {
  if (value is! List) return const [];

  return value.whereType<Map<String, dynamic>>().toList(growable: false);
}

int _int(Object? value, {int fallback = 0}) {
  if (value is int) return value;
  if (value is num) return value.toInt();

  return int.tryParse(value?.toString() ?? '') ?? fallback;
}

double _double(Object? value, {double fallback = 0}) {
  if (value is num) return value.toDouble();

  return double.tryParse(value?.toString() ?? '') ?? fallback;
}
