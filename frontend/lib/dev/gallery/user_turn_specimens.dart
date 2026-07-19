import 'package:flutter/widgets.dart';

import '../../core/ui/ui.dart';
import '../../features/chat/model/mention_spans.dart';
import '../../features/chat/model/user_attachment.dart';
import '../../features/chat/ui/chat_turn.dart';
import '../../features/chat/ui/user_turn_content.dart';
import 'demo_images.dart';
import 'specimen.dart';

// The sent user bubble's COMPLETE body — attachments (real thumbs / file cards, all states) + @mentions
// (AnRefPill at derived positions) + text, composed via UserTurnContent inside ChatTurn. dev-only strings,
// i18n-exempt; the Chinese inside samples is message CONTENT. Images are dev-rasterized (zero network);
// in the matrix they stay resolving (engine-async) — by design, the resolving state IS a real state.
//
// 用户泡完整体——附件(真缩略图/文件卡全态)+ @提及(AnRefPill 推位)+ 文本,经 UserTurnContent 组装进 ChatTurn。
// dev 串豁免;样本中文是消息内容。图为 dev 光栅化(零网络);matrix 里停在 resolving(引擎异步)——有意,resolving 本身是真态。

const double _turnW = 620;

Widget _bubble(Widget child) => ChatTurn(role: ChatRole.user, child: child);

Widget _turn(BuildContext c, {String text = '', List<MentionSnapshot> mentions = const [], List<UserAttachment> attachments = const []}) =>
    _bubble(UserTurnContent(text: text, mentions: mentions, attachments: attachments, onMentionTap: (_) {}));

