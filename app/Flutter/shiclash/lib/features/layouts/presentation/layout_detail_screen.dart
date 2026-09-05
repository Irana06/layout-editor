import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:shiclash/core/theme/app_theme.dart';
import 'package:shiclash/features/layouts/data/draft_store.dart';

class LayoutDetailScreen extends StatelessWidget {
  const LayoutDetailScreen({super.key, required this.draft});
  final LocalDraft draft;
  @override
  Widget build(BuildContext context) {
    final rows = (draft.layout['data'] as List).cast<Map>();
    final kinds = rows.map((row) => row['building_type_id']).toSet().length;
    return Scaffold(
      appBar: AppBar(title: const Text('Detail layout')),
      body: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          Text(draft.title, style: Theme.of(context).textTheme.headlineMedium),
          const SizedBox(height: 8),
          Text(
            'Disimpan ${draft.updatedAt.toLocal().toString().substring(0, 16)}',
          ),
          const SizedBox(height: 24),
          Container(
            height: 260,
            decoration: BoxDecoration(
              color: AppColors.panel,
              border: Border.all(color: AppColors.line),
              borderRadius: BorderRadius.circular(8),
            ),
            child: rows.isEmpty
                ? const Center(child: Text('Canvas kosong'))
                : CustomPaint(painter: _PositionPreview(rows)),
          ),
          const SizedBox(height: 8),
          const Text(
            'Pratinjau posisi objek • ukuran titik bukan footprint bangunan',
            style: TextStyle(fontSize: 11),
          ),
          const SizedBox(height: 20),
          Card(
            child: Column(
              children: [
                ListTile(
                  title: const Text('Town Hall'),
                  trailing: Text('${draft.layout['th_level']}'),
                ),
                ListTile(
                  title: const Text('Jumlah objek'),
                  trailing: Text('${rows.length}'),
                ),
                ListTile(
                  title: const Text('Jenis bangunan'),
                  trailing: Text('$kinds'),
                ),
                const ListTile(
                  title: Text('Penyimpanan'),
                  trailing: Text('Perangkat ini'),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          FilledButton.icon(
            onPressed: () => Navigator.pop(context, true),
            icon: const Icon(Icons.edit_outlined),
            label: const Text('Buka di editor'),
          ),
        ],
      ),
    );
  }
}

class _PositionPreview extends CustomPainter {
  _PositionPreview(this.rows);
  final List<Map> rows;
  @override
  void paint(Canvas canvas, Size size) {
    if (rows.isEmpty) return;
    final points = rows.map((row) {
      final x = (row['gx'] as num).toDouble();
      final y = (row['gy'] as num).toDouble();
      return Offset(x - y, (x + y) / 2);
    }).toList();
    final minX = points.map((p) => p.dx).reduce(math.min);
    final maxX = points.map((p) => p.dx).reduce(math.max);
    final minY = points.map((p) => p.dy).reduce(math.min);
    final maxY = points.map((p) => p.dy).reduce(math.max);
    final scale = math.min(
      (size.width - 48) / math.max(maxX - minX, 8),
      (size.height - 48) / math.max(maxY - minY, 8),
    );
    final center = Offset((minX + maxX) / 2, (minY + maxY) / 2);
    final paint = Paint()..color = AppColors.brass;
    for (final p in points) {
      final location = (p - center) * scale + size.center(Offset.zero);
      canvas.drawCircle(location, math.max(2, math.min(5, scale / 3)), paint);
    }
  }

  @override
  bool shouldRepaint(covariant _PositionPreview oldDelegate) =>
      oldDelegate.rows != rows;
}
