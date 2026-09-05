import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';

/// Local versioned document; placement keys match Laravel's layout payload.
class LocalDraft {
  LocalDraft({required this.id, required this.title, required this.layout,
    required this.updatedAt});

  final String id;
  final String title;
  final Map<String, dynamic> layout;
  final DateTime updatedAt;

  factory LocalDraft.fromJson(Map<String, dynamic> json) => LocalDraft(
    id: json['id'] as String,
    title: json['title'] as String,
    layout: Map<String, dynamic>.from(json['layout'] as Map),
    updatedAt: DateTime.parse(json['updated_at'] as String),
  );

  Map<String, dynamic> toJson() => {
    'id': id, 'title': title, 'layout': layout,
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
        final json = jsonDecode(await _file.readAsString()) as Map<String, dynamic>;
        if (json['version'] != 1) throw const FormatException('Versi draft tidak didukung');
        final restored = json['active'] == null ? null :
          LocalDraft.fromJson(Map<String, dynamic>.from(json['active'] as Map));
        final saved = (json['saved'] as List).map((item) =>
          LocalDraft.fromJson(Map<String, dynamic>.from(item as Map))).toList();
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

  Future<void> autosave(Map<String, dynamic> layout) async {
    await ready;
    active = LocalDraft(id: 'autosave', title: 'Draft terakhir',
      layout: layout, updatedAt: DateTime.now());
    await _persist();
  }

  Future<void> saveCopy(String title) async {
    await ready;
    if (active == null) throw StateError('Belum ada draft');
    _saved = [LocalDraft(id: DateTime.now().microsecondsSinceEpoch.toString(),
      title: title.trim(), layout: active!.layout, updatedAt: DateTime.now()), ..._saved];
    await _persist();
  }

  Future<void> delete(String id) async {
    await ready;
    _saved = _saved.where((item) => item.id != id).toList();
    await _persist();
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

  Future<void> _persist() {
    final content = jsonEncode({'version': 1, 'active': active?.toJson(),
      'saved': _saved.map((item) => item.toJson()).toList()});
    _pending++;
    _notify();
    final operation = _queue.then((_) async {
      final temporary = File('${_file.path}.tmp');
      await temporary.writeAsString(content, flush: true);
      await temporary.rename(_file.path);
    });
    _queue = operation.then<void>((_) {
      error = null;
    }, onError: (Object failure) {
      error = 'Penyimpanan gagal. Perubahan masih ada di memori; coba simpan lagi.';
    }).whenComplete(() {
      _pending--;
      _notify();
    });
    return operation;
  }

  void _notify() { if (!_closed) notifyListeners(); }

  @override
  void dispose() { _closed = true; super.dispose(); }
}
