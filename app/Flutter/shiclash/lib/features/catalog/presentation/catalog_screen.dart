import 'package:flutter/material.dart';
import 'package:shiclash/core/config/app_config.dart';
import 'package:shiclash/core/theme/app_theme.dart';
import 'package:shiclash/features/catalog/data/catalog_api.dart';
import 'package:shiclash/features/catalog/data/catalog_models.dart';

class CatalogScreen extends StatefulWidget {
  const CatalogScreen({super.key, required this.repository});

  final CatalogRepository repository;

  @override
  State<CatalogScreen> createState() => _CatalogScreenState();
}

class _CatalogScreenState extends State<CatalogScreen> {
  late Future<CatalogBootstrap> _catalog;
  int _selectedTh = 1;

  @override
  void initState() {
    super.initState();
    _catalog = widget.repository.load();
  }

  void _retry() => setState(() => _catalog = widget.repository.load());

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      bottom: false,
      child: FutureBuilder<CatalogBootstrap>(
        future: _catalog,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const _LoadingView();
          }

          if (snapshot.hasError || !snapshot.hasData) {
            return _ErrorView(error: snapshot.error, onRetry: _retry);
          }

          return _CatalogView(
            catalog: snapshot.data!,
            selectedTh: _selectedTh,
            onThSelected: (level) => setState(() => _selectedTh = level),
            onRefresh: () async {
              _retry();
              await _catalog;
            },
          );
        },
      ),
    );
  }
}

class _CatalogView extends StatelessWidget {
  const _CatalogView({
    required this.catalog,
    required this.selectedTh,
    required this.onThSelected,
    required this.onRefresh,
  });

  final CatalogBootstrap catalog;
  final int selectedTh;
  final ValueChanged<int> onThSelected;
  final Future<void> Function() onRefresh;

  @override
  Widget build(BuildContext context) {
    final townHallLevels = catalog.townHall?.levels ?? const <BuildingLevel>[];
    final visibleBuildings = catalog.buildingTypes
        .where((type) {
          return !type.isTownHall &&
              catalog.maxLevelFor(type.id, selectedTh) > 0;
        })
        .toList(growable: false);
    final grouped = <String, List<BuildingType>>{};
    for (final building in visibleBuildings) {
      grouped.putIfAbsent(building.category, () => []).add(building);
    }

    return RefreshIndicator(
      onRefresh: onRefresh,
      color: AppColors.brass,
      child: CustomScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        slivers: [
          SliverToBoxAdapter(
            child: _StudioHeader(buildings: visibleBuildings.length),
          ),
          const SliverToBoxAdapter(child: SizedBox(height: 26)),
          const SliverToBoxAdapter(
            child: _SectionHeading(
              label: 'SCENERIES',
              title: 'Pilih medan perang',
            ),
          ),
          SliverToBoxAdapter(child: _SceneryRail(sceneries: catalog.sceneries)),
          const SliverToBoxAdapter(child: SizedBox(height: 28)),
          const SliverToBoxAdapter(
            child: _SectionHeading(
              label: 'TOWN HALL',
              title: 'Tentukan level base',
            ),
          ),
          SliverToBoxAdapter(
            child: _TownHallRail(
              levels: townHallLevels,
              selected: selectedTh,
              onSelected: onThSelected,
            ),
          ),
          const SliverToBoxAdapter(child: SizedBox(height: 30)),
          SliverToBoxAdapter(
            child: _SectionHeading(
              label: 'BUILDING LIBRARY',
              title: 'Tersedia di TH$selectedTh',
            ),
          ),
          if (grouped.isEmpty)
            const SliverToBoxAdapter(child: _EmptyBuildings())
          else
            ...grouped.entries.expand(
              (entry) => [
                SliverToBoxAdapter(child: _CategoryHeading(entry.key)),
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
                  sliver: SliverGrid.builder(
                    gridDelegate:
                        const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 3,
                          mainAxisSpacing: 10,
                          crossAxisSpacing: 10,
                          childAspectRatio: .8,
                        ),
                    itemCount: entry.value.length,
                    itemBuilder: (context, index) {
                      final building = entry.value[index];
                      final maxLevel = catalog.maxLevelFor(
                        building.id,
                        selectedTh,
                      );
                      return _BuildingCard(
                        building: building,
                        maxLevel: maxLevel,
                      );
                    },
                  ),
                ),
              ],
            ),
          const SliverToBoxAdapter(child: SizedBox(height: 24)),
        ],
      ),
    );
  }
}

