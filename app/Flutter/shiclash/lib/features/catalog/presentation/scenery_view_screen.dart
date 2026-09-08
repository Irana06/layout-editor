import 'package:shiclash/features/catalog/presentation/offline_image.dart';
import 'package:flutter/material.dart';
import 'package:shiclash/core/theme/app_theme.dart';
import 'package:shiclash/features/catalog/data/catalog_models.dart';

/// A scenery on its own, large enough to judge before building on it.
///
/// Deliberately just the artwork: the grid and calibration belong to the editor
/// and the calibrator, and repeating them here would only invite editing from a
/// screen that cannot save.
class SceneryViewScreen extends StatelessWidget {
  const SceneryViewScreen({required this.scenery, super.key});

  final Scenery scenery;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF070605),
      appBar: AppBar(
        title: Text(scenery.name),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(18),
          child: Padding(
            padding: const EdgeInsets.only(left: 16, bottom: 8),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(
                '${scenery.gridSize} × ${scenery.gridSize} petak · '
                '${scenery.imageWidth.round()} × ${scenery.imageHeight.round()} piksel',
                style: const TextStyle(color: AppColors.muted, fontSize: 11),
              ),
            ),
          ),
        ),
      ),
      body: InteractiveViewer(
        maxScale: 5,
        child: Center(
          child: OfflineImage(
            scenery.imageUrl,
            fit: BoxFit.contain,
            errorBuilder: (_, _, _) => const Padding(
              padding: EdgeInsets.all(24),
              child: Text(
                'Gambar scenery gagal dimuat.',
                style: TextStyle(color: AppColors.muted),
              ),
            ),
            loadingBuilder: (context, child, progress) => progress == null
                ? child
                : const Center(
                    child: CircularProgressIndicator(color: AppColors.brass),
                  ),
          ),
        ),
      ),
    );
  }
}
