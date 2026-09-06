import 'package:flutter/material.dart';
import 'package:shiclash/features/catalog/data/catalog_models.dart';

Offset isoPoint(Scenery scenery, double x, double y) => Offset(
  scenery.originX + (x - y) * scenery.tileWidth / 2,
  scenery.originY + (x + y) * scenery.tileHeight / 2,
);

/// Matches the web editor: natural aspect ratio, footprint width, bottom anchor.
class BuildingSprite extends StatelessWidget {
  const BuildingSprite({
    super.key,
    required this.scenery,
    required this.level,
    required this.gridX,
    required this.gridY,
    required this.footprintWidth,
    required this.footprintHeight,
    this.opacity = 1,
    this.tint,
  });
  final Scenery scenery;
  final BuildingLevel level;
  final double gridX, gridY, footprintWidth, footprintHeight;
  final double opacity;
  final Color? tint;

  @override
  Widget build(BuildContext context) {
    final a = isoPoint(scenery, gridX, gridY);
    final b = isoPoint(
      scenery,
      gridX + footprintWidth,
      gridY + footprintHeight,
    );
    final centerX = (a.dx + b.dx) / 2 + level.offsetX;
    final baseY =
        (a.dy + b.dy) / 2 +
        footprintHeight * scenery.tileHeight / 2 +
        level.offsetY;
    final width = footprintWidth * scenery.tileWidth * level.scale;
    return Positioned(
      left: centerX - width / 2,
      top: baseY,
      width: width,
      child: IgnorePointer(
        child: FractionalTranslation(
          translation: const Offset(0, -1),
          child: Opacity(
            opacity: opacity,
            child: ColorFiltered(
              colorFilter: tint == null
                  ? const ColorFilter.mode(Colors.transparent, BlendMode.dst)
                  : ColorFilter.mode(tint!, BlendMode.srcATop),
              child: Image.network(
                level.imageUrl,
                width: width,
                fit: BoxFit.fitWidth,
                errorBuilder: (_, _, _) => const SizedBox(
                  height: 80,
                  child: Icon(Icons.broken_image_outlined),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
