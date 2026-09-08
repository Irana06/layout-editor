import 'package:shiclash/features/catalog/presentation/offline_image.dart';
import 'package:flutter/material.dart';
import 'package:shiclash/core/theme/app_theme.dart';
import 'package:shiclash/features/calibration/data/calibration_api.dart';
import 'package:shiclash/features/catalog/data/catalog_models.dart';

class TownHallRulesPanel extends StatefulWidget {
  const TownHallRulesPanel({
    super.key,
    required this.catalog,
    required this.api,
    required this.onSaved,
  });

  final CatalogBootstrap catalog;
  final CalibrationApi api;
  final ValueChanged<List<BuildingUnlockRule>> onSaved;

  @override
  State<TownHallRulesPanel> createState() => TownHallRulesPanelState();
}

class TownHallRulesPanelState extends State<TownHallRulesPanel> {
  late int _townHallLevel;
  Map<int, _RuleDraft> _drafts = {};
  Map<int, _RuleDraft> _saved = {};
  bool _saving = false;
  String? _message;

  bool get dirty => !_sameRules(_drafts, _saved);

  List<int> get _townHallLevels {
    final levels = widget.catalog.townHall?.levels
        .map((level) => level.level)
        .toSet()
        .toList();
    if (levels == null || levels.isEmpty) return const [1];
    levels.sort();
    return levels;
  }

  List<BuildingType> get _buildings => widget.catalog.buildingTypes
      .where((type) => !type.isTownHall && type.levels.isNotEmpty)
      .toList();

  int? get _previousTownHallLevel {
    final earlier = _townHallLevels.where((level) => level < _townHallLevel);
    return earlier.isEmpty ? null : earlier.last;
  }

  @override
  void initState() {
    super.initState();
    _townHallLevel = _townHallLevels.first;
    _loadRules();
  }

