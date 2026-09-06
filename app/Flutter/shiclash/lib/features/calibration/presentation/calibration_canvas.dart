import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:shiclash/core/theme/app_theme.dart';
import 'package:shiclash/features/catalog/data/catalog_models.dart';
import 'package:shiclash/features/editor/presentation/building_sprite.dart';

class CalibrationCanvas extends StatefulWidget {
  const CalibrationCanvas({
    super.key,
    required this.scenery,
    this.type,
    this.level,
    required this.editMode,
    required this.showGrid,
    required this.showDeploymentRing,
    required this.opacity,
    required this.onDrag,
    required this.onStart,
    required this.onEnd,
  });
  final Scenery scenery;
  final BuildingType? type;
  final BuildingLevel? level;
  final bool editMode, showGrid, showDeploymentRing;
  final double opacity;
  final ValueChanged<Offset> onDrag;
  final VoidCallback onStart, onEnd;

  @override
  State<CalibrationCanvas> createState() => _CalibrationCanvasState();
}

class _CalibrationCanvasState extends State<CalibrationCanvas> {
  final _transform = TransformationController();
  Size? _viewport;
  @override
  void dispose() {
    _transform.dispose();
    super.dispose();
  }

  void _fit(Size viewport) {
    final s = widget.scenery;
    final width = s.imageWidth > 0 ? s.imageWidth : 1600.0;
    final height = s.imageHeight > 0 ? s.imageHeight : 1200.0;
    var scale = math.min(viewport.width / width, viewport.height / height);
    var center = Offset(width / 2, height / 2);
    if (widget.level != null) {
      scale = math.min(
        viewport.width / (s.tileWidth * 9),
        viewport.height / (s.tileHeight * 11),
      );
      center = isoPoint(s, s.gridSize / 2, s.gridSize / 2);
    }
    scale = scale.clamp(.02, 8);
    _transform.value = Matrix4.translationValues(
      viewport.width / 2 - center.dx * scale,
      viewport.height / 2 - center.dy * scale,
      0,
    )..scaleByDouble(scale, scale, scale, 1);
  }

