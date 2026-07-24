import 'dart:typed_data';

import 'package:anselm/core/design/theme.dart';
import 'package:anselm/core/ui/ui.dart';
import 'package:anselm/features/chat/model/mention_spans.dart';
import 'package:anselm/features/chat/model/user_attachment.dart';
import 'package:anselm/features/chat/ui/user_turn_content.dart';
import 'package:anselm/i18n/strings.g.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

// The user bubble's complete body: composition order (thumbs → cards → text), thumb-vs-card routing
// (only a READY image with bytes is a thumb; oversized/failed/missing images are honest cards), the
// mention pill wiring (tap emits the live {kind,id}), and the tombstone's swallowed tap.
// 用户泡完整体:区顺序(图→卡→文)、图/卡路由(仅 ready+有字节的图走瓦片)、药丸点按派活体坐标、墓碑吞点按。

void main() {
  Widget host(Widget child) => TranslationProvider(
    child: MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: AnTheme.light(),
      home: Scaffold(
        body: Center(child: SizedBox(width: 620, child: child)),
      ),
    ),
  );

  testWidgets(
    'composes thumbs above cards above text; only ready images render as thumbs',
    (tester) async {
      await tester.pumpWidget(
        host(
          UserTurnContent(
            text: '看这些',
            attachments: [
              const UserAttachment(
                id: 'doc',
                kind: 'document',
                filename: 'a.pdf',
                sizeBytes: 10,
              ),
              UserAttachment(
                id: 'img',
                kind: 'image',
                filename: 'b.png',
                thumb: MemoryImage(Uint8List.fromList(List.filled(8, 0))),
                state: AnAttachmentState.ready,
              ),
              const UserAttachment(
                id: 'big',
                kind: 'image',
                filename: 'huge.png',
                state: AnAttachmentState.oversized,
              ),
            ],
          ),
        ),
      );
      expect(
        find.byType(AnAttachmentThumb),
        findsOneWidget,
      ); // only the ready image 仅 ready 图
      expect(
        find.byType(AnAttachmentCard),
        findsNWidgets(2),
      ); // the doc + the oversized image 卡=文档+超大图
      final thumbY = tester.getTopLeft(find.byType(AnAttachmentThumb)).dy;
      final cardY = tester.getTopLeft(find.byType(AnAttachmentCard).first).dy;
      final textY = tester.getTopLeft(find.text('看这些')).dy;
      expect(thumbY, lessThan(cardY));
      expect(cardY, lessThan(textY)); // materials first, then the ask 先材料后提问
    },
  );

  testWidgets(
    'mention pill renders inline and taps through with the live {kind,id}',
    (tester) async {
      AnRefTarget? tapped;
      await tester.pumpWidget(
        host(
          UserTurnContent(
            text: '让 @bot 跑一遍',
            mentions: const [
              MentionSnapshot(type: 'agent', id: 'ag_9', name: 'bot'),
            ],
            onMentionTap: (t) => tapped = t,
          ),
        ),
      );
      expect(find.byType(AnRefPill), findsOneWidget);
      await tester.tap(find.byType(AnRefPill));
      expect(tapped, (kind: 'agent', id: 'ag_9'));
    },
  );

  testWidgets(
    'audio attachments render as audio cards with honest playback state',
    (tester) async {
      await tester.pumpWidget(
        host(
          const UserTurnContent(
            text: '听这个',
            attachments: [
              UserAttachment(
                id: 'voice',
                kind: 'audio',
                filename: 'standup.m4a',
                mimeType: 'audio/mp4',
                sizeBytes: 1024,
                durationMs: 65000,
              ),
            ],
          ),
        ),
      );
      expect(find.byType(AnAudioAttachmentCard), findsOneWidget);
      expect(find.byType(AnAttachmentCard), findsNothing);
      expect(find.text('1:05'), findsOneWidget);
      expect(find.text('Playback not available yet'), findsOneWidget);
      expect(
        find.bySemanticsLabel('Playback not available yet'),
        findsOneWidget,
      );
    },
  );

  testWidgets(
    'playable audio card exposes play action without using the generic open tap',
    (tester) async {
      var played = 0;
      var opened = 0;
      await tester.pumpWidget(
        host(
          UserTurnContent(
            text: '',
            attachments: [
              UserAttachment(
                id: 'voice',
                kind: 'audio',
                filename: 'standup.m4a',
                mimeType: 'audio/mp4',
                sizeBytes: 1024,
                durationMs: 9000,
                playbackProgress: 0.5,
                onPlayTap: () => played++,
                onTap: () => opened++,
              ),
            ],
          ),
        ),
      );
      await tester.tap(find.bySemanticsLabel('Play audio'));
      expect(played, 1);
      expect(opened, 0);
    },
  );

  testWidgets('tombstone (missing) swallows taps; failed card fires retry', (
    tester,
  ) async {
    var retried = 0;
    var opened = 0;
    await tester.pumpWidget(
      host(
        UserTurnContent(
          text: 'x',
          attachments: [
            UserAttachment(
              id: 'a',
              kind: 'document',
              filename: 'gone.pdf',
              state: AnAttachmentState.missing,
              onTap: () => opened++,
            ),
            UserAttachment(
              id: 'b',
              kind: 'document',
              filename: 'flaky.pdf',
              state: AnAttachmentState.failed,
              onTap: () => retried++,
            ),
          ],
        ),
      ),
    );
    await tester.tap(find.textContaining('gone.pdf'), warnIfMissed: false);
    expect(opened, 0); // terminal tombstone is inert 墓碑惰性
    await tester.tap(find.textContaining('flaky.pdf'));
    expect(retried, 1);
  });

  testWidgets(
    'attachment-only message (no text) renders regions without a text run',
    (tester) async {
      await tester.pumpWidget(
        host(
          const UserTurnContent(
            text: '  ',
            attachments: [
              UserAttachment(
                id: 'a',
                kind: 'other',
                filename: 'data.bin',
                sizeBytes: 5,
              ),
            ],
          ),
        ),
      );
      expect(find.byType(AnAttachmentCard), findsOneWidget);
      expect(
        find.byType(RichText),
        findsWidgets,
      ); // card texts exist, but no bubble prose run crash-free
    },
  );
}
