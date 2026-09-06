import 'package:flutter/material.dart';
import 'package:shiclash/core/theme/app_theme.dart';
import 'package:shiclash/core/update/update_service.dart';
import 'package:shiclash/core/update/update_install_dialog.dart';
import 'package:shiclash/features/account/data/drive_backup_service.dart';
import 'package:shiclash/features/account/data/google_account_controller.dart';
import 'package:shiclash/features/account/presentation/account_gate.dart';
import 'package:shiclash/features/catalog/data/catalog_api.dart';
import 'package:shiclash/features/catalog/presentation/catalog_screen.dart';
import 'package:shiclash/features/editor/presentation/editor_screen.dart';
import 'package:shiclash/features/layouts/data/draft_store.dart';
import 'package:shiclash/features/layouts/presentation/layouts_screen.dart';
import 'package:shiclash/features/studio/studio_screen.dart';
import 'package:shiclash/features/studio/more_screen.dart';

class ShiclashApp extends StatelessWidget {
  const ShiclashApp({super.key, this.googleServicesEnabled = true});

  final bool googleServicesEnabled;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Shiclash',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.dark,
      home: AppShell(googleServicesEnabled: googleServicesEnabled),
    );
  }
}

class AppShell extends StatefulWidget {
  const AppShell({super.key, required this.googleServicesEnabled});

  final bool googleServicesEnabled;

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  int _index = 0;
  late final CatalogRepository _repository;
  late final List<Widget> _pages;
  final DraftStore _drafts = DraftStore();
  final UpdateService _updates = UpdateService();
  late final GoogleAccountController _account;
  final DriveBackupService _drive = DriveBackupService();
  late bool _continueOffline;

  @override
  void initState() {
    super.initState();
    // Startup must never invoke Google's account picker. The editor is always
    // usable offline; login remains an explicit action from the account page.
    _continueOffline = true;
    _account = GoogleAccountController(enabled: widget.googleServicesEnabled)
      ..addListener(_onAccountChanged);
    _account.initialize();
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
      MoreScreen(
        repository: _repository,
        updates: _updates,
        account: _account,
        drive: _drive,
        drafts: _drafts,
        onOpenAccount: () => setState(() => _continueOffline = false),
      ),
    ];
    WidgetsBinding.instance.addPostFrameCallback((_) => _checkForUpdate());
  }

  void _onAccountChanged() {
    if (mounted) setState(() {});
  }

  Future<void> _checkForUpdate() async {
    try {
      final info = await _updates.check();
      if (!mounted || !info.available || !_updates.directInstallSupported) {
        return;
      }
      await showDialog<void>(
        context: context,
        barrierDismissible: false,
        builder: (_) => UpdateInstallDialog(service: _updates, info: info),
      );
    } catch (_) {
      // Startup checks stay quiet when the device is offline or no release exists.
    }
  }

  @override
  void dispose() {
    _account
      ..removeListener(_onAccountChanged)
      ..dispose();
    _repository.dispose();
    _drafts.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!_account.ready) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    if (!_continueOffline && !_account.signedIn) {
      return AccountGate(
        account: _account,
        onContinueOffline: () => setState(() => _continueOffline = true),
      );
    }
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
