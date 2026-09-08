import 'package:shiclash/features/catalog/presentation/offline_image.dart';
import 'package:flutter/material.dart';
import 'package:shiclash/core/theme/app_theme.dart';
import 'package:shiclash/features/account/data/google_account_controller.dart';
import 'package:shiclash/features/catalog/data/catalog_api.dart';
import 'package:shiclash/features/catalog/data/catalog_models.dart';
import 'package:shiclash/features/layouts/data/draft_store.dart';
import 'package:url_launcher/url_launcher.dart';

class StudioScreen extends StatelessWidget {
  const StudioScreen({
    super.key,
    required this.store,
    required this.repository,
    required this.navigate,
    required this.account,
  });
  final DraftStore store;
  final CatalogRepository repository;
  final ValueChanged<int> navigate;
  final GoogleAccountController account;

  static final Uri _saweria = Uri.parse('https://saweria.co/shicomp');

  Future<void> _create(BuildContext context) async {
    final draft = await Navigator.of(context).push<LocalDraft>(
      MaterialPageRoute(
        builder: (_) => NewBaseScreen(repository: repository, store: store),
      ),
    );
    if (draft != null && context.mounted) {
      store.requestOpen(draft);
      navigate(2);
    }
  }

  @override
  Widget build(BuildContext context) => SafeArea(
    child: ListView(
      padding: const EdgeInsets.all(22),
      children: [
        Row(
          children: [
            const Icon(Icons.diamond_outlined, color: AppColors.brass),
            const SizedBox(width: 12),
            Text('SHICLASH', style: Theme.of(context).textTheme.labelSmall),
            const Spacer(),
            IconButton(
              tooltip: 'Panduan dan informasi',
              onPressed: () => navigate(4),
              icon: const Icon(Icons.help_outline),
            ),
          ],
        ),
        const SizedBox(height: 28),
        Text('Base Atelier', style: Theme.of(context).textTheme.headlineLarge),
        const SizedBox(height: 10),
        const Text(
          'Ruang untuk merancang, menyempurnakan, dan menyimpan base milikmu.',
        ),
        const SizedBox(height: 26),
        Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            border: Border.all(color: AppColors.line),
            borderRadius: BorderRadius.circular(8),
            gradient: const LinearGradient(
              colors: [Color(0xFF302219), AppColors.panel],
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(Icons.architecture, color: AppColors.brass, size: 42),
              const SizedBox(height: 22),
              Text(
                'Mulai dari petak pertama.',
                style: Theme.of(context).textTheme.headlineMedium,
              ),
              const SizedBox(height: 10),
              const Text(
                'Pilih Town Hall dan medan, lalu susun pertahananmu sendiri.',
              ),
              const SizedBox(height: 20),
              FilledButton.icon(
                onPressed: () => _create(context),
                icon: const Icon(Icons.add),
                label: const Text('Buat base'),
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),
        FutureBuilder<void>(
          future: store.ready,
          builder: (context, snapshot) {
            if (snapshot.hasError) {
              return Text(store.error ?? 'Penyimpanan tidak tersedia.');
            }
            if (snapshot.connectionState != ConnectionState.done) {
              return const LinearProgressIndicator();
            }
            return ListenableBuilder(
              listenable: store,
              builder: (context, _) => Column(
                children: [
                  if (store.active != null)
                    Card(
                      child: ListTile(
                        leading: const Icon(Icons.history),
                        title: const Text('Lanjutkan draft'),
                        subtitle: Text(
                          'TH ${store.active!.layout['th_level']} · ${(store.active!.layout['data'] as List).length} objek',
                        ),
                        trailing: const Icon(Icons.arrow_forward),
                        onTap: () => navigate(2),
                      ),
                    ),
                  Card(
                    child: ListTile(
                      leading: const Icon(Icons.bookmarks_outlined),
                      title: const Text('Koleksi pribadi'),
                      subtitle: Text(
                        '${store.saved.length} salinan di perangkat',
                      ),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () => navigate(3),
                    ),
                  ),
                ],
              ),
            );
          },
        ),
        Card(
          child: ListTile(
            leading: const Icon(Icons.castle_outlined),
            title: const Text('Jelajahi katalog'),
            subtitle: const Text('Bangunan, level, footprint, dan batas TH'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => navigate(1),
          ),
        ),
        const SizedBox(height: 22),
        ListenableBuilder(
          listenable: account,
          // Only worth saying while the layouts really are at risk. Once signed
          // in, repeating it would be nagging about a solved problem.
          builder: (context, _) => account.signedIn
              ? const SizedBox.shrink()
              : _BackupReminder(onOpenAccount: () => navigate(4)),
        ),
        const SizedBox(height: 14),
        _DonationCard(
          onOpen: () =>
              launchUrl(_saweria, mode: LaunchMode.externalApplication),
        ),
        const SizedBox(height: 20),
        const Text(
          'Studio pribadi · Layout disimpan di perangkat ini.',
          style: TextStyle(fontSize: 11),
        ),
      ],
    ),
  );
}

class NewBaseScreen extends StatefulWidget {
  const NewBaseScreen({
    super.key,
    required this.repository,
    required this.store,
  });
  final CatalogRepository repository;
  final DraftStore store;
  @override
  State<NewBaseScreen> createState() => _NewBaseScreenState();
}

class _NewBaseScreenState extends State<NewBaseScreen> {
  late Future<CatalogBootstrap> _future;
  int? _th;
  int? _scenery;
  bool _busy = false;
  String? _error;
  @override
  void initState() {
    super.initState();
    _future = widget.repository.load();
  }

  Future<void> _start(CatalogBootstrap catalog) async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await widget.store.ready;
      if (widget.store.active != null &&
          (widget.store.active!.layout['data'] as List).isNotEmpty) {
        await widget.store.saveCopy(
          'Draft sebelum base baru · ${DateTime.now().toLocal().toString().substring(0, 16)}',
        );
      }
      final draft = LocalDraft(
        id: 'new',
        title: 'Base baru',
        updatedAt: DateTime.now(),
        layout: {
          'th_level': _th ?? catalog.townHall!.levels.first.level,
          'scenery_id': _scenery ?? catalog.sceneries.first.id,
          'data': <Map<String, dynamic>>[],
        },
      );
      if (mounted) Navigator.pop(context, draft);
    } catch (_) {
      if (mounted) {
        setState(() {
          _error = 'Draft lama belum berhasil disimpan. Coba lagi sebelum memulai base baru.';
          _busy = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Buat base')),
    body: FutureBuilder<CatalogBootstrap>(
      future: _future,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Center(child: CircularProgressIndicator());
        }
        final catalog = snapshot.data;
        if (snapshot.hasError ||
            catalog == null ||
            catalog.sceneries.isEmpty ||
            (catalog.townHall?.levels.isEmpty ?? true)) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                    'Konfigurasi base belum tersedia. Periksa koneksi dan muat katalog kembali.',
                  ),
                  TextButton(
                    onPressed: () =>
                        setState(() => _future = widget.repository.load()),
                    child: const Text('Coba lagi'),
                  ),
                ],
              ),
            ),
          );
        }
        return ListView(
          padding: const EdgeInsets.all(24),
          children: [
            Text(
              'Atur medanmu.',
              style: Theme.of(context).textTheme.headlineLarge,
            ),
            const SizedBox(height: 10),
            const Text(
              'Mulai dengan canvas kosong. Draft aktif yang berisi bangunan akan disimpan sebagai salinan.',
            ),
            const SizedBox(height: 24),
            DropdownButtonFormField<int>(
              initialValue: _th ?? catalog.townHall!.levels.first.level,
              decoration: const InputDecoration(labelText: 'Town Hall'),
              items: catalog.townHall!.levels
                  .map(
                    (item) => DropdownMenuItem(
                      value: item.level,
                      child: Text('TH ${item.level}'),
                    ),
                  )
                  .toList(),
              onChanged: _busy ? null : (value) => setState(() => _th = value),
            ),
            const SizedBox(height: 24),
            Text('SCENERY', style: Theme.of(context).textTheme.labelSmall),
            const SizedBox(height: 12),
            for (final scenery in catalog.sceneries)
              Card(
                child: InkWell(
                  onTap: _busy
                      ? null
                      : () => setState(() => _scenery = scenery.id),
                  child: Column(
                    children: [
                      SizedBox(
                        height: 150,
                        width: double.infinity,
                        child: OfflineImage(
                          scenery.imageUrl,
                          fit: BoxFit.cover,
                          errorBuilder: (_, _, _) => const Center(
                            child: Icon(Icons.landscape_outlined, size: 48),
                          ),
                        ),
                      ),
                      ListTile(
                        title: Text(scenery.name),
                        subtitle: Text(
                          '${scenery.gridSize} × ${scenery.gridSize} petak',
                        ),
                        trailing: Icon(
                          (_scenery ?? catalog.sceneries.first.id) == scenery.id
                              ? Icons.radio_button_checked
                              : Icons.radio_button_off,
                          color: AppColors.brass,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            if (_error != null)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 12),
                child: Text(_error!),
              ),
            const SizedBox(height: 20),
            FilledButton(
              onPressed: _busy ? null : () => _start(catalog),
              child: Text(_busy ? 'Menyiapkan…' : 'Buka editor'),
            ),
          ],
        );
      },
    ),
  );
}

