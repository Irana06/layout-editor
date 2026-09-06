import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:shiclash/features/catalog/data/catalog_models.dart';
import 'package:shiclash/features/editor/domain/editor_controller.dart';
import 'package:shiclash/features/editor/domain/wall_connections.dart';
import 'package:shiclash/features/editor/presentation/building_sprite.dart';

/// Draws procedural rails behind the wall pillar sprites.  The catalog only
/// needs a single calibrated wall image per level; runs, corners and junctions
/// are assembled automatically from the placed tiles.
class WallConnectionPainter extends CustomPainter {
  const WallConnectionPainter({
    required this.scenery,
    required this.connections,
  });

  final Scenery scenery;
  final WallConnectionIndex connections;

  @override
  void paint(Canvas canvas, Size size) {
    for (final connection in connections.forwardConnections) {
      _drawRail(
        canvas,
        _nodeFor(connection.from),
        _nodeFor(connection.to),
        WallConnectionSkin.forLevel(connection.from.level),
      );
    }
  }

  /// [BuildingSprite] uses the bottom point of the diamond as its anchor.  A
  /// rail meeting that same point stays attached even when individual wall
  /// artwork has a different transparent crop.
  Offset _nodeFor(EditorPlacement placement) => isoPoint(
    scenery,
    placement.gridX.toDouble() + 1,
    placement.gridY.toDouble() + 1,
  ).translate(0, -scenery.tileHeight * .13);

  void _drawRail(
    Canvas canvas,
    Offset from,
    Offset to,
    WallConnectionSkin skin,
  ) {
    final delta = to - from;
    final distance = delta.distance;
    if (distance == 0) return;

    // Leave room for the two pillar sprites, which are painted afterward.
    final start = from + delta * .18;
    final end = to - delta * .18;
    final width = math.max(3.5, scenery.tileHeight * .23);
    final unit = Offset(delta.dx / distance, delta.dy / distance);
    final normal = Offset(-unit.dy, unit.dx);

    canvas.drawLine(
      start.translate(0, width * .20),
      end.translate(0, width * .20),
      Paint()
        ..color = Colors.black.withValues(alpha: .48)
        ..strokeWidth = width * 1.22
        ..strokeCap = StrokeCap.round,
    );
    canvas.drawLine(
      start,
      end,
      Paint()
        ..color = skin.body
        ..strokeWidth = width
        ..strokeCap = StrokeCap.round,
    );
    canvas.drawLine(
      start.translate(0, -width * .13),
      end.translate(0, -width * .13),
      Paint()
        ..color = skin.edge.withValues(alpha: .92)
        ..strokeWidth = width * .44
        ..strokeCap = StrokeCap.round,
    );
    canvas.drawLine(
      start,
      end,
      Paint()
        ..color = skin.energy.withValues(alpha: .48)
        ..strokeWidth = width * .42
        ..strokeCap = StrokeCap.round
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, width * .36),
    );
    canvas.drawLine(
      start,
      end,
      Paint()
        ..color = skin.energy
        ..strokeWidth = math.max(1.15, width * .15)
        ..strokeCap = StrokeCap.round,
    );

    // Small perpendicular seams stop a long rail from reading as a plain
    // neon line and make corners/junctions feel built from wall sections.
    final seamPaint = Paint()
      ..color = skin.edge.withValues(alpha: .72)
      ..strokeWidth = math.max(1, width * .10)
      ..strokeCap = StrokeCap.round;
    for (final progress in const [.38, .62]) {
      final center = start + (end - start) * progress;
      final half = normal * (width * .28);
      canvas.drawLine(center - half, center + half, seamPaint);
    }
  }

  @override
  bool shouldRepaint(covariant WallConnectionPainter oldDelegate) => true;
}

class WallConnectionSkin {
  const WallConnectionSkin({
    required this.body,
    required this.edge,
    required this.energy,
  });

  final Color body;
  final Color edge;
  final Color energy;

  /// Deliberately grouped in broad upgrade eras rather than trying to pretend
  /// one generic PNG is every official connected-wall sprite.  The blue-silver
  /// family covers the calibrated high-level walls visible in the current app.
  factory WallConnectionSkin.forLevel(int level) {
    if (level <= 3) {
      return const WallConnectionSkin(
        body: Color(0xFF72543B),
        edge: Color(0xFFD6B47B),
        energy: Color(0xFFF0CD80),
      );
    }
    if (level <= 6) {
      return const WallConnectionSkin(
        body: Color(0xFF4D4352),
        edge: Color(0xFFB18AC6),
        energy: Color(0xFFC982F6),
      );
    }
    if (level <= 9) {
      return const WallConnectionSkin(
        body: Color(0xFF344052),
        edge: Color(0xFF93A7C3),
        energy: Color(0xFF67A8FF),
      );
    }
    if (level <= 13) {
      return const WallConnectionSkin(
        body: Color(0xFF293C4C),
        edge: Color(0xFFBBCAD5),
        energy: Color(0xFF16D5FF),
      );
    }
    if (level <= 16) {
      return const WallConnectionSkin(
        body: Color(0xFF4C352B),
        edge: Color(0xFFE0A054),
        energy: Color(0xFFFF7047),
      );
    }
    return const WallConnectionSkin(
      body: Color(0xFF30293E),
      edge: Color(0xFFD4C3EF),
      energy: Color(0xFFC56BFF),
    );
  }
}
