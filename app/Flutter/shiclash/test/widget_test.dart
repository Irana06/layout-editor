import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shiclash/app.dart';

void main() {
  testWidgets('app exposes its three primary destinations', (tester) async {
    await tester.pumpWidget(const ShiclashApp());

    expect(find.text('Studio'), findsOneWidget);
    expect(find.text('Editor'), findsOneWidget);
    expect(find.text('Layouts'), findsOneWidget);
    expect(find.byType(NavigationBar), findsOneWidget);
  });
}
