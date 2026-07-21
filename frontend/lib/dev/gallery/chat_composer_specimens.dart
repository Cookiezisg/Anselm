import 'package:flutter/material.dart';

import '../../core/design/tokens.dart';
import '../../core/ui/ui.dart';
import 'specimen.dart';

// The chat composer (AnComposer) in its states — dev-only strings, i18n-exempt (like the rest of the
// catalog). INTERACTIVE: click into any box to see the accent focus halo, type to watch the pill↔card
// morph. The send/stop glyph is the host's call (the primitive just renders `trailing`), so each state
// passes the right one: none (empty), send ↑ (has text), stop (generating). No specimen auto-focuses — a
// focused TextField blinks its caret forever, which would hang the matrix test's pumpAndSettle.
//
// 聊天发送框各态。dev 明文串豁免 i18n。可交互:点入见 accent 聚焦光环、打字看药丸↔卡片演变。send/stop 由宿主定
// (原语只渲 trailing),故每态给对的那个:空=无 / 有字=send↑ / 生成中=stop。无 specimen 自动聚焦(聚焦的输入框
// 光标永远闪 → 挂死 matrix 的 pumpAndSettle)。

const double _composerW =
    560; // narrowed toward the 720 reading column feel for the gallery cell 逼近阅读列观感

final GalleryItem chatComposerGalleryItem = GalleryItem(
  'AnComposer 发送框',
  '演变输入:单行药丸 ↔ 多行卡片 · @/📎 · send↔stop · 聚焦 accent 光环 · landing 浮起',
  [
    GallerySpecimen(
      '空态 · 单行药丸 (send 藏)',
      (_) => const _ComposerSpecimen(),
      span: true,
      maxWidth: _composerW,
    ),
    GallerySpecimen(
      '聚焦看光环 (点进去↑)',
      (_) => const _ComposerSpecimen(hint: '点这里 → 看 accent 光环'),
      span: true,
      maxWidth: _composerW,
    ),
    GallerySpecimen(
      '有字 · 单行 (send ↑)',
      (_) => const _ComposerSpecimen(seed: '帮我看下这个 workflow 为什么失败', send: true),
      span: true,
      maxWidth: _composerW,
    ),
    GallerySpecimen(
      '多行 · 卡片 reflow',
      (_) => const _ComposerSpecimen(
        seed: '第一行……\n第二行,继续写更多内容,看它换行后钮组落到下面一排、圆角从药丸渐变到卡片\n第三行',
        send: true,
      ),
      span: true,
      maxWidth: _composerW,
    ),
    GallerySpecimen(
      '生成中 · stop',
      (_) => const _ComposerSpecimen(generating: true),
      span: true,
      maxWidth: _composerW,
    ),
    GallerySpecimen(
      '带附件条',
      (_) => const _ComposerSpecimen(
        seed: '看下这两个文件',
        send: true,
        attachments: true,
      ),
      span: true,
      maxWidth: _composerW,
    ),
    GallerySpecimen(
      'landing · 浮起药丸',
      (_) => const _ComposerSpecimen(floating: true, hint: '下午好 · 今天想做点什么?'),
      span: true,
      maxWidth: _composerW,
    ),
    GallerySpecimen(
      '超长 URL 不撑破',
      (_) => const _ComposerSpecimen(
        seed:
            'https://example.com/a/really/really/long/url/that/must/wrap/inside/the/box/not/blow/it/out?x=1&y=2',
        send: true,
      ),
      stress: true,
      span: true,
      maxWidth: _composerW,
    ),
  ],
);

class _ComposerSpecimen extends StatefulWidget {
  const _ComposerSpecimen({
    this.seed = '',
    this.hint = '问点什么…',
    this.send = false,
    this.generating = false,
    this.attachments = false,
    this.floating = false,
  });

  final String seed;
  final String hint;
  final bool send;
  final bool generating;
  final bool attachments;
  final bool floating;

  @override
  State<_ComposerSpecimen> createState() => _ComposerSpecimenState();
}

class _ComposerSpecimenState extends State<_ComposerSpecimen> {
  late final TextEditingController _ctrl = TextEditingController(
    text: widget.seed,
  );
  final FocusNode _focus = FocusNode();

  @override
  void dispose() {
    _ctrl.dispose();
    _focus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Key the trailing so AnComposer's AnimatedSwitcher cross-fades send↔stop (not a hard swap),
    // and keep it the SAME control tier as lead (lg + primary round — the product arrangement) — a
    // taller trailing popping in would grow the whole box. trailing 加 key + 与 lead 同档(lg,产品排布:
    // 实心墨圆)——异档 trailing 出现会撑高整盒。
    final Widget? trailing = widget.generating
        ? AnButton.iconOnly(
            AnIcons.stop,
            variant: AnButtonVariant.primary,
            round: true,
            size: AnButtonSize.lg,
            semanticLabel: '停止',
            onPressed: () {},
            key: const ValueKey('stop'),
          )
        : widget.send
        ? AnButton.iconOnly(
            AnIcons.send,
            variant: AnButtonVariant.primary,
            round: true,
            size: AnButtonSize.lg,
            semanticLabel: '发送',
            onPressed: () {},
            key: const ValueKey('send'),
          )
        : null;
    return AnComposer(
      controller: _ctrl,
      focusNode: _focus,
      placeholder: widget.hint,
      floating: widget.floating,
      lead: [
        AnButton.iconOnly(
          AnIcons.mention,
          size: AnButtonSize.lg,
          semanticLabel: '提及',
          onPressed: () {},
        ),
        AnButton.iconOnly(
          AnIcons.attach,
          size: AnButtonSize.lg,
          semanticLabel: '附件',
          onPressed: () {},
        ),
      ],
      trailing: trailing,
      attachments: widget.attachments ? _chips() : null,
    );
  }

  // The REAL pending strip pieces (chip + failed chip) — the gallery must show the true arrangement,
  // not badge stand-ins. 真附件条件(chip+失败 chip)——gallery 展示真排布,不用徽章占位。
  Widget _chips() => Wrap(
    spacing: AnSpace.s6,
    runSpacing: AnSpace.s6,
    children: [
      AnAttachmentChip(
        kind: 'other',
        filename: 'spec.md',
        meta: 'MD · 4.2 KB',
        onRemove: () {},
      ),
      AnAttachmentChip(
        kind: 'image',
        filename: 'screenshot.png',
        meta: '上传中…',
        uploading: true,
        onRemove: () {},
      ),
    ],
  );
}
