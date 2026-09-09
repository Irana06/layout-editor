import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';

/// Local versioned document; placement keys match Laravel's layout payload.
class LocalDraft {
  LocalDraft({
    required this.id,
    required this.title,
    required this.layout,
    required this.updatedAt,
  });

  final String id;
  final String title;
  final Map<String, dynamic> layout;
  final DateTime updatedAt;

  factory LocalDraft.fromJson(Map<String, dynamic> json) {
    final layout = Map<String, dynamic>.from(json['layout'] as Map);
    if (layout['scenery_id'] is! int ||
        layout['th_level'] is! int ||
        layout['data'] is! List) {
      throw const FormatException('Format layout tidak valid');
    }
    for (final row in layout['data'] as List) {
      if (row is! Map ||
          [
            'building_type_id',
            'level',
            'gx',
            'gy',
          ].any((key) => row[key] is! int)) {
        throw const FormatException('Format bangunan tidak valid');
      }
      // Optional, and only ever a mode key — a number or a map here means the
      // file was written by something that does not speak this format.
      if (row['variant'] != null && row['variant'] is! String) {
        throw const FormatException('Format mode bangunan tidak valid');
      }
    }
    return LocalDraft(
      id: json['id'] as String,
      title: json['title'] as String,
      layout: layout,
      updatedAt: DateTime.parse(json['updated_at'] as String),
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'title': title,
    'layout': layout,
    'updated_at': updatedAt.toIso8601String(),
  };
}

class DraftStore extends ChangeNotifier {
  DraftStore({Future<Directory> Function()? directory})
    : _directory = directory ?? getApplicationDocumentsDirectory;

  final Future<Directory> Function() _directory;
  late final Future<void> ready = _load();
  late File _file;
  Future<void> _queue = Future.value();
  LocalDraft? active;
  List<LocalDraft> _saved = [];
  List<LocalDraft> get saved => List.unmodifiable(_saved);
  int openVersion = 0;
  int _pending = 0;
  bool get saving => _pending > 0;
  String? error;
  bool _closed = false;

  Future<void> _load() async {
    try {
      final directory = await _directory();
      await directory.create(recursive: true);
      _file = File('${directory.path}/shiclash-drafts-v1.json');
      if (await _file.exists()) {
        final json =
            jsonDecode(await _file.readAsString()) as Map<String, dynamic>;
        if (json['version'] != 1) {
          throw const FormatException('Versi draft tidak didukung');
        }
        final restored = json['active'] == null
            ? null
            : LocalDraft.fromJson(
                Map<String, dynamic>.from(json['active'] as Map),
              );
        final saved = (json['saved'] as List)
            .map(
              (item) =>
                  LocalDraft.fromJson(Map<String, dynamic>.from(item as Map)),
            )
            .toList();
        active = restored;
        _saved = saved;
      }
    } catch (_) {
      error = 'Draft lokal gagal dibaca. Data lama tidak ditimpa.';
      rethrow;
    } finally {
      _notify();
    }
  }

  /// Id of the untitled working draft, before it is given a name.
  static const String scratchId = 'autosave';

  Future<void> autosave(Map<String, dynamic> layout) async {
    await ready;
    final previous = active;
    final updated = LocalDraft(
      id: previous?.id ?? scratchId,
      title: previous?.title ?? 'Draft terakhir',
      layout: layout,
      updatedAt: DateTime.now(),
    );
    active = updated;

    // Once the draft has a name it lives in the collection, and every later
    // edit keeps saving straight into that entry — there is no separate
    // "save" step to forget.
    if (updated.id != scratchId) {
      _saved = _saved
          .map((item) => item.id == updated.id ? updated : item)
          .toList();
    }
    await _persist();
  }

  /// Name the working draft, promoting it into the collection the first time.
  Future<void> renameActive(String title) async {
    await ready;
    final current = active;
    if (current == null) throw StateError('Belum ada draft');
    final clean = title.trim();
    if (clean.isEmpty || clean.length > 100) {
      throw ArgumentError('Nama harus berisi 1–100 karakter');
    }

    final promoted = current.id == scratchId;
    final updated = LocalDraft(
      id: promoted
          ? DateTime.now().microsecondsSinceEpoch.toString()
          : current.id,
      title: clean,
      layout: current.layout,
      updatedAt: DateTime.now(),
    );
    active = updated;
    _saved = promoted
        ? [updated, ..._saved]
        : _saved.map((item) => item.id == updated.id ? updated : item).toList();
    await _persist();
  }

  /// Snapshot the open canvas into the collection under [title], leaving the
  /// canvas itself untouched. Used to rescue an unnamed draft that is about to
  /// be replaced, not as a manual save step.
  Future<void> saveCopy(String title) async {
    await ready;
    if (active == null) throw StateError('Belum ada draft');
    _saved = [
      LocalDraft(
        id: DateTime.now().microsecondsSinceEpoch.toString(),
        title: title.trim(),
        layout: active!.layout,
        updatedAt: DateTime.now(),
      ),
      ..._saved,
    ];
    await _persist();
  }

