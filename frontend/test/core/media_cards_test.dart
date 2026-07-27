import 'package:anselm/core/contract/attachment.dart';
import 'package:anselm/core/design/theme.dart';
import 'package:anselm/core/media/media_cards.dart';
import 'package:anselm/core/media/attachment_image_provider.dart';
import 'package:anselm/core/ui/an_attachment_card.dart';
import 'package:anselm/core/media/media_video.dart';
import 'package:anselm/core/net/api_client.dart';
import 'package:anselm/core/media/media_source.dart';
import 'package:anselm/i18n/strings.g.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';

// The one card family (WRK-082 批B' 不变量④): dispatch comes from the attachment ROW's mime, a
// payload with no refs costs nothing, an unreadable row is said out loud, and a non-image artifact
// falls back to the file card instead of a broken image.
//
// 一族卡(批B' 不变量④):按**附件行**的 mime 分发;无引用的 payload 零代价;读不到的行明说;非图产物
// 回落文件卡而不是破图。
const _id = 'att_00112233445566aa';
const _receipt =
    '{"attachmentId":"$_id","mime":"image/png","source":"generate_image",'
    '"width":1536,"height":1024}';

class _StubSource implements MediaSource {
  const _StubSource(this._meta);
  final AttachmentMeta _meta;

  @override
  Future<AttachmentMeta> meta(String id) async => _meta;

  // Bytes are never fetched in these tests — a decode would need a real image and a real frame.
  // 本测试从不取字节——解码需要真图与真帧。
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
                child: SizedBox(width: 560, child: child),
              ),
            ),
          ),
        ),
      ),
    );

