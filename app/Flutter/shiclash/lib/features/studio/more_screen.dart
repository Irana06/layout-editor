import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shiclash/core/config/app_config.dart';
import 'package:shiclash/core/update/update_service.dart';
import 'package:shiclash/features/account/data/drive_backup_service.dart';
import 'package:shiclash/features/account/data/google_account_controller.dart';
import 'package:shiclash/features/catalog/data/catalog_api.dart';
import 'package:shiclash/features/calibration/presentation/calibration_screen.dart';
import 'package:shiclash/features/layouts/data/draft_store.dart';

class MoreScreen extends StatefulWidget {
  const MoreScreen({
    super.key,
    required this.repository,
    required this.updates,
    required this.account,
    required this.drive,
    required this.drafts,
    required this.onOpenAccount,
  });
  final CatalogRepository repository;
  final UpdateService updates;
  final GoogleAccountController account;
  final DriveBackupService drive;
  final DraftStore drafts;
  final VoidCallback onOpenAccount;
  @override
  State<MoreScreen> createState() => _MoreScreenState();
}

class _MoreScreenState extends State<MoreScreen> {
  bool _checking = false;
  String? _result;
  bool _updateChecking = false;
  UpdateInfo? _update;
  String? _updateMessage;
  bool _cloudBusy = false;
  String? _cloudMessage;

  @override
  void initState() {
    super.initState();
    widget.account.addListener(_accountChanged);
  }

  void _accountChanged() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    widget.account.removeListener(_accountChanged);
    super.dispose();
  }

  Future<void> _backup() async {
    final account = widget.account.account;
    if (account == null) return;
    setState(() {
      _cloudBusy = true;
      _cloudMessage = null;
    });
    try {
      await widget.drafts.ready;
      final backup = await widget.drive.upload(
        account,
        widget.drafts.exportDocument(),
      );
      if (mounted) {
        setState(
          () => _cloudMessage = backup.modifiedAt == null
              ? 'Backup Google Drive berhasil.'
              : 'Backup berhasil diperbarui.',
        );
      }
    } catch (error) {
      if (mounted) {
        setState(() => _cloudMessage = 'Backup gagal: ${_message(error)}');
      }
    } finally {
      if (mounted) setState(() => _cloudBusy = false);
    }
  }

  Future<void> _restore() async {
    final account = widget.account.account;
    if (account == null) return;
    setState(() {
      _cloudBusy = true;
      _cloudMessage = null;
    });
    try {
      final content = await widget.drive.download(account);
      if (!mounted) return;
      if (content == null) {
        setState(() => _cloudMessage = 'Belum ada backup di Google Drive.');
        return;
      }
      final approved = await showDialog<bool>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: const Text('Pulihkan backup?'),
          content: const Text(
            'Draft dan koleksi lokal saat ini akan diganti dengan isi backup Google Drive.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('Batal'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              child: const Text('Pulihkan'),
            ),
          ],
        ),
      );
      if (approved != true) return;
      await widget.drafts.restoreDocument(content);
      if (mounted) {
        setState(() => _cloudMessage = 'Backup berhasil dipulihkan ke HP.');
      }
    } catch (error) {
      if (mounted) {
        setState(() => _cloudMessage = 'Pemulihan gagal: ${_message(error)}');
      }
    } finally {
      if (mounted) setState(() => _cloudBusy = false);
    }
  }

  String _message(Object error) {
    final text = error.toString();
    return text.replaceFirst(RegExp(r'^(Exception|StateError):\s*'), '');
  }

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
        _accountCard(context),
        Card(
          child: ListTile(
            leading: const Icon(Icons.tune),
            title: const Text('Calibrator · Admin'),
            subtitle: const Text(
              'Atur grid scenery dan posisi building per level.',
            ),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => Navigator.of(context).push<void>(
              MaterialPageRoute(
                builder: (_) => CalibrationScreen(
                  account: widget.account,
                  repository: widget.repository,
                ),
              ),
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
                  'Perubahan disimpan otomatis di HP. Simpan salinan untuk memberi nama dan menaruh layout di koleksi. Jika sudah masuk dengan Google, gunakan menu Akun & backup untuk mencadangkan atau memulihkan semua draft.',
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

  Widget _accountCard(BuildContext context) {
    final account = widget.account.account;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                if (account?.photoUrl != null)
                  CircleAvatar(
                    backgroundImage: NetworkImage(account!.photoUrl!),
                  )
                else
                  const CircleAvatar(child: Icon(Icons.person_outline)),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        account?.displayName ?? 'Akun & backup',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      Text(
                        account?.email ??
                            'Masuk dengan Google untuk backup privat.',
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            const Text(
              'Layout selalu tersimpan di HP. Backup Drive disimpan di ruang tersembunyi milik Shiclash dan tidak memberi akses ke file Drive lainnya.',
            ),
            if (_cloudMessage != null) ...[
              const SizedBox(height: 10),
              Text(_cloudMessage!),
            ],
            const SizedBox(height: 12),
            if (account == null)
              FilledButton.icon(
                onPressed: widget.onOpenAccount,
                icon: const Icon(Icons.login),
                label: const Text('Masuk / daftar Google'),
              )
            else
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  FilledButton.icon(
                    onPressed: _cloudBusy ? null : _backup,
                    icon: const Icon(Icons.cloud_upload_outlined),
                    label: Text(_cloudBusy ? 'Memproses…' : 'Backup'),
                  ),
                  OutlinedButton.icon(
                    onPressed: _cloudBusy ? null : _restore,
                    icon: const Icon(Icons.cloud_download_outlined),
                    label: const Text('Pulihkan'),
                  ),
                  TextButton.icon(
                    onPressed: widget.account.busy
                        ? null
                        : widget.account.signOut,
                    icon: const Icon(Icons.logout),
                    label: const Text('Keluar'),
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }
}
