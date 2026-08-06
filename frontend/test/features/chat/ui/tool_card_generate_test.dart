import 'dart:async';

import 'package:anselm/core/contract/attachment.dart';
import 'package:anselm/core/contract/messages/block_content.dart';
import 'package:anselm/core/net/api_client.dart';
import 'package:anselm/core/media/media_source.dart';
import 'package:anselm/core/media/media_video.dart';
import 'package:anselm/core/design/theme.dart';
import 'package:anselm/core/messages/block_tree_reducer.dart';
import 'package:anselm/features/chat/model/tool_receipts.dart';
import 'package:anselm/features/chat/data/chat_fixtures.dart';
import 'package:anselm/features/chat/data/chat_providers.dart';
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

const _editReceipt =
    '{"attachmentId":"att_8899aabbccddeeff","filename":"edited-x.png",'
    '"mime":"image/png","sizeBytes":2345,"provider":"anselm","aspect":"portrait",'
    '"sourceAttachmentId":"att_0011223344556677","source":"edit_image",'
    '"width":720,"height":1280}';

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

BlockNode _settledEditCall() {
  final node = BlockNode(id: 'tc_edit_image', kind: BlockKind.toolCall)
    ..status = 'completed'
    ..content = {
      'name': 'edit_image',
      'arguments':
          '{"attachmentId":"att_0011223344556677","prompt":"make it night","aspect":"portrait"}',
    };
  node.children.add(
    BlockNode(id: 'tr_edit_image', kind: BlockKind.toolResult)
      ..status = 'completed'
      ..content = {'content': _editReceipt},
  );
  return node;
}

BlockNode _settledSpeechCall() {
  final node = BlockNode(id: 'tc_speech', kind: BlockKind.toolCall)
    ..status = 'completed'
    ..content = {
      'name': 'generate_speech',
      'arguments': '{"text":"A short acceptance clip"}',
    };
  node.children.add(
    BlockNode(id: 'tr_speech', kind: BlockKind.toolResult)
      ..status = 'completed'
      ..content = {
        'content':
            '{"attachmentId":"att_0011223344556677","filename":"generated-x.wav",'
            '"mime":"audio/wav","sizeBytes":4096,"provider":"anselm",'
            '"characters":24,"source":"generate_speech","durationMs":1250}',
      },
  );
  return node;
}

BlockNode _settledVideoCall() {
  final node = BlockNode(id: 'tc_video', kind: BlockKind.toolCall)
    ..status = 'completed'
    ..content = {
      'name': 'generate_video',
      'arguments': '{"prompt":"a lighthouse at dusk","aspect":"portrait"}',
    };
  node.children.add(
    BlockNode(id: 'tr_video', kind: BlockKind.toolResult)
      ..status = 'completed'
      ..content = {
        'content':
            '{"attachmentId":"att_0011223344556677","filename":"generated-x.mp4",'
            '"mime":"video/mp4","sizeBytes":4096,"provider":"anselm",'
            '"seconds":5,"aspect":"portrait","source":"generate_video"}',
      },
  );
  return node;
}

