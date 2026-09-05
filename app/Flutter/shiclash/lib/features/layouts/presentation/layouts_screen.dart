import 'package:flutter/material.dart';
import 'package:shiclash/features/layouts/data/draft_store.dart';
import 'package:shiclash/features/layouts/presentation/layout_detail_screen.dart';

class LayoutsScreen extends StatefulWidget {
  const LayoutsScreen({required this.store, required this.onOpen, super.key});
  final DraftStore store;
  final VoidCallback onOpen;

  @override
  State<LayoutsScreen> createState() => _LayoutsScreenState();
}

class _LayoutsScreenState extends State<LayoutsScreen> {
  DraftStore get store => widget.store;
  String _query = '';
  bool _oldestFirst = false;

  Future<void> _details(LocalDraft draft) async {
    final edit = await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (_) => LayoutDetailScreen(draft: draft)),
    );
    if (edit == true && mounted) await _open(context, draft);
  }

  Future<void> _rename(LocalDraft draft) async {
    var name = draft.title;
    final result = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Ganti nama'),
        content: TextFormField(
          initialValue: name,
          maxLength: 100,
          autofocus: true,
          onChanged: (value) => name = value,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Batal'),
          ),
          FilledButton(
            onPressed: () {
              if (name.trim().isNotEmpty) Navigator.pop(context, name);
            },
            child: const Text('Simpan'),
          ),
        ],
      ),
    );
    if (result != null) {
      try {
        await store.rename(draft.id, result);
      } catch (_) {}
    }
  }

  Future<void> _open(BuildContext context, LocalDraft draft) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Buka layout?'),
        content: const Text(
          'Canvas akan diganti. Simpan salinan draft aktif dari Editor jika ingin menyimpannya terpisah.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Batal'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Buka'),
          ),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return;
    store.requestOpen(draft);
    widget.onOpen();
  }

  Future<void> _delete(BuildContext context, LocalDraft draft) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Hapus salinan?'),
        content: Text(draft.title),
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
    try {
      await store.delete(draft.id);
    } catch (_) {
      /* Store displays failure. */
    }
  }

  @override
  Widget build(BuildContext context) => SafeArea(
    child: FutureBuilder<void>(
      future: store.ready,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Text(store.error ?? 'Draft gagal dibaca.'),
            ),
          );
        }
        if (snapshot.connectionState != ConnectionState.done) {
          return const Center(child: CircularProgressIndicator());
        }
        return ListenableBuilder(
          listenable: store,
          builder: (context, _) => ListView(
            padding: const EdgeInsets.all(20),
            children: [
              Text(
                'YOUR COLLECTION',
                style: Theme.of(context).textTheme.labelSmall,
              ),
              const SizedBox(height: 8),
              Text(
                'Layout tersimpan',
                style: Theme.of(context).textTheme.headlineMedium,
              ),
              const Text(
                'Tersimpan di perangkat ini. Belum disinkronkan ke akun.',
              ),
              if (store.error != null) ...[
                Text(
                  store.error!,
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
                TextButton(
                  onPressed: () async {
                    try {
                      await store.retrySave();
                    } catch (_) {}
                  },
                  child: const Text('Coba simpan lagi'),
                ),
              ],
              const SizedBox(height: 20),
              TextField(
                onChanged: (value) => setState(() => _query = value),
                decoration: const InputDecoration(
                  prefixIcon: Icon(Icons.search),
                  hintText: 'Cari nama layout',
                ),
              ),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton.icon(
                  onPressed: () => setState(() => _oldestFirst = !_oldestFirst),
                  icon: const Icon(Icons.sort),
                  label: Text(
                    _oldestFirst ? 'Terlama dahulu' : 'Terbaru dahulu',
                  ),
                ),
              ),
              if (store.active != null)
                Card(
                  child: ListTile(
                    leading: const Icon(Icons.history),
                    title: const Text('Draft terakhir'),
                    subtitle: Text(
                      '${(store.active!.layout['data'] as List).length} objek · autosave',
                    ),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () => _details(store.active!),
                  ),
                ),
              if (store.saved.isEmpty)
                const Padding(
                  padding: EdgeInsets.all(20),
                  child: Text(
                    'Belum ada salinan. Gunakan “Simpan salinan” di Editor untuk menambahkan layout.',
                  ),
                ),
              if (store.saved.isNotEmpty &&
                  !store.saved.any(
                    (item) => item.title.toLowerCase().contains(
                      _query.trim().toLowerCase(),
                    ),
                  ))
                const Padding(
                  padding: EdgeInsets.all(20),
                  child: Text('Tidak ada layout yang cocok.'),
                ),
              for (final draft
                  in (store.saved
                      .where(
                        (item) => item.title.toLowerCase().contains(
                          _query.trim().toLowerCase(),
                        ),
                      )
                      .toList()
                    ..sort(
                      (a, b) => _oldestFirst
                          ? a.updatedAt.compareTo(b.updatedAt)
                          : b.updatedAt.compareTo(a.updatedAt),
                    )))
                Card(
                  child: ListTile(
                    leading: const Icon(Icons.grid_view),
                    title: Text(draft.title),
                    subtitle: Text(
                      'TH ${draft.layout['th_level']} · ${(draft.layout['data'] as List).length} objek\n${draft.updatedAt.toLocal().toString().substring(0, 16)}',
                    ),
                    isThreeLine: true,
                    onTap: () => _details(draft),
                    trailing: PopupMenuButton<String>(
                      tooltip: 'Kelola layout',
                      itemBuilder: (_) => const [
                        PopupMenuItem(
                          value: 'rename',
                          child: Text('Ganti nama'),
                        ),
                        PopupMenuItem(value: 'delete', child: Text('Hapus')),
                      ],
                      onSelected: (value) {
                        if (value == 'rename') {
                          _rename(draft);
                        } else {
                          _delete(context, draft);
                        }
                      },
                    ),
                  ),
                ),
            ],
          ),
        );
      },
    ),
  );
}
