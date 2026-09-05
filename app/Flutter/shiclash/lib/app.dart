import 'package:flutter/material.dart';
import 'package:shiclash/core/theme/app_theme.dart';
import 'package:shiclash/core/update/update_service.dart';
import 'package:shiclash/features/catalog/data/catalog_api.dart';
import 'package:shiclash/features/catalog/presentation/catalog_screen.dart';
import 'package:shiclash/features/editor/presentation/editor_screen.dart';
import 'package:shiclash/features/layouts/data/draft_store.dart';
import 'package:shiclash/features/layouts/presentation/layouts_screen.dart';
import 'package:shiclash/features/studio/studio_screen.dart';
import 'package:shiclash/features/studio/more_screen.dart';

class ShiclashApp extends StatelessWidget {
  const ShiclashApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Shiclash',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.dark,
      home: const AppShell(),
    );
  }
}

class AppShell extends StatefulWidget {
  const AppShell({super.key});

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  int _index = 0;
  late final CatalogRepository _repository;
  late final List<Widget> _pages;
  final DraftStore _drafts = DraftStore();
  final UpdateService _updates = UpdateService();

  @override
  void initState() {
    super.initState();
    _repository = CatalogRepository(CatalogApi());
    _pages = [
      StudioScreen(
        store: _drafts,
        repository: _repository,
        navigate: (index) => setState(() => _index = index),
      ),
      CatalogScreen(repository: _repository),
      EditorScreen(repository: _repository, drafts: _drafts),
      LayoutsScreen(store: _drafts, onOpen: () => setState(() => _index = 2)),
      MoreScreen(repository: _repository, updates: _updates),
    ];
    WidgetsBinding.instance.addPostFrameCallback((_) => _checkForUpdate());
  }

  Future<void> _checkForUpdate() async {
    try {
      final info = await _updates.check();
      if (!mounted || !info.available) return;
      await showDialog<void>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: const Text('Update Shiclash tersedia'),
          content: Text(
            'Versi ${info.latestVersion} sudah tersedia. Versi di perangkat: ${info.currentVersion}.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Nanti'),
            ),
            FilledButton(
              onPressed: () async {
                Navigator.pop(dialogContext);
                try {
                  await _updates.openDownload(info);
                } catch (_) {
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Halaman update tidak dapat dibuka.'),
                      ),
                    );
                  }
                }
              },
              child: const Text('Download update'),
            ),
          ],
        ),
      );
    } catch (_) {
      // Startup checks stay quiet when the device is offline or no release exists.
    }
  }

  @override
  void dispose() {
    _drafts.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: _index == 0,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop && mounted) setState(() => _index = 0);
      },
      child: Scaffold(
        body: IndexedStack(index: _index, children: _pages),
        bottomNavigationBar: NavigationBar(
          selectedIndex: _index,
          onDestinationSelected: (value) => setState(() => _index = value),
          destinations: const [
            NavigationDestination(
              icon: Icon(Icons.home_outlined),
              selectedIcon: Icon(Icons.home_rounded),
              label: 'Studio',
            ),
            NavigationDestination(
              icon: Icon(Icons.castle_outlined),
              selectedIcon: Icon(Icons.castle),
              label: 'Katalog',
            ),
            NavigationDestination(
              icon: Icon(Icons.grid_view_outlined),
              selectedIcon: Icon(Icons.grid_view_rounded),
              label: 'Editor',
            ),
            NavigationDestination(
              icon: Icon(Icons.bookmark_border_rounded),
              selectedIcon: Icon(Icons.bookmark_rounded),
              label: 'Layouts',
            ),
            NavigationDestination(
              icon: Icon(Icons.more_horiz),
              label: 'Lainnya',
            ),
          ],
        ),
      ),
    );
  }
}
