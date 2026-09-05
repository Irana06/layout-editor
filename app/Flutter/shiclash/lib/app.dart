import 'package:flutter/material.dart';
import 'package:shiclash/core/theme/app_theme.dart';
import 'package:shiclash/features/catalog/data/catalog_api.dart';
import 'package:shiclash/features/catalog/presentation/catalog_screen.dart';
import 'package:shiclash/features/editor/presentation/editor_screen.dart';
import 'package:shiclash/features/layouts/data/draft_store.dart';
import 'package:shiclash/features/layouts/presentation/layouts_screen.dart';

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

  @override
  void initState() {
    super.initState();
    _repository = CatalogRepository(CatalogApi());
    _pages = [
      CatalogScreen(repository: _repository),
      EditorScreen(repository: _repository, drafts: _drafts),
      LayoutsScreen(store: _drafts, onOpen: () => setState(() => _index = 1)),
    ];
  }

  @override
  void dispose() {
    _drafts.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
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
            icon: Icon(Icons.grid_view_outlined),
            selectedIcon: Icon(Icons.grid_view_rounded),
            label: 'Editor',
          ),
          NavigationDestination(
            icon: Icon(Icons.bookmark_border_rounded),
            selectedIcon: Icon(Icons.bookmark_rounded),
            label: 'Layouts',
          ),
        ],
      ),
    );
  }
}
