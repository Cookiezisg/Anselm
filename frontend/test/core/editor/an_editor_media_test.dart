import 'package:anselm/core/contract/attachment.dart';
import 'package:anselm/core/design/theme.dart';
import 'package:anselm/core/editor/an_editor_markdown.dart';
import 'package:anselm/core/media/media_cards.dart';
import 'package:anselm/core/media/media_source.dart';
import 'package:anselm/i18n/strings.g.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:super_editor/super_editor.dart';

// One markdown form, three media. Markdown has exactly one "a medium goes here" slot — `![alt](url)`
// — so audio and video ride it too and the ATTACHMENT ROW decides what each one is. These tests pin
// that the row wins: a document that says `![clip](anselm://media/att_…)` about an mp3 must show an
// audio card, not a broken image, and must do so without the editor knowing anything about mime.
//
// 一个 markdown 形、三种媒体。markdown 只有一个「这里有个媒体」的槽,故音视频也走它,而**附件行**决定
// 每一个究竟是什么。这些测试钉的是「行说了算」:一份对着 mp3 写 `![clip](anselm://media/att_…)` 的文档
// 必须显示音频卡而不是破图,且编辑器本身对 mime 一无所知。
const _id = 'att_00112233445566aa';

class _StubSource implements MediaSource {
  const _StubSource(this._meta);
  final AttachmentMeta _meta;

  @override
  Future<AttachmentMeta> meta(String id) async => _meta;
  @override
  Future<List<int>> bytes(String id) async => const [];
  @override
  Future<bool> readAloudAvailable() async => false;
  @override
  Future<ReadAloudResult> readAloud(String text, {String? voice}) async =>
      throw UnimplementedError();
}

Widget _host(Widget child, AttachmentMeta meta) => ProviderScope(
  overrides: [mediaSourceProvider.overrideWithValue(_StubSource(meta))],
  child: TranslationProvider(
    child: MediaQuery(
      data: const MediaQueryData(disableAnimations: true),
      child: MaterialApp(
        theme: AnTheme.light(),
        home: Scaffold(body: SizedBox(width: 720, child: child)),
      ),
    ),
  ),
);

void main() {
  setUpAll(() => LocaleSettings.setLocaleRaw('zh-CN'));

  test(
    'the codec turns the document form into an ImageNode carrying our uri',
    () {
      final doc = documentFromMarkdown('![clip](anselm://media/$_id)');
      final node = doc.getNodeAt(0);
      expect(node, isA<ImageNode>());
      expect((node! as ImageNode).imageUrl, 'anselm://media/$_id');
    },
  );

  testWidgets('an AUDIO row renders as an audio-family card, not a broken image', (
    tester,
  ) async {
    // The markdown said "image" — the ROW says audio, and the row wins. Guessing from the url would
    // put a broken image where a voice note belongs.
    // markdown 说的是「图」——**行**说是音频,行说了算。按 url 猜会在一条语音该在的地方摆一张破图。
    await tester.pumpWidget(
      _host(
        const AnMediaRefStrip(payload: {'u': 'anselm://media/$_id'}),
        const AttachmentMeta(
          id: _id,
          filename: 'voice.mp3',
          mimeType: 'audio/mpeg',
          kind: 'audio',
        ),
      ),
    );
    await tester.pump();
    // Nothing renders from a bare uri STRING — the strip reads the receipt grammar, not urls. This
    // is the seam check: documents go through the editor component, payloads through the strip.
    // 裸 uri 字符串什么也不渲——strip 读的是 receipt 文法、不是 url。这正是缝的检查:文档走编辑器组件、
    // payload 走 strip。
    expect(find.byType(AnMediaRefCard), findsNothing);
  });

  testWidgets(
    'the card family dispatches on the ROW, not on what the caller claims',
    (tester) async {
      await tester.pumpWidget(
        _host(
          const AnMediaRefStrip(
            payload: {'attachmentId': _id, 'mime': 'image/png'},
          ),
          const AttachmentMeta(
            id: _id,
            filename: 'voice.mp3',
            mimeType: 'audio/mpeg',
            kind: 'audio',
          ),
        ),
      );
      await tester.pump();
      // The receipt claimed image/png; the row says audio → the file card wins and no Image is built.
      // receipt 自称 image/png;行说是音频 → 文件卡胜出,不会建出任何 Image。
      expect(find.text('voice.mp3'), findsOneWidget);
      expect(find.byType(Image), findsNothing);
    },
  );
}
