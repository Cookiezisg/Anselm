// Dev screenshot harness for ChatToolCard — NOT part of the gate. Run explicitly:
//   flutter test test/dev/capture_tool_card.dart
// Renders the V3a chassis's full lifecycle (all phases + the expanded generic body) headlessly
// → test/dev/out/tool_card.png. Full (non-reduced) motion; captured with pump (never
// pumpAndSettle — the running rows shimmer + tick by design).
//
// ChatToolCard 开发截图夹具(非门禁)。无头渲全生命周期(全部相位+展开的通用体)→ tool_card.png。
// 全动效;用 pump 截(绝不 pumpAndSettle——运行行的流光与读秒本该常动)。
import 'dart:io';
import 'dart:ui' as ui;

import 'package:anselm/core/design/theme.dart';
import 'package:anselm/core/design/tokens.dart';
import 'package:anselm/core/design/typography.dart';
import 'package:anselm/dev/gallery/chat_tool_card_specimens.dart';
import 'package:anselm/dev/gallery/tool_card_builds_specimens.dart';
import 'package:anselm/dev/gallery/tool_card_family_specimens.dart';
import 'package:anselm/i18n/strings.g.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

Future<void> _load(String family, String path) async {
  final f = File(path);
  if (!f.existsSync()) return;
  final b = f.readAsBytesSync();
  final loader = FontLoader(family)
    ..addFont(Future.value(ByteData.view(b.buffer, b.offsetInBytes, b.length)));
  await loader.load();
}

void main() {
  setUpAll(() async {
    await _load('Inter', 'assets/fonts/InterVariable.ttf');
    await _load('MiSans', 'assets/fonts/MiSansVF.ttf');
    await _load('JetBrains Mono', 'assets/fonts/JetBrainsMono.ttf');
    final cache = '${Platform.environment['HOME']}/.pub-cache/hosted/pub.dev';
    await _load('packages/lucide_icons_flutter/Lucide300',
        '$cache/lucide_icons_flutter-3.1.14+2/assets/build_font/LucideVariable-w300.ttf');
  });

  testWidgets('capture tool card lifecycle', (tester) async {
    LocaleSettings.setLocaleRaw('zh-CN');
    const key = ValueKey('cap');
    tester.view.devicePixelRatio = 1.0;
    tester.view.physicalSize = const Size(760, 5400);
    addTearDown(tester.view.reset);

    await tester.pumpWidget(RepaintBoundary(
      key: key,
      child: TranslationProvider(
        child: MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: AnTheme.light(),
          home: Scaffold(
            body: SingleChildScrollView(
              padding: const EdgeInsets.all(AnSpace.s24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  for (final s in [
                    ...toolCardBuildsGalleryItem.specimens,
                    ...toolCardShellGalleryItem.specimens,
                    ...toolCardFsGalleryItem.specimens,
                    ...toolCardSearchGalleryItem.specimens,
                    ...chatToolCardGalleryItem.specimens,
                  ]) ...[
                    Builder(
                        builder: (context) => Text(s.label,
                            style: AnText.meta
                                .copyWith(color: Theme.of(context).colorScheme.outline))),
                    const SizedBox(height: AnSpace.s6),
                    Builder(builder: (context) => s.builder(context)),
                    const SizedBox(height: AnSpace.s24),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    ));
    // Expand the family bodies for the still: Bash-ok terminal, Write code window, Edit diff,
    // Grep hit window (Bash-fail auto-expands). 点开 Bash成功/Write/Edit/Grep 四张入镜。
    await tester.pump(const Duration(milliseconds: 60));
    for (final f in [
      find.text('quarterly_rollup').at(1), // builds 成功卡(第 0 个是流入卡的 name)
      find.textContaining('已更新智能体').last, // edit_agent prompt 窗(first=标签)
      find.text('npm test').at(1), // Bash · exit 0 (第 0 个是活尾巴卡) 成功终端窗
      find.text('已创建工作流'), // create_workflow 两幕:展开看图生长
      find.text('已更新工作流').first, // edit_workflow morph 花名册
      find.text('已创建控制'), // control 决策梯
      find.text('已创建审批'), // approval 表单预览
      find.text('已创建文档'), // document 稿子流
      find.text('已创建技能'), // skill 稿子 + 警示药丸(精确匹配行动词)
      find.text('已创建触发器').at(0), // trigger cron 脸
      find.text('已创建触发器').at(1), // trigger webhook 脸(可复制 URL)
      find.text('已创建触发器').at(2), // trigger fsnotify 脸
      find.text('已更新触发器'), // trigger sensor 脸(CEL 条件/输出)
      find.text('quarters.py').first, // Write 代码窗
      find.text('rollup.py').at(1), // Edit diff 窗(第 0 个是 Read 回执卡的 chip)
      find.text('"amount"'), // Grep 命中窗
      find.text('已回答').at(0), // ask_user 选项 Q/A(选中章)
      find.text('已回答').at(1), // ask_user 自由文本 Q/A(引用)
      find.text('已跳过'), // ask_user 已跳过
      find.text('已批准'), // decide_approval 批准判词+后果条
      find.text('已否决'), // decide_approval 否决判词
      find.text('已清点').at(0), // list_approval_inbox 薄表
      find.text('已清点').at(1), // list_approval_inbox 空态
    ]) {
      await tester.tap(f, warnIfMissed: false);
      await tester.pump(const Duration(milliseconds: 100));
    }
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pump(const Duration(milliseconds: 400));

    late final Uint8List bytes;
    await tester.runAsync(() async {
      final boundary = tester.renderObject<RenderRepaintBoundary>(find.byKey(key));
      final image = await boundary.toImage(pixelRatio: 2.0);
      final png = await image.toByteData(format: ui.ImageByteFormat.png);
      bytes = png!.buffer.asUint8List();
      image.dispose();
    });
    final dir = Directory('test/dev/out')..createSync(recursive: true);
    File('${dir.path}/tool_card.png').writeAsBytesSync(bytes);
  });
}
