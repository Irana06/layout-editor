import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shiclash/app.dart';

void main() {
  testWidgets('app exposes five destinations and opens help on a phone', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(360, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(const ShiclashApp(googleServicesEnabled: false));

    expect(find.text('Studio'), findsOneWidget);
    expect(find.text('Editor'), findsOneWidget);
    expect(find.text('Layouts'), findsOneWidget);
    expect(find.text('Katalog'), findsOneWidget);
    expect(find.text('Lainnya'), findsOneWidget);
    expect(find.byType(NavigationBar), findsOneWidget);
    expect(find.text('Buat base'), findsOneWidget);
    await tester.tap(find.text('Lainnya'));
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.text('Panduan & informasi'), findsOneWidget);
    await tester.tap(find.text('Gerakan dan kontrol'));
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.textContaining('Geser canvas untuk pan'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.binding.handlePopRoute();
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.text('Buat base'), findsOneWidget);
  });
}