class _StudioHeader extends StatelessWidget {
  const _StudioHeader({required this.buildings});

  final int buildings;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 0),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: AppColors.panel,
          border: Border.all(color: AppColors.line),
          borderRadius: BorderRadius.circular(6),
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF211A14), AppColors.panel],
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 34,
                  height: 34,
                  decoration: BoxDecoration(
                    border: Border.all(color: AppColors.brass),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: const Icon(
                    Icons.diamond_outlined,
                    size: 18,
                    color: AppColors.brass,
                  ),
                ),
                const SizedBox(width: 12),
                const Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Base Atelier',
                      style: TextStyle(
                        fontFamily: 'serif',
                        fontStyle: FontStyle.italic,
                        fontSize: 20,
                        color: AppColors.ivory,
                      ),
                    ),
                    Text(
                      'SHICLASH MOBILE STUDIO',
                      style: TextStyle(
                        fontSize: 8,
                        letterSpacing: 1.5,
                        color: AppColors.muted,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
                const Spacer(),
                const _LiveBadge(),
              ],
            ),
            const SizedBox(height: 26),
            Text(
              'Rancang base di mana saja.',
              style: Theme.of(context).textTheme.headlineLarge,
            ),
            const SizedBox(height: 8),
            Text(
              'Katalog tersinkron dengan Laravel API. $buildings bangunan tersedia untuk level Town Hall aktif.',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ],
        ),
      ),
    );
  }
}

class _LiveBadge extends StatelessWidget {
  const _LiveBadge();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
      decoration: BoxDecoration(
        color: AppColors.brass.withValues(alpha: .12),
        border: Border.all(color: AppColors.brass.withValues(alpha: .35)),
        borderRadius: BorderRadius.circular(20),
      ),
      child: const Row(
        children: [
          Icon(Icons.circle, size: 6, color: AppColors.brass),
          SizedBox(width: 6),
          Text(
            'SYNCED',
            style: TextStyle(
              fontSize: 8,
              letterSpacing: 1,
              fontWeight: FontWeight.w700,
              color: AppColors.brass,
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionHeading extends StatelessWidget {
  const _SectionHeading({required this.label, required this.title});

  final String label;
  final String title;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 13),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: Theme.of(context).textTheme.labelSmall),
          const SizedBox(height: 5),
          Text(title, style: Theme.of(context).textTheme.titleLarge),
        ],
      ),
    );
  }
}

class _SceneryRail extends StatelessWidget {
  const _SceneryRail({required this.sceneries});
  final List<Scenery> sceneries;

