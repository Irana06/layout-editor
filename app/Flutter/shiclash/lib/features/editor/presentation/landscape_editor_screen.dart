import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shiclash/core/theme/app_theme.dart';
import 'package:shiclash/features/catalog/data/catalog_models.dart';
import 'package:shiclash/features/editor/domain/editor_controller.dart';
import 'package:shiclash/features/editor/presentation/isometric_board.dart';
import 'package:shiclash/features/editor/presentation/selection_card.dart';

/// Full-screen landscape editing, opened from the portrait editor's maximize
/// button.
///
/// It is a pushed route rather than an in-place mode so the orientation lock and
/// immersive system UI are tied to this route's lifetime — popping always
/// restores the app, even when the user leaves with the system back gesture. It
/// shares the caller's [EditorController], so placements, history and autosave
/// continue uninterrupted in both orientations.
class LandscapeEditorScreen extends StatefulWidget {
  const LandscapeEditorScreen({required this.controller, super.key});

  final EditorController controller;

  @override
  State<LandscapeEditorScreen> createState() => _LandscapeEditorScreenState();
}

class _LandscapeEditorScreenState extends State<LandscapeEditorScreen> {
  bool _dockOpen = true;

  @override
  void initState() {
    super.initState();
    SystemChrome.setPreferredOrientations(const [
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);
    // The scenery is the point of this mode, so the status and navigation bars
    // step aside; a swipe from the edge still brings them back temporarily.
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
  }

  @override
  void dispose() {
    SystemChrome.setPreferredOrientations(const [
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
    ]);
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    super.dispose();
  }

  Future<void> _minimize() async {
    // Ask for portrait before popping so the rotation and the screen change land
    // together instead of flashing the portrait editor sideways.
    await SystemChrome.setPreferredOrientations(const [
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
    ]);
    if (mounted) Navigator.of(context).maybePop();
  }

  @override
  Widget build(BuildContext context) {
    final controller = widget.controller;

    return Scaffold(
      backgroundColor: const Color(0xFF070605),
      body: AnimatedBuilder(
        animation: controller,
        builder: (context, _) {
          return Stack(
            children: [
              Positioned.fill(child: IsometricBoard(controller: controller)),
              // Mirrors the portrait editor, but on the opposite side: the tool
              // column already owns the top-right corner in landscape.
              if (controller.selectedPlacement != null)
                Positioned(
                  top: 10,
                  left: 10,
                  child: SafeArea(
                    child: SelectionCard(controller: controller),
                  ),
                ),
              Positioned(
                top: 10,
                right: 10,
                child: SafeArea(
                  child: _LandscapeTools(
                    controller: controller,
                    dockOpen: _dockOpen,
                    onToggleDock: () => setState(() => _dockOpen = !_dockOpen),
                    onMinimize: _minimize,
                  ),
                ),
              ),
              Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                child: SafeArea(
                  top: false,
                  child: _StatusStrip(controller: controller, dock: _dockOpen),
                ),
              ),
              if (_dockOpen)
                Positioned(
                  left: 0,
                  right: 0,
                  bottom: 0,
                  child: SafeArea(
                    top: false,
                    child: _BuildingDock(controller: controller),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}

/// Compact vertical tool column; the board keeps the rest of the screen.
class _LandscapeTools extends StatelessWidget {
  const _LandscapeTools({
    required this.controller,
    required this.dockOpen,
    required this.onToggleDock,
    required this.onMinimize,
  });

  final EditorController controller;
  final bool dockOpen;
  final VoidCallback onToggleDock;
  final Future<void> Function() onMinimize;

  @override
  Widget build(BuildContext context) {
    final selected = controller.selectedPlacement;

    return DecoratedBox(
      decoration: BoxDecoration(
        color: AppColors.panel.withValues(alpha: .88),
        border: Border.all(color: AppColors.line),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _ToolIcon(
            icon: Icons.undo_rounded,
            tooltip: 'Undo',
            onPressed: controller.canUndo ? controller.undo : null,
          ),
          _ToolIcon(
            icon: Icons.redo_rounded,
            tooltip: 'Redo',
            onPressed: controller.canRedo ? controller.redo : null,
          ),
          _ToolIcon(
            icon: controller.showGrid
                ? Icons.grid_on_rounded
                : Icons.grid_off_rounded,
            tooltip: 'Grid',
            onPressed: controller.toggleGrid,
            active: controller.showGrid,
          ),
          _ToolIcon(
            icon: Icons.delete_outline_rounded,
            tooltip: 'Hapus objek terpilih',
            onPressed: selected == null ? null : controller.deleteSelected,
          ),
          _ToolIcon(
            icon: dockOpen
                ? Icons.keyboard_double_arrow_down_rounded
                : Icons.keyboard_double_arrow_up_rounded,
            tooltip: dockOpen ? 'Sembunyikan bangunan' : 'Tampilkan bangunan',
            onPressed: onToggleDock,
          ),
          _ToolIcon(
            icon: Icons.close_fullscreen_rounded,
            tooltip: 'Kembali ke mode potrait',
            onPressed: () => onMinimize(),
            active: true,
          ),
        ],
      ),
    );
  }
}

class _ToolIcon extends StatelessWidget {
  const _ToolIcon({
    required this.icon,
    required this.tooltip,
    required this.onPressed,
    this.active = false,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback? onPressed;
  final bool active;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      tooltip: tooltip,
      onPressed: onPressed,
      visualDensity: VisualDensity.compact,
      icon: Icon(
        icon,
        size: 19,
        color: onPressed == null
            ? AppColors.muted.withValues(alpha: .4)
            : active
            ? AppColors.brass
            : AppColors.ivory,
      ),
    );
  }
}

/// One-line feedback that sits just above the dock so it never covers it.
class _StatusStrip extends StatelessWidget {
  const _StatusStrip({required this.controller, required this.dock});

  final EditorController controller;
  final bool dock;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        left: 12,
        right: 12,
        bottom: dock ? _BuildingDock.height + 8 : 12,
      ),
      child: Align(
        alignment: Alignment.centerLeft,
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: AppColors.ink.withValues(alpha: .74),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            child: Text(
              controller.status,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(color: AppColors.ivory, fontSize: 11),
            ),
          ),
        ),
      ),
    );
  }
}

/// Horizontal inventory bar: tap to arm, or drag a card straight onto the board.
class _BuildingDock extends StatelessWidget {
  const _BuildingDock({required this.controller});

  static const double height = 96;

  final EditorController controller;

  @override
  Widget build(BuildContext context) {
    final buildings = controller.availableBuildings;

    return Container(
      height: height,
      decoration: BoxDecoration(
        color: AppColors.panel.withValues(alpha: .93),
        border: const Border(top: BorderSide(color: AppColors.line)),
      ),
      child: buildings.isEmpty
          ? const Center(
              child: Text(
                'Belum ada bangunan yang terbuka di Town Hall ini.',
                style: TextStyle(color: AppColors.muted, fontSize: 11),
              ),
            )
          : ListView.separated(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              scrollDirection: Axis.horizontal,
              itemCount: buildings.length,
              separatorBuilder: (_, _) => const SizedBox(width: 8),
              itemBuilder: (context, index) =>
                  _DockCard(controller: controller, type: buildings[index]),
            ),
    );
  }
}

class _DockCard extends StatelessWidget {
  const _DockCard({required this.controller, required this.type});

  final EditorController controller;
  final BuildingType type;

  @override
  Widget build(BuildContext context) {
    final maxLevel = controller.maxLevelFor(type);
    final level = type.thumbnailFor(maxLevel);
    final remaining = controller.remainingFor(type.id);
    final exhausted = remaining == 0;
    final armed = controller.armedBuildingTypeId == type.id;

    final card = Opacity(
      opacity: exhausted ? .4 : 1,
      child: Container(
        width: 74,
        decoration: BoxDecoration(
          color: armed
              ? AppColors.brass.withValues(alpha: .18)
              : const Color(0xFF100E0C),
          border: Border.all(color: armed ? AppColors.brass : AppColors.line),
          borderRadius: BorderRadius.circular(6),
        ),
        child: Stack(
          children: [
            Positioned.fill(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(4, 4, 4, 2),
                child: Column(
                  children: [
                    Expanded(
                      child: Image.network(
                        level?.imageUrl ?? '',
                        fit: BoxFit.contain,
                        errorBuilder: (_, _, _) => const Icon(
                          Icons.home_work_outlined,
                          color: AppColors.brass,
                          size: 18,
                        ),
                      ),
                    ),
                    Text(
                      'Level $maxLevel',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: AppColors.ivory,
                        fontSize: 9,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            // Remaining allowance, mirroring the inventory counter in game.
            if (remaining != null)
              Positioned(
                top: 2,
                left: 4,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: AppColors.ink.withValues(alpha: .8),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 4,
                      vertical: 1,
                    ),
                    child: Text(
                      'x$remaining',
                      style: const TextStyle(
                        color: AppColors.brass,
                        fontSize: 9,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );

    if (exhausted) return card;

    return LongPressDraggable<PaletteBuildingDrag>(
      data: PaletteBuildingDrag(buildingTypeId: type.id, level: maxLevel),
      feedback: Material(
        color: Colors.transparent,
        child: SizedBox(
          width: 64,
          height: 64,
          child: Image.network(level?.imageUrl ?? '', fit: BoxFit.contain),
        ),
      ),
      childWhenDragging: Opacity(opacity: .35, child: card),
      child: InkWell(
        onTap: () => controller.arm(type, level: maxLevel),
        borderRadius: BorderRadius.circular(6),
        child: card,
      ),
    );
  }
}
