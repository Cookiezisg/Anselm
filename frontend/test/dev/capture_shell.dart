// Dev screenshot harness — NOT part of the `flutter test` suite proper (it depends on the
// bundled font + writes a PNG). Run explicitly:  flutter test test/dev/capture_shell.dart
// Renders the three-island shell skeleton headlessly via Skia (no Xcode) → test/dev/out/shell.png
// so the layout/spacing/font can be inspected without launching the app. The macOS traffic
// lights are OS-drawn (absent here), so the left island's leading zone shows as reserved empty
// space — layout is still faithful. All capture boilerplate lives in capture_support.dart.
// 开发截图夹具:无头渲染三岛骨架成 PNG,免起 app 看布局/间距/字体。红绿灯是 OS 画的(此处无),
// 故前导区显为留白——布局仍忠实。样板全在 capture_support.dart 地基。
import 'package:anselm/core/design/tokens.dart';
import 'package:anselm/core/ui/an_shell.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'capture_support.dart';

void main() {
  setUpAll(loadAppFonts);

  testWidgets('shell', (tester) async {
    setCaptureSurface(
      tester,
      const Size(AnSize.windowInitialWidth, AnSize.windowInitialHeight),
      dpr: 1.0,
    );
    await tester.pumpWidget(const CaptureHost(bare: true, home: AnShell()));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
    await capturePng(tester, 'shell', pixelRatio: 1.0);
  });
}
