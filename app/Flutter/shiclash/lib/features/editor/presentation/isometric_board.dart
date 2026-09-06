import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:shiclash/core/theme/app_theme.dart';
import 'package:shiclash/features/catalog/data/catalog_models.dart';
import 'package:shiclash/features/editor/domain/editor_controller.dart';
import 'package:shiclash/features/editor/domain/wall_connections.dart';
import 'package:shiclash/features/editor/presentation/building_sprite.dart';
import 'package:shiclash/features/editor/presentation/wall_connection_painter.dart';

class IsometricBoard extends StatefulWidget {
  const IsometricBoard({required this.controller, super.key});

  final EditorController controller;

  @override
  State<IsometricBoard> createState() => _IsometricBoardState();
}

class _IsometricBoardState extends State<IsometricBoard> {
  final TransformationController _transform = TransformationController();
  int? _fittedSceneryId;

  @override
  void dispose() {
    _transform.dispose();
    super.dispose();
  }

  void _tap(TapUpDetails details) {
    final scenery = widget.controller.scenery;
    final dx = details.localPosition.dx - scenery.originX;
    final dy = details.localPosition.dy - scenery.originY;
    final halfW = scenery.tileWidth / 2;
    final halfH = scenery.tileHeight / 2;
    final gridX = ((dx / halfW + dy / halfH) / 2).floor();
    final gridY = ((dy / halfH - dx / halfW) / 2).floor();
    widget.controller.handleGridTap(gridX, gridY);
  }

  void resetView() => _transform.value = Matrix4.identity();

