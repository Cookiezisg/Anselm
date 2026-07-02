// Dev screenshot harness — the sent user bubble's COMPLETE body (real thumbs / file cards / mentions /
// degraded states) on the white ocean. NOT part of the gate.
//   flutter test test/dev/capture_user_turn.dart  → test/dev/out/user_turn.png
// 用户泡完整体截图夹具(真缩略图/文件卡/提及/降级态)。非门禁。
import 'dart:io';
import 'dart:ui' as ui;

import 'package:anselm/core/design/colors.dart';
import 'package:anselm/core/design/theme.dart';
import 'package:anselm/core/design/tokens.dart';
import 'package:anselm/core/design/typography.dart';
import 'package:anselm/core/ui/ui.dart';
import 'package:anselm/dev/gallery/demo_images.dart';
import 'package:anselm/features/chat/model/mention_spans.dart';
import 'package:anselm/features/chat/model/user_attachment.dart';
import 'package:anselm/features/chat/ui/chat_turn.dart';
import 'package:anselm/features/chat/ui/user_turn_content.dart';
import 'package:anselm/i18n/strings.g.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

Future<void> _load(String family, String path) async {
  final f = File(path);
  if (!f.existsSync()) return;
  await (FontLoader(family)
        ..addFont(Future.value(ByteData.view(
            f.readAsBytesSync().buffer, 0, f.readAsBytesSync().length))))
      .load();
}

void main() {
  setUpAll(() async {
    await _load('MiSans', 'assets/fonts/MiSansVF.ttf');
    await _load('JetBrains Mono', 'assets/fonts/JetBrainsMono.ttf');
    final cache = '${Platform.environment['HOME']}/.pub-cache/hosted/pub.dev';
    await _load('packages/lucide_icons_flutter/Lucide300',
        '$cache/lucide_icons_flutter-3.1.14+2/assets/build_font/LucideVariable-w300.ttf');
  });

  testWidgets('capture the complete user bubble', (tester) async {
    const key = ValueKey('cap');
    tester.view.devicePixelRatio = 1.0;
    tester.view.physicalSize = const Size(700, 1500);
    addTearDown(tester.view.reset);

    // Rasterize the demo photos up front (engine-async → runAsync). 先光栅化假照片(引擎异步→runAsync)。
    late final MemoryImage single, t1, t2, t3;
    await tester.runAsync(() async {
      single = await demoImage(seed: 0, width: 560, height: 340);
      t1 = await demoImage(seed: 1, width: 300, height: 300);
      t2 = await demoImage(seed: 2, width: 300, height: 300);
      t3 = await demoImage(seed: 3, width: 300, height: 300);
    });

    UserAttachment img(String id, String name, MemoryImage m) =>
        UserAttachment(id: id, kind: 'image', filename: name, thumb: m);

    await tester.pumpWidget(RepaintBoundary(
      key: key,
      child: TranslationProvider(
        child: MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: AnTheme.light(),
          home: Builder(builder: (context) {
            final c = context.colors;
            Widget row(String label, Widget w) => Padding(
                  padding: const EdgeInsets.only(bottom: AnSpace.s24),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(label, style: AnText.meta.copyWith(color: c.inkFaint)),
                    const SizedBox(height: AnSpace.s6),
                    SizedBox(
                      width: 620,
                      child: ChatTurn(role: ChatRole.user, child: w),
                    ),
                  ]),
                );
            return Material(
              color: c.surface,
              child: Padding(
                padding: const EdgeInsets.all(AnSpace.s32),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    row('单图 + 文本', UserTurnContent(
                      text: '这张图里的报表是哪来的?',
                      attachments: [img('a', 'report.png', single)],
                    )),
                    row('三图瓦片 + 文本', UserTurnContent(
                      text: '对比这三张截图',
                      attachments: [img('a', 's1.png', t1), img('b', 's2.png', t2), img('c', 's3.png', t3)],
                    )),
                    row('文件卡 + 提及 + 文本(全家福)', UserTurnContent(
                      text: '让 @deploy-bot 按 @发布手册 检查这两份材料',
                      mentions: const [
                        MentionSnapshot(type: 'agent', id: 'ag_1', name: 'deploy-bot'),
                        MentionSnapshot(type: 'document', id: 'doc_1', name: '发布手册'),
                      ],
                      attachments: const [
                        UserAttachment(id: 'a', kind: 'document', filename: 'Q3-financial-report.pdf', sizeBytes: 1258291),
                        UserAttachment(id: 'b', kind: 'video', filename: 'demo-walkthrough.mp4', sizeBytes: 25270026),
                      ],
                    )),
                    row('降级态(已删 / 失败重试 / 超大图)', UserTurnContent(
                      text: '这些文件呢?',
                      attachments: [
                        const UserAttachment(id: 'a', kind: 'document', filename: 'deleted-report.pdf', state: AnAttachmentState.missing),
                        UserAttachment(id: 'b', kind: 'document', filename: 'flaky-network.docx', sizeBytes: 88123, state: AnAttachmentState.failed, onTap: () {}),
                        UserAttachment(id: 'c', kind: 'image', filename: 'huge-scan.png', sizeBytes: 48234567, state: AnAttachmentState.oversized, onTap: () {}),
                      ],
                    )),
                  ],
                ),
              ),
            );
          }),
        ),
      ),
    ));
    // Let the MemoryImages decode (engine-async) then settle a frame. 让图解码(引擎异步)再落帧。
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 150)));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 60));

    late final Uint8List bytes;
    await tester.runAsync(() async {
      final boundary = tester.renderObject<RenderRepaintBoundary>(find.byKey(key));
      final image = await boundary.toImage(pixelRatio: 2.0);
      final png = await image.toByteData(format: ui.ImageByteFormat.png);
      bytes = png!.buffer.asUint8List();
      image.dispose();
    });
    Directory('test/dev/out').createSync(recursive: true);
    File('test/dev/out/user_turn.png').writeAsBytesSync(bytes);
  });
}