  Future<bool> confirmDiscard() async {
    if (!dirty) return true;
    return await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Aturan TH belum disimpan'),
            content: const Text(
              'Perubahan jumlah dan level building akan hilang jika dilanjutkan.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Tetap di sini'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text('Buang perubahan'),
              ),
            ],
          ),
        ) ??
        false;
  }

  void _loadRules() {
    final rules = {
      for (final type in _buildings) type.id: _ruleFor(type.id, _townHallLevel),
    };
    _drafts = rules.map((id, rule) => MapEntry(id, rule.copy()));
    _saved = rules.map((id, rule) => MapEntry(id, rule.copy()));
    _message = null;
  }

  _RuleDraft _ruleFor(int typeId, int thLevel) {
    for (final rule in widget.catalog.unlockRules) {
      if (rule.buildingTypeId == typeId && rule.thLevel == thLevel) {
        return _RuleDraft(rule.maxBuildingLevel, rule.maxCount);
      }
    }
    return _RuleDraft(0, 0);
  }

  Future<void> _changeTownHall(int value) async {
    if (value == _townHallLevel || !await confirmDiscard() || !mounted) return;
    setState(() {
      _townHallLevel = value;
      _loadRules();
    });
  }

  void _change(int typeId, _RuleDraft value) {
    setState(() {
      _drafts = {..._drafts, typeId: value};
      _message = null;
    });
  }

  /// Bring a folder forward from the immediately previous Town Hall without
  /// overwriting a rule that has already been configured here.  A level of 0
  /// is the editor's reset/unavailable state, so it is safe to fill from the
  /// prior TH only after the owner explicitly confirms it.
  Future<void> _syncFolderFromPrevious(
    String category,
    List<BuildingType> buildings,
  ) async {
    final previous = _previousTownHallLevel;
    if (_saving || previous == null) return;
    final candidates = buildings.where((type) {
      final current = _drafts[type.id];
      final source = _ruleFor(type.id, previous);
      return (current?.maxLevel ?? 0) == 0 && source.maxLevel > 0;
    }).toList();
    if (candidates.isEmpty) {
      setState(() {
        _message =
            'Tidak ada aturan ${_title(category)} yang masih reset untuk disinkronkan dari TH $previous.';
      });
      return;
    }
    final confirmed =
        await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: Text('Sync ${_title(category)} dari TH $previous?'),
            content: Text(
              '${candidates.length} aturan yang masih level 0 di TH $_townHallLevel akan mengikuti level dan jumlah dari TH $previous. Aturan yang sudah aktif tidak diubah.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Batal'),
              ),
              FilledButton.icon(
                onPressed: () => Navigator.pop(context, true),
                icon: const Icon(Icons.sync),
                label: const Text('Ya, sync'),
              ),
            ],
          ),
        ) ??
        false;
    if (!confirmed || !mounted) return;
    setState(() {
      _drafts = {
        ..._drafts,
        for (final type in candidates)
          type.id: _ruleFor(type.id, previous).copy(),
      };
      _message =
          '${candidates.length} aturan ${_title(category)} mengikuti TH $previous. Tekan Simpan aturan TH untuk menerapkan.';
    });
  }

  Future<void> _save() async {
    if (_saving || !dirty) return;
    setState(() {
      _saving = true;
      _message = null;
    });
    try {
      final saved = await widget.api.saveUnlockRules(_townHallLevel, [
        for (final type in _buildings)
          {
            'building_type_id': type.id,
            'max_building_level': _drafts[type.id]!.maxLevel,
            'max_count': _drafts[type.id]!.maxCount,
          },
      ]);
      if (!mounted) return;
      final touchedTownHalls = saved.map((rule) => rule.thLevel).toSet();
      final otherRules = widget.catalog.unlockRules
          .where((rule) => !touchedTownHalls.contains(rule.thLevel))
          .toList();
      widget.onSaved([...otherRules, ...saved]);
      setState(() {
        _saved = _drafts.map((id, rule) => MapEntry(id, rule.copy()));
        _message = 'Aturan TH $_townHallLevel tersimpan dan aktif di Editor.';
      });
    } catch (error) {
      if (mounted) setState(() => _message = error.toString());
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final unlocked = _buildings
        .where((type) => (_drafts[type.id]?.maxLevel ?? 0) > 0)
        .toList();
    final unlimited = unlocked.any(
      (type) => _drafts[type.id]?.maxCount == null,
    );
    final total = unlocked.fold<int>(
      0,
      (sum, type) => sum + (_drafts[type.id]?.maxCount ?? 0),
    );
    final folders = <String, List<BuildingType>>{};
    for (final type in _buildings) {
      folders.putIfAbsent(type.category, () => []).add(type);
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        DropdownButtonFormField<int>(
          initialValue: _townHallLevel,
          decoration: const InputDecoration(
            labelText: 'Town Hall yang dikonfigurasi',
            prefixIcon: Icon(Icons.castle_outlined),
          ),
          items: [
            for (final level in _townHallLevels)
              DropdownMenuItem(value: level, child: Text('Town Hall $level')),
          ],
          onChanged: _saving
              ? null
              : (value) {
                  if (value != null) _changeTownHall(value);
                },
        ),
        const SizedBox(height: 12),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                const Icon(Icons.inventory_2_outlined, color: AppColors.brass),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'TH $_townHallLevel · ${unlocked.length} jenis building',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      Text(
                        unlimited
                            ? 'Total maksimum: ada building tanpa batas'
                            : 'Total maksimum: $total building',
                        style: const TextStyle(color: AppColors.muted),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 8),
        const Text(
          'Aktifkan building yang tersedia, lalu tentukan level dan jumlah maksimum untuk TH ini.',
          style: TextStyle(color: AppColors.muted),
        ),
        const SizedBox(height: 8),
        for (final entry in folders.entries)
          Card(
            clipBehavior: Clip.antiAlias,
            child: ExpansionTile(
              leading: const Icon(Icons.folder_outlined),
              title: Text(_title(entry.key)),
              subtitle: Text(
                '${entry.value.where((type) => (_drafts[type.id]?.maxLevel ?? 0) > 0).length}/${entry.value.length} tersedia',
              ),
              children: [
                if (_previousTownHallLevel != null)
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(12, 4, 12, 8),
                      child: OutlinedButton.icon(
                        onPressed: _saving
                            ? null
                            : () => _syncFolderFromPrevious(
                                entry.key,
                                entry.value,
                              ),
                        icon: const Icon(Icons.sync, size: 18),
                        label: Text(
                          'Sync yang reset dari TH $_previousTownHallLevel',
                        ),
                      ),
                    ),
                  ),
                for (final type in entry.value) _ruleTile(type),
              ],
            ),
          ),
        if (_message != null) ...[
          const SizedBox(height: 10),
          Text(_message!, style: const TextStyle(color: AppColors.muted)),
        ],
        const SizedBox(height: 12),
        SizedBox(
          width: double.infinity,
          child: FilledButton.icon(
            onPressed: _saving || !dirty ? null : _save,
            icon: _saving
                ? const SizedBox.square(
                    dimension: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.cloud_upload_outlined),
            label: Text(_saving ? 'Menyimpan…' : 'Simpan aturan TH'),
          ),
        ),
      ],
    );
  }

  Widget _ruleTile(BuildingType type) {
    final draft = _drafts[type.id]!;
    final enabled = draft.maxLevel > 0;
    final availableLevels =
        type.levels
            .map((level) => level.level)
            .where((level) => level > 0)
            .toSet()
            .toList()
          ..sort();
    final hasActiveLevel = availableLevels.isNotEmpty;
    final selectedLevel = availableLevels.contains(draft.maxLevel)
        ? draft.maxLevel
        : hasActiveLevel
        ? availableLevels.last
        : 0;
    final image =
        type.thumbnailFor(enabled ? selectedLevel : 999)?.imageUrl ?? '';
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 8, 8, 12),
      decoration: const BoxDecoration(
        border: Border(top: BorderSide(color: AppColors.line)),
      ),
      child: Column(
        children: [
          Row(
            children: [
              SizedBox.square(
                dimension: 52,
                child: OfflineImage(
                  image,
                  fit: BoxFit.contain,
                  errorBuilder: (_, _, _) =>
                      const Icon(Icons.home_work_outlined),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      type.name,
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                    Text(
                      type.subfolder?.isNotEmpty == true
                          ? type.subfolder!
                          : '${type.defaultGridWidth} × ${type.defaultGridHeight} tile',
                      style: const TextStyle(
                        color: AppColors.muted,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              Switch(
                key: ValueKey('unlock-building-${type.id}'),
                value: enabled,
                onChanged: _saving || !hasActiveLevel
                    ? null
                    : (value) => _change(
                        type.id,
                        value
                            ? _RuleDraft(availableLevels.first, 1)
                            : _RuleDraft(0, 0),
                      ),
              ),
            ],
          ),
          if (!hasActiveLevel)
            const Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'Belum ada level building aktif di katalog.',
                style: TextStyle(color: AppColors.muted, fontSize: 12),
              ),
            )
          else if (enabled)
            Row(
              children: [
                Expanded(
                  child: DropdownButtonFormField<int>(
                    initialValue: selectedLevel,
                    isExpanded: true,
                    decoration: const InputDecoration(labelText: 'Level maks.'),
                    items: [
                      for (final level in availableLevels)
                        DropdownMenuItem(
                          value: level,
                          child: Text(
                            'Level $level',
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                    ],
                    onChanged: _saving
                        ? null
                        : (value) {
                            if (value != null) {
                              _change(
                                type.id,
                                _RuleDraft(value, draft.maxCount),
                              );
                            }
                          },
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: InkWell(
                    onTap: _saving ? null : () => _editCount(type, draft),
                    child: InputDecorator(
                      decoration: const InputDecoration(
                        labelText: 'Jumlah maks.',
                        suffixIcon: Icon(Icons.edit_outlined, size: 18),
                      ),
                      child: Text(draft.maxCount?.toString() ?? 'Tanpa batas'),
                    ),
                  ),
                ),
              ],
            ),
        ],
      ),
    );
  }

  Future<void> _editCount(BuildingType type, _RuleDraft draft) async {
    var input = draft.maxCount?.toString() ?? '';
    var submitted = false;
    final result = await showDialog<int?>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Jumlah maksimum ${type.name}'),
        content: TextFormField(
          autofocus: true,
          keyboardType: TextInputType.number,
          initialValue: input,
          decoration: const InputDecoration(
            labelText: 'Jumlah',
            helperText: 'Kosongkan untuk tanpa batas',
          ),
          onChanged: (value) => input = value,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Batal'),
          ),
          FilledButton(
            onPressed: () {
              final value = input.trim().isEmpty ? null : int.tryParse(input);
              if (value == null && input.trim().isNotEmpty) return;
              if (value != null && (value < 1 || value > 1000)) return;
              submitted = true;
              Navigator.pop(context, value);
            },
            child: const Text('Terapkan'),
          ),
        ],
      ),
    );
    if (!mounted) return;
    if (submitted) {
      _change(type.id, _RuleDraft(draft.maxLevel, result));
    }
  }
}

class _RuleDraft {
  const _RuleDraft(this.maxLevel, this.maxCount);
  final int maxLevel;
  final int? maxCount;
  _RuleDraft copy() => _RuleDraft(maxLevel, maxCount);

  @override
  bool operator ==(Object other) =>
      other is _RuleDraft &&
      other.maxLevel == maxLevel &&
      other.maxCount == maxCount;

  @override
  int get hashCode => Object.hash(maxLevel, maxCount);
}

bool _sameRules(Map<int, _RuleDraft> a, Map<int, _RuleDraft> b) {
  if (a.length != b.length) return false;
  for (final entry in a.entries) {
    if (b[entry.key] != entry.value) return false;
  }
  return true;
}

String _title(String value) => value
    .replaceAll(RegExp(r'[_-]+'), ' ')
    .split(' ')
    .where((part) => part.isNotEmpty)
    .map((part) => '${part[0].toUpperCase()}${part.substring(1)}')
    .join(' ');
