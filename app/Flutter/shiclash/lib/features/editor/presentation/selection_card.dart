import 'package:shiclash/features/catalog/presentation/offline_image.dart';
import 'package:flutter/material.dart';
import 'package:shiclash/core/theme/app_theme.dart';
import 'package:shiclash/features/editor/domain/editor_controller.dart';

/// Details of the placement currently selected on the board: artwork, name,
/// level, and the level stepper when the building has more than one unlocked
/// level.
///
/// Shared by the portrait and landscape editors so a selection reads and behaves
/// identically in both orientations.
class SelectionCard extends StatelessWidget {
  const SelectionCard({
    required this.controller,
    this.readOnly = false,
    super.key,
  });

  final EditorController controller;

  /// Someone else's layout: the card reports, it does not offer to change
  /// levels or hint at dragging.
  final bool readOnly;

  @override
  Widget build(BuildContext context) {
    final placement = controller.selectedPlacement;
    if (placement == null) return const SizedBox.shrink();
    final type = controller.typeFor(placement.buildingTypeId);
    final level = controller.levelFor(placement);
    if (type == null || level == null) return const SizedBox.shrink();
    final available =
        type.levels
            .map((item) => item.level)
            .where((item) => item <= controller.maxLevelFor(type))
            .toSet()
            .toList()
          ..sort();
    final index = available.indexOf(placement.level);
    final editable = !readOnly && !type.isTownHall && index >= 0;
    final modes = controller.variantsFor(placement);
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 190),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: AppColors.panel.withValues(alpha: .95),
          border: Border.all(color: AppColors.brass.withValues(alpha: .7)),
          borderRadius: BorderRadius.circular(7),
          boxShadow: const [BoxShadow(color: Colors.black54, blurRadius: 14)],
        ),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(9, 8, 6, 6),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  SizedBox.square(
                    dimension: 34,
                    child: OfflineImage(
                      level.imageUrl,
                      fit: BoxFit.contain,
                      errorBuilder: (_, _, _) => const Icon(
                        Icons.home_work_outlined,
                        color: AppColors.brass,
                      ),
                    ),
                  ),
                  const SizedBox(width: 7),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          type.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: AppColors.ivory,
                            fontWeight: FontWeight.w700,
                            fontSize: 12,
                          ),
                        ),
                        Text(
                          type.isTownHall
                              ? 'TH ${placement.level}'
                              : 'Level ${placement.level}',
                          style: const TextStyle(
                            color: AppColors.muted,
                            fontSize: 10,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    tooltip: 'Tutup detail',
                    onPressed: controller.clearSelection,
                    icon: const Icon(Icons.close_rounded, size: 17),
                    constraints: const BoxConstraints.tightFor(
                      width: 30,
                      height: 30,
                    ),
                  ),
                ],
              ),
              if (editable) ...[
                const SizedBox(height: 5),
                Row(
                  children: [
                    IconButton.filledTonal(
                      tooltip: 'Turunkan level',
                      onPressed: index > 0
                          ? controller.decreaseSelectedLevel
                          : null,
                      icon: const Icon(Icons.remove_rounded, size: 17),
                    ),
                    Expanded(
                      child: Text(
                        'Maks. TH ${controller.townHallLevel}: Lv ${available.last}',
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          color: AppColors.muted,
                          fontSize: 9,
                        ),
                      ),
                    ),
                    IconButton.filled(
                      tooltip: 'Naikkan level',
                      onPressed: index < available.length - 1
                          ? controller.increaseSelectedLevel
                          : null,
                      icon: const Icon(Icons.add_rounded, size: 17),
                    ),
                  ],
                ),
              ],
              if (modes.length > 1) ...[
                const SizedBox(height: 6),
                Wrap(
                  spacing: 5,
                  runSpacing: 5,
                  children: [
                    for (final mode in modes)
                      _ModeChip(
                        label: mode.value,
                        selected: mode.key == placement.variant,
                        onTap: readOnly
                            ? null
                            : () => controller.setSelectedVariant(mode.key),
                      ),
                  ],
                ),
              ],
              const SizedBox(height: 3),
              Text(
                readOnly
                    ? 'Ketuk bangunan lain untuk melihat detailnya.'
                    : 'Tahan lalu geser untuk memindahkan.',
                style: const TextStyle(color: AppColors.muted, fontSize: 9),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// One mode a building can be switched to. Small enough to sit inside the
/// detail card without turning it into a settings panel.
class _ModeChip extends StatelessWidget {
  const _ModeChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
        decoration: BoxDecoration(
          color: selected
              ? AppColors.brass.withValues(alpha: .22)
              : Colors.transparent,
          border: Border.all(
            color: selected ? AppColors.brass : AppColors.line,
          ),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 10,
            color: selected ? AppColors.ivory : AppColors.muted,
            fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
          ),
        ),
      ),
    );
  }
}
