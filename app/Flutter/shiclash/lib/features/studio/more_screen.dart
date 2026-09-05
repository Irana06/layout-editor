import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shiclash/core/config/app_config.dart';
import 'package:shiclash/core/update/update_service.dart';
import 'package:shiclash/features/catalog/data/catalog_api.dart';

class MoreScreen extends StatefulWidget {
  const MoreScreen({
    super.key,
    required this.repository,
    required this.updates,
  });
  final CatalogRepository repository;
  final UpdateService updates;
  @override
  State<MoreScreen> createState() => _MoreScreenState();
}

class _MoreScreenState extends State<MoreScreen> {
  bool _checking = false;
  String? _result;
  bool _updateChecking = false;
  UpdateInfo? _update;
  String? _updateMessage;

  Future<void> _checkUpdate() async {
    setState(() {
      _updateChecking = true;
      _updateMessage = null;
    });
    try {
      final info = await widget.updates.check();
      if (mounted) {
        setState(() {
          _update = info;
          _updateMessage = info.available
              ? 'Versi ${info.latestVersion} tersedia.'
              : 'Shiclash sudah versi terbaru (${info.currentVersion}).';
        });
      }
    } catch (error) {
      if (mounted) setState(() => _updateMessage = error.toString());
    } finally {
      if (mounted) setState(() => _updateChecking = false);
    }
  }

  Future<void> _downloadUpdate() async {
    final update = _update;
    if (update == null) return;
    try {
      await widget.updates.openDownload(update);
    } catch (error) {
      if (mounted) setState(() => _updateMessage = error.toString());
    }
  }

  Future<void> _check() async {
    setState(() {
      _checking = true;
      _result = null;
    });
    try {
      final catalog = await widget.repository.load();
      if (mounted) {
        setState(
          () => _result =
              'Terhubung · ${catalog.buildingTypes.length} bangunan, ${catalog.sceneries.length} scenery.',
        );
      }
    } catch (_) {
      if (mounted) {
        setState(
          () => _result = 'Tidak dapat terhubung. Periksa internet dan pastikan server aktif.',
        );
      }
    } finally {
      if (mounted) setState(() => _checking = false);
    }
  }

  @override
  Widget build(BuildContext context) => SafeArea(
    child: ListView(
      padding: const EdgeInsets.all(22),
      children: [
        Text('STUDIO NOTES', style: Theme.of(context).textTheme.labelSmall),
        const SizedBox(height: 8),
        Text(
          'Panduan & informasi',
          style: Theme.of(context).textTheme.headlineMedium,
        ),
        const SizedBox(height: 24),
        const Card(
          child: ListTile(
            leading: Icon(Icons.phone_android),
            title: Text('Penyimpanan perangkat'),
            subtitle: Text(
              'Autosave dan koleksi tersimpan lokal. Sinkronisasi akun belum tersedia.',
            ),
          ),
        ),
        const Card(
          child: ExpansionTile(
            title: Text('Mulai merancang'),
            leading: Icon(Icons.architecture),
            children: [
              Padding(
                padding: EdgeInsets.all(16),
                child: Text(
                  'Buka Studio → Buat base, pilih TH dan scenery. Ketuk bangunan di palet Editor, lalu ketuk petak kosong. Batas TH dan tabrakan diperiksa saat placement.',
                ),
              ),
            ],
          ),
        ),
        const Card(
          child: ExpansionTile(
            title: Text('Gerakan dan kontrol'),
            leading: Icon(Icons.touch_app_outlined),
            children: [
              Padding(
                padding: EdgeInsets.all(16),
                child: Text(
                  'Geser canvas untuk pan dan cubit dengan dua jari untuk zoom. Gunakan mode pilih untuk memilih petak bangunan. Tombol pindah diikuti ketukan pada tujuan memindahkan objek. Hapus menghapus pilihan; undo/redo mengembalikan perubahan pada sesi ini.',
                ),
              ),
            ],
          ),
        ),
        const Card(
          child: ExpansionTile(
            title: Text('Simpan dan buka layout'),
            leading: Icon(Icons.save_outlined),
            children: [
              Padding(
                padding: EdgeInsets.all(16),
                child: Text(
                  'Perubahan disimpan otomatis. Simpan salinan untuk memberi nama dan menaruh layout di koleksi. Dari Layouts, buka detail lalu pilih Buka di editor. Salinan tidak berubah ketika canvas diedit. Data dapat hilang jika data aplikasi dihapus; belum tersedia backup akun.',
                ),
              ),
            ],
          ),
        ),
        const Card(
          child: ExpansionTile(
            title: Text('Jika gambar atau katalog tidak muncul'),
            leading: Icon(Icons.wifi_off),
            children: [
              Padding(
                padding: EdgeInsets.all(16),
                child: Text(
                  'Katalog dan gambar memerlukan koneksi server. Coba muat ulang Katalog. Server gratis yang sedang tidur bisa membutuhkan waktu untuk aktif. Draft lokal tetap tersimpan walaupun server tidak dapat dihubungi.',
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),
        Text(
          'Pembaruan aplikasi',
          style: Theme.of(context).textTheme.titleLarge,
        ),
        const SizedBox(height: 8),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Periksa GitHub Release untuk versi Shiclash terbaru.',
                ),
                if (_updateMessage != null) ...[
                  const SizedBox(height: 8),
                  Text(_updateMessage!),
                ],
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  children: [
                    OutlinedButton.icon(
                      onPressed: _updateChecking ? null : _checkUpdate,
                      icon: const Icon(Icons.system_update_alt),
                      label: Text(
                        _updateChecking ? 'Memeriksa…' : 'Cek update',
                      ),
                    ),
                    if (_update?.available == true)
                      FilledButton.icon(
                        onPressed: _downloadUpdate,
                        icon: const Icon(Icons.download),
                        label: const Text('Download update'),
                      ),
                  ],
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 24),
        Text('Koneksi', style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 8),
        SelectableText(AppConfig.apiBaseUrl),
        Wrap(
          spacing: 8,
          children: [
            FilledButton.icon(
              onPressed: _checking ? null : _check,
              icon: const Icon(Icons.network_check),
              label: Text(_checking ? 'Memeriksa…' : 'Tes koneksi'),
            ),
            TextButton(
              onPressed: () async {
                await Clipboard.setData(
                  const ClipboardData(text: AppConfig.apiBaseUrl),
                );
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Alamat server disalin.')),
                  );
                }
              },
              child: const Text('Salin alamat'),
            ),
          ],
        ),
        if (_result != null) Text(_result!),
        const SizedBox(height: 24),
        const Text(
          'Tentang Shiclash',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        const Text(
          'Studio komunitas untuk merancang base. Aplikasi ini tidak berafiliasi dengan atau didukung oleh Supercell. Clash of Clans dan aset terkait merupakan milik pemilik haknya.',
        ),
        const SizedBox(height: 24),
      ],
    ),
  );
}