  /// File a layout someone shared into the collection without disturbing the
  /// canvas — taking a copy should never cost the work in progress.
  Future<LocalDraft> saveShared(
    String title,
    Map<String, dynamic> layout,
  ) async {
    await ready;
    final copy = LocalDraft(
      id: DateTime.now().microsecondsSinceEpoch.toString(),
      title: title.trim().isEmpty ? 'Layout dibagikan' : title.trim(),
      layout: layout,
      updatedAt: DateTime.now(),
    );
    _saved = [copy, ..._saved];
    await _persist();

    return copy;
  }

  /// Copy a stored layout, leaving the original and the open canvas untouched.
  Future<void> duplicate(String id) async {
    await ready;
    final source = _saved.firstWhere(
      (item) => item.id == id,
      orElse: () => throw StateError('Layout tidak ditemukan'),
    );
    final copy = LocalDraft(
      id: DateTime.now().microsecondsSinceEpoch.toString(),
      title: '${source.title} (salinan)',
      layout: source.layout,
      updatedAt: DateTime.now(),
    );
    final at = _saved.indexOf(source);
    _saved = [..._saved.take(at + 1), copy, ..._saved.skip(at + 1)];
    await _persist();
  }

  Future<void> delete(String id) async {
    await ready;
    _saved = _saved.where((item) => item.id != id).toList();
    // Deleting the layout that is currently open leaves the canvas as an
    // unnamed draft rather than writing back into an entry that is gone.
    if (active?.id == id) {
      active = LocalDraft(
        id: scratchId,
        title: 'Draft terakhir',
        layout: active!.layout,
        updatedAt: DateTime.now(),
      );
    }
    await _persist();
  }

  Future<void> rename(String id, String title) async {
    await ready;
    final clean = title.trim();
    if (clean.isEmpty || clean.length > 100) {
      throw ArgumentError('Nama harus berisi 1–100 karakter');
    }
    _saved = _saved
        .map(
          (item) => item.id == id
              ? LocalDraft(
                  id: item.id,
                  title: clean,
                  layout: item.layout,
                  updatedAt: DateTime.now(),
                )
              : item,
        )
        .toList();
    // The open canvas may be this very layout, so keep its name in step
    // instead of leaving the editor header showing the old one.
    if (active?.id == id) {
      active = LocalDraft(
        id: id,
        title: clean,
        layout: active!.layout,
        updatedAt: DateTime.now(),
      );
    }
    await _persist();
  }

  /// Make [draft] the document the canvas is editing, so later autosaves write
  /// back into it instead of into whatever was open before.
  void adopt(LocalDraft draft) {
    active = draft;
    _notify();
  }

  // Opening does not overwrite autosave until the editor validates the layout.
  LocalDraft? requested;
  void requestOpen(LocalDraft draft) {
    requested = draft;
    openVersion++;
    _notify();
  }

  Future<void> retrySave() async {
    await ready;
    await _persist();
  }

  String exportDocument() {
    return jsonEncode(_document());
  }

  Future<void> restoreDocument(String content) async {
    await ready;
    final decoded = jsonDecode(content);
    if (decoded is! Map) {
      throw const FormatException('Backup Google Drive tidak valid');
    }
    final document = Map<String, dynamic>.from(decoded);
    if (document['version'] != 1 || document['saved'] is! List) {
      throw const FormatException('Versi backup Google Drive tidak didukung');
    }
    final restoredActive = document['active'] == null
        ? null
        : LocalDraft.fromJson(
            Map<String, dynamic>.from(document['active'] as Map),
          );
    final restoredSaved = (document['saved'] as List)
        .map(
          (item) => LocalDraft.fromJson(Map<String, dynamic>.from(item as Map)),
        )
        .toList();
    active = restoredActive;
    _saved = restoredSaved;
    await _persist();
  }

  Map<String, dynamic> _document() => {
    'version': 1,
    'active': active?.toJson(),
    'saved': _saved.map((item) => item.toJson()).toList(),
  };

  Future<void> _persist() {
    final content = jsonEncode(_document());
    _pending++;
    _notify();
    final operation = _queue.then((_) async {
      final temporary = File('${_file.path}.tmp');
      await temporary.writeAsString(content, flush: true);
      await temporary.rename(_file.path);
    });
    _queue = operation
        .then<void>(
          (_) {
            error = null;
          },
          onError: (Object failure) {
            error = 'Penyimpanan gagal. Perubahan masih ada di memori; coba simpan lagi.';
          },
        )
        .whenComplete(() {
          _pending--;
          _notify();
        });
    return operation;
  }

  void _notify() {
    if (!_closed) notifyListeners();
  }

  @override
  void dispose() {
    _closed = true;
    super.dispose();
  }
}