/// Layouts live on this device until an account is attached, and nothing warns
/// about that at the moment it matters — when the phone is replaced or the app
/// removed. This says it while there is still something to be done.
class _BackupReminder extends StatelessWidget {
  const _BackupReminder({required this.onOpenAccount});

  final VoidCallback onOpenAccount;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        border: Border.all(color: AppColors.brass.withValues(alpha: .55)),
        borderRadius: BorderRadius.circular(8),
        color: AppColors.panel.withValues(alpha: .6),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.cloud_off_rounded,
                color: AppColors.brass,
                size: 20,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Layout belum dicadangkan',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          const Text(
            'Semua layout hanya tersimpan di HP ini. Kalau aplikasi dihapus, '
            'data dibersihkan, atau kamu ganti HP, semuanya ikut hilang. '
            'Masuk dengan Google untuk mencadangkannya ke Drive.',
            style: TextStyle(fontSize: 12, color: AppColors.muted),
          ),
          const SizedBox(height: 14),
          FilledButton.icon(
            onPressed: onOpenAccount,
            icon: const Icon(Icons.login_rounded, size: 18),
            label: const Text('Masuk & cadangkan'),
          ),
        ],
      ),
    );
  }
}

class _DonationCard extends StatelessWidget {
  const _DonationCard({required this.onOpen});

  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListTile(
        leading: const Icon(
          Icons.volunteer_activism_outlined,
          color: AppColors.brass,
        ),
        title: const Text('Dukung pengembangan'),
        subtitle: const Text('Traktir lewat Saweria · saweria.co/shicomp'),
        trailing: const Icon(Icons.open_in_new_rounded, size: 18),
        onTap: onOpen,
      ),
    );
  }
}
