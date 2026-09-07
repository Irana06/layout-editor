import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:shiclash/core/theme/app_theme.dart';
import 'package:shiclash/features/catalog/data/catalog_models.dart';
import 'package:shiclash/features/editor/domain/editor_controller.dart';
import 'package:shiclash/features/editor/domain/wall_connections.dart';
import 'package:shiclash/features/editor/presentation/building_sprite.dart';

class IsometricBoard extends StatefulWidget {
  const IsometricBoard({required this.controller, super.key});

  final EditorController controller;

  @override
  State<IsometricBoard> createState() => _IsometricBoardState();
}

class _IsometricBoardState extends State<IsometricBoard> {
  final TransformationController _transform = TransformationController();
  int? _fittedSceneryId;
  Size? _fittedViewport;

  @override
  void dispose() {
    _transform.dispose();
    super.dispose();
  }

  ({int x, int y}) _gridAt(Offset position) {
    final scenery = widget.controller.scenery;
    final dx = position.dx - scenery.originX;
    final dy = position.dy - scenery.originY;
    final halfW = scenery.tileWidth / 2;
    final halfH = scenery.tileHeight / 2;
    return (
      x: ((dx / halfW + dy / halfH) / 2).floor(),
      y: ((dy / halfH - dx / halfW) / 2).floor(),
    );
  }

  void _tap(TapUpDetails details) {
    final grid = _gridAt(details.localPosition);
    widget.controller.handleGridTap(grid.x, grid.y);
  }

  void _beginMove(LongPressStartDetails details) {
    final grid = _gridAt(details.localPosition);
    widget.controller.beginDragAt(grid.x, grid.y);
  }

  void _updateMove(LongPressMoveUpdateDetails details) {
    final grid = _gridAt(details.localPosition);
    widget.controller.updateDragTarget(grid.x, grid.y);
  }

  void _updatePaletteDrag(Offset viewportPosition) {
    final scenePosition = _transform.toScene(viewportPosition);
    final grid = _gridAt(scenePosition);
    widget.controller.updateDragTarget(grid.x, grid.y);
  }

  void resetView() => _transform.value = Matrix4.identity();

  /// Scale at which the whole scenery is visible. Sceneries are far larger than
  /// a phone screen (a typical one is 3705x2545), so this is well below 1 and
  /// must not be floored at a fixed minimum or the map never fits.
  double _fitScaleFor(Size viewport, Scenery scenery) {
    final sceneWidth = scenery.imageWidth > 0 ? scenery.imageWidth : 1600.0;
    final sceneHeight = scenery.imageHeight > 0 ? scenery.imageHeight : 1200.0;

    return math
        .min(viewport.width / sceneWidth, viewport.height / sceneHeight)
        .clamp(.02, 1.0);
  }

