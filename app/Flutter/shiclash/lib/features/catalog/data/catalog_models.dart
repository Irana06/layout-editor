class CatalogBootstrap {
  const CatalogBootstrap({
    required this.sceneries,
    required this.buildingTypes,
    required this.unlockRules,
    this.version = '',
    this.fromCache = false,
  });

  factory CatalogBootstrap.fromJson(
    Map<String, dynamic> json, {
    bool fromCache = false,
  }) {
    final data = json['data'] as Map<String, dynamic>? ?? const {};
    final meta = json['meta'] as Map<String, dynamic>? ?? const {};

    return CatalogBootstrap(
      version: meta['catalog_version'] as String? ?? '',
      fromCache: fromCache,
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

  /// Fingerprint of the catalogue, used to tell a stored copy of the images
  /// apart from a newer one on the server.
  final String version;

  /// True when this came off the device because the server could not be
  /// reached — the app works, but may be out of date.
  final bool fromCache;

  /// Every image this catalogue refers to, for a full offline download.
  List<String> get imageUrls => [
    for (final scenery in sceneries)
      if (scenery.imageUrl.isNotEmpty) scenery.imageUrl,
    for (final type in buildingTypes)
      for (final level in type.levels)
        if (level.imageUrl.isNotEmpty) level.imageUrl,
  ];

  CatalogBootstrap withUnlockRules(List<BuildingUnlockRule> rules) =>
      CatalogBootstrap(
        sceneries: sceneries,
        buildingTypes: buildingTypes,
        unlockRules: rules,
      );

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
    this.locked = false,
    this.calibrated = false,
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
    locked: json['locked'] == true,
    calibrated: json['calibrated'] == true,
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
  final bool locked;
  final bool calibrated;

  Scenery withCalibration(Map<String, dynamic> values) => Scenery(
    id: id,
    name: name,
    imageUrl: imageUrl,
    imageWidth: imageWidth,
    imageHeight: imageHeight,
    tileWidth: (values['tile_w'] as num).toDouble(),
    tileHeight: (values['tile_h'] as num).toDouble(),
    originX: (values['origin_x'] as num).toDouble(),
    originY: (values['origin_y'] as num).toDouble(),
    gridSize: (values['grid_n'] as num).toInt(),
    locked: values['locked'] as bool? ?? locked,
    calibrated: values['calibrated'] as bool? ?? calibrated,
  );

  Map<String, dynamic> calibrationValues() => {
    'tile_w': tileWidth,
    'tile_h': tileHeight,
    'origin_x': originX,
    'origin_y': originY,
    'grid_n': gridSize,
  };
}

/// Library order: the sequence a base is actually built in, decided by the
/// server. Ties fall back to the name so a category stays predictable.
int compareForLibrary(BuildingType a, BuildingType b) {
  final byOrder = a.displayOrder.compareTo(b.displayOrder);

  return byOrder != 0 ? byOrder : a.name.compareTo(b.name);
}

class BuildingType {
  const BuildingType({
    required this.id,
    required this.name,
    required this.category,
    this.subfolder,
    required this.isTownHall,
    required this.defaultGridWidth,
    required this.defaultGridHeight,
    required this.levels,
    this.showsDeploymentRing = true,
    this.attackRangeMin = 0,
    this.attackRangeMax = 0,
    this.displayOrder = 9999,
    this.modes = const {},
  });

  factory BuildingType.fromJson(Map<String, dynamic> json) => BuildingType(
    id: _int(json['id']),
    name: json['name'] as String? ?? 'Unknown building',
    category: json['category'] as String? ?? 'other',
    subfolder: json['subfolder'] as String?,
    isTownHall: json['is_town_hall'] == true || json['is_town_hall'] == 1,
    defaultGridWidth: _int(json['default_grid_width'], fallback: 1),
    defaultGridHeight: _int(json['default_grid_height'], fallback: 1),
    showsDeploymentRing: json['shows_deployment_ring'] == null
        ? _defaultDeploymentRing(json)
        : json['shows_deployment_ring'] == true ||
              json['shows_deployment_ring'] == 1,
    attackRangeMin: _int(json['attack_range_min']),
    attackRangeMax: _int(json['attack_range_max']),
    displayOrder: _int(json['display_order'], fallback: 9999),
    modes: {
      for (final entry in ((json['modes'] as Map?) ?? const {}).entries)
        '${entry.key}': '${entry.value}',
    },
    levels: _list(json['levels'])
        .map((item) => BuildingLevel.fromJson(item))
        .toList(growable: false),
  );

  final int id;
  final String name;
  final String category;
  final String? subfolder;
  final bool isTownHall;
  final int defaultGridWidth;
  final int defaultGridHeight;
  final bool showsDeploymentRing;

  /// Attack range in tiles from the building's centre, as the game states it.
  /// Zero means no range at all, so nothing is drawn. A non-zero
  /// [attackRangeMin] is a blind spot.
  final int attackRangeMin;
  final int attackRangeMax;

  /// Where this sits in the library, decided by the server so the editor, the
  /// catalogue, and the web app never disagree about it.
  final int displayOrder;

  /// Modes this building can be switched between, as `key => label`, in the
  /// order they should be offered. Empty for buildings with no choice. The
  /// server owns this table so no client keeps its own copy.
  final Map<String, String> modes;
  final List<BuildingLevel> levels;

  /// Radius of a range ring, in tiles from the building's centre.
  ///
  /// The range *is* the radius: a Mortar of 11 reaches 11 tiles from its
  /// middle, not 11 beyond its own footprint. Footprint width played no part —
  /// adding half of it drew every multi-tile building's ring a tile too wide.
  double ringRadius(int range) => range.toDouble();

  BuildingType copyWith({
    int? defaultGridWidth,
    int? defaultGridHeight,
    bool? showsDeploymentRing,
    int? attackRangeMin,
    int? attackRangeMax,
    int? displayOrder,
    List<BuildingLevel>? levels,
  }) => BuildingType(
    id: id,
    name: name,
    category: category,
    subfolder: subfolder,
    isTownHall: isTownHall,
    defaultGridWidth: defaultGridWidth ?? this.defaultGridWidth,
    defaultGridHeight: defaultGridHeight ?? this.defaultGridHeight,
    showsDeploymentRing: showsDeploymentRing ?? this.showsDeploymentRing,
    attackRangeMin: attackRangeMin ?? this.attackRangeMin,
    attackRangeMax: attackRangeMax ?? this.attackRangeMax,
    displayOrder: displayOrder ?? this.displayOrder,
    modes: modes,
    levels: levels ?? this.levels,
  );

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

  /// A footprint belongs to the building family, not to one sprite level.
  /// Level-specific visual calibration remains intact when this changes.
  BuildingType withSharedFootprint(int size) => copyWith(
    defaultGridWidth: size,
    defaultGridHeight: size,
    levels: levels
        .map((level) => level.withFootprint(width: null, height: null))
        .toList(growable: false),
  );

  BuildingType withLevels(List<BuildingLevel> values) =>
      copyWith(levels: List.unmodifiable(values));

  BuildingType withDeploymentRing(bool value) =>
      copyWith(showsDeploymentRing: value);

  BuildingType withAttackRange({int? min, int? max}) =>
      copyWith(attackRangeMin: min, attackRangeMax: max);
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
    this.variant,
  });

  factory BuildingLevel.fromJson(Map<String, dynamic> json) => BuildingLevel(
    id: _int(json['id']),
    level: _int(json['level']),
    variant: json['variant'] as String?,
    imageUrl: json['image_url'] as String? ?? '',
    gridWidth: json['grid_width'] == null ? null : _int(json['grid_width']),
    gridHeight: json['grid_height'] == null ? null : _int(json['grid_height']),
    scale: _double(json['scale'], fallback: 1),
    offsetX: _double(json['offset_x']),
    offsetY: _double(json['offset_y']),
  );

  final int id;
  final int level;

  /// Which mode this artwork is, for buildings the player chooses between —
  /// an Inferno Tower's `single`/`multi`, an X-Bow's `ground`/`air`. Null for
  /// the ordinary case of one artwork per level.
  final String? variant;
  final String imageUrl;
  final int? gridWidth;
  final int? gridHeight;
  final double scale;
  final double offsetX;
  final double offsetY;

  BuildingLevel withCalibration(Map<String, dynamic> values) => BuildingLevel(
    id: id,
    level: level,
    variant: variant,
    imageUrl: imageUrl,
    gridWidth: values['grid_width'] as int?,
    gridHeight: values['grid_height'] as int?,
    scale: (values['scale'] as num).toDouble(),
    offsetX: (values['offset_x'] as num).toDouble(),
    offsetY: (values['offset_y'] as num).toDouble(),
  );

  /// Keep the shared footprint untouched while editing the artwork for one
  /// level.  This is intentionally separate from [withCalibration] so a
  /// scale/position save cannot recreate a per-level footprint override.
  BuildingLevel withVisualCalibration(Map<String, dynamic> values) =>
      BuildingLevel(
        id: id,
        level: level,
        variant: variant,
        imageUrl: imageUrl,
        gridWidth: gridWidth,
        gridHeight: gridHeight,
        scale: (values['scale'] as num).toDouble(),
        offsetX: (values['offset_x'] as num).toDouble(),
        offsetY: (values['offset_y'] as num).toDouble(),
      );

  BuildingLevel withFootprint({int? width, int? height}) => BuildingLevel(
    id: id,
    level: level,
    variant: variant,
    imageUrl: imageUrl,
    gridWidth: width,
    gridHeight: height,
    scale: scale,
    offsetX: offsetX,
    offsetY: offsetY,
  );

  Map<String, dynamic> calibrationValues() => {
    'grid_width': gridWidth,
    'grid_height': gridHeight,
    'scale': scale,
    'offset_x': offsetX,
    'offset_y': offsetY,
  };

  Map<String, dynamic> visualCalibrationValues() => {
    'scale': scale,
    'offset_x': offsetX,
    'offset_y': offsetY,
  };
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

bool _defaultDeploymentRing(Map<String, dynamic> json) {
  final category = (json['category']?.toString() ?? '').toLowerCase();
  final subfolder = (json['subfolder']?.toString() ?? '')
      .toLowerCase()
      .replaceAll('_', '-')
      .replaceAll(' ', '-');
  return category != 'traps' && subfolder != 'hidden-tesla';
}
