import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:airhop/main.dart';

void main() {
  testWidgets('AirHop app boots', (WidgetTester tester) async {
    tester.view.physicalSize = const Size(1200, 2000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(const FileTransferApp());
    await tester.pump();

    expect(find.text('AirHop'), findsOneWidget);
    expect(find.text('ارسال فایل'), findsOneWidget);
    expect(find.text('دریافت فایل'), findsOneWidget);
  });
}