  void _fitScene(Size viewport, Scenery scenery) {
    final sceneWidth = scenery.imageWidth > 0 ? scenery.imageWidth : 1600.0;
    final sceneHeight = scenery.imageHeight > 0 ? scenery.imageHeight : 1200.0;
    final scale = math
        .min(viewport.width / sceneWidth, viewport.height / sceneHeight)
        .clamp(.35, 1.0);
    final dx = (viewport.width - sceneWidth * scale) / 2;
    final dy = (viewport.height - sceneHeight * scale) / 2;
    _transform.value = Matrix4.translationValues(dx, dy, 0)
      ..scaleByDouble(scale, scale, scale, 1);
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: widget.controller,
      builder: (context, _) {
        final controller = widget.controller;
        final scenery = controller.scenery;
        final width = scenery.imageWidth > 0 ? scenery.imageWidth : 1600.0;
        final height = scenery.imageHeight > 0 ? scenery.imageHeight : 1200.0;
        final sorted = [...controller.placements]
          ..sort((a, b) => (a.gridX + a.gridY).compareTo(b.gridX + b.gridY));
        final wallConnections = WallConnectionIndex(
          controller.placements,
          controller.typeFor,
        );

        return LayoutBuilder(
          builder: (context, constraints) {
            if (_fittedSceneryId != scenery.id) {
              _fittedSceneryId = scenery.id;
              WidgetsBinding.instance.addPostFrameCallback((_) {
                if (mounted) _fitScene(constraints.biggest, scenery);
              });
            }
            return ClipRect(
              child: ColoredBox(
                color: const Color(0xFF070605),
                child: InteractiveViewer(
                  transformationController: _transform,
                  constrained: false,
                  minScale: .35,
                  maxScale: 3.5,
                  boundaryMargin: const EdgeInsets.all(500),
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTapUp: _tap,
                    child: SizedBox(
                      width: width,
                      height: height,
                      child: Stack(
                        clipBehavior: Clip.none,
                        children: [
                          Positioned.fill(
                            child: Image.network(
                              scenery.imageUrl,
                              fit: BoxFit.fill,
                              errorBuilder: (_, _, _) => const ColoredBox(
                                color: Color(0xFF16120F),
                                child: Center(
                                  child: Icon(
                                    Icons.image_not_supported_outlined,
                                    color: AppColors.muted,
                                  ),
                                ),
                              ),
                            ),
                          ),
                          if (controller.showGrid)
                            Positioned.fill(
                              child: IgnorePointer(
                                child: CustomPaint(
                                  painter: _GridPainter(scenery),
                                ),
                              ),
                            ),
                          Positioned.fill(
                            child: IgnorePointer(
                              child: CustomPaint(
                                painter: _PlacementGroundPainter(
                                  scenery,
                                  controller,
                                ),
                              ),
                            ),
                          ),
                          Positioned.fill(
                            child: IgnorePointer(
                              child: CustomPaint(
                                painter: WallConnectionPainter(
                                  scenery: scenery,
                                  connections: wallConnections,
                                ),
                              ),
                            ),
                          ),
                          ...sorted.map(
                            (placement) => _PlacementSprite(
                              placement: placement,
                              controller: controller,
                              scenery: scenery,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }
}

class _PlacementSprite extends StatelessWidget {
  const _PlacementSprite({
    required this.placement,
    required this.controller,
    required this.scenery,
  });

  final EditorPlacement placement;
  final EditorController controller;
  final Scenery scenery;

  @override
  Widget build(BuildContext context) {
    final level = controller.levelFor(placement);
    final size = controller.footprint(placement);
    if (level == null) return const SizedBox.shrink();
    return BuildingSprite(
      scenery: scenery,
      level: level,
      gridX: placement.gridX.toDouble(),
      gridY: placement.gridY.toDouble(),
      footprintWidth: size.width.toDouble(),
      footprintHeight: size.height.toDouble(),
    );
  }
}

class _GridPainter extends CustomPainter {
  const _GridPainter(this.scenery);

  final Scenery scenery;

  Offset point(double x, double y) => Offset(
    scenery.originX + (x - y) * scenery.tileWidth / 2,
    scenery.originY + (x + y) * scenery.tileHeight / 2,
  );

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white.withValues(alpha: .34)
      ..strokeWidth = 1.15;
    final border = Paint()
      ..color = Colors.white.withValues(alpha: .48)
      ..strokeWidth = 1.2;
    for (var i = 0; i <= scenery.gridSize; i++) {
      canvas.drawLine(
        point(i.toDouble(), 0),
        point(i.toDouble(), scenery.gridSize.toDouble()),
        paint,
      );
      canvas.drawLine(
        point(0, i.toDouble()),
        point(scenery.gridSize.toDouble(), i.toDouble()),
        paint,
      );
    }
    final outline = Path()
      ..moveTo(point(0, 0).dx, point(0, 0).dy)
      ..lineTo(
        point(scenery.gridSize.toDouble(), 0).dx,
        point(scenery.gridSize.toDouble(), 0).dy,
      )
      ..lineTo(
        point(scenery.gridSize.toDouble(), scenery.gridSize.toDouble()).dx,
        point(scenery.gridSize.toDouble(), scenery.gridSize.toDouble()).dy,
      )
      ..lineTo(
        point(0, scenery.gridSize.toDouble()).dx,
        point(0, scenery.gridSize.toDouble()).dy,
      )
      ..close();
    canvas.drawPath(outline, border);
  }

  @override
  bool shouldRepaint(covariant _GridPainter oldDelegate) =>
      oldDelegate.scenery != scenery;
}

class _PlacementGroundPainter extends CustomPainter {
  const _PlacementGroundPainter(this.scenery, this.controller);

  final Scenery scenery;
  final EditorController controller;

  List<Offset> _points(Rect rect) => [
    rect.topLeft,
    rect.topRight,
    rect.bottomRight,
    rect.bottomLeft,
  ].map((point) => isoPoint(scenery, point.dx, point.dy)).toList();

  @override
  void paint(Canvas canvas, Size size) {
    final map = Rect.fromLTWH(
      0,
      0,
      scenery.gridSize.toDouble(),
      scenery.gridSize.toDouble(),
    );
    for (final placement in controller.placements) {
      final isWall = isWallBuilding(
        controller.typeFor(placement.buildingTypeId),
      );
      final footprint = controller.footprint(placement);
      final area = Rect.fromLTWH(
        placement.gridX.toDouble(),
        placement.gridY.toDouble(),
        footprint.width.toDouble(),
        footprint.height.toDouble(),
      );
      final buffer = Rect.fromLTRB(
        (area.left - 1).clamp(map.left, map.right),
        (area.top - 1).clamp(map.top, map.bottom),
        (area.right + 1).clamp(map.left, map.right),
        (area.bottom + 1).clamp(map.top, map.bottom),
      );
      final inner = _points(area);
      if (!isWall) {
        final outer = _points(buffer);
        final deploymentRing = Path()
          ..fillType = PathFillType.evenOdd
          ..addPolygon(outer, true)
          ..addPolygon(inner, true);
        canvas.drawPath(
          deploymentRing,
          Paint()
            ..color = Colors.white.withValues(alpha: .10)
            ..style = PaintingStyle.fill,
        );
        canvas.drawPath(
          Path()..addPolygon(outer, true),
          Paint()
            ..color = Colors.white.withValues(alpha: .55)
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1.25,
        );
      }

      final ground = Path()..addPolygon(inner, true);
      canvas.drawPath(
        ground,
        Paint()
          ..color = const Color(0xFF315D21)
              .withValues(alpha: isWall ? .22 : .34)
          ..style = PaintingStyle.fill,
      );
      _drawGrass(canvas, area, ground);
      if (placement.id == controller.selectedId) {
        canvas.drawPath(
          ground,
          Paint()
            ..color = Colors.white.withValues(alpha: .88)
            ..style = PaintingStyle.stroke
            ..strokeWidth = 2,
        );
      }
    }
  }

  void _drawGrass(Canvas canvas, Rect area, Path clip) {
    canvas.save();
    canvas.clipPath(clip);
    final blade = Paint()
      ..color = const Color(0xFFB0CF6A).withValues(alpha: .28)
      ..strokeWidth = .8;
    for (var x = area.left; x < area.right; x += .5) {
      for (var y = area.top; y < area.bottom; y += .5) {
        final center = isoPoint(scenery, x + .25, y + .25);
        canvas.drawLine(center, center + const Offset(1.2, -3.2), blade);
      }
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _PlacementGroundPainter oldDelegate) => true;
}
