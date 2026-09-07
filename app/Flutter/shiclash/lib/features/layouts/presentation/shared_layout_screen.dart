import 'package:flutter/material.dart';
import 'package:shiclash/core/theme/app_theme.dart';
import 'package:shiclash/features/catalog/data/catalog_api.dart';
import 'package:shiclash/features/editor/domain/editor_controller.dart';
import 'package:shiclash/features/editor/presentation/isometric_board.dart';
import 'package:shiclash/features/editor/presentation/landscape_editor_screen.dart';
import 'package:shiclash/features/editor/presentation/selection_card.dart';
import 'package:shiclash/features/layouts/data/draft_store.dart';
import 'package:shiclash/features/layouts/data/share_api.dart';

/// Read-only view of a layout someone shared.
///
/// The board is the editor's own, so a shared base looks exactly as it did to
/// the person who made it, in either orientation. Nothing here writes to the
/// canvas: taking a copy files it in the collection and leaves whatever is
/// being edited alone.
class SharedLayoutScreen extends StatefulWidget {
  const SharedLayoutScreen({
    required this.code,
    required this.repository,
    required this.drafts,
    this.api,
    super.key,
  });

  final String code;
  final CatalogRepository repository;
  final DraftStore drafts;
  final ShareApi? api;

  @override
  State<SharedLayoutScreen> createState() => _SharedLayoutScreenState();
}

class _SharedLayoutScreenState extends State<SharedLayoutScreen> {
  late final ShareApi _api = widget.api ?? ShareApi();
  EditorController? _controller;
  SharedLayout? _shared;
  String? _error;
  bool _loading = true;
  bool _copied = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _controller?.dispose();
    if (widget.api == null) _api.close();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final shared = await _api.fetch(widget.code);
      final catalog = await widget.repository.load();
      final controller = EditorController(catalog)
        ..restoreLayout(shared.toLayout());
      if (!mounted) {
        controller.dispose();
        return;
      }
      setState(() {
        _shared = shared;
        _controller?.dispose();
        _controller = controller;
      });
    } catch (error) {
      if (mounted) setState(() => _error = error.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _copyToCollection() async {
    final shared = _shared;
    if (shared == null) return;
    final messenger = ScaffoldMessenger.of(context);
    try {
      await widget.drafts.saveShared(shared.title, shared.toLayout());
      if (mounted) {
        setState(() => _copied = true);
        messenger.showSnackBar(
          SnackBar(content: Text('“${shared.title}” tersimpan di Layouts.')),
        );
      }
    } catch (_) {
      messenger.showSnackBar(
        const SnackBar(content: Text('Layout gagal disimpan di perangkat.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final controller = _controller;

    return Scaffold(
      backgroundColor: const Color(0xFF070605),
      appBar: AppBar(
        title: Text(_shared?.title ?? 'Layout dibagikan'),
        actions: [
          if (controller != null)
            IconButton(
              tooltip: 'Mode landscape',
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => LandscapeEditorScreen(
                    controller: controller,
                    readOnly: true,
                  ),
                ),
              ),
              icon: const Icon(Icons.open_in_full_rounded),
            ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(18),
          child: Padding(
            padding: const EdgeInsets.only(left: 16, bottom: 8),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(
                _shared == null
                    ? 'Hanya baca'
                    : 'Hanya baca · TH ${_shared!.thLevel} · ${_shared!.data.length} objek',
                style: const TextStyle(color: AppColors.muted, fontSize: 11),
              ),
            ),
          ),
        ),
      ),
      body: _loading
          ? const Center(
              child: CircularProgressIndicator(color: AppColors.brass),
            )
          : _error != null
          ? _Failure(message: _error!, onRetry: _load)
          : AnimatedBuilder(
              animation: controller!,
              builder: (context, _) => Stack(
                children: [
                  Positioned.fill(
                    child: IsometricBoard(
                      controller: controller,
                      readOnly: true,
                    ),
                  ),
                  // Tapping a building reads out its level and range, the same
                  // card the editor shows — minus the level stepper, since
                  // there is nothing here to change.
                  if (controller.selectedPlacement != null)
                    Positioned(
                      top: 10,
                      right: 10,
                      child: SelectionCard(
                        controller: controller,
                        readOnly: true,
                      ),
                    ),
                ],
              ),
            ),
      bottomNavigationBar: _error != null || _loading
          ? null
          : SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
                child: FilledButton.icon(
                  onPressed: _copied ? null : _copyToCollection,
                  icon: Icon(
                    _copied ? Icons.check_rounded : Icons.copy_all_rounded,
                  ),
                  label: Text(
                    _copied ? 'Tersimpan di Layouts' : 'Salin layout ini',
                  ),
                ),
              ),
            ),
    );
  }
}

class _Failure extends StatelessWidget {
  const _Failure({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(message, textAlign: TextAlign.center),
          const SizedBox(height: 12),
          FilledButton(onPressed: onRetry, child: const Text('Coba lagi')),
        ],
      ),
    ),
  );
}
