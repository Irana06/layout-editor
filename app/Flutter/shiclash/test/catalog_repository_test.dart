import 'dart:async';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:shiclash/features/catalog/data/catalog_api.dart';
import 'package:shiclash/features/catalog/data/offline_store.dart';

/// Stands in for the server so the test can control whether it answers, hangs,
/// or fails.
class _FakeApi implements CatalogApi {
  _FakeApi(this.behaviour);

  Future<Map<String, dynamic>> Function() behaviour;
  int calls = 0;

  @override
  Future<Map<String, dynamic>> getBootstrap() {
    calls++;

    return behaviour();
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

Map<String, dynamic> payload(String version) => {
  'data': {'sceneries': [], 'building_types': [], 'unlock_rules': []},
  'meta': {'catalog_version': version},
};

void main() {
  late Directory directory;
  late OfflineStore offline;

  setUp(() async {
    directory = await Directory.systemTemp.createTemp('shiclash-repo-');
    offline = OfflineStore(directory: () async => directory);
    await offline.load();
  });
  tearDown(() async {
    offline.dispose();
    if (await directory.exists()) await directory.delete(recursive: true);
  });

  test(
    'a stored catalogue is served without waiting for the network',
    () async {
      await offline.rememberCatalog(payload('v1'));
      // A server that never answers: if load() waited for it, this test would
      // time out rather than finish.
      final api = _FakeApi(() => Completer<Map<String, dynamic>>().future);
      final repository = CatalogRepository(api, offline: offline);

      final catalog = await repository.load().timeout(
        const Duration(seconds: 2),
      );

      expect(catalog.fromCache, isTrue);
      expect(catalog.version, 'v1');
      repository.dispose();
    },
  );

  test(
    'a newer catalogue arriving in the background notifies listeners',
    () async {
      await offline.rememberCatalog(payload('v1'));
      final api = _FakeApi(() async => payload('v2'));
      final repository = CatalogRepository(api, offline: offline);
      // Waiting for the notification itself rather than for a fixed number of
      // milliseconds: how fast the machine is must not decide whether this
      // passes.
      final notified = Completer<void>();
      repository.addListener(() {
        if (!notified.isCompleted) notified.complete();
      });

      await repository.load();
      await notified.future.timeout(const Duration(seconds: 5));

      expect((await offline.cachedCatalog())!['meta']['catalog_version'], 'v2');
      repository.dispose();
    },
  );

  test('an unchanged catalogue does not notify, which would loop', () async {
    await offline.rememberCatalog(payload('v1'));
    final api = _FakeApi(() async => payload('v1'));
    final repository = CatalogRepository(api, offline: offline);
    var notified = 0;
    repository.addListener(() => notified++);

    await repository.load();
    // Proving an absence needs a generous wait, and waiting longer can only
    // make this stricter, never flakier.
    await Future<void>.delayed(const Duration(seconds: 1));

    expect(notified, 0);
    expect(api.calls, 1);
    repository.dispose();
  });

  test('with nothing stored the network is still the only source', () async {
    final api = _FakeApi(() async => payload('v1'));
    final repository = CatalogRepository(api, offline: offline);

    final catalog = await repository.load();

    expect(catalog.fromCache, isFalse);
    expect(api.calls, 1);
    repository.dispose();
  });
}
