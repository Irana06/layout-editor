import 'package:flutter/material.dart';
import 'package:shiclash/core/theme/app_theme.dart';
import 'package:shiclash/features/catalog/data/catalog_api.dart';
import 'package:shiclash/features/catalog/data/catalog_models.dart';
import 'package:shiclash/features/catalog/data/offline_store.dart';

/// Downloading the catalogue's artwork so the editor works with no connection.
///
/// The catalogue itself is always kept, without being asked — losing signal
/// should not make the app unopenable. This card is only about the images,
/// which are large enough that nobody should get them by surprise.
class OfflineCard extends StatefulWidget {
  const OfflineCard({required this.store, required this.repository, super.key});

  final OfflineStore store;
  final CatalogRepository repository;

  @override
  State<OfflineCard> createState() => _OfflineCardState();
}

class _OfflineCardState extends State<OfflineCard> {
  CatalogBootstrap? _catalog;
  int _bytes = 0;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  Future<void> _refresh() async {
    setState(() => _loading = true);
    try {
      await widget.store.load();
      final catalog = await widget.repository.load();
      final bytes = await widget.store.storedBytes();
      if (mounted) {
        setState(() {
          _catalog = catalog;
          _bytes = bytes;
        });
      }
    } catch (_) {
      // Offline already, or the server is down: the card still reports what is
      // stored, which is exactly what matters at that moment.
      final bytes = await widget.store.storedBytes();
      if (mounted) setState(() => _bytes = bytes);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  String _size(int bytes) => bytes < 1048576
      ? '${(bytes / 1024).round()} KB'
      : '${(bytes / 1048576).toStringAsFixed(1)} MB';

  Future<void> _download() async {
    final catalog = _catalog;
    if (catalog == null) return;
    await widget.store.downloadAll(
      urls: catalog.imageUrls,
      version: catalog.version,
    );
    if (mounted) {
      final bytes = await widget.store.storedBytes();
      if (mounted) setState(() => _bytes = bytes);
    }
  }

  Future<void> _clear() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Hapus data offline?'),
        content: Text(
          'Gambar sebesar ${_size(_bytes)} akan dihapus dari perangkat. '
          'Layout-mu tidak ikut terhapus.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Batal'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Hapus'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    await widget.store.clear();
    if (mounted) setState(() => _bytes = 0);
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: widget.store,
      builder: (context, _) {
        final store = widget.store;
        final catalog = _catalog;
        final stored = store.storedVersion;
        final hasData = _bytes > 0;
        // An update is only worth offering when we know both versions and they
        // disagree; offline, the stored copy is simply what there is.
        final outdated =
            stored != null &&
            catalog != null &&
            catalog.version.isNotEmpty &&
            catalog.version != stored;

        return Card(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      hasData
                          ? Icons.offline_pin_rounded
                          : Icons.cloud_download_outlined,
                      color: AppColors.brass,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'Mode offline',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                    ),
                    if (outdated && !store.downloading)
                      const Tooltip(
                        message: 'Ada pembaruan aset',
                        child: Icon(
                          Icons.sync_problem_rounded,
                          color: AppColors.brass,
                          size: 20,
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  _loading
                      ? 'Memeriksa…'
                      : !hasData
                      ? 'Unduh gambar bangunan dan scenery agar editor tetap bisa dipakai tanpa sinyal.'
                      : outdated
                      ? 'Tersimpan ${_size(_bytes)}. Ada kalibrasi baru di server — unduh ulang agar gambarmu ikut terbaru.'
                      : 'Tersimpan ${_size(_bytes)}. Editor sudah bisa dipakai tanpa sinyal.',
                  style: const TextStyle(color: AppColors.muted, fontSize: 12),
                ),
                if (store.downloading) ...[
                  const SizedBox(height: 12),
                  LinearProgressIndicator(
                    value: store.progress?.fraction ?? 0,
                    color: AppColors.brass,
                  ),
                  const SizedBox(height: 6),
                  Text(
                    '${store.progress?.done ?? 0} dari ${store.progress?.total ?? 0} berkas',
                    style: const TextStyle(
                      color: AppColors.muted,
                      fontSize: 11,
                    ),
                  ),
                ],
                if (store.error != null) ...[
                  const SizedBox(height: 8),
                  Text(
                    store.error!,
                    style: const TextStyle(
                      color: AppColors.brass,
                      fontSize: 11,
                    ),
                  ),
                ],
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    if (store.downloading)
                      OutlinedButton.icon(
                        onPressed: store.cancel,
                        icon: const Icon(Icons.stop_rounded, size: 18),
                        label: const Text('Hentikan'),
                      )
                    else
                      FilledButton.icon(
                        onPressed: catalog == null ? null : _download,
                        icon: Icon(
                          outdated
                              ? Icons.sync_rounded
                              : Icons.download_rounded,
                          size: 18,
                        ),
                        label: Text(
                          !hasData
                              ? 'Unduh aset'
                              : outdated
                              ? 'Perbarui aset'
                              : 'Lengkapi aset',
                        ),
                      ),
                    if (hasData && !store.downloading)
                      TextButton.icon(
                        onPressed: _clear,
                        icon: const Icon(Icons.delete_outline, size: 18),
                        label: const Text('Hapus'),
                      ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
