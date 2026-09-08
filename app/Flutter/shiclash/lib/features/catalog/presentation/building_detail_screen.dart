import 'package:shiclash/features/catalog/presentation/offline_image.dart';
import 'package:flutter/material.dart';
import 'package:shiclash/features/catalog/data/catalog_models.dart';

class BuildingDetailScreen extends StatefulWidget {
  const BuildingDetailScreen({
    super.key,
    required this.building,
    required this.maxLevel,
    required this.thLevel,
    required this.maxCount,
  });
  final BuildingType building;
  final int maxLevel;
  final int thLevel;
  final int? maxCount;
  @override
  State<BuildingDetailScreen> createState() => _BuildingDetailScreenState();
}

class _BuildingDetailScreenState extends State<BuildingDetailScreen> {
  BuildingLevel? _selected;
  @override
  Widget build(BuildContext context) {
    final levels = widget.building.levels
        .where((item) => item.level <= widget.maxLevel)
        .toList();
    final level = _selected ?? widget.building.thumbnailFor(widget.maxLevel);
    return Scaffold(
      appBar: AppBar(title: Text(widget.building.name)),
      body: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          SizedBox(
            height: 230,
            child: level == null
                ? const Icon(Icons.castle_outlined, size: 80)
                : OfflineImage(
                    level.imageUrl,
                    fit: BoxFit.contain,
                    errorBuilder: (_, _, _) => const Center(
                      child: Icon(Icons.broken_image_outlined, size: 64),
                    ),
                  ),
          ),
          const SizedBox(height: 20),
          Text(
            widget.building.name,
            style: Theme.of(context).textTheme.headlineMedium,
          ),
          Text(
            widget.building.category.toUpperCase(),
            style: Theme.of(context).textTheme.labelSmall,
          ),
          const SizedBox(height: 24),
          if (levels.isNotEmpty)
            DropdownButtonFormField<int>(
              initialValue: level?.level,
              decoration: const InputDecoration(labelText: 'Level bangunan'),
              items: levels
                  .map(
                    (item) => DropdownMenuItem(
                      value: item.level,
                      child: Text('Level ${item.level}'),
                    ),
                  )
                  .toList(),
              onChanged: (value) => setState(
                () => _selected = levels.firstWhere(
                  (item) => item.level == value,
                ),
              ),
            ),
          const SizedBox(height: 20),
          Card(
            child: Column(
              children: [
                ListTile(
                  title: const Text('Footprint'),
                  trailing: Text(
                    '${level?.gridWidth ?? widget.building.defaultGridWidth} × ${level?.gridHeight ?? widget.building.defaultGridHeight} petak',
                  ),
                ),
                ListTile(
                  title: Text('Level maksimum di TH ${widget.thLevel}'),
                  trailing: Text('${widget.maxLevel}'),
                ),
                ListTile(
                  title: const Text('Batas jumlah'),
                  trailing: Text(
                    widget.maxCount?.toString() ?? 'Belum ditentukan',
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          const Text(
            'Level dan batas jumlah mengikuti katalog yang tersedia. Statistik tempur seperti DPS, jangkauan, dan target belum tersedia di katalog mobile ini.',
          ),
        ],
      ),
    );
  }
}
