import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:shiclash/features/layouts/data/draft_store.dart';

void main() {
  late Directory directory;
  late DraftStore store;
  Map<String, dynamic> layout(int x) => {
    'scenery_id': 1,
    'th_level': 10,
    'data': [
      {'building_type_id': 2, 'level': 10, 'gx': x, 'gy': 2},
    ],
  };

  setUp(() async {
    directory = await Directory.systemTemp.createTemp('shiclash-test-');
    store = DraftStore(directory: () async => directory);
    await store.ready;
  });
  tearDown(() async {
    store.dispose();
    await directory.delete(recursive: true);
  });

  test('rapid autosaves persist the newest draft after restart', () async {
    await Future.wait([
      store.autosave(layout(1)),
      store.autosave(layout(2)),
      store.autosave(layout(3)),
    ]);
    final reopened = DraftStore(directory: () async => directory);
    await reopened.ready;
    expect(reopened.active!.layout, layout(3));
    reopened.dispose();
  });

  test('saved copy survives later edits and deletion persists', () async {
    await store.autosave(layout(1));
    await store.saveCopy('War base');
    await store.autosave(layout(8));
    final reopened = DraftStore(directory: () async => directory);
    await reopened.ready;
    expect(reopened.saved.single.title, 'War base');
    expect(reopened.saved.single.layout, layout(1));
    expect(reopened.active!.layout, layout(8));
    await reopened.delete(reopened.saved.single.id);
    reopened.dispose();
    final finalStore = DraftStore(directory: () async => directory);
    await finalStore.ready;
    expect(finalStore.saved, isEmpty);
    finalStore.dispose();
  });

  test(
    'corrupt file is preserved and cannot be overwritten by autosave',
    () async {
      final file = File('${directory.path}/shiclash-drafts-v1.json');
      await file.writeAsString('{broken');
      final reopened = DraftStore(directory: () async => directory);
      await expectLater(reopened.ready, throwsFormatException);
      await expectLater(reopened.autosave(layout(2)), throwsFormatException);
      expect(await file.readAsString(), '{broken');
      reopened.dispose();
    },
  );

  test('opening a draft does not write unvalidated content to disk', () async {
    await store.autosave(layout(1));
    store.requestOpen(
      LocalDraft(
        id: 'bad',
        title: 'Bad',
        layout: layout(1000),
        updatedAt: DateTime.now(),
      ),
    );
    final json = jsonDecode(
      await File('${directory.path}/shiclash-drafts-v1.json').readAsString(),
    ) as Map;
    expect((json['active'] as Map)['layout'], layout(1));
  });

  test('rename persists without changing placement data', () async {
    await store.autosave(layout(4));
    await store.saveCopy('Original');
    await store.rename(store.saved.single.id, '  War TH 10  ');
    final reopened = DraftStore(directory: () async => directory);
    await reopened.ready;
    expect(reopened.saved.single.title, 'War TH 10');
    expect(reopened.saved.single.layout, layout(4));
    await expectLater(
      store.rename(store.saved.single.id, '   '),
      throwsArgumentError,
    );
    reopened.dispose();
  });

  test('Drive document round-trip replaces local drafts safely', () async {
    await store.autosave(layout(5));
    await store.saveCopy('Backup TH 10');
    final backup = store.exportDocument();

    await store.autosave(layout(9));
    await store.restoreDocument(backup);

    expect(store.active!.layout, layout(5));
    expect(store.saved.single.title, 'Backup TH 10');
    final document = jsonDecode(store.exportDocument()) as Map;
    expect(document['version'], 1);
  });

  test(
    'invalid Drive document is rejected without changing local data',
    () async {
      await store.autosave(layout(3));
      await expectLater(
        store.restoreDocument('{"version":99,"saved":[]}'),
        throwsFormatException,
      );
      expect(store.active!.layout, layout(3));
    },
  );
}
