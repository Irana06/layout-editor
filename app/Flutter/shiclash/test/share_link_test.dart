import 'package:flutter_test/flutter_test.dart';
import 'package:shiclash/features/layouts/domain/share_link.dart';

void main() {
  String? code(String uri) => shareCodeFromUri(Uri.parse(uri));

  test('accepts both link shapes for the same layout', () {
    expect(
      code('https://layout-editor-production.up.railway.app/l/a7k2mq'),
      'a7k2mq',
    );
    expect(code('http://localhost:8000/l/a7k2mq'), 'a7k2mq');
    expect(code('shiclash://layout/a7k2mq'), 'a7k2mq');
  });

  test('ignores links that are not shared layouts', () {
    expect(code('https://example.com/'), isNull);
    expect(code('https://example.com/layouts/a7k2mq'), isNull);
    expect(code('shiclash://settings/a7k2mq'), isNull);
    expect(code('https://example.com/l/'), isNull);
  });

  test('rejects codes that cannot be ours before hitting the network', () {
    // Wrong length, and characters the alphabet deliberately leaves out so a
    // code survives being read aloud.
    expect(code('https://example.com/l/abc'), isNull);
    expect(code('https://example.com/l/a7k2mq99'), isNull);
    expect(code('https://example.com/l/a7k2m0'), isNull);
    expect(code('https://example.com/l/a7k2mI'), isNull);
  });

  test('trailing slashes and extra path do not confuse the code', () {
    expect(code('https://example.com/l/a7k2mq/'), 'a7k2mq');
    expect(code('https://example.com/l/a7k2mq?from=chat'), 'a7k2mq');
  });
}
