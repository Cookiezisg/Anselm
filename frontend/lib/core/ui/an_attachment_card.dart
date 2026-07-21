import 'package:flutter/widgets.dart';

import '../../i18n/strings.g.dart';
import '../design/colors.dart';
import '../design/tokens.dart';
import '../design/typography.dart';
import 'an_interactive.dart';
import 'an_skeleton.dart';
import 'icons.dart';

/// Lifecycle of a sent attachment's surface (card or thumb). The RESOLVER (feature/data layer) decides the
/// state; these primitives only render it. 已发送附件面的生命周期态;解析归数据层,原语只渲。
enum AnAttachmentState {
  /// Metadata still loading → skeleton. 元数据在途→骨架。
  resolving,

  /// Normal render. 正常。
  ready,

  /// 404 / deleted — a terminal tombstone, never interactive. 已删/404,终态不可点。
  missing,

  /// Transient fetch failure — tap retries. 网络失败,点按重试。
  failed,

  /// An image too large to auto-fetch — tap to load (renders as a CARD until loaded). 超大图,点按加载。
  oversized,
}

/// A sent-attachment FILE CARD (chat user bubble): a white island on the bubble's sunken fill — icon tile
/// (28px, `surfaceSunken`, kind glyph in `inkMuted` — neutral, NOT accent: a resting card isn't an action)
/// + filename (body, emphasis weight, ellipsis) + a meta line (TYPE · SIZE, or the state's honest word).
/// Fixed [AnSize.attachCard] width (clamps under tighter parents). Purely presentational: [metaLine] is
/// caller-derived (the pure helper lives in the feature model); [onTap] is honoured for ready (open —
/// e.g. the right island later), failed (retry) and oversized (load) — a missing tombstone swallows it.
///
/// 已发送附件文件卡(用户泡内):白岛浮在泡的凹陷底上——图标格(28px,surfaceSunken 底,kind 字形 inkMuted——
/// 中性非 accent:静止卡不是动作)+ 文件名(body,强调字重,省略)+ meta 行(类型·大小,或状态的诚实文案)。
/// 定宽 attachCard(父更窄时自动收)。纯呈现:metaLine 由调用方推(纯函数在 feature model);onTap 在 ready(打开,
/// 如后续右岛)/failed(重试)/oversized(加载)生效——missing 墓碑吞掉它。
class AnAttachmentCard extends StatelessWidget {
  const AnAttachmentCard({
    required this.kind,
    required this.filename,
    required this.metaLine,
    this.state = AnAttachmentState.ready,
    this.onTap,
    super.key,
  });

  /// Backend attachment kind wire value: image|document|text|audio|video|other. 后端 kind 线缆值。
  final String kind;
  final String filename;

  /// The "TYPE · SIZE" line (caller-derived); ignored for missing/failed/oversized (state text wins).
  /// 「类型·大小」行(调用方推);missing/failed/oversized 时被状态文案取代。
  final String metaLine;
  final AnAttachmentState state;
  final VoidCallback? onTap;

  /// Kind → glyph (the attachment vocabulary of the kit's single icon source). kind→字形(单一图标源)。
  static IconData glyph(String kind) => switch (kind) {
    'image' => AnIcons.image,
    'document' => AnIcons.doc,
    'text' => AnIcons.fileCode,
    'audio' => AnIcons.audio,
    'video' => AnIcons.video,
    _ => AnIcons.file,
  };

  bool get _interactive =>
      onTap != null &&
      (state == AnAttachmentState.ready ||
          state == AnAttachmentState.failed ||
          state == AnAttachmentState.oversized);

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final t = Translations.of(context);
    if (state == AnAttachmentState.resolving) {
      // Bone matches the READY body height (28 tile / two text lines ≈ 35) — an undersized skeleton
      // made the card grow ~5px when metadata landed, a layout shift inside the centre-anchored
      // transcript. 骨架高度对齐 ready 内容(35)——偏矮的骨架在元数据落地时把卡撑高 5px、移动锚定列。
      return _frame(
        c,
        active: false,
        child: const SizedBox(
          height: AnSize.attachBodyH,
          child: Center(child: AnSkeleton.row()),
        ),
      );
    }
    final missing = state == AnAttachmentState.missing;
    final meta = switch (state) {
      AnAttachmentState.missing => t.attach.unavailable,
      AnAttachmentState.failed => t.attach.retry,
      AnAttachmentState.oversized => t.attach.tapToLoad,
      _ => metaLine,
    };
    final body = Row(
      children: [
        // Icon tile: neutral sunken square — kind reads from the glyph + meta text, never colour alone.
        // 图标格:中性凹陷方格——kind 靠字形+meta 文字,不靠色单独。
        Container(
          width: AnSize.control,
          height: AnSize.control,
          decoration: BoxDecoration(
            color: c.surfaceSunken,
            borderRadius: BorderRadius.circular(AnRadius.button),
          ),
          child: Icon(
            missing ? AnIcons.fileMissing : glyph(kind),
            size: AnSize.icon,
            color: c.inkFaint,
          ),
        ),
        const SizedBox(width: AnSpace.s8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                filename,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AnText.body
                    .weight(AnText.emphasisWeight)
                    .copyWith(color: missing ? c.inkFaint : c.ink),
              ),
              Text(
                meta,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AnText.label.copyWith(color: c.inkFaint),
              ),
            ],
          ),
        ),
      ],
    );

    final semantics = '$filename, $meta';
    if (!_interactive) {
      return Semantics(
        label: semantics,
        child: ExcludeSemantics(child: _frame(c, active: false, child: body)),
      );
    }
    return MergeSemantics(
      child: Semantics(
        label: semantics,
        child: AnInteractive(
          onTap: onTap,
          builder: (ctx, states) => ExcludeSemantics(
            child: _frame(ctx.colors, active: states.isActive, child: body),
          ),
        ),
      ),
    );
  }

  Widget _frame(AnColors c, {required bool active, required Widget child}) =>
      Container(
        width: AnSize.attachCard,
        padding: const EdgeInsets.all(AnSpace.s8),
        decoration: BoxDecoration(
          color: active ? c.surfaceHover : c.surface,
          border: Border.all(color: c.line, width: AnSize.hairline),
          borderRadius: BorderRadius.circular(AnRadius.chip),
        ),
        child: child,
      );
}
