import 'dart:math' as math;

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/design/colors.dart';
import '../../../../core/design/tokens.dart';
import '../../../../core/design/typography.dart';
import '../../../../core/model/byte_format.dart';
import '../../../../core/ui/ui.dart';
import '../../../../i18n/strings.g.dart';
import '../../model/tool_receipts.dart';
import '../../state/stage_truth.dart';
import '../../state/mention_names.dart';
import '../tool_card_document_skill.dart';
import '../tool_card_skins.dart';
import 'stage_scene.dart';

/// The DOCUMENT stage (WRK-061 §7-8, W2 flagship) — the prose curtain: a spine minimap on the left
/// edge inks up as content is dictated, the main window shows the newest lines with `[[id]]` pilled
/// inline. An EDIT fast-forwards through the COMMON PREFIX against the fetched baseline (R-5: content
/// identical to the old version is muted "known truth", the divergence point onward is fresh ink) —
/// computed INCREMENTALLY (each new delta only compares its own span, W0 discipline). Settle:
/// cross-fade to the 1:1 typeset reading state + the honest badge «全量替换 aKB→bKB». Failure keeps
/// the whole unsaved draft scrollable (failed-hold rescue).
///
/// document 舞台(W2 旗舰)——散文幕:左缘书脊随听写着墨,主窗渲最新行([[id]] 内联药丸)。edit 对基线做
/// **前缀快进**(R-5:与旧版一致段=muted 旧真,分叉起才是新墨)——增量计算(每个 delta 只比自己那段)。
/// 落定:cross-fade 成 1:1 排版阅读态+诚实徽「全量替换 aKB→bKB」。失败:整篇未保存草稿可滚可救。
class DocumentStageBody extends ConsumerStatefulWidget {
  const DocumentStageBody({required this.scene, super.key});

  final StageScene scene;

  @override
  ConsumerState<DocumentStageBody> createState() => _DocumentStageBodyState();
}

class _DocumentStageBodyState extends ConsumerState<DocumentStageBody> {
  // Incremental prefix/paragraph bookkeeping (O(delta) per frame, W0). 增量前缀/段界记账。
  int _compared = 0; // chars compared against the baseline so far 已比对字符数
  int _prefixLen = 0; // common prefix length (freezes at divergence) 公共前缀长(分叉即冻)
  bool _diverged = false;
  int _paraScanned = 0;
  final List<int> _paragraphs = [];
  String _baselineKey = ''; // rebuild bookkeeping if the baseline swaps 基线换则重算

