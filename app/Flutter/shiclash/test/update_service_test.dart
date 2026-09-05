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
}
