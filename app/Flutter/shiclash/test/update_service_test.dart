import 'package:flutter_test/flutter_test.dart';
import 'package:shiclash/core/update/update_service.dart';

void main() {
  test('semantic version comparison detects available updates', () {
    expect(compareAppVersions('0.1.1', '0.1.0'), isPositive);
    expect(compareAppVersions('1.0.0', '0.9.9'), isPositive);
    expect(compareAppVersions('0.1.0', '0.1.0'), 0);
    expect(compareAppVersions('0.1.0', '0.2.0'), isNegative);
    expect(compareAppVersions('v2.3.4+8', '2.3.3+7'), isPositive);
  });

  test('GitHub SHA-256 digest parser only accepts a complete digest', () {
    expect(
      parseReleaseSha256(
        'sha256:7a582e871f9995ca33922eb7deb6cf9a0c865be6f63b7737e3ddd0d7f35ba940',
      ),
      '7a582e871f9995ca33922eb7deb6cf9a0c865be6f63b7737e3ddd0d7f35ba940',
    );
    expect(parseReleaseSha256('sha256:abc'), isNull);
    expect(parseReleaseSha256(null), isNull);
  });
}