final GalleryItem userTurnGalleryItem = GalleryItem(
  '用户泡完整体 UserTurnContent',
  '附件(图瓦片/文件卡)在上 · 提及药丸内联 · 文本在下;超大/失败/删除全态诚实',
  [
    GallerySpecimen('单图 + 文本', (c) => DemoImageBuilder(
      builder: (ctx, img) => _turn(ctx,
          text: '这张图里的报表是哪来的?',
          attachments: [UserAttachment(id: 'att_1', kind: 'image', filename: 'report.png', thumb: img, state: img == null ? AnAttachmentState.resolving : AnAttachmentState.ready)]),
    ), span: true, maxWidth: _turnW),
    GallerySpecimen('三图瓦片 + 文本', (c) => DemoImageBuilder(
      seed: 1,
      builder: (ctx, a) => DemoImageBuilder(
        seed: 2,
        builder: (ctx2, b) => DemoImageBuilder(
          seed: 3,
          builder: (ctx3, d) => _turn(ctx3, text: '对比这三张截图', attachments: [
            for (final (i, img) in [a, b, d].indexed)
              UserAttachment(id: 'att_$i', kind: 'image', filename: 'shot_$i.png', thumb: img, state: img == null ? AnAttachmentState.resolving : AnAttachmentState.ready),
          ]),
        ),
      ),
    ), span: true, maxWidth: _turnW),
    GallerySpecimen('文件卡各 kind(pdf/代码/音频/视频/其他)', (c) => _turn(c, text: '帮我过一遍这些材料', attachments: const [
      UserAttachment(id: 'a', kind: 'document', filename: 'Q3-financial-report.pdf', sizeBytes: 1258291),
      UserAttachment(id: 'b', kind: 'text', filename: 'deploy-notes.md', sizeBytes: 8601),
      UserAttachment(id: 'c', kind: 'audio', filename: 'standup-recording.m4a', sizeBytes: 3984588),
      UserAttachment(id: 'd', kind: 'video', filename: 'demo-walkthrough.mp4', sizeBytes: 25270026),
      UserAttachment(id: 'e', kind: 'other', filename: 'dataset.bin', sizeBytes: 13212180),
    ]), span: true, maxWidth: _turnW),
    GallerySpecimen('降级态(解析中/已删/失败/超大图)', (c) => _turn(c, text: '这些文件呢?', attachments: [
      const UserAttachment(id: 'a', kind: 'document', filename: 'loading.pdf', state: AnAttachmentState.resolving),
      const UserAttachment(id: 'b', kind: 'document', filename: 'deleted-report.pdf', state: AnAttachmentState.missing),
      UserAttachment(id: 'c', kind: 'document', filename: 'flaky-network.docx', sizeBytes: 88123, state: AnAttachmentState.failed, onTap: () {}),
      UserAttachment(id: 'd', kind: 'image', filename: 'huge-scan.png', sizeBytes: 48234567, state: AnAttachmentState.oversized, onTap: () {}),
    ]), span: true, maxWidth: _turnW),
    GallerySpecimen('提及 + 附件 + 文本(全家福)', (c) => _turn(c,
      text: '让 @deploy-bot 按 @发布手册 的流程检查这份文件',
      mentions: const [
        MentionSnapshot(type: 'agent', id: 'ag_1', name: 'deploy-bot'),
        MentionSnapshot(type: 'document', id: 'doc_1', name: '发布手册'),
      ],
      attachments: const [UserAttachment(id: 'a', kind: 'document', filename: 'rollout-plan.pdf', sizeBytes: 421000)],
    ), span: true, maxWidth: _turnW),
    GallerySpecimen('提及降级(改名后字面保留 · unavailable)', (c) => _turn(c,
      text: '看下 @旧名字 和 @找不到的 这两个',
      mentions: const [
        MentionSnapshot(type: 'function', id: 'fn_1', name: '新名字'), // renamed source text → literal 原文未含新名→字面
        MentionSnapshot(type: 'function', id: '', name: '找不到的', available: false),
      ],
    ), span: true, maxWidth: _turnW),
    // ── 五电池 five-battery ──
    GallerySpecimen('空(纯文本兜底)', (c) => _turn(c, text: '就一句话'), stress: true, span: true, maxWidth: _turnW),
    GallerySpecimen('超长(200字文件名 + 80字实体名)', (c) => _turn(c,
      text: '看下 @${'实体名超长' * 16} 和这个文件',
      mentions: [MentionSnapshot(type: 'workflow', id: 'wf_1', name: '实体名超长' * 16)],
      attachments: [UserAttachment(id: 'a', kind: 'document', filename: '${'超长文件名' * 40}.pdf', sizeBytes: 1024)],
    ), stress: true, span: true, maxWidth: _turnW),
    GallerySpecimen('海量(6卡 + 8提及一泡)', (c) => _turn(c,
      text: List.generate(8, (i) => '@实体$i').join(' 和 '),
      mentions: [for (var i = 0; i < 8; i++) MentionSnapshot(type: 'function', id: 'fn_$i', name: '实体$i')],
      attachments: [for (var i = 0; i < 6; i++) UserAttachment(id: 'a$i', kind: 'document', filename: 'doc_$i.pdf', sizeBytes: 1000 * (i + 1))],
    ), stress: true, span: true, maxWidth: _turnW),
    GallerySpecimen('极值(0字节 · 无扩展名 · 纯附件无文本)', (c) => _turn(c, attachments: const [
      UserAttachment(id: 'a', kind: 'other', filename: 'empty', sizeBytes: 0),
      UserAttachment(id: 'b', kind: 'document', filename: 'no-ext', mimeType: 'application/pdf', sizeBytes: 12),
    ]), stress: true, span: true, maxWidth: _turnW),
    GallerySpecimen('注入(RTL 覆写/script 文件名/正则元字符实体名)', (c) => _turn(c,
      text: r'调 @a.*b(x) 处理 一下',
      mentions: const [MentionSnapshot(type: 'function', id: 'fn_x', name: r'a.*b(x)')],
      attachments: const [
        UserAttachment(id: 'a', kind: 'document', filename: '"><script>alert(1)</script>.pdf', sizeBytes: 66),
        UserAttachment(id: 'b', kind: 'document', filename: 'evil\u202Efdp.exe', sizeBytes: 66),
      ],
    ), stress: true, span: true, maxWidth: _turnW),
  ],
);