void main() {
  _batteryTests();
  _videoTests();
  setUpAll(() => LocaleSettings.setLocaleRaw('zh-CN'));

  testWidgets('a payload with no refs renders nothing at all', (tester) async {
    await tester.pumpWidget(
      _host(const AnMediaRefStrip(payload: {'out': 'plain result'})),
    );
    expect(find.byType(AnMediaRefCard), findsNothing);
    // And the spread form contributes no slot — the gapped-host contract.
    // 展开形也不占槽位——带间距宿主的契约。
    expect(AnMediaRefStrip.forPayload({'out': 'plain result'}), isEmpty);
  });

  testWidgets(
    'an image row renders the artifact, a meta line proves the chain',
    (tester) async {
      await tester.pumpWidget(
        _host(
          const AnMediaRefStrip(payload: {'text': _receipt}),
          overrides: [
            mediaSourceProvider.overrideWithValue(
              const _StubSource(
                AttachmentMeta(
                  id: _id,
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
      await tester.pump(); // meta future / 元数据落定
      expect(find.byType(AnMediaRefCard), findsOneWidget);
      expect(find.textContaining('generated-x.png'), findsWidgets);
      expect(find.textContaining('1536×1024'), findsWidgets);
    },
  );

  testWidgets('a non-image artifact falls back to the file card', (
    tester,
  ) async {
    await tester.pumpWidget(
      _host(
        const AnMediaRefStrip(payload: {'text': _receipt}),
        overrides: [
          mediaSourceProvider.overrideWithValue(
            const _StubSource(
              AttachmentMeta(
                id: _id,
                filename: 'voice.mp3',
                mimeType: 'audio/mpeg',
                sizeBytes: 2048,
                kind: 'audio',
              ),
            ),
          ),
        ],
      ),
    );
    await tester.pump();
    // The ROW's mime decides — the receipt claimed image/png and must lose.
    // 由**行**的 mime 决定——receipt 自称 image/png,必须输。
    expect(find.text('voice.mp3'), findsOneWidget);
    expect(find.byType(Image), findsNothing);
  });

  testWidgets('an unreadable row is said out loud, never a broken image', (
    tester,
  ) async {
    await tester.pumpWidget(
      _host(
        const AnMediaRefStrip(payload: {'text': _receipt}),
        overrides: [
          mediaSourceProvider.overrideWithValue(const _FailingSource()),
        ],
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    // WORDS, not the raw id — this asserted `findsWidgets` on the att_ id until 2026-07-27, which
    // pinned exactly the behaviour that leaked an internal identifier at the user (WRK-082 H6).
    // The id survives as the semantics anchor, which is where a machine wants it and a person does not.
    // **人话,不是裸 id**——本断言在 2026-07-27 之前钉的是「找得到 att_ id」,而那恰好钉住了「把内部标识
    // 漏给用户」这个行为(H6)。id 作为 semantics 锚点仍在,那正是机器要它、而人不要它的地方。
    expect(find.textContaining(_id), findsNothing);
    expect(find.text('已不可用'), findsOneWidget);
    expect(find.byType(Image), findsNothing);
  });

  testWidgets('many refs render as the family, capped and keyed by id', (
    tester,
  ) async {
    const hex = '0123456789abcdef';
    final payload = {
      'items': [
        for (var i = 0; i < 12; i++)
          {'attachmentId': 'att_00112233445566${hex[i % 16]}0'},
      ],
    };
    await tester.pumpWidget(
      _host(
        AnMediaRefStrip(payload: payload),
        overrides: [
          mediaSourceProvider.overrideWithValue(
            const _StubSource(
              AttachmentMeta(
                id: _id,
                filename: 'f.bin',
                mimeType: 'application/octet-stream',
                kind: 'other',
              ),
            ),
          ),
        ],
      ),
    );
    await tester.pump();
    expect(find.byType(AnMediaRefCard), findsNWidgets(8));
  });
}

class _FailingSource implements MediaSource {
  const _FailingSource();

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

// --- inline video (WRK-082 H5.5) --------------------------------------------

void _videoTests() {
  testWidgets(
    'a video artifact renders the inline player card, NOT the file card',
    (tester) async {
      await tester.pumpWidget(
        _host(
          const AnMediaRefStrip(payload: {'text': _receipt}),
          overrides: [
            mediaSourceProvider.overrideWithValue(
              const _StubSource(
                AttachmentMeta(
                  id: _id,
                  filename: 'clip.mp4',
                  mimeType: 'video/mp4',
                  sizeBytes: 2491742,
                  kind: 'video',
                ),
              ),
            ),
          ],
        ),
      );
      await tester.pump();
      expect(find.byType(AnVideoCard), findsOneWidget);
      expect(find.byType(AnAttachmentCard), findsNothing);
      expect(find.textContaining('clip.mp4'), findsWidgets);
    },
  );

  // THE load-bearing guard of this batch. `Player()` reaches into libmpv, which does not exist in
  // a widget test — so if the card ever built one eagerly, this test would not "fail an
  // assertion", it would CRASH. That it renders at all is the assertion: ten clips scrolled past
  // in a transcript start zero native players.
  //
  // 本批**承重**的守卫。`Player()` 要伸到 libmpv,而 widget test 里根本没有它——故这张卡若哪天急切地
  // 构造了一个,本测试不会「断言失败」,它会**崩**。**它能渲出来**这件事本身就是断言:transcript 里
  // 滚过十段片子,起零个原生播放器。
  testWidgets('the video card builds no native player until it is tapped', (
    tester,
  ) async {
    await tester.pumpWidget(
      _host(
        const AnMediaRefStrip(payload: {'text': _receipt}),
        overrides: [
          mediaSourceProvider.overrideWithValue(
            const _StubSource(
              AttachmentMeta(
                id: _id,
                filename: 'clip.mp4',
                mimeType: 'video/mp4',
                sizeBytes: 2491742,
                kind: 'video',
              ),
            ),
          ),
        ],
      ),
    );
    await tester.pump();
    expect(find.byType(AnVideoCard), findsOneWidget);
    // Now dispose the whole subtree. A player created off-screen — or leaked in dispose() —
    // surfaces as a native call here too. Overrides must stay identical: Riverpod forbids changing
    // their COUNT between pumps, and swapping in an override-free host fails for that reason
    // rather than for the reason under test.
    // 现在销毁整棵子树。一个在屏外被创建、或在 dispose() 里泄漏的 player,同样会在这里暴露成原生调用。
    // overrides 必须保持一致:Riverpod 禁止两次 pump 之间改变它们的**数量**,换成一个没有 override 的
    // host 会因**那个**理由失败,而不是因为被测的那个理由。
    await tester.pumpWidget(
      _host(
        const SizedBox.shrink(),
        overrides: [
          mediaSourceProvider.overrideWithValue(
            const _StubSource(
              AttachmentMeta(
                id: _id,
                filename: 'clip.mp4',
                mimeType: 'video/mp4',
                sizeBytes: 2491742,
                kind: 'video',
              ),
            ),
          ),
        ],
      ),
    );
    await tester.pump();
    expect(find.byType(AnVideoCard), findsNothing);
    expect(tester.takeException(), isNull);
  });
}

// --- the batteries the matrix was missing (迭代铁律④, WRK-082 H6) ---------------
//
// The file had empty / unreadable / many-refs but not 超长 / 极值 / 注入. Those three are exactly
// where a media card meets data it did not author: filenames come from providers and from user
// code, sizes come from whatever landed, and neither is sanitized on the way in.
//
// 本文件此前有 空 / 读不到 / 海量,却没有**超长 / 极值 / 注入**。而那三样恰恰是媒体卡遇到「不是自己
// 写的数据」的地方:文件名来自上游、也来自用户代码,大小来自落进来的任何东西,两者在入口处都没被消毒。
void _batteryTests() {
  Widget hostFor(AttachmentMeta meta) => _host(
    const AnMediaRefStrip(payload: {'text': _receipt}),
    overrides: [mediaSourceProvider.overrideWithValue(_StubSource(meta))],
  );

  testWidgets('超长 — an absurd filename does not overflow the card', (
    tester,
  ) async {
    await tester.pumpWidget(
      hostFor(
        AttachmentMeta(
          id: _id,
          filename: '${'とてもながいファイル名' * 40}.png',
          mimeType: 'image/png',
          sizeBytes: 1234,
          kind: 'image',
        ),
      ),
    );
    await tester.pump();
    expect(tester.takeException(), isNull);
  });

  testWidgets('极值 — zero bytes and an absurd size both render', (tester) async {
    for (final size in <int>[0, 9007199254740991]) {
      await tester.pumpWidget(
        hostFor(
          AttachmentMeta(
            id: _id,
            filename: 'edge.mp4',
            mimeType: 'video/mp4',
            sizeBytes: size,
            kind: 'video',
          ),
        ),
      );
      await tester.pump();
      expect(tester.takeException(), isNull, reason: 'sizeBytes=$size');
    }
  });

  testWidgets('注入 — markup in a filename is text, never markup', (
    tester,
  ) async {
    const hostile = '<script>alert(1)</script>![x](http://evil/x.png)';
    await tester.pumpWidget(
      hostFor(
        const AttachmentMeta(
          id: _id,
          filename: hostile,
          mimeType: 'image/png',
          sizeBytes: 10,
          kind: 'image',
        ),
      ),
    );
    await tester.pump();
    expect(tester.takeException(), isNull);
    // Rendered as literal text — no markdown pass. The ONE image present is the attachment's own,
    // sourced from the id through AttachmentImageProvider; the `![x](http://evil/x.png)` inside the
    // filename summons nothing, because a filename is never a source. A provider chooses these
    // strings, so the card must never let one become markup or a fetch.
    // 按**字面文本**渲、不过 markdown。在场的**那一张**图是附件自己的,经 AttachmentImageProvider 按 id
    // 取;文件名里那段 `![x](http://evil/x.png)` **召唤不出任何东西**,因为文件名从来不是图源。这些字符串
    // 是上游选的,故卡片绝不能让其中之一变成标记、或变成一次抓取。
    expect(find.textContaining('<script>'), findsWidgets);
    final images = tester.widgetList<Image>(find.byType(Image)).toList();
    expect(images, hasLength(1));
    expect(images.single.image, isA<AttachmentImageProvider>());
  });

  testWidgets('注入 — a hostile MIME does not pick a renderer', (tester) async {
    // The family dispatches on the ROW's mime, so a lying mime is the one input that could send an
    // artifact down the wrong branch. `image/png; charset=<script>` must not read as an image.
    // 一族卡按**行的 mime** 分发,故一个撒谎的 mime 是唯一可能把产物送错分支的输入。
    // `image/png; charset=<script>` 不得被读成图像。
    await tester.pumpWidget(
      hostFor(
        const AttachmentMeta(
          id: _id,
          filename: 'x.bin',
          mimeType: 'application/octet-stream; x=image/png',
          sizeBytes: 10,
          kind: 'other',
        ),
      ),
    );
    await tester.pump();
    expect(tester.takeException(), isNull);
    expect(find.byType(Image), findsNothing);
    expect(find.byType(AnVideoCard), findsNothing);
  });
}