  @override
  Widget build(BuildContext context) {
    if (sceneries.isEmpty) {
      return const _EmptyMessage('Belum ada scenery terkalibrasi.');
    }

    return SizedBox(
      height: 132,
      child: ListView.separated(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        scrollDirection: Axis.horizontal,
        itemCount: sceneries.length,
        separatorBuilder: (_, _) => const SizedBox(width: 10),
        itemBuilder: (context, index) {
          final scenery = sceneries[index];
          return SizedBox(
            width: 174,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(5),
              child: Stack(
                fit: StackFit.expand,
                children: [
                  _NetworkArt(url: scenery.imageUrl),
                  const DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [Colors.transparent, Color(0xE6100E0C)],
                      ),
                    ),
                  ),
                  Positioned(
                    left: 12,
                    right: 12,
                    bottom: 10,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          scenery.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        Text(
                          '${scenery.gridSize} × ${scenery.gridSize} grid',
                          style: const TextStyle(
                            fontSize: 9,
                            color: AppColors.muted,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

class _TownHallRail extends StatelessWidget {
  const _TownHallRail({
    required this.levels,
    required this.selected,
    required this.onSelected,
  });
  final List<BuildingLevel> levels;
  final int selected;
  final ValueChanged<int> onSelected;

  @override
  Widget build(BuildContext context) {
    if (levels.isEmpty) {
      return const _EmptyMessage('Town Hall belum tersedia di katalog.');
    }
    return SizedBox(
      height: 94,
      child: ListView.separated(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        scrollDirection: Axis.horizontal,
        itemCount: levels.length,
        separatorBuilder: (_, _) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          final level = levels[index];
          final active = level.level == selected;
          return InkWell(
            onTap: () => onSelected(level.level),
            borderRadius: BorderRadius.circular(4),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 160),
              width: 72,
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: active
                    ? AppColors.brass.withValues(alpha: .13)
                    : AppColors.panel,
                border: Border.all(
                  color: active ? AppColors.brass : AppColors.line,
                ),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Column(
                children: [
                  Expanded(
                    child: _NetworkArt(
                      url: level.imageUrl,
                      fit: BoxFit.contain,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    'TH${level.level}',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      color: active ? AppColors.brass : AppColors.ivory,
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

class _CategoryHeading extends StatelessWidget {
  const _CategoryHeading(this.category);
  final String category;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(20, 8, 20, 10),
    child: Row(
      children: [
        Text(
          category.toUpperCase(),
          style: const TextStyle(
            color: AppColors.muted,
            fontSize: 9,
            fontWeight: FontWeight.w700,
            letterSpacing: 1.2,
          ),
        ),
        const SizedBox(width: 12),
        const Expanded(child: Divider()),
      ],
    ),
  );
}

class _BuildingCard extends StatelessWidget {
  const _BuildingCard({required this.building, required this.maxLevel});
  final BuildingType building;
  final int maxLevel;
  @override
  Widget build(BuildContext context) {
    final level = building.thumbnailFor(maxLevel);
    return Container(
      padding: const EdgeInsets.all(9),
      decoration: BoxDecoration(
        color: AppColors.panel,
        border: Border.all(color: AppColors.line),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Column(
        children: [
          Expanded(
            child: level == null
                ? const Icon(
                    Icons.question_mark_rounded,
                    color: AppColors.muted,
                  )
                : _NetworkArt(url: level.imageUrl, fit: BoxFit.contain),
          ),
          const SizedBox(height: 7),
          Text(
            building.name,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 2),
          Text(
            'hingga Lv$maxLevel',
            style: const TextStyle(fontSize: 8, color: AppColors.muted),
          ),
        ],
      ),
    );
  }
}

class _NetworkArt extends StatelessWidget {
  const _NetworkArt({required this.url, this.fit = BoxFit.cover});
  final String url;
  final BoxFit fit;
  @override
  Widget build(BuildContext context) {
    if (url.isEmpty) return const ColoredBox(color: AppColors.panelRaised);
    return Image.network(
      url,
      fit: fit,
      filterQuality: FilterQuality.medium,
      errorBuilder: (_, _, _) => const ColoredBox(
        color: AppColors.panelRaised,
        child: Center(
          child: Icon(Icons.broken_image_outlined, color: AppColors.muted),
        ),
      ),
    );
  }
}

class _EmptyBuildings extends StatelessWidget {
  const _EmptyBuildings();
  @override
  Widget build(BuildContext context) => const _EmptyMessage(
    'Belum ada unlock rule untuk Town Hall ini. Atur melalui website admin.',
  );
}

class _EmptyMessage extends StatelessWidget {
  const _EmptyMessage(this.message);
  final String message;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
    child: Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        border: Border.all(color: AppColors.line),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(message, style: Theme.of(context).textTheme.bodyMedium),
    ),
  );
}

class _LoadingView extends StatelessWidget {
  const _LoadingView();
  @override
  Widget build(BuildContext context) => const Center(
    child: CircularProgressIndicator(color: AppColors.brass, strokeWidth: 2),
  );
}

class _ErrorView extends StatelessWidget {
  const _ErrorView({required this.error, required this.onRetry});
  final Object? error;
  final VoidCallback onRetry;
  @override
  Widget build(BuildContext context) => Center(
    child: SingleChildScrollView(
      padding: const EdgeInsets.all(28),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            Icons.cloud_off_outlined,
            color: AppColors.brass,
            size: 38,
          ),
          const SizedBox(height: 18),
          Text(
            'Laravel API belum terhubung',
            style: Theme.of(context).textTheme.headlineMedium,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 10),
          Text(
            error?.toString() ?? 'Periksa alamat API.',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          const SizedBox(height: 8),
          Text(
            AppConfig.apiBaseUrl,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 10, color: AppColors.brass),
          ),
          const SizedBox(height: 22),
          FilledButton.icon(
            onPressed: onRetry,
            icon: const Icon(Icons.refresh_rounded),
            label: const Text('Coba lagi'),
          ),
        ],
      ),
    ),
  );
}
