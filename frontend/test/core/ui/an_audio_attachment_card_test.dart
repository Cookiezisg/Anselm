import 'package:anselm/core/design/theme.dart';
import 'package:anselm/core/ui/an_audio_attachment_card.dart';
import 'package:anselm/i18n/strings.g.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

// The audio card's STATE LINE — the one line that tells a user what is happening to a clip.
//
// WRK-082 B1 人眼验收查出:`busy` 之下这行说的是「暂不能播放」,而它其实正在正常加载。transcript 在自己的
// 调用处算了 loadingAudio 传进来,generate_speech 工具卡抄了那次调用、漏了它——于是**每一段生成的语音**
// 在加载时都宣布自己坏了。修法是把这一行推到卡里(它本来就收 busy),使两个调用方不可能再走偏。
//
// Found by the B1 human-eye pass: under `busy` this line said "playback not available" while the clip
// was loading perfectly normally. The transcript computed loadingAudio at its call site; the
// generate_speech tool card copied the call and dropped it. The fix derives the line inside the card,
// where `busy` already lives, so the two call sites cannot drift again.
Widget _host(Widget child) => TranslationProvider(
  child: MaterialApp(
    theme: AnTheme.light(),
    home: Scaffold(body: Center(child: child)),
  ),
);

void main() {
  testWidgets('busy says LOADING, not "not available"', (tester) async {
    await tester.pumpWidget(
      _host(
        AnAudioAttachmentCard(
          filename: 'read-aloud.wav',
          metaLine: '280 KB',
          busy: true,
          onPlayTap: () {},
        ),
      ),
    );
    expect(find.text('Loading audio…'), findsOneWidget);
    expect(find.text('Playback not available yet'), findsNothing);
  });

  testWidgets('an explicit statusLine still wins over the busy line', (
    tester,
  ) async {
    // The caller knows more than the card when it bothers to say so — the transcript uses this to
    // report playback failures and media preparation. 调用方开口时它知道得更多。
    await tester.pumpWidget(
      _host(
        AnAudioAttachmentCard(
          filename: 'read-aloud.wav',
          metaLine: '280 KB',
          busy: true,
          statusLine: 'Preparing media…',
          onPlayTap: () {},
        ),
      ),
    );
    expect(find.text('Preparing media…'), findsOneWidget);
    expect(find.text('Loading audio…'), findsNothing);
  });

  testWidgets('with no play action it is genuinely not playable, and says so', (
    tester,
  ) async {
    // The pre-existing meaning of that line is preserved: no onPlayTap = there is no playback here.
    // 那行原本的含义不变:没有 onPlayTap = 这里根本没有播放这回事。
    await tester.pumpWidget(
      _host(
        const AnAudioAttachmentCard(
          filename: 'read-aloud.wav',
          metaLine: '280 KB',
        ),
      ),
    );
    expect(find.text('Playback not available yet'), findsOneWidget);
  });

  testWidgets('idle playable card shows its meta line', (tester) async {
    await tester.pumpWidget(
      _host(
        AnAudioAttachmentCard(
          filename: 'read-aloud.wav',
          metaLine: '280 KB',
          durationLabel: '0:12',
          onPlayTap: () {},
        ),
      ),
    );
    expect(find.text('280 KB'), findsOneWidget);
    expect(find.text('0:12'), findsOneWidget);
  });
}
