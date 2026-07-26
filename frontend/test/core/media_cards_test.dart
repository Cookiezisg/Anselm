import 'package:anselm/core/contract/attachment.dart';
import 'package:anselm/core/design/theme.dart';
import 'package:anselm/core/media/media_cards.dart';
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
    expect(find.textContaining(_id), findsWidgets);
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
  Future<bool> readAloudAvailable() async => false;

  @override
  Future<ReadAloudResult> readAloud(String text, {String? voice}) async =>
      throw UnimplementedError();
}
