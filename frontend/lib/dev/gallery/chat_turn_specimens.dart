import 'package:flutter/widgets.dart';

import '../../core/design/colors.dart';
import '../../core/design/tokens.dart';
import '../../core/design/typography.dart';
import '../../features/chat/ui/chat_turn.dart';
import 'specimen.dart';

// ChatTurn — the transcript's rhythm atom, shown against the gallery's white cell (= the real white ocean).
// dev-only strings, i18n-exempt (like the rest of the catalog). No focus/animation → matrix-safe.
// Two rhythm values on show: inter-TURN gap = 24 (airy), inter-BLOCK gap within an assistant turn = 12
// (tighter) — a hierarchy so a turn's own blocks group more closely than separate turns.
//
// ChatTurn——transcript 韵律原子,衬在画廊白 cell(=真实白海洋)上。dev 明文串豁免 i18n。无聚焦/动画→matrix 安全。
// 展两档韵律:**轮间距 24**(透气)· **助手轮内块间距 12**(更紧)——层级:一轮自己的块比不同轮之间靠得更近。

const double _turnW = 620;
const double _turnGap = AnSpace.s24; // between turns — the airy value 轮间距(透气档)
const double _blockGap = AnSpace.s12; // between blocks within one assistant turn 轮内块间距(更紧)

TextStyle _ink(BuildContext c) => AnText.body.copyWith(color: c.colors.ink);
Widget _text(BuildContext c, String s) => Text(s, style: _ink(c));

Widget _user(BuildContext c, String s, {bool sending = false}) =>
    ChatTurn(role: ChatRole.user, sending: sending, child: _text(c, s));

Widget _assistant(BuildContext c, List<String> paras) => ChatTurn(
      role: ChatRole.assistant,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (var i = 0; i < paras.length; i++) ...[
            if (i > 0) const SizedBox(height: _blockGap),
            _text(c, paras[i]),
          ],
        ],
      ),
    );

final GalleryItem chatTurnGalleryItem = GalleryItem(
  'ChatTurn 回合韵律',
  '用户泡(右·灰·≤80%) vs 助手裸(左·全宽);轮间距 24 · 轮内块间距 12',
  [
    GallerySpecimen('迷你对话(节奏)', (c) => const _MiniTranscript(), span: true, maxWidth: _turnW),
    GallerySpecimen('用户泡 · 短', (c) => _user(c, '帮我把 sync_inventory 加上失败重试'), span: true, maxWidth: _turnW),
    GallerySpecimen('用户泡 · 长(≤80% 换行)',
        (c) => _user(c, '这个 workflow 昨晚跑到第 3 个节点就失败了,你能不能先帮我看下是哪个 handler 抛的错、再决定要不要加重试'),
        span: true, maxWidth: _turnW),
    GallerySpecimen('用户泡 · 发送中(淡显)', (c) => _user(c, '第 3 次还失败呢?', sending: true), span: true, maxWidth: _turnW),
    GallerySpecimen('助手 · 单段',
        (c) => _assistant(c, const ['好的,我给 sync_inventory 加了指数退避重试——最多 3 次,间隔 1s→2s→4s。']),
        span: true, maxWidth: _turnW),
    GallerySpecimen('助手 · 多段(块间距 12 < 轮间距 24)',
        (c) => _assistant(c, const [
              '失败超过 3 次会抛 SyncError,让上游 workflow 决定是否降级——不再静默吞掉。',
              '要不要我顺手把第 3 次失败自动开一个 issue?那样你早上就能直接看到,不用翻日志。',
            ]),
        span: true, maxWidth: _turnW),
    GallerySpecimen('超长 URL 不撑破',
        (c) => _user(c, 'https://example.com/a/really/really/long/url/that/must/wrap/inside/the/bubble/not/blow/it/out?x=1&y=2&z=3'),
        stress: true, span: true, maxWidth: _turnW),
  ],
);

/// A few turns stacked at the airy inter-turn gap — reads the conversation rhythm (user右泡 → 助手左裸 → …).
/// 几轮以透气轮间距堆叠——读出对话节奏。
class _MiniTranscript extends StatelessWidget {
  const _MiniTranscript();

  @override
  Widget build(BuildContext context) {
    final turns = <Widget>[
      _user(context, '帮我把 sync_inventory 这个 function 加上失败重试'),
      _assistant(context, const ['好的,我给 sync_inventory 加了指数退避重试——最多 3 次,间隔 1s→2s→4s。']),
      _user(context, '第 3 次还失败的话,能不能自动开个 issue?'),
      _assistant(context, const ['可以。我在最后一次失败的分支上挂了 create_issue,标题带上 flowrun id,方便你回溯。']),
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (var i = 0; i < turns.length; i++) ...[
          if (i > 0) const SizedBox(height: _turnGap),
          turns[i],
        ],
      ],
    );
  }
}
