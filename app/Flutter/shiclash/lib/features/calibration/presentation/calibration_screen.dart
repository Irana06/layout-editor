import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:shiclash/core/theme/app_theme.dart';
import 'package:shiclash/features/account/data/google_account_controller.dart';
import 'package:shiclash/features/calibration/data/calibration_api.dart';
import 'package:shiclash/features/calibration/domain/calibration_draft.dart';
import 'package:shiclash/features/calibration/presentation/building_level_picker.dart';
import 'package:shiclash/features/calibration/presentation/calibration_canvas.dart';
import 'package:shiclash/features/calibration/presentation/town_hall_rules_panel.dart';
import 'package:shiclash/features/catalog/data/catalog_api.dart';
import 'package:shiclash/features/catalog/data/catalog_models.dart';

class CalibrationScreen extends StatefulWidget {
  const CalibrationScreen({
    super.key,
    required this.account,
    required this.repository,
    this.api,
  });
  final GoogleAccountController account;
  final CatalogRepository repository;
  final CalibrationApi? api;
  @override
  State<CalibrationScreen> createState() => _CalibrationScreenState();
}

class _CalibrationScreenState extends State<CalibrationScreen> {
  late final CalibrationApi _api;
  CatalogBootstrap? _catalog;
  Scenery? _scenery;
  BuildingType? _type;
  BuildingLevel? _level;
  CalibrationDraft? _draft;
  final _rulesKey = GlobalKey<TownHallRulesPanelState>();
  int _section = 0;
  bool _loading = true, _saving = false;
  bool _edit = false, _grid = true;
  double _opacity = .8;
  String? _error, _status;
  bool _needsLogin = false;

  bool get _building => _section == 1;
  bool get _rules => _section == 2;

  @override
  void initState() {
    super.initState();
    _api =
        widget.api ??
        CalibrationApi(
          idToken: () async => widget.account.account?.authentication.idToken,
        );
    _load();
  }