  void _fitScene(Size viewport, Scenery scenery) {
    final sceneWidth = scenery.imageWidth > 0 ? scenery.imageWidth : 1600.0;
    final sceneHeight = scenery.imageHeight > 0 ? scenery.imageHeight : 1200.0;
    final scale = _fitScaleFor(viewport, scenery);
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

        return LayoutBuilder(
          builder: (context, constraints) {
            // Re-fit for a new scenery, and also when the viewport itself
            // changes shape — rotating into landscape would otherwise keep the
            // portrait framing and leave the scenery half off-screen.
            final viewport = constraints.biggest;
            if (_fittedSceneryId != scenery.id || _fittedViewport != viewport) {
              _fittedSceneryId = scenery.id;
              _fittedViewport = viewport;
              WidgetsBinding.instance.addPostFrameCallback((_) {
                if (mounted) _fitScene(viewport, scenery);
              });
            }
            return DragTarget<PaletteBuildingDrag>(
              onWillAcceptWithDetails: (details) {
                final type = controller.typeFor(details.data.buildingTypeId);
                if (type == null) return false;
                controller.beginPaletteDrag(type, level: details.data.level);
                _updatePaletteDrag(details.offset);
                return true;
              },
              onMove: (details) => _updatePaletteDrag(details.offset),
              onAcceptWithDetails: (details) {
                _updatePaletteDrag(details.offset);
                controller.commitDrag();
              },
              onLeave: (_) => controller.cancelDrag(),
              builder: (context, _, _) => ClipRect(
                child: ColoredBox(
                  color: const Color(0xFF070605),
                  child: InteractiveViewer(
                    transformationController: _transform,
                    constrained: false,
                    panEnabled: !controller.dragging,
                    // Room to breathe past the edges: stopping exactly at the
                    // map made the view feel stuck, with no way to pull a
                    // corner toward the middle of the screen to work on it.
                    minScale: _fitScaleFor(viewport, scenery) * .45,
                    maxScale: 3.5,
                    boundaryMargin: const EdgeInsets.all(double.infinity),
                    child: GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTapUp: _tap,
                      onLongPressStart: _beginMove,
                      onLongPressMoveUpdate: _updateMove,
                      onLongPressEnd: (_) => controller.commitDrag(),
                      onLongPressCancel: controller.cancelDrag,
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
                            ...sorted.map(
                              (placement) => _PlacementSprite(
                                placement: placement,
                                controller: controller,
                                scenery: scenery,
                                tint:
                                    controller.invalidPlacementIds.contains(
                                      placement.id,
                                    )
                                    ? AppColors.danger.withValues(alpha: .15)
                                    : null,
                              ),
                            ),
                            if (controller.dragPreview != null)
                              _PlacementSprite(
                                placement: controller.dragPreview!.placement,
                                controller: controller,
                                scenery: scenery,
                                opacity: controller.dragIsInvalid ? .35 : .68,
                                tint: controller.dragIsInvalid
                                    ? AppColors.danger.withValues(alpha: .15)
                                    : null,
                              ),
                          ],
                        ),
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
    this.opacity = 1,
    this.tint,
  });

  final EditorPlacement placement;
  final EditorController controller;
  final Scenery scenery;
  final double opacity;
  final Color? tint;

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
      opacity: opacity,
      tint: tint,
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
    final ringCells = _deploymentRingCells(map, controller.placements);
    _drawDeploymentRing(canvas, ringCells);
    for (final placement in controller.placements) {
      _drawPlacement(
        canvas,
        placement,
        invalid: controller.invalidPlacementIds.contains(placement.id),
      );
    }
    final preview = controller.dragPreview;
    if (preview != null) {
      final previewRing = _deploymentRingCells(map, [preview.placement]);
      _drawDeploymentRing(
        canvas,
        previewRing,
        invalid: controller.dragIsInvalid,
      );
      _drawPlacement(
        canvas,
        preview.placement,
        invalid: controller.dragIsInvalid,
        preview: true,
      );
    }
    _drawAttackRange(canvas);
  }

  /// Rings showing what the selected defence covers, the way the game does:
  /// an outer reach and, for mortars and the like, an inner blind spot.
  void _drawAttackRange(Canvas canvas) {
    final placement = controller.selectedPlacement;
    if (placement == null) return;
    final type = controller.typeFor(placement.buildingTypeId);
    if (type == null || type.attackRangeMax <= 0) return;

    final footprint = controller.footprint(placement);
    final centre = isoPoint(
      scenery,
      placement.gridX + footprint.width / 2,
      placement.gridY + footprint.height / 2,
    );

    final stroke = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2
      ..color = Colors.white.withValues(alpha: .85);
    final fill = Paint()..color = Colors.white.withValues(alpha: .07);

    void ring(int range, {required bool filled}) {
      if (range <= 0) return;
      // A circle on the ground is an ellipse on screen; the tile grid is twice
      // as wide as it is tall, so the two axes scale by their own tile size.
      final radius = type.ringRadius(range);
      final box = Rect.fromCenter(
        center: centre,
        width: radius * scenery.tileWidth * math.sqrt2,
        height: radius * scenery.tileHeight * math.sqrt2,
      );
      if (filled) canvas.drawOval(box, fill);
      canvas.drawOval(box, stroke);
    }

    ring(type.attackRangeMax, filled: true);
    ring(type.attackRangeMin, filled: false);
  }

  void _drawPlacement(
    Canvas canvas,
    EditorPlacement placement, {
    required bool invalid,
    bool preview = false,
  }) {
    final type = controller.typeFor(placement.buildingTypeId);
    final isWall = isWallBuilding(type);
    final footprint = controller.footprint(placement);
    final area = Rect.fromLTWH(
      placement.gridX.toDouble(),
      placement.gridY.toDouble(),
      footprint.width.toDouble(),
      footprint.height.toDouble(),
    );
    final inner = _points(area);

    final ground = Path()..addPolygon(inner, true);
    canvas.drawPath(
      ground,
      Paint()
        ..color = invalid
            ? AppColors.danger.withValues(alpha: .15)
            : const Color(0xFF315D21).withValues(alpha: isWall ? .22 : .34)
        ..style = PaintingStyle.fill,
    );
    _drawGrass(canvas, area, ground);
    if (invalid || (!preview && placement.id == controller.selectedId)) {
      canvas.drawPath(
        ground,
        Paint()
          ..color = invalid
              ? AppColors.danger.withValues(alpha: .9)
              : Colors.white.withValues(alpha: .88)
          ..style = PaintingStyle.stroke
          ..strokeWidth = invalid ? 2.2 : 2,
      );
    }
  }

  Set<String> _deploymentRingCells(
    Rect map,
    Iterable<EditorPlacement> placements,
  ) {
    final cells = <String>{};
    for (final placement in placements) {
      final type = controller.typeFor(placement.buildingTypeId);
      if (type?.showsDeploymentRing != true) continue;
      final footprint = controller.footprint(placement);
      final left = math.max(0, placement.gridX - 1).toInt();
      final top = math.max(0, placement.gridY - 1).toInt();
      final right = math.min(
        map.right.toInt(),
        placement.gridX + footprint.width + 1,
      );
      final bottom = math.min(
        map.bottom.toInt(),
        placement.gridY + footprint.height + 1,
      );
      for (var x = left; x < right; x++) {
        for (var y = top; y < bottom; y++) {
          cells.add('$x:$y');
        }
      }
    }
    return cells;
  }

  void _drawDeploymentRing(
    Canvas canvas,
    Set<String> cells, {
    bool invalid = false,
  }) {
    bool contains(int x, int y) => cells.contains('$x:$y');
    final fill = Paint()
      ..color = invalid
          ? AppColors.danger.withValues(alpha: .15)
          : Colors.white.withValues(alpha: .10)
      ..style = PaintingStyle.fill;
    final outline = Paint()
      ..color = invalid
          ? AppColors.danger.withValues(alpha: .86)
          : Colors.white.withValues(alpha: .55)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.25;
    for (final key in cells) {
      final parts = key.split(':');
      final x = int.parse(parts.first);
      final y = int.parse(parts.last);
      final top = isoPoint(scenery, x.toDouble(), y.toDouble());
      final right = isoPoint(scenery, x + 1.0, y.toDouble());
      final bottom = isoPoint(scenery, x + 1.0, y + 1.0);
      final left = isoPoint(scenery, x.toDouble(), y + 1.0);
      canvas.drawPath(
        Path()..addPolygon([top, right, bottom, left], true),
        fill,
      );
      if (!contains(x, y - 1)) canvas.drawLine(top, right, outline);
      if (!contains(x + 1, y)) canvas.drawLine(right, bottom, outline);
      if (!contains(x, y + 1)) canvas.drawLine(bottom, left, outline);
      if (!contains(x - 1, y)) canvas.drawLine(left, top, outline);
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