  void _advance(String baseline, String content) {
    if (_baselineKey != baseline.length.toString()) {
      _baselineKey = baseline.length.toString();
      _compared = 0;
      _prefixLen = 0;
      _diverged = false;
    }
    if (!_diverged) {
      final limit = math.min(content.length, baseline.length);
      var i = _compared;
      for (; i < limit; i++) {
        if (content.codeUnitAt(i) != baseline.codeUnitAt(i)) {
          _diverged = true;
          break;
        }
      }
      _compared = i;
      _prefixLen = _diverged ? i : _compared;
      if (!_diverged && content.length > baseline.length) _diverged = true; // grew past 旧尾即分叉
    }
    // Paragraph boundaries: scan only the new span for '\n\n'. 段界只扫新段。
    for (var i = math.max(_paraScanned, 1); i < content.length; i++) {
      if (content.codeUnitAt(i) == 0x0a && content.codeUnitAt(i - 1) == 0x0a) _paragraphs.add(i);
    }
    _paraScanned = content.length;
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final t = Translations.of(context);
    final scene = widget.scene;
    final session = scene.session;
    final editId = scene.editTargetId;
    final truth = editId == null ? null : ref.watch(documentTruthProvider(editId));
    final baseline = truth?.asData?.value.content ?? '';

    final content = session.liveStringNamed('content');
    final path = truth?.asData?.value.path ?? '';

    // R-9: an edit whose args never opened `content` is METADATA-ONLY — never fake an empty prose
    // curtain (缺省保留 ≠ 显式清空). R-9:没出现 content 键=只动元数据,不开散文幕。
    if (content == null && !scene.live) {
      return Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
        if (baseline.isNotEmpty) ...[
          AnLayerDiff(oldText: baseline, versionLabel: t.chat.stage.proseUntouched, maxLines: 5),
          const SizedBox(height: AnSpace.s6),
        ],
        runStatBarOf(context, scene.state),
      ]);
    }

    final text = content ?? '';
    if (scene.live) _advance(baseline, text);

    if (scene.live) {
      final fastForwarding = baseline.isNotEmpty && !_diverged && text.isNotEmpty;
      return Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
        if (path.isNotEmpty) ...[
          AnPathChip(path: path),
          const SizedBox(height: AnSpace.s4),
        ],
        if (baseline.isNotEmpty && _diverged && _prefixLen > 0) ...[
          Text(t.chat.stage.prefixKept(n: _prefixLen),
              style: AnText.meta.copyWith(color: c.inkFaint)),
          const SizedBox(height: AnSpace.s4),
        ] else if (fastForwarding) ...[
          Text(t.chat.stage.fastForwarding, style: AnText.meta.copyWith(color: c.inkFaint)),
          const SizedBox(height: AnSpace.s4),
        ],
        // Explicit twin heights instead of stretch/IntrinsicHeight — AnWindow's internal
        // LayoutBuilder cannot answer intrinsic queries (they throw). 双侧显式同高:AnWindow 内有
        // LayoutBuilder,IntrinsicHeight 会炸。
        Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          SizedBox(
            height: AnSize.proseStage,
            child: AnMinimapSpine(
              totalUnits: math.max(baseline.length, text.length),
              inkedUnits: text.length,
              prefixUnits: _prefixLen,
              paragraphOffsets: _paragraphs,
            ),
          ),
          const SizedBox(width: AnSpace.s6),
          Expanded(child: SizedBox(height: AnSize.proseStage, child: _ProseTail(text: text))),
        ]),
      ]);
    }

    if (scene.failed) {
      // The unsaved draft, whole and scrollable — rescue over spectacle. 整篇残稿可滚可救。
      return AnStickViewport(
        maxHeight: AnSize.proseStageFail,
        child: Padding(
          padding: const EdgeInsets.all(AnSpace.s8),
          child: _PilledProse(text: text.isEmpty ? baseline : text),
        ),
      );
    }

    // Settle: the typeset 1:1 reading state + the honest size badge. 落定:排版阅读态+尺寸徽。
    final settled = session.closedStringAt(['content']) ?? text;
    final oldBytes = truth?.asData?.value.sizeBytes ?? baseline.length;
    return Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
      if (path.isNotEmpty) ...[
        AnPathChip(path: path),
        const SizedBox(height: AnSpace.s4),
      ],
      if (settled.isNotEmpty) ProseWindow(markdown: settled),
      const SizedBox(height: AnSpace.s6),
      Row(children: [
        // The whole-replace byte badge only when the content ACTUALLY changed — a pure current-truth render
        // (sceneFromTruth: settled == baseline) is not an edit, so no phantom «X B → Y B». 内容真变才显字节徽。
        if (editId != null && settled != baseline) ...[
          Text(t.chat.stage.wholeReplace(from: formatBytes(oldBytes), to: formatBytes(settled.length)),
              style: AnText.meta.copyWith(color: c.inkFaint)),
          const SizedBox(width: AnSpace.s8),
        ],
        Expanded(child: runStatBarOf(context, scene.state)),
      ]),
    ]);
  }

}

/// Prose with `[[id]]` pilled inline — names resolved through the composer/editor's ONE
/// [MentionSource] seam (`stageMentionNamesProvider`); an unresolved id renders as itself
/// (a missing name is a gap, never a block). The id-set key is computed off the SLICE being
/// rendered (the ~40-line tail while live), so streaming never regex-scans megabytes per frame.
///
/// 散文 + `[[id]]` 内联药丸——名字走 composer/编辑器同一条 [MentionSource] 缝;解析不到渲 id 本身
/// (缺名是缺口,绝不挡路)。id 集键按**被渲切片**算(live 期 ~40 行尾),流式绝不每帧扫兆级正文。
class _PilledProse extends ConsumerWidget {
  const _PilledProse({required this.text});

  final String text;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.colors;
    final key = mentionIdsKeyOf(text);
    final names = key.isEmpty
        ? const <String, String>{}
        : ref.watch(stageMentionNamesProvider(key)).value ?? const <String, String>{};
    final spans = <InlineSpan>[];
    var last = 0;
    for (final m in mentionIdRe.allMatches(text)) {
      if (m.start > last) spans.add(TextSpan(text: text.substring(last, m.start)));
      final id = m.group(1)!;
      spans.add(WidgetSpan(
        alignment: PlaceholderAlignment.middle,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: AnSpace.s4, vertical: 1),
          decoration: BoxDecoration(
            color: c.accentSoft,
            borderRadius: BorderRadius.circular(AnRadius.tag),
          ),
          child: Text(names[id] ?? id, style: AnText.meta.copyWith(color: c.accent)),
        ),
      ));
      last = m.end;
    }
    if (last < text.length) spans.add(TextSpan(text: text.substring(last)));
    return Text.rich(
      TextSpan(children: spans),
      style: AnText.reading.copyWith(color: c.inkMuted),
    );
  }
}

/// The live prose window: the newest ~40 lines, bottom-anchored, [[id]] pilled. 活散文窗:尾 40 行贴底。
class _ProseTail extends StatelessWidget {
  const _ProseTail({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    final tail = tailLines(text, 40);
    return AnWindow(
      child: Align(
        alignment: Alignment.bottomLeft,
        child: ClipRect(
          child: SingleChildScrollView(
            reverse: true, // pinned to the frontier 钉在前沿
            physics: const NeverScrollableScrollPhysics(),
            child: _PilledProse(text: tail),
          ),
        ),
      ),
    );
  }
}