  @override
  void dispose() {
    _draft?.dispose();
    if (widget.api == null) _api.close();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
      _needsLogin = false;
    });
    try {
      if (!await _api.isAdmin()) {
        throw const CalibrationException(
          'Akun ini belum memiliki akses admin.',
          403,
        );
      }
      final data = await _api.load();
      if (!mounted) return;
      final sceneryId = _scenery?.id;
      final typeId = _type?.id;
      final levelId = _level?.id;
      setState(() {
        _catalog = data;
        _scenery =
            data.sceneries.where((s) => s.id == sceneryId).firstOrNull ??
            data.sceneries.firstOrNull;
        _type =
            data.buildingTypes.where((t) => t.id == typeId).firstOrNull ??
            data.buildingTypes.firstOrNull;
        _level =
            _type?.levels.where((l) => l.id == levelId).firstOrNull ??
            _type?.levels.firstOrNull;
        _newDraft();
      });
    } catch (error) {
      _showError(error);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _newDraft() {
    _draft?.dispose();
    final values = _rules
        ? null
        : _building
        ? _level?.calibrationValues()
        : _scenery?.calibrationValues();
    _draft = values == null ? null : CalibrationDraft(values);
    _draft?.addListener(() {
      if (mounted) setState(() {});
    });
    _edit = false;
    _status = null;
  }

  void _showError(Object error) {
    if (!mounted) return;
    setState(() {
      _error = error.toString();
      _needsLogin = error is CalibrationException && error.status == 401;
    });
  }

  Future<bool> _discard() async {
    if (_saving) return false;
    if (_rulesKey.currentState?.dirty == true) {
      return _rulesKey.currentState!.confirmDiscard();
    }
    if (_draft?.dirty != true) return true;
    return await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('Perubahan belum disimpan'),
            content: const Text(
              'Tetap di sini untuk menyimpan, atau buang perubahan untuk melanjutkan.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('Tetap di sini'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(ctx, true),
                child: const Text('Buang perubahan'),
              ),
            ],
          ),
        ) ??
        false;
  }

  Future<void> _switch(VoidCallback action) async {
    if (!await _discard() || !mounted) return;
    setState(() {
      action();
      _error = null;
      _newDraft();
    });
  }

  Future<void> _save() async {
    final draft = _draft;
    if (draft == null || _saving || !_canSave) return;
    setState(() {
      _saving = true;
      _error = null;
      _status = null;
    });
    try {
      final result = await _api.request(
        _building
            ? 'admin/building-levels/${_level!.id}'
            : 'admin/sceneries/${_scenery!.id}',
        body: {...draft.values, if (!_building) 'calibrated': true},
      );
      if (!mounted) return;
      setState(() {
        if (_building) {
          final values = BuildingLevel.fromJson(
            Map<String, dynamic>.from(result['buildingLevel']),
          ).calibrationValues();
          _level = _level!.withCalibration(values);
          final index = _type!.levels.indexWhere(
            (item) => item.id == _level!.id,
          );
          _type!.levels[index] = _level!;
          draft.saved(values);
        } else {
          _scenery = _scenery!.withCalibration(
            Map<String, dynamic>.from(result['scenery']),
          );
          final index = _catalog!.sceneries.indexWhere(
            (s) => s.id == _scenery!.id,
          );
          _catalog!.sceneries[index] = _scenery!;
          draft.saved(_scenery!.calibrationValues());
        }
        _status = 'Tersimpan di server. Editor dan katalog akan memakai kalibrasi terbaru.';
      });
      widget.repository.invalidate();
    } catch (error) {
      _showError(error);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _toggleLock() async {
    if (_scenery == null || _saving || !await _discard() || !mounted) return;
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      final result = await _api.request(
        'admin/sceneries/${_scenery!.id}',
        body: {'locked': !_scenery!.locked},
      );
      if (!mounted) return;
      setState(() {
        _scenery = _scenery!.withCalibration(
          Map<String, dynamic>.from(result['scenery']),
        );
        _catalog!.sceneries[_catalog!.sceneries.indexWhere(
              (s) => s.id == _scenery!.id,
            )] =
            _scenery!;
        _newDraft();
      });
      widget.repository.invalidate();
    } catch (error) {
      _showError(error);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _login() async {
    await widget.account.signIn();
    if (!mounted) return;
    if (widget.account.error != null) {
      _showError(widget.account.error!);
      return;
    }
    if (_catalog == null) {
      await _load();
      return;
    }
    try {
      if (!await _api.isAdmin()) {
        throw const CalibrationException(
          'Akun ini belum memiliki akses admin.',
          403,
        );
      }
      if (mounted) {
        setState(() {
          _error = null;
          _needsLogin = false;
        });
      }
    } catch (error) {
      _showError(error);
    }
  }

  bool get _locked => !_building && (_scenery?.locked ?? false);
  bool get _canSave =>
      _draft != null &&
      !_locked &&
      (_draft!.dirty || (!_building && !_scenery!.calibrated));
  void _drag(Offset delta) {
    final d = _draft;
    if (d == null || _saving || _locked) return;
    final x = _building ? 'offset_x' : 'origin_x';
    final y = _building ? 'offset_y' : 'origin_y';
    d.change({
      x: ((d.values[x] as num).toDouble() + delta.dx).clamp(
        _building ? -500.0 : -50000.0,
        _building ? 500.0 : 50000.0,
      ),
      y: ((d.values[y] as num).toDouble() + delta.dy).clamp(
        _building ? -500.0 : -50000.0,
        _building ? 500.0 : 50000.0,
      ),
    });
  }

  @override
  Widget build(BuildContext context) => PopScope(
    canPop:
        !_saving &&
        _draft?.dirty != true &&
        _rulesKey.currentState?.dirty != true,
    onPopInvokedWithResult: (didPop, result) async {
      if (!didPop && await _discard() && mounted) {
        _draft?.saved(_draft!.values);
        if (context.mounted) Navigator.pop(context);
      }
    },
    child: Scaffold(
      appBar: AppBar(
        title: const Text('Calibrator'),
        actions: [
          IconButton(
            tooltip: 'Panduan kalibrasi',
            onPressed: _help,
            icon: const Icon(Icons.help_outline),
          ),
          IconButton(
            tooltip: 'Muat ulang dari server',
            onPressed: _loading || _saving
                ? null
                : () async {
                    if (await _discard()) _load();
                  },
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: SafeArea(
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : _content(),
      ),
    ),
  );

  Widget _content() {
    if (_catalog == null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.admin_panel_settings_outlined, size: 48),
              const SizedBox(height: 16),
              Text(
                _error ?? 'Katalog belum tersedia.',
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              FilledButton(
                onPressed: _needsLogin ? _login : _load,
                child: Text(_needsLogin ? 'Login Google kembali' : 'Coba lagi'),
              ),
            ],
          ),
        ),
      );
    }
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: SegmentedButton<int>(
            segments: const [
              ButtonSegment(
                value: 0,
                label: Text('Scenery'),
                icon: Icon(Icons.landscape_outlined),
              ),
              ButtonSegment(
                value: 1,
                label: Text('Building'),
                icon: Icon(Icons.castle_outlined),
              ),
              ButtonSegment(
                value: 2,
                label: Text('Aturan TH'),
                icon: Icon(Icons.rule_folder_outlined),
              ),
            ],
            selected: {_section},
            onSelectionChanged: _saving
                ? null
                : (v) => _switch(() => _section = v.first),
          ),
        ),
        Expanded(
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              if (_error != null)
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      children: [
                        Text(
                          _error!,
                          style: const TextStyle(color: AppColors.danger),
                        ),
                        if (_needsLogin)
                          TextButton(
                            onPressed: _login,
                            child: const Text('Login kembali'),
                          ),
                      ],
                    ),
                  ),
                ),
              if (_rules)
                TownHallRulesPanel(
                  key: _rulesKey,
                  catalog: _catalog!,
                  api: _api,
                  onSaved: (rules) {
                    setState(() => _catalog = _catalog!.withUnlockRules(rules));
                    widget.repository.invalidate();
                  },
                )
              else ...[
                _selector<Scenery>(
                  'Scenery preview',
                  _scenery,
                  _catalog!.sceneries,
                  (s) =>
                      '${s.name}${s.locked ? ' · terkunci' : ''}${s.calibrated ? '' : ' · belum dikalibrasi'}',
                  (s) => _building
                      ? setState(() {
                          _scenery = s;
                          _edit = false;
                        })
                      : _switch(() => _scenery = s),
                ),
                if (_building) ...[
                  const SizedBox(height: 12),
                  _buildingPicker(),
                ],
                const SizedBox(height: 12),
              ],
              if (!_rules)
                if (_scenery == null || (_building && _level == null))
                  const Padding(
                    padding: EdgeInsets.all(24),
                    child: Text(
                      'Belum ada scenery atau level building. Tambahkan aset melalui pengelolaan katalog website.',
                    ),
                  )
                else if (_draft != null) ...[
                  ClipRRect(
                    borderRadius: BorderRadius.circular(16),
                    child: SizedBox(
                      height: math.min(
                        MediaQuery.sizeOf(context).height * .42,
                        440,
                      ),
                      child: CalibrationCanvas(
                        key: ValueKey(
                          '${_building}_${_scenery!.id}_${_building ? _level!.id : 0}',
                        ),
                        scenery: _building
                            ? _scenery!
                            : _scenery!.withCalibration(_draft!.values),
                        type: _building ? _type : null,
                        level: _building
                            ? _level!.withCalibration(_draft!.values)
                            : null,
                        editMode: _edit && !_locked && !_saving,
                        showGrid: _grid,
                        opacity: _opacity,
                        onDrag: _drag,
                        onStart: _draft!.beginGesture,
                        onEnd: _draft!.endGesture,
                      ),
                    ),
                  ),
                  Wrap(
                    spacing: 8,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      FilterChip(
                        label: Text(
                          _edit
                              ? 'Geser ${_building ? 'building' : 'grid'}'
                              : 'Zoom / pan',
                        ),
                        selected: _edit,
                        onSelected: _locked || _saving
                            ? null
                            : (v) => setState(() => _edit = v),
                      ),
                      FilterChip(
                        label: const Text('Grid'),
                        selected: _grid,
                        onSelected: (v) => setState(() => _grid = v),
                      ),
                      IconButton(
                        tooltip: 'Undo',
                        onPressed: !_saving && _draft!.canUndo
                            ? _draft!.undo
                            : null,
                        icon: const Icon(Icons.undo),
                      ),
                      IconButton(
                        tooltip: 'Redo',
                        onPressed: !_saving && _draft!.canRedo
                            ? _draft!.redo
                            : null,
                        icon: const Icon(Icons.redo),
                      ),
                    ],
                  ),
                  Text(
                    _edit
                        ? 'Geser satu jari untuk mengatur ${_building ? 'offset building' : 'titik origin grid'}.'
                        : 'Cubit untuk zoom, geser untuk pan. Aktifkan mode geser untuk mengubah kalibrasi.',
                    style: const TextStyle(color: AppColors.muted),
                  ),
                  if (_building) ...[
                    const SizedBox(height: 8),
                    const Text(
                      'Transparansi building · garis biru menandai footprint',
                    ),
                    Slider(
                      value: _opacity,
                      min: .1,
                      max: 1,
                      onChanged: (v) => setState(() => _opacity = v),
                    ),
                  ],
                  if (_locked)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 12),
                      child: Text(
                        'Grid terkunci. Buka kunci untuk mengubah kalibrasi.',
                      ),
                    ),
                  IgnorePointer(
                    ignoring: _saving || _locked,
                    child: Opacity(
                      opacity: _locked ? .45 : 1,
                      child: _fields(),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    children: [
                      OutlinedButton.icon(
                        onPressed: _saving || _locked || !_draft!.dirty
                            ? null
                            : _draft!.reset,
                        icon: const Icon(Icons.restore),
                        label: const Text('Nilai tersimpan'),
                      ),
                      if (!_building)
                        OutlinedButton.icon(
                          onPressed: _saving ? null : _toggleLock,
                          icon: Icon(
                            _scenery!.locked
                                ? Icons.lock_open
                                : Icons.lock_outline,
                          ),
                          label: Text(
                            _scenery!.locked ? 'Buka kunci' : 'Kunci grid',
                          ),
                        ),
                      if (_building)
                        OutlinedButton(
                          onPressed: _saving
                              ? null
                              : () => _draft!.change({
                                  'grid_width': null,
                                  'grid_height': null,
                                }),
                          child: const Text('Footprint bawaan'),
                        ),
                      if (_building && (_type?.levels.length ?? 0) > 1)
                        OutlinedButton(
                          onPressed: _saving ? null : _copyLevel,
                          child: const Text('Salin dari level lain'),
                        ),
                    ],
                  ),
                ],
            ],
          ),
        ),
        if (_draft != null && !_rules)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  _draft!.dirty
                      ? 'Ada perubahan belum disimpan'
                      : (_status ?? 'Nilai tersimpan di server'),
                  style: const TextStyle(color: AppColors.muted, fontSize: 12),
                ),
                const SizedBox(height: 8),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: _saving || !_canSave ? null : _save,
                    icon: _saving
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.cloud_upload_outlined),
                    label: Text(_saving ? 'Menyimpan…' : 'Simpan kalibrasi'),
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }

  Widget _buildingPicker() {
    final type = _type;
    final level = _level;
    return InkWell(
      borderRadius: BorderRadius.circular(8),
      onTap: _saving
          ? null
          : () async {
              final selection = await showBuildingLevelPicker(
                context,
                buildingTypes: _catalog!.buildingTypes,
                selectedType: type,
                selectedLevel: level,
              );
              if (selection == null || !mounted) return;
              await _switch(() {
                _type = selection.type;
                _level = selection.level;
              });
            },
      child: InputDecorator(
        decoration: const InputDecoration(
          labelText: 'Aset building & level',
          suffixIcon: Icon(Icons.folder_open_outlined),
        ),
        child: Row(
          children: [
            SizedBox.square(
              dimension: 54,
              child: Image.network(
                level?.imageUrl ?? '',
                fit: BoxFit.contain,
                errorBuilder: (_, _, _) => const Icon(Icons.home_work_outlined),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    type == null || level == null
                        ? 'Pilih building'
                        : '${type.name} · Level ${level.level}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                  if (type != null)
                    Text(
                      [
                        type.category,
                        if (type.subfolder?.isNotEmpty == true) type.subfolder!,
                      ].join(' / '),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: AppColors.muted,
                        fontSize: 12,
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _selector<T>(
    String label,
    T? value,
    List<T> items,
    String Function(T) name,
    ValueChanged<T> changed,
  ) => InputDecorator(
    decoration: InputDecoration(labelText: label),
    child: DropdownButtonHideUnderline(
      child: DropdownButton<T>(
        value: value,
        isExpanded: true,
        items: items
            .map(
              (v) => DropdownMenuItem(
                value: v,
                child: Text(name(v), overflow: TextOverflow.ellipsis),
              ),
            )
            .toList(),
        onChanged: _saving
            ? null
            : (v) {
                if (v != null) changed(v);
              },
      ),
    ),
  );

  Widget _fields() {
    final d = _draft!;
    Widget number(
      String name,
      String key,
      double min,
      double max,
      double step, {
      double? fallback,
    }) => _NumberControl(
      label: name,
      value: (d.values[key] as num?)?.toDouble() ?? fallback ?? 0,
      inherited: d.values[key] == null,
      min: min,
      max: max,
      step: step,
      onChanged: (v) => d.change({key: step == 1 ? v.toInt() : v}),
    );
    return Column(
      children: _building
          ? [
              number(
                'Footprint lebar (tile)',
                'grid_width',
                1,
                20,
                1,
                fallback: _type!.defaultGridWidth.toDouble(),
              ),
              number(
                'Footprint tinggi (tile)',
                'grid_height',
                1,
                20,
                1,
                fallback: _type!.defaultGridHeight.toDouble(),
              ),
              number('Skala gambar', 'scale', .1, 5, .01),
              number('Offset X (px)', 'offset_x', -500, 500, .5),
              number('Offset Y (px)', 'offset_y', -500, 500, .5),
            ]
          : [
              number('Lebar tile (px)', 'tile_w', 4, 2000, .5),
              number('Tinggi tile (px)', 'tile_h', 4, 2000, .5),
              number('Origin X (px)', 'origin_x', -50000, 50000, .5),
              number('Origin Y (px)', 'origin_y', -50000, 50000, .5),
              number('Jumlah tile per sisi', 'grid_n', 4, 200, 1),
            ],
    );
  }

  Future<void> _copyLevel() async {
    final source = await showModalBottomSheet<BuildingLevel>(
      context: context,
      builder: (ctx) => SafeArea(
        child: ListView(
          shrinkWrap: true,
          children: [
            const ListTile(title: Text('Salin kalibrasi dari level')),
            ..._type!.levels
                .where((l) => l.id != _level!.id)
                .map(
                  (l) => ListTile(
                    title: Text('Level ${l.level}'),
                    onTap: () => Navigator.pop(ctx, l),
                  ),
                ),
          ],
        ),
      ),
    );
    if (source != null && mounted) _draft!.change(source.calibrationValues());
  }

  void _help() => showDialog<void>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: const Text('Kalibrasi yang presisi'),
      content: const SingleChildScrollView(
        child: Text(
          '1. Scenery: atur lebar/tinggi tile dan jumlah tile. Geser origin hingga grid mengikuti tanah base, simpan, lalu kunci.\n\n'
          '2. Building: pilih jenis dan level. Atur footprint sesuai tile yang ditempati. Gunakan skala untuk ukuran gambar dan offset untuk posisi visual.\n\n'
          '3. Aturan TH: pilih Town Hall, aktifkan building yang tersedia, lalu isi level dan jumlah maksimum. Aturan ini langsung membatasi pilihan di Editor.\n\n'
          '4. Garis biru adalah batas footprint. Lapisan rumput mengikuti footprint dan area putih satu tile di luarnya menandai zona deployment pasukan.\n\n'
          '5. Simpan ke server untuk menerapkan ke katalog bersama. Salin level lain mengisi nilai pratinjau; periksa gambar level baru sebelum menyimpan.\n\n'
          'Undo/redo berlaku untuk sesi kalibrasi ini. Perubahan belum tersimpan tidak diterapkan ke editor.',
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx),
          child: const Text('Mengerti'),
        ),
      ],
    ),
  );
}

class _NumberControl extends StatefulWidget {
  const _NumberControl({
    required this.label,
    required this.value,
    required this.min,
    required this.max,
    required this.step,
    required this.onChanged,
    this.inherited = false,
  });
  final String label;
  final double value, min, max, step;
  final bool inherited;
  final ValueChanged<double> onChanged;
  @override
  State<_NumberControl> createState() => _NumberControlState();
}

class _NumberControlState extends State<_NumberControl> {
  String _format(double v) => v.toStringAsFixed(widget.step == 1 ? 0 : 2);

  Future<void> _editNumber() async {
    var input = _format(widget.value);
    final form = GlobalKey<FormState>();
    final result = await showDialog<double>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(widget.label),
        content: Form(
          key: form,
          child: TextFormField(
            initialValue: input,
            onChanged: (value) => input = value,
            autofocus: true,
            keyboardType: const TextInputType.numberWithOptions(
              decimal: true,
              signed: true,
            ),
            decoration: InputDecoration(
              helperText: '${widget.min} sampai ${widget.max}',
            ),
            validator: (text) {
              final value = double.tryParse((text ?? '').replaceAll(',', '.'));
              if (value == null ||
                  !value.isFinite ||
                  value < widget.min ||
                  value > widget.max ||
                  (widget.step == 1 && value != value.roundToDouble())) {
                return widget.step == 1
                    ? 'Masukkan bilangan bulat dalam batas.'
                    : 'Masukkan angka dalam batas.';
              }
              return null;
            },
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Batal'),
          ),
          FilledButton(
            onPressed: () {
              if (form.currentState!.validate()) {
                Navigator.pop(ctx, double.parse(input.replaceAll(',', '.')));
              }
            },
            child: const Text('Terapkan'),
          ),
        ],
      ),
    );
    if (result != null && mounted) widget.onChanged(result);
  }

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(top: 12),
    child: Row(
      children: [
        Expanded(
          child: InkWell(
            onTap: _editNumber,
            child: InputDecorator(
              decoration: InputDecoration(
                labelText: widget.label,
                helperText: widget.inherited
                    ? 'Mengikuti footprint bawaan'
                    : null,
                suffixIcon: const Icon(Icons.edit_outlined, size: 18),
              ),
              child: Text(_format(widget.value)),
            ),
          ),
        ),
        IconButton(
          tooltip: 'Kurangi ${widget.step}',
          onPressed: () => widget.onChanged(
            (widget.value - widget.step).clamp(widget.min, widget.max),
          ),
          icon: const Icon(Icons.remove_circle_outline),
        ),
        IconButton(
          tooltip: 'Tambah ${widget.step}',
          onPressed: () => widget.onChanged(
            (widget.value + widget.step).clamp(widget.min, widget.max),
          ),
          icon: const Icon(Icons.add_circle_outline),
        ),
      ],
    ),
  );
}
