import 'dart:io';

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shiclash/features/catalog/data/offline_store.dart';

void main() {
  late Directory directory;
  late OfflineStore store;

  setUp(() async {
    directory = await Directory.systemTemp.createTemp('shiclash-offline-');
    store = OfflineStore(directory: () async => directory);
    await store.load();
  });
  tearDown(() async {
    store.dispose();
    if (await directory.exists()) await directory.delete(recursive: true);
  });

  Map<String, dynamic> payload(String version) => {
    'data': {'sceneries': [], 'building_types': [], 'unlock_rules': []},
    'meta': {'catalog_version': version},
  };

  test('the catalogue survives losing signal', () async {
    await store.rememberCatalog(payload('abc123'));

    final reopened = OfflineStore(directory: () async => directory);
    await reopened.load();
    final cached = await reopened.cachedCatalog();

    expect(cached, isNotNull);
    expect((cached!['meta'] as Map)['catalog_version'], 'abc123');
    reopened.dispose();
  });

  test('a corrupt cache reads as absent instead of throwing', () async {
    await store.rememberCatalog(payload('abc123'));
    final file = File('${directory.path}/offline/catalog.json');
    await file.writeAsString('{not json');

    expect(await store.cachedCatalog(), isNull);
  });

  test('images come from disk once stored, and the network before that', () async {
    const url = 'https://example.com/game/buildings/cannon/1.png';
    expect(store.imageProvider(url), isA<NetworkImage>());

    // Simulate a completed download of that one file.
    final key = Uri.parse(url).path.replaceAll(RegExp(r'[^A-Za-z0-9._-]'), '_');
    await File('${directory.path}/offline/$key').writeAsString('png');
    await store.load();

    expect(store.imageProvider(url), isA<FileImage>());
    // Anything not downloaded still falls back, so a partial set stays useful.
    expect(
      store.imageProvider('https://example.com/game/other.png'),
      isA<NetworkImage>(),
    );
  });

  test('a version is only stamped when every file arrived', () async {
    // No server here, so every fetch fails and the set is incomplete.
    await store.downloadAll(
      urls: const ['https://127.0.0.1:9/missing-a.png'],
      version: 'v2',
    );

    expect(store.storedVersion, isNull);
    expect(store.error, isNotNull);
    expect(store.progress!.failed, 1);
  });

  test('clearing removes the images but reports an empty store', () async {
    await store.rememberCatalog(payload('abc123'));
    expect(await store.storedBytes(), greaterThan(0));

    await store.clear();

    expect(store.storedVersion, isNull);
    expect(await store.storedBytes(), 0);
  });
}
