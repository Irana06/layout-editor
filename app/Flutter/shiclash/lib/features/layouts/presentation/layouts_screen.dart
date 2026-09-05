import 'package:flutter/material.dart';
import 'package:shiclash/features/layouts/data/draft_store.dart';

class LayoutsScreen extends StatelessWidget {
  const LayoutsScreen({required this.store, required this.onOpen, super.key});
  final DraftStore store;
  final VoidCallback onOpen;

  Future<void> _open(BuildContext context, LocalDraft draft) async {
    final confirmed = await showDialog<bool>(context: context, builder: (context) => AlertDialog(
      title: const Text('Buka layout?'),
      content: const Text('Canvas akan diganti. Simpan salinan draft aktif dari Editor jika ingin menyimpannya terpisah.'),
      actions: [TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Batal')),
        FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Buka'))],
    ));
    if (confirmed != true || !context.mounted) return;
    store.requestOpen(draft);
    onOpen();
  }

  Future<void> _delete(BuildContext context, LocalDraft draft) async {
    final confirmed = await showDialog<bool>(context: context, builder: (context) => AlertDialog(
      title: const Text('Hapus salinan?'), content: Text(draft.title),
      actions: [TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Batal')),
        FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Hapus'))],
    ));
    if (confirmed != true) return;
    try { await store.delete(draft.id); } catch (_) { /* Store displays failure. */ }
  }

  @override
  Widget build(BuildContext context) => SafeArea(child: FutureBuilder<void>(
    future: store.ready,
    builder: (context, snapshot) {
      if (snapshot.hasError) return Center(child: Padding(
        padding: const EdgeInsets.all(24), child: Text(store.error ?? 'Draft gagal dibaca.')));
      if (snapshot.connectionState != ConnectionState.done) {
        return const Center(child: CircularProgressIndicator());
      }
      return ListenableBuilder(listenable: store, builder: (context, _) => ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Text('YOUR COLLECTION', style: Theme.of(context).textTheme.labelSmall),
          const SizedBox(height: 8),
          Text('Layout tersimpan', style: Theme.of(context).textTheme.headlineMedium),
          const Text('Tersimpan di perangkat ini. Belum disinkronkan ke akun.'),
          if (store.error != null) ...[
            Text(store.error!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
            TextButton(onPressed: () async { try { await store.retrySave(); } catch (_) {} },
              child: const Text('Coba simpan lagi')),
          ],
          const SizedBox(height: 20),
          if (store.active != null) Card(child: ListTile(
            leading: const Icon(Icons.history), title: const Text('Draft terakhir'),
            subtitle: Text('${(store.active!.layout['data'] as List).length} objek · autosave'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => _open(context, store.active!),
          )),
          if (store.saved.isEmpty) const Padding(padding: EdgeInsets.all(20),
            child: Text('Belum ada salinan. Gunakan “Simpan salinan” di Editor untuk menambahkan layout.')),
          for (final draft in store.saved) Card(child: ListTile(
            leading: const Icon(Icons.grid_view),
            title: Text(draft.title),
            subtitle: Text('TH ${draft.layout['th_level']} · ${(draft.layout['data'] as List).length} objek\n${draft.updatedAt.toLocal().toString().substring(0, 16)}'),
            isThreeLine: true,
            onTap: () => _open(context, draft),
            trailing: IconButton(tooltip: 'Hapus salinan', icon: const Icon(Icons.delete_outline),
              onPressed: () => _delete(context, draft)),
          )),
        ],
      ));
    },
  ));
}
