import 'package:anselm/core/contract/attachment.dart';
import 'package:anselm/core/contract/messages/block_content.dart';
import 'package:anselm/core/design/theme.dart';
import 'package:anselm/core/messages/block_tree_reducer.dart';
import 'package:anselm/features/chat/model/tool_receipts.dart';
import 'package:anselm/features/chat/data/chat_fixtures.dart';
import 'package:anselm/features/chat/data/chat_providers.dart';
import 'package:anselm/features/chat/state/attachment_meta.dart';
import 'package:anselm/features/chat/ui/chat_tool_card.dart';
import 'package:anselm/i18n/strings.g.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';

// generate_image card (WRK-082 批B, 代拍 B7): the receipt parser is pinned to the backend's exact
// keys, the settled card renders the artifact THROUGH the attachment pipeline (meta provider), and
// a foreign JSON (right keys, wrong source) yields no receipt — receipts never guess.
// generate_image 卡:回执解析钉后端逐字键;落定卡经附件管线渲产物;键对而 source 不对的 JSON
// 不出回执——回执绝不猜。

const _receipt =
    '{"attachmentId":"att_0011223344556677","filename":"generated-x.png",'
    '"mime":"image/png","sizeBytes":1234,"provider":"openai","aspect":"landscape",'
    '"source":"generate_image","model":"gpt-image-2","width":1536,"height":1024}';

BlockNode _settledCall() {
  final node = BlockNode(id: 'tc_gen', kind: BlockKind.toolCall)
    ..status = 'completed'
    ..content = {
      'name': 'generate_image',
      'arguments': '{"prompt":"a lighthouse at dusk","aspect":"landscape"}',
    };
  node.children.add(
    BlockNode(id: 'tr_gen', kind: BlockKind.toolResult)
      ..status = 'completed'
      ..content = {'content': _receipt},
  );
  return node;
}

Widget _host(Widget child, {List<Override> overrides = const []}) =>
    ProviderScope(
      overrides: overrides,
      child: TranslationProvider(
        child: MediaQuery(
          data: const MediaQueryData(disableAnimations: true),
          child: MaterialApp(
            theme: AnTheme.light(),
            home: Scaffold(
              body: SingleChildScrollView(
                child: SizedBox(width: 560, child: Center(child: child)),
              ),
            ),
          ),
        ),
      ),
    );

void main() {
  setUpAll(() => LocaleSettings.setLocaleRaw('zh-CN'));

  test('parseGeneratedImage pins the backend receipt keys', () {
    final r = parseGeneratedImage(_receipt);
    expect(r, isNotNull);
    expect(r!.attachmentId, 'att_0011223344556677');
    expect(r.mime, 'image/png');
    expect(r.width, 1536);
    expect(r.height, 1024);
    expect(r.provider, 'openai');
    expect(r.model, 'gpt-image-2');
  });

  test('parseGeneratedImage never guesses', () {
    // Right keys, wrong source — a foreign tool echoing similar JSON must not become an image card.
    // 键对 source 不对——别的工具回类似 JSON 不得变成图片卡。
    expect(
      parseGeneratedImage('{"attachmentId":"att_x","source":"other_tool"}'),
      isNull,
    );
    expect(parseGeneratedImage('{"source":"generate_image"}'), isNull);
    expect(parseGeneratedImage('not json'), isNull);
    expect(parseGeneratedImage(null), isNull);
  });

  testWidgets('settled card renders the artifact via the attachment pipeline', (
    tester,
  ) async {
    await tester.pumpWidget(
      _host(
        ChatToolCard(node: _settledCall()),
        overrides: [
          // The fixture repo serves attachment bytes in-process — no dio, no pending timers.
          // fixture 仓进程内供字节——无 dio、无残留计时器。
          chatRepositoryProvider.overrideWithValue(FixtureChatRepository()),
          attachmentMetaProvider('att_0011223344556677').overrideWith(
            (ref) async => const AttachmentMeta(
              id: 'att_0011223344556677',
              filename: 'generated-x.png',
              mimeType: 'image/png',
              sizeBytes: 1234,
              kind: 'image',
            ),
          ),
        ],
      ),
    );
    // Collapsed row: settled verb + receipt with dims. 收起行:落定动词 + 带尺寸回执。
    expect(find.textContaining('已生成图像'), findsOneWidget);
    expect(find.textContaining('已存为附件 · 1536×1024'), findsOneWidget);

    await tester.tap(find.textContaining('已生成图像'), warnIfMissed: false);
    await tester.pump(const Duration(milliseconds: 300)); // expansion / 展开
    await tester.pump(const Duration(milliseconds: 300)); // meta future / 元数据落定

    // The meta line proves the whole chain: parser → catalog → body → attachment meta.
    // (Bytes aren't fetched — that would hit the network; the meta line IS the body's proof.)
    // 元数据行证明整链(字节不真拉——那会打网络;元数据行渲出即体在场之证)。
    expect(find.textContaining('generated-x.png'), findsWidgets);
  });

  testWidgets('missing attachment row is said out loud', (tester) async {
    await tester.pumpWidget(
      _host(
        ChatToolCard(node: _settledCall()),
        overrides: [
          chatRepositoryProvider.overrideWithValue(FixtureChatRepository()),
          attachmentMetaProvider('att_0011223344556677').overrideWith(
            (ref) => Future<AttachmentMeta>.error(Exception('gone')),
          ),
        ],
      ),
    );
    await tester.tap(find.textContaining('已生成图像'), warnIfMissed: false);
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pump(const Duration(milliseconds: 300));
    // The id itself is the honest fallback line — never a broken image widget.
    // id 本身就是诚实兜底行——绝不渲破图。
    expect(find.textContaining('att_0011223344556677'), findsWidgets);
  });

  test('parseGeneratedSpeech pins the backend receipt keys and never guesses', () {
    const receipt =
        '{"attachmentId":"att_0011223344556677","filename":"generated-x.wav",'
        '"mime":"audio/wav","sizeBytes":4096,"provider":"qwen","characters":11,'
        '"source":"generate_speech","model":"qwen3-tts-flash"}';
    final r = parseGeneratedSpeech(receipt);
    expect(r, isNotNull);
    expect(r!.attachmentId, 'att_0011223344556677');
    expect(r.mime, 'audio/wav');
    expect(r.characters, 11);
    expect(r.provider, 'qwen');

    // The IMAGE receipt must not parse as speech and vice versa: the two families put different
    // bodies on screen, and a crossover would render an audio player over a picture.
    // 图像回执不得被当成语音解析、反之亦然:两族在屏上是不同的体,串线会在一张图上渲出播放器。
    expect(parseGeneratedSpeech(_receipt), isNull);
    expect(parseGeneratedImage(receipt), isNull);
    expect(
      parseGeneratedSpeech('{"attachmentId":"att_x","source":"other"}'),
      isNull,
    );
    expect(parseGeneratedSpeech('not json'), isNull);
    expect(parseGeneratedSpeech(null), isNull);
  });
}
