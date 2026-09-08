import 'package:shiclash/features/catalog/presentation/offline_image.dart';
import 'package:flutter/material.dart';
import 'package:shiclash/core/theme/app_theme.dart';
import 'package:shiclash/features/catalog/data/catalog_models.dart';

typedef BuildingLevelSelection = ({BuildingType type, BuildingLevel level});

Future<BuildingLevelSelection?> showBuildingLevelPicker(
  BuildContext context, {
  required List<BuildingType> buildingTypes,
  BuildingType? selectedType,
  BuildingLevel? selectedLevel,
}) => showModalBottomSheet<BuildingLevelSelection>(
  context: context,
  isScrollControlled: true,
  useSafeArea: true,
  builder: (_) => _BuildingLevelPicker(
    buildingTypes: buildingTypes,
    selectedType: selectedType,
    selectedLevel: selectedLevel,
  ),
);

class _BuildingLevelPicker extends StatefulWidget {
  const _BuildingLevelPicker({
    required this.buildingTypes,
    this.selectedType,
    this.selectedLevel,
  });

  final List<BuildingType> buildingTypes;
  final BuildingType? selectedType;
  final BuildingLevel? selectedLevel;

  @override
  State<_BuildingLevelPicker> createState() => _BuildingLevelPickerState();
}

class _BuildingLevelPickerState extends State<_BuildingLevelPicker> {
  String _query = '';

  @override
  Widget build(BuildContext context) {
    final query = _query.trim().toLowerCase();
    final visible = widget.buildingTypes.where((type) {
      if (query.isEmpty) return true;
      return type.name.toLowerCase().contains(query) ||
          type.category.toLowerCase().contains(query) ||
          (type.subfolder?.toLowerCase().contains(query) ?? false) ||
          type.levels.any((level) => 'level ${level.level}'.contains(query));
    }).toList();
    final folders = <String, List<BuildingType>>{};
    for (final type in visible) {
      folders.putIfAbsent(type.category, () => []).add(type);
    }

    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: .88,
      minChildSize: .55,
      maxChildSize: .96,
      builder: (context, scrollController) => Column(
        children: [
          const SizedBox(height: 10),
          Container(
            width: 42,
            height: 4,
            decoration: BoxDecoration(
              color: AppColors.muted.withValues(alpha: .5),
              borderRadius: BorderRadius.circular(99),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 18, 18, 10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Pilih aset building',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 4),
                const Text(
                  'Buka folder kategori, pilih building, lalu pilih level.',
                  style: TextStyle(color: AppColors.muted),
                ),
                const SizedBox(height: 14),
                TextField(
                  autofocus: false,
                  decoration: const InputDecoration(
                    hintText: 'Cari nama, folder, atau level…',
                    prefixIcon: Icon(Icons.search),
                  ),
                  onChanged: (value) => setState(() => _query = value),
                ),
              ],
            ),
          ),
          Expanded(
            child: visible.isEmpty
                ? const Center(child: Text('Building tidak ditemukan.'))
                : ListView(
                    controller: scrollController,
                    padding: const EdgeInsets.fromLTRB(10, 0, 10, 24),
                    children: [
                      for (final entry in folders.entries)
                        Card(
                          clipBehavior: Clip.antiAlias,
                          child: ExpansionTile(
                            key: ValueKey('${entry.key}:$query'),
                            initiallyExpanded:
                                query.isNotEmpty ||
                                entry.value.any(
                                  (type) => type.id == widget.selectedType?.id,
                                ),
                            leading: Icon(_categoryIcon(entry.key)),
                            title: Text(_folderName(entry.key)),
                            subtitle: Text('${entry.value.length} building'),
                            children: [
                              for (final type in entry.value)
                                ExpansionTile(
                                  key: ValueKey('type:${type.id}:$query'),
                                  initiallyExpanded:
                                      type.id == widget.selectedType?.id ||
                                      query.isNotEmpty,
                                  leading: _BuildingIcon(
                                    url: type.thumbnailFor(999)?.imageUrl ?? '',
                                  ),
                                  title: Text(type.name),
                                  subtitle: Text(
                                    [
                                      if (type.subfolder?.isNotEmpty == true)
                                        type.subfolder!,
                                      '${type.levels.length} level',
                                    ].join(' · '),
                                  ),
                                  children: [
                                    for (final level in type.levels)
                                      ListTile(
                                        contentPadding: const EdgeInsets.only(
                                          left: 42,
                                          right: 16,
                                        ),
                                        leading: _BuildingIcon(
                                          url: level.imageUrl,
                                          size: 44,
                                        ),
                                        title: Text(
                                          '${type.name} · Level ${level.level}',
                                        ),
                                        subtitle: Text(
                                          '${level.gridWidth ?? type.defaultGridWidth} × ${level.gridHeight ?? type.defaultGridHeight} tile',
                                        ),
                                        trailing:
                                            type.id ==
                                                    widget.selectedType?.id &&
                                                level.id ==
                                                    widget.selectedLevel?.id
                                            ? const Icon(
                                                Icons.check_circle,
                                                color: AppColors.brass,
                                              )
                                            : null,
                                        onTap: () => Navigator.pop(context, (
                                          type: type,
                                          level: level,
                                        )),
                                      ),
                                  ],
                                ),
                            ],
                          ),
                        ),
                    ],
                  ),
          ),
        ],
      ),
    );
  }
}

class _BuildingIcon extends StatelessWidget {
  const _BuildingIcon({required this.url, this.size = 48});
  final String url;
  final double size;

  @override
  Widget build(BuildContext context) => SizedBox.square(
    dimension: size,
    child: OfflineImage(
      url,
      fit: BoxFit.contain,
      errorBuilder: (_, _, _) => const Icon(Icons.home_work_outlined),
    ),
  );
}

String _folderName(String value) => value
    .replaceAll(RegExp(r'[_-]+'), ' ')
    .split(' ')
    .where((part) => part.isNotEmpty)
    .map((part) => '${part[0].toUpperCase()}${part.substring(1)}')
    .join(' ');

IconData _categoryIcon(String category) {
  final value = category.toLowerCase();
  if (value.contains('defen')) return Icons.shield_outlined;
  if (value.contains('army') || value.contains('troop')) {
    return Icons.groups_outlined;
  }
  if (value.contains('resource')) return Icons.savings_outlined;
  if (value.contains('trap')) return Icons.warning_amber_rounded;
  if (value.contains('wall')) return Icons.view_week_outlined;
  if (value.contains('town')) return Icons.castle_outlined;
  return Icons.folder_outlined;
}