  @override
  Widget build(BuildContext context) {
    final s = widget.scenery;
    final fw = (widget.level?.gridWidth ?? widget.type?.defaultGridWidth ?? 1)
        .toDouble();
    final fh = (widget.level?.gridHeight ?? widget.type?.defaultGridHeight ?? 1)
        .toDouble();
    final gx = (s.gridSize / 2).floorToDouble() - (fw / 2).floorToDouble();
    final gy = (s.gridSize / 2).floorToDouble() - (fh / 2).floorToDouble();
    return LayoutBuilder(
      builder: (context, box) {
        if (_viewport != box.biggest) {
          _viewport = box.biggest;
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) _fit(box.biggest);
          });
        }
        return Stack(
          children: [
            Positioned.fill(
              child: ClipRect(
                child: InteractiveViewer(
                  transformationController: _transform,
                  constrained: false,
                  alignment: Alignment.topLeft,
                  panEnabled: !widget.editMode,
                  scaleEnabled: !widget.editMode,
                  minScale: .02,
                  maxScale: 8,
                  boundaryMargin: const EdgeInsets.all(4000),
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onPanStart: widget.editMode
                        ? (_) => widget.onStart()
                        : null,
                    onPanUpdate: widget.editMode
                        ? (event) => widget.onDrag(event.delta)
                        : null,
                    onPanEnd: widget.editMode ? (_) => widget.onEnd() : null,
                    onPanCancel: widget.editMode ? widget.onEnd : null,
                    child: SizedBox(
                      width: s.imageWidth > 0 ? s.imageWidth : 1600,
                      height: s.imageHeight > 0 ? s.imageHeight : 1200,
                      child: Stack(
                        clipBehavior: Clip.none,
                        children: [
                          Positioned.fill(
                            child: Image.network(
                              s.imageUrl,
                              fit: BoxFit.fill,
                              loadingBuilder: (context, child, progress) =>
                                  progress == null
                                  ? child
                                  : const Center(
                                      child: CircularProgressIndicator(),
                                    ),
                              errorBuilder: (_, _, _) => const ColoredBox(
                                color: AppColors.panel,
                                child: Center(
                                  child: Text(
                                    'Scenery gagal dimuat. Periksa koneksi lalu buka ulang.',
                                  ),
                                ),
                              ),
                            ),
                          ),
                          Positioned.fill(
                            child: IgnorePointer(
                              child: CustomPaint(
                                painter: CalibrationGridPainter(
                                  s,
                                  showGrid: widget.showGrid,
                                  showDeploymentRing: widget.showDeploymentRing,
                                  footprint: widget.level == null
                                      ? null
                                      : Rect.fromLTWH(gx, gy, fw, fh),
                                ),
                              ),
                            ),
                          ),
                          if (widget.level != null)
                            BuildingSprite(
                              scenery: s,
                              level: widget.level!,
                              gridX: gx,
                              gridY: gy,
                              footprintWidth: fw,
                              footprintHeight: fh,
                              opacity: widget.opacity,
                            ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
            Positioned(
              right: 8,
              top: 8,
              child: IconButton.filledTonal(
                tooltip: 'Paskan preview',
                onPressed: () => _fit(box.biggest),
                icon: const Icon(Icons.center_focus_strong),
              ),
            ),
          ],
        );
      },
    );
  }
}

class CalibrationGridPainter extends CustomPainter {
  const CalibrationGridPainter(
    this.scenery, {
    required this.showGrid,
    required this.showDeploymentRing,
    this.footprint,
  });
  final Scenery scenery;
  final bool showGrid;
  final bool showDeploymentRing;
  final Rect? footprint;

  @override
  void paint(Canvas canvas, Size size) {
    final n = scenery.gridSize.toDouble();
    final thin = Paint()
      ..color = Colors.white.withValues(alpha: .28)
      ..strokeWidth = 1;
    if (showGrid) {
      for (var i = 0; i <= scenery.gridSize; i++) {
        canvas.drawLine(
          isoPoint(scenery, i.toDouble(), 0),
          isoPoint(scenery, i.toDouble(), n),
          thin,
        );
        canvas.drawLine(
          isoPoint(scenery, 0, i.toDouble()),
          isoPoint(scenery, n, i.toDouble()),
          thin,
        );
      }
    }
    void diamond(Rect area, Color color, double width) {
      final points = [
        area.topLeft,
        area.topRight,
        area.bottomRight,
        area.bottomLeft,
      ].map((p) => isoPoint(scenery, p.dx, p.dy)).toList();
      final path = Path()..addPolygon(points, true);
      canvas.drawPath(
        path,
        Paint()
          ..color = color
          ..style = PaintingStyle.stroke
          ..strokeWidth = width,
      );
    }

    if (showGrid) diamond(Rect.fromLTWH(0, 0, n, n), AppColors.brass, 3);
    if (footprint != null) {
      final map = Rect.fromLTWH(0, 0, n, n);
      final expanded = Rect.fromLTRB(
        (footprint!.left - 1).clamp(map.left, map.right),
        (footprint!.top - 1).clamp(map.top, map.bottom),
        (footprint!.right + 1).clamp(map.left, map.right),
        (footprint!.bottom + 1).clamp(map.top, map.bottom),
      );
      final outer = [
        expanded.topLeft,
        expanded.topRight,
        expanded.bottomRight,
        expanded.bottomLeft,
      ].map((p) => isoPoint(scenery, p.dx, p.dy)).toList();
      final inner = [
        footprint!.topLeft,
        footprint!.topRight,
        footprint!.bottomRight,
        footprint!.bottomLeft,
      ].map((p) => isoPoint(scenery, p.dx, p.dy)).toList();
      if (showDeploymentRing) {
        canvas.drawPath(
          Path()
            ..fillType = PathFillType.evenOdd
            ..addPolygon(outer, true)
            ..addPolygon(inner, true),
          Paint()..color = Colors.white.withValues(alpha: .10),
        );
        canvas.drawPath(
          Path()..addPolygon(outer, true),
          Paint()
            ..color = Colors.white.withValues(alpha: .55)
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1.25,
        );
      }
      canvas.drawPath(
        Path()..addPolygon(inner, true),
        Paint()..color = const Color(0xFF315D21).withValues(alpha: .34),
      );
      diamond(footprint!, Colors.cyanAccent, 3);
      final center = isoPoint(
        scenery,
        footprint!.center.dx,
        footprint!.center.dy,
      );
      canvas.drawCircle(center, 4, Paint()..color = Colors.cyanAccent);
    } else {
      final origin = isoPoint(scenery, 0, 0);
      final axis = Paint()
        ..color = Colors.cyanAccent
        ..strokeWidth = 3;
      canvas.drawLine(
        origin - const Offset(14, 0),
        origin + const Offset(14, 0),
        axis,
      );
      canvas.drawLine(
        origin - const Offset(0, 14),
        origin + const Offset(0, 14),
        axis,
      );
    }
  }

  @override
  bool shouldRepaint(CalibrationGridPainter old) => true;
}
