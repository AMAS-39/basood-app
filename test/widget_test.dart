// Basic smoke test - verifies app module loads
import 'package:flutter_test/flutter_test.dart';

import 'package:basood/presentation/app.dart';

void main() {
  test('SupplyGoApp class exists', () {
    expect(const SupplyGoApp(), isNotNull);
  });
}
