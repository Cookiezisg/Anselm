// Capture SUPPORT — the shared foundation for every headless-Skia screenshot harness (dev tooling,
// not a test suite). Consolidates the boilerplate every one-off harness used to re-roll (and the
// pits each re-roll re-fell into):
//   · loadAppFonts(): the full font family INCLUDING Lucide300 → LucideVariable-w300.ttf — without
//     it every icon renders as tofu boxes (twice-fallen pit: the family is NOT 'Lucide', AnIcons
//     pins the w300 variable instance).
//   · CaptureHost: ProviderScope(overrides) + TranslationProvider + MaterialApp(light/dark theme)
//     + Scaffold, with the RepaintBoundary ABOVE MaterialApp's Navigator/Overlay — so a modal
//     (picker sheet, dialog) pushed on the root overlay is INSIDE the capture (third pit: a
//     boundary in `home` silently crops every dialog out of the shot).
//   · capturePng(): the runAsync(toImage→PNG) dance — engine-thread async never resolves inside
//     the fake-async zone (flutter#49317), a fourth pit each harness had to re-learn.
// A new capture harness is now ~15 declarative lines: pump a CaptureHost, settle, capturePng.
//
// 截图地基——所有无头 Skia 截图夹具的共享底座(开发工具,非测试)。收编每个一次性夹具重抄的样板与
// 反复踩过的坑:loadAppFonts 含 Lucide300 变量字体(不是 'Lucide',漏了全豆腐块,踩过两次);
// CaptureHost 把 RepaintBoundary 放在 MaterialApp 的 Navigator/Overlay **之上**(放 home 里会把
// 模态静默裁掉);capturePng 固化 runAsync(toImage) 舞步(引擎线程真异步在 fake-async zone 永不
// 解析)。新夹具从 ~160 行降到 ~15 行声明。
import 'dart:io';
import 'dart:ui' as ui;

import 'package:anselm/core/design/theme.dart';
import 'package:anselm/i18n/strings.g.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';

/// Loads ONE font file into the given family (missing file = silent no-op, matching the harness
/// convention). Harness-specific extra faces (serif/code axes) ride this beside [loadAppFonts].
/// 单字体加载(缺文件静默跳过);夹具自有的补充字体(衬线/代码轴)用它搭在 loadAppFonts 旁。
Future<void> loadFont(String family, String path) async {
  final f = File(path);
  if (!f.existsSync()) return;
  final b = f.readAsBytesSync();
  final loader = FontLoader(family)
    ..addFont(Future.value(ByteData.view(b.buffer, b.offsetInBytes, b.length)));
  await loader.load();
}

/// Loads the app's real font stack so captures are glyph-faithful: Inter + MiSans + SF Mono +
/// Lucide300 (the icon face — the variable w300 instance, NOT plain 'Lucide'). Call in setUpAll.
/// 载入真字体栈(含 Lucide300 图标脸),setUpAll 里调。
Future<void> loadAppFonts() async {
  await loadFont('Inter', 'assets/fonts/InterVariable.ttf');
  await loadFont('MiSans', 'assets/fonts/MiSansVF.ttf');
  await loadFont('SF Mono', '/System/Library/Fonts/SFNSMono.ttf');
  // The icon font ships in the package's pub cache; the family name carries the weight instance.
  // 图标字体在 pub 缓存;family 名带字重档。
  final home = Platform.environment['HOME'] ?? '';
  final pubCache = '$home/.pub-cache/hosted/pub.dev';
  final lucideDirs = Directory(pubCache).existsSync()
      ? Directory(pubCache)
            .listSync()
            .whereType<Directory>()
            .where(
              (d) => d.path.split('/').last.startsWith('lucide_icons_flutter-'),
            )
            .toList()
      : <Directory>[];
  if (lucideDirs.isNotEmpty) {
    await loadFont(
      'packages/lucide_icons_flutter/Lucide300',
      '${lucideDirs.last.path}/assets/build_font/LucideVariable-w300.ttf',
    );
  }
}

/// The capture host: RepaintBoundary(捕获边界) ABOVE MaterialApp — a modal route pushed on the root
/// Overlay lands inside the shot. [overrides] seed providers (fixture repos, pinned selections);
/// [dark] flips the theme; [home] is wrapped in a Scaffold unless [bare]. 截图宿主:边界在 MaterialApp
/// 之上(模态入镜);overrides 注 fixture;dark 换主题;home 默认裹 Scaffold。
class CaptureHost extends StatelessWidget {
  const CaptureHost({
    required this.home,
    this.overrides = const [],
    this.dark = false,
    this.bare = false,
    super.key,
  });

  static const boundaryKey = ValueKey('capture-boundary');

  final Widget home;
  final List<Override> overrides;
  final bool dark;

  /// Skip the Scaffold wrapper (the widget brings its own page chrome). 免 Scaffold(自带页面壳)。
  final bool bare;

  @override
  Widget build(BuildContext context) {
    return ProviderScope(
      overrides: overrides,
      child: TranslationProvider(
        child: RepaintBoundary(
          key: boundaryKey,
          child: MaterialApp(
            debugShowCheckedModeBanner: false,
            theme: dark ? AnTheme.dark() : AnTheme.light(),
            home: bare ? home : Scaffold(body: home),
          ),
        ),
      ),
    );
  }
}

/// Renders the [CaptureHost] boundary (or [key]) to `test/dev/out/<name>.png`. Must run inside a
/// testWidgets body AFTER pumping; wraps the engine-thread toImage in runAsync (fake-async never
/// resolves it). Returns the written path. 把捕获边界渲成 PNG 落 test/dev/out;引擎线程异步须 runAsync。
Future<String> capturePng(
  WidgetTester tester,
  String name, {
  double pixelRatio = 2.0,
  Key key = CaptureHost.boundaryKey,
}) async {
  late final Uint8List bytes;
  await tester.runAsync(() async {
    final boundary = tester.renderObject<RenderRepaintBoundary>(
      find.byKey(key),
    );
    final image = await boundary.toImage(pixelRatio: pixelRatio);
    final png = await image.toByteData(format: ui.ImageByteFormat.png);
    bytes = png!.buffer.asUint8List();
    image.dispose();
  });
  final dir = Directory('test/dev/out')..createSync(recursive: true);
  final path = '${dir.path}/$name.png';
  File(path).writeAsBytesSync(bytes);
  return path;
}

/// Standard capture surface sizing: logical [size] at [dpr] onto the test view, reset on teardown.
/// 标准画布设定:逻辑尺寸 × dpr,teardown 复位。
void setCaptureSurface(WidgetTester tester, Size size, {double dpr = 2.0}) {
  tester.view.devicePixelRatio = dpr;
  tester.view.physicalSize = size * dpr;
  addTearDown(tester.view.reset);
}
