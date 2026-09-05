import 'package:flutter/material.dart';
import 'package:shiclash/core/theme/app_theme.dart';
import 'package:shiclash/features/catalog/data/catalog_api.dart';
import 'package:shiclash/features/catalog/data/catalog_models.dart';
import 'package:shiclash/features/editor/domain/editor_controller.dart';
import 'package:shiclash/features/editor/presentation/isometric_board.dart';

class EditorScreen extends StatefulWidget {
  const EditorScreen({required this.repository, super.key});

  final CatalogRepository repository;

  @override
  State<EditorScreen> createState() => _EditorScreenState();
}

class _EditorScreenState extends State<EditorScreen> {
  late Future<CatalogBootstrap> _catalog;

  @override
  void initState() {
    super.initState();
    _catalog = widget.repository.load();
  }

  void _retry() => setState(() => _catalog = widget.repository.load());

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      bottom: false,
      child: FutureBuilder<CatalogBootstrap>(
        future: _catalog,
        builder: (context, snapshot) {
          if (snapshot.hasData && snapshot.data!.sceneries.isNotEmpty) {
            return _EditorWorkspace(catalog: snapshot.data!);
          }
          if (snapshot.hasError) {
            return _LoadFailure(error: snapshot.error, onRetry: _retry);
          }
          return const Center(
            child: CircularProgressIndicator(color: AppColors.brass),
          );
        },
      ),
    );
  }
}

class _EditorWorkspace extends StatefulWidget {
  const _EditorWorkspace({required this.catalog});

  final CatalogBootstrap catalog;

  @override
  State<_EditorWorkspace> createState() => _EditorWorkspaceState();
}

class _EditorWorkspaceState extends State<_EditorWorkspace> {
  late final EditorController controller;

  @override
  void initState() {
    super.initState();
    controller = EditorController(widget.catalog);
  }

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: controller,
      builder: (context, _) {
        return Column(
          children: [
            _Header(controller: controller),
            Expanded(
              child: Stack(
                children: [
                  Positioned.fill(
                    child: IsometricBoard(controller: controller),
                  ),
                  Positioned(
                    top: 12,
                    left: 12,
                    child: _ToolDock(controller: controller),
                  ),
                  Positioned(
                    left: 12,
                    right: 12,
                    bottom: 10,
                    child: _StatusCard(controller: controller),
                  ),
                ],
              ),
            ),
            _BuildingPalette(controller: controller),
          ],
        );
      },
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.controller});

  final EditorController controller;

  @override
  Widget build(BuildContext context) {
    final thLevels =
        controller.catalog.townHall?.levels
            .map((item) => item.level)
            .toSet()
            .toList() ??
        [controller.townHallLevel];
    thLevels.sort();

    return DecoratedBox(
      decoration: const BoxDecoration(
        color: AppColors.panel,
        border: Border(bottom: BorderSide(color: AppColors.line)),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 12, 8, 10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'BASE ATELIER',
                        style: Theme.of(context).textTheme.labelSmall,
                      ),
                      const SizedBox(height: 3),
                      Text(
                        'Layout editor',
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                    ],
                  ),
                ),
                IconButton(
                  tooltip: 'Undo',
                  onPressed: controller.canUndo ? controller.undo : null,
                  icon: const Icon(Icons.undo_rounded),
                ),
                IconButton(
                  tooltip: 'Redo',
                  onPressed: controller.canRedo ? controller.redo : null,
                  icon: const Icon(Icons.redo_rounded),
                ),
                IconButton(
                  tooltip: 'Kosongkan canvas',
                  onPressed: controller.placements.isEmpty
                      ? null
                      : controller.reset,
                  icon: const Icon(Icons.restart_alt_rounded),
                ),
              ],
            ),
            const SizedBox(height: 9),
            Row(
              children: [
                Expanded(
                  child: _CompactDropdown<Scenery>(
                    value: controller.scenery,
                    items: controller.catalog.sceneries,
                    label: (item) => item.name,
                    onChanged: (value) {
                      if (value != null) controller.setScenery(value);
                    },
                  ),
                ),
                const SizedBox(width: 8),
                SizedBox(
                  width: 104,
                  child: _CompactDropdown<int>(
                    value: controller.townHallLevel,
                    items: thLevels,
                    label: (item) => 'TH $item',
                    onChanged: (value) {
                      if (value != null) controller.setTownHall(value);
                    },
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _CompactDropdown<T> extends StatelessWidget {
  const _CompactDropdown({
    required this.value,
    required this.items,
    required this.label,
    required this.onChanged,
  });

  final T value;
  final List<T> items;
  final String Function(T item) label;
  final ValueChanged<T?> onChanged;

  @override
  Widget build(BuildContext context) {
    return DropdownButtonFormField<T>(
      initialValue: value,
      isExpanded: true,
      icon: const Icon(Icons.keyboard_arrow_down_rounded, size: 18),
      decoration: const InputDecoration(
        isDense: true,
        contentPadding: EdgeInsets.symmetric(horizontal: 11, vertical: 9),
      ),
      items: items
          .map(
            (item) => DropdownMenuItem<T>(
              value: item,
              child: Text(
                label(item),
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 12),
              ),
            ),
          )
          .toList(),
      onChanged: onChanged,
    );
  }
}

class _ToolDock extends StatelessWidget {
  const _ToolDock({required this.controller});

  final EditorController controller;

  @override
  Widget build(BuildContext context) {
    final hasSelection = controller.selectedPlacement != null;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: AppColors.panel.withValues(alpha: .94),
        border: Border.all(color: AppColors.line),
        borderRadius: BorderRadius.circular(5),
        boxShadow: const [BoxShadow(color: Colors.black38, blurRadius: 14)],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _DockButton(
            tooltip: 'Pilih objek',
            icon: Icons.near_me_outlined,
            active:
                controller.armedBuildingTypeId == null &&
                !controller.movingSelection,
            onPressed: controller.cancelTool,
          ),
          _DockButton(
            tooltip: 'Pindahkan pilihan',
            icon: Icons.open_with_rounded,
            active: controller.movingSelection,
            onPressed: hasSelection ? controller.beginMove : null,
          ),
          _DockButton(
            tooltip: 'Hapus pilihan',
            icon: Icons.delete_outline_rounded,
            onPressed: hasSelection ? controller.deleteSelected : null,
          ),
          const Divider(height: 1),
          _DockButton(
            tooltip: 'Tampilkan grid',
            icon: Icons.grid_4x4_rounded,
            active: controller.showGrid,
            onPressed: controller.toggleGrid,
          ),
        ],
      ),
    );
  }
}