BlockNode _settledAnimatedImageCall() {
  final node = BlockNode(id: 'tc_animate_image', kind: BlockKind.toolCall)
    ..status = 'completed'
    ..content = {
      'name': 'animate_image',
      'arguments':
          '{"attachmentId":"att_0011223344556677","prompt":"slow push in","seconds":5}',
    };
  node.children.add(
    BlockNode(id: 'tr_animate_image', kind: BlockKind.toolResult)
      ..status = 'completed'
      ..content = {
        'content':
            '{"attachmentId":"att_ffeeddccbbaa0099","filename":"animated-x.mp4",'
            '"mime":"video/mp4","sizeBytes":4096,"provider":"anselm",'
            '"seconds":5,"sourceAttachmentId":"att_0011223344556677",'
            '"source":"animate_image"}',
      },
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
    expect(r.filename, 'generated-x.png');
    expect(r.sizeBytes, 1234);
    expect(r.width, 1536);
    expect(r.height, 1024);
    expect(r.provider, 'openai');
    expect(r.model, 'gpt-image-2');
    expect(r.source, 'generate_image');
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

  test('parseGeneratedImage accepts edit_image without losing lineage', () {
    final r = parseGeneratedImage(_editReceipt);
    expect(r, isNotNull);
    expect(r!.source, 'edit_image');
    expect(r.aspect, 'portrait');
    expect(r.sourceAttachmentId, 'att_0011223344556677');
    expect(r.width, 720);
    expect(r.height, 1280);
  });

  testWidgets(
    'edit_image uses the shared image card and keeps portrait geometry',
    (tester) async {
      final source = _DelayedMedia(
        AttachmentMeta(
          id: 'att_8899aabbccddeeff',
          filename: 'edited-x.png',
          mimeType: 'image/png',
          sizeBytes: 2345,
          kind: 'image',
        ),
      );
      await tester.pumpWidget(
        _host(
          ChatToolCard(node: _settledEditCall()),
          overrides: [
            chatRepositoryProvider.overrideWithValue(FixtureChatRepository()),
            mediaSourceProvider.overrideWithValue(source),
          ],
        ),
      );

      expect(find.textContaining('已改图'), findsOneWidget);
      expect(find.textContaining('已存为改图附件 · 720×1280'), findsOneWidget);
      await tester.tap(find.textContaining('已改图'), warnIfMissed: false);
      await tester.pump();
      expect(
        tester.widget<AspectRatio>(find.byType(AspectRatio)).aspectRatio,
        closeTo(9 / 16, 0.001),
      );
      source.complete();
      await tester.pump();
      expect(find.textContaining('edited-x.png'), findsWidgets);
    },
  );

  testWidgets('settled card renders the artifact via the attachment pipeline', (
    tester,
  ) async {
    await tester.pumpWidget(
      _host(
        ChatToolCard(node: _settledCall()),
        overrides: [
          // The body is a thin wrapper over the ONE card family now (H5.5R), so the seam to stub is
          // the PLATFORM media port — not chat's own provider. That the override moved is itself the
          // proof the duplication is gone.
          // 现在体只是**一族卡**的薄包装(H5.5R),故要打桩的缝是**平台**媒体端口、不是 chat 自己的
          // provider。override 换了地方这件事本身,就是重复已消失的证据。
          chatRepositoryProvider.overrideWithValue(FixtureChatRepository()),
          mediaSourceProvider.overrideWithValue(
            const _StubMedia(
              AttachmentMeta(
                id: 'att_0011223344556677',
                filename: 'generated-x.png',
                mimeType: 'image/png',
                sizeBytes: 1234,
                kind: 'image',
              ),
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

  testWidgets(
    'landscape receipt holds its aspect before attachment metadata arrives',
    (tester) async {
      final source = _DelayedMedia(
        AttachmentMeta(
          id: 'att_0011223344556677',
          filename: 'generated-x.png',
          mimeType: 'image/png',
          sizeBytes: 1234,
          kind: 'image',
        ),
      );
      await tester.pumpWidget(
        _host(
          ChatToolCard(node: _settledCall()),
          overrides: [
            chatRepositoryProvider.overrideWithValue(FixtureChatRepository()),
            mediaSourceProvider.overrideWithValue(source),
          ],
        ),
      );

      await tester.tap(find.textContaining('已生成图像'), warnIfMissed: false);
      await tester.pump();

      final placeholder = tester.widget<AspectRatio>(find.byType(AspectRatio));
      expect(placeholder.aspectRatio, closeTo(1.5, 0.001));

      source.complete();
      await tester.pump();
      expect(find.textContaining('generated-x.png'), findsWidgets);
    },
  );

  testWidgets('missing attachment row is said out loud', (tester) async {
    await tester.pumpWidget(
      _host(
        ChatToolCard(node: _settledCall()),
        overrides: [
          chatRepositoryProvider.overrideWithValue(FixtureChatRepository()),
          mediaSourceProvider.overrideWithValue(const _FailingMedia()),
        ],
      ),
    );
    await tester.tap(find.textContaining('已生成图像'), warnIfMissed: false);
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pump(const Duration(milliseconds: 300));
    // WORDS, not the raw id. This asserted on the att_ id until 2026-07-27 — a SECOND copy of the
    // same stale expectation (the first lived in media_cards_test), which is exactly what having two
    // rendering paths cost. One family, one expectation.
    // **人话,不是裸 id**。本断言在 2026-07-27 之前钉的是 att_ id——那是同一条陈旧期望的**第二份拷贝**
    // (第一份在 media_cards_test 里),而这正是「两条渲染路径」的代价。一族卡,一份期望。
    expect(find.textContaining('att_0011223344556677'), findsNothing);
    expect(find.text('已不可用'), findsOneWidget);
  });

  test('parseGeneratedSpeech pins the backend receipt keys and never guesses', () {
    const receipt =
        '{"attachmentId":"att_0011223344556677","filename":"generated-x.wav",'
        '"mime":"audio/wav","sizeBytes":4096,"provider":"qwen","characters":11,'
        '"source":"generate_speech","durationMs":1250,"model":"qwen3-tts-flash"}';
    final r = parseGeneratedSpeech(receipt);
    expect(r, isNotNull);
    expect(r!.attachmentId, 'att_0011223344556677');
    expect(r.mime, 'audio/wav');
    expect(r.filename, 'generated-x.wav');
    expect(r.sizeBytes, 4096);
    expect(r.characters, 11);
    expect(r.durationMs, 1250);
    expect(r.provider, 'qwen');
    expect(r.source, 'generate_speech');

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

  testWidgets(
    'generated speech keeps receipt facts and audio geometry while metadata is pending',
    (tester) async {
      final repo = _DelayedChatRepository(
        const AttachmentMeta(
          id: 'att_0011223344556677',
          filename: 'generated-x.wav',
          mimeType: 'audio/wav',
          sizeBytes: 4096,
          kind: 'audio',
        ),
      );
      await tester.pumpWidget(
        _host(
          ChatToolCard(node: _settledSpeechCall()),
          overrides: [chatRepositoryProvider.overrideWithValue(repo)],
        ),
      );

      await tester.tap(find.textContaining('已合成语音'), warnIfMissed: false);
      await tester.pump();

      expect(find.text('generated-x.wav'), findsOneWidget);
      expect(find.text('正在加载音频…'), findsOneWidget);
      expect(find.text('0:01'), findsOneWidget);
      expect(find.textContaining('att_0011223344556677'), findsNothing);

      repo.complete();
      await tester.pump();
      expect(find.text('generated-x.wav'), findsOneWidget);
      expect(find.text('正在加载音频…'), findsNothing);
      expect(find.text('暂不能播放'), findsNothing);
    },
  );

  testWidgets('generated speech metadata failure is human and retryable', (
    tester,
  ) async {
    await tester.pumpWidget(
      _host(
        ChatToolCard(node: _settledSpeechCall()),
        overrides: [
          chatRepositoryProvider.overrideWithValue(_MissingChatRepository()),
        ],
      ),
    );
    await tester.tap(find.textContaining('已合成语音'), warnIfMissed: false);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.textContaining('att_0011223344556677'), findsNothing);
    expect(find.text('点按重试'), findsOneWidget);
  });

  test(
    'parseGeneratedVideo reports what was MADE, and the three families never cross',
    () {
      const receipt =
          '{"attachmentId":"att_0011223344556677","filename":"generated-x.mp4",'
          '"mime":"video/mp4","sizeBytes":900000,"provider":"google","seconds":8,'
          '"aspect":"landscape","source":"generate_video","model":"veo-3.1-fast-generate-preview"}';
      final r = parseGeneratedVideo(receipt);
      expect(r, isNotNull);
      // `seconds` is the length the route actually produced — a 30-second ask is clamped to the
      // provider's cap, and the receipt must report the clip that exists.
      // `seconds` 是路由**真正做出来**的长度——30 秒的请求会被钳到该家上限,而 receipt 必须报**存在的**那段。
      expect(r!.seconds, 8);
      expect(r.mime, 'video/mp4');
      expect(r.filename, 'generated-x.mp4');
      expect(r.sizeBytes, 900000);
      expect(r.aspect, 'landscape');
      expect(r.provider, 'google');
      expect(r.source, 'generate_video');

      // Three families, three bodies on screen. A crossover would render a video file card where a
      // picture belongs, or an audio player over one.
      // 三族、屏上三种体。串线会在该出图的地方渲出视频文件卡,或在图上盖一个播放器。
      expect(parseGeneratedVideo(_receipt), isNull);
      expect(parseGeneratedImage(receipt), isNull);
      expect(parseGeneratedSpeech(receipt), isNull);
      expect(
        parseGeneratedVideo('{"attachmentId":"att_x","source":"other"}'),
        isNull,
      );
      expect(parseGeneratedVideo(null), isNull);
    },
  );

  test(
    'parseGeneratedVideo accepts animation receipts and preserves lineage',
    () {
      final r = parseGeneratedVideo(
        '{"attachmentId":"att_ffeeddccbbaa0099","source":"animate_image",'
        '"sourceAttachmentId":"att_0011223344556677","seconds":5}',
      );
      expect(r, isNotNull);
      expect(r!.source, 'animate_image');
      expect(r.sourceAttachmentId, 'att_0011223344556677');
      expect(r.seconds, 5);
    },
  );

  testWidgets(
    'generated video holds receipt aspect before attachment metadata arrives',
    (tester) async {
      final source = _DelayedMedia(
        const AttachmentMeta(
          id: 'att_0011223344556677',
          filename: 'generated-x.mp4',
          mimeType: 'video/mp4',
          sizeBytes: 4096,
          kind: 'video',
        ),
      );
      await tester.pumpWidget(
        _host(
          ChatToolCard(node: _settledVideoCall()),
          overrides: [mediaSourceProvider.overrideWithValue(source)],
        ),
      );

      await tester.tap(find.textContaining('已生成视频'), warnIfMissed: false);
      await tester.pump();

      final placeholder = tester.widget<AspectRatio>(find.byType(AspectRatio));
      expect(placeholder.aspectRatio, closeTo(9 / 16, 0.001));

      source.complete();
      await tester.pump();
      expect(find.byType(AnVideoCard), findsOneWidget);
    },
  );

  testWidgets('animate_image uses its dedicated video card grammar', (
    tester,
  ) async {
    final source = _StubMedia(
      const AttachmentMeta(
        id: 'att_ffeeddccbbaa0099',
        filename: 'animated-x.mp4',
        mimeType: 'video/mp4',
        sizeBytes: 4096,
        kind: 'video',
      ),
    );
    await tester.pumpWidget(
      _host(
        ChatToolCard(node: _settledAnimatedImageCall()),
        overrides: [mediaSourceProvider.overrideWithValue(source)],
      ),
    );

    expect(find.textContaining('已让图片动起来'), findsOneWidget);
    await tester.tap(find.textContaining('已让图片动起来'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.byType(AnVideoCard), findsOneWidget);
    expect(find.textContaining('att_'), findsNothing);
  });
}

/// The narrowest MediaSource these card tests need: answer `meta`, never fetch bytes.
/// 这些卡片测试所需的**最窄** MediaSource:答得出 `meta`,从不取字节。
class _StubMedia implements MediaSource {
  const _StubMedia(this._meta);
  final AttachmentMeta _meta;

  @override
  Future<AttachmentMeta> meta(String id) async => _meta;

  @override
  Future<List<int>> bytes(String id) async => const [];

  @override
  NativeFetchTarget nativeTarget(String id) =>
      const NativeFetchTarget(uri: 'http://127.0.0.1:0/stub', headers: {});

  @override
  Future<AttachmentMeta> upload({
    required List<int> bytes,
    required String filename,
    required String mimeType,
  }) async => throw UnimplementedError();

  @override
  Future<bool> readAloudAvailable() async => false;

  @override
  Future<ReadAloudResult> readAloud(String text, {String? voice}) async =>
      throw UnimplementedError();
}

/// A row the app cannot read — the honest-degradation case.
/// 读不到的行——诚实降级那一格。
class _FailingMedia implements MediaSource {
  const _FailingMedia();

  @override
  Future<AttachmentMeta> meta(String id) async => throw Exception('gone');

  @override
  Future<List<int>> bytes(String id) async => throw Exception('gone');

  @override
  NativeFetchTarget nativeTarget(String id) =>
      const NativeFetchTarget(uri: 'http://127.0.0.1:0/stub', headers: {});

  @override
  Future<AttachmentMeta> upload({
    required List<int> bytes,
    required String filename,
    required String mimeType,
  }) async => throw UnimplementedError();

  @override
  Future<bool> readAloudAvailable() async => false;

  @override
  Future<ReadAloudResult> readAloud(String text, {String? voice}) async =>
      throw UnimplementedError();
}

class _DelayedMedia implements MediaSource {
  _DelayedMedia(this._meta);

  final AttachmentMeta _meta;
  final _completer = Completer<AttachmentMeta>();

  void complete() => _completer.complete(_meta);

  @override
  Future<AttachmentMeta> meta(String id) => _completer.future;

  @override
  Future<List<int>> bytes(String id) async => const [];

  @override
  NativeFetchTarget nativeTarget(String id) =>
      const NativeFetchTarget(uri: 'http://127.0.0.1:0/stub', headers: {});

  @override
  Future<AttachmentMeta> upload({
    required List<int> bytes,
    required String filename,
    required String mimeType,
  }) async => throw UnimplementedError();

  @override
  Future<bool> readAloudAvailable() async => false;

  @override
  Future<ReadAloudResult> readAloud(String text, {String? voice}) async =>
      throw UnimplementedError();
}

class _DelayedChatRepository extends FixtureChatRepository {
  _DelayedChatRepository(this._meta);

  final AttachmentMeta _meta;
  final _ready = Completer<void>();

  void complete() => _ready.complete();

  @override
  Future<AttachmentMeta> getAttachment(String id) async {
    await _ready.future;
    return _meta;
  }
}

class _MissingChatRepository extends FixtureChatRepository {
  @override
  Future<AttachmentMeta> getAttachment(String id) async {
    throw StateError('attachment not found: $id');
  }
}