class _DockButton extends StatelessWidget {
  const _DockButton({
    required this.tooltip,
    required this.icon,
    required this.onPressed,
    this.active = false,
  });

  final String tooltip;
  final IconData icon;
  final VoidCallback? onPressed;
  final bool active;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      tooltip: tooltip,
      onPressed: onPressed,
      color: active ? AppColors.brass : AppColors.ivory,
      disabledColor: AppColors.muted.withValues(alpha: .35),
      iconSize: 20,
      constraints: const BoxConstraints.tightFor(width: 43, height: 43),
      icon: Icon(icon),
    );
  }
}

class _StatusCard extends StatelessWidget {
  const _StatusCard({required this.controller});

  final EditorController controller;

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: AppColors.panel.withValues(alpha: .9),
          border: Border.all(color: AppColors.line),
          borderRadius: BorderRadius.circular(4),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: Row(
            children: [
              const Icon(
                Icons.adjust_rounded,
                color: AppColors.brass,
                size: 14,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  controller.status,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: AppColors.ivory, fontSize: 11),
                ),
              ),
              Text(
                '${controller.placements.length} objek',
                style: const TextStyle(color: AppColors.muted, fontSize: 10),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _BuildingPalette extends StatelessWidget {
  const _BuildingPalette({required this.controller});

  final EditorController controller;

  @override
  Widget build(BuildContext context) {
    final buildings = controller.catalog.buildingTypes
        .where(
          (type) =>
              !type.isTownHall &&
              controller.catalog.maxLevelFor(
                    type.id,
                    controller.townHallLevel,
                  ) >
                  0,
        )
        .toList();
    return Container(
      height: 132,
      decoration: const BoxDecoration(
        color: AppColors.panel,
        border: Border(top: BorderSide(color: AppColors.line)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 10, 14, 6),
            child: Row(
              children: [
                Text(
                  'BUILDING LIBRARY',
                  style: Theme.of(context).textTheme.labelSmall,
                ),
                const Spacer(),
                Text(
                  '${buildings.length} tersedia',
                  style: const TextStyle(color: AppColors.muted, fontSize: 10),
                ),
              ],
            ),
          ),
          Expanded(
            child: ListView.separated(
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 10),
              scrollDirection: Axis.horizontal,
              itemCount: buildings.length,
              separatorBuilder: (_, _) => const SizedBox(width: 7),
              itemBuilder: (context, index) {
                final type = buildings[index];
                final maxLevel = controller.catalog.maxLevelFor(
                  type.id,
                  controller.townHallLevel,
                );
                final level = type.thumbnailFor(maxLevel);
                final selected = controller.armedBuildingTypeId == type.id;
                final placed = controller.placements
                    .where((item) => item.buildingTypeId == type.id)
                    .length;
                final limit = controller.maxCountFor(type.id);
                return InkWell(
                  onTap: () => controller.arm(type, level: maxLevel),
                  borderRadius: BorderRadius.circular(4),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 150),
                    width: 78,
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: selected
                          ? AppColors.brass.withValues(alpha: .15)
                          : const Color(0xFF100E0C),
                      border: Border.all(
                        color: selected ? AppColors.brass : AppColors.line,
                      ),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Column(
                      children: [
                        Expanded(
                          child: Image.network(
                            level?.imageUrl ?? '',
                            fit: BoxFit.contain,
                            errorBuilder: (_, _, _) => const Icon(
                              Icons.home_work_outlined,
                              color: AppColors.brass,
                            ),
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          type.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: AppColors.ivory,
                            fontSize: 9,
                          ),
                        ),
                        Text(
                          'Lv $maxLevel · $placed/${limit >= 999 ? '∞' : limit}',
                          style: const TextStyle(
                            color: AppColors.muted,
                            fontSize: 8,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _LoadFailure extends StatelessWidget {
  const _LoadFailure({required this.error, required this.onRetry});

  final Object? error;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.cloud_off_outlined,
              color: AppColors.brass,
              size: 34,
            ),
            const SizedBox(height: 18),
            Text(
              'Editor belum dapat dibuka',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 8),
            Text(
              error.toString(),
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 18),
            FilledButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('Coba lagi'),
            ),
          ],
        ),
      ),
    );
  }
}
