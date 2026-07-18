import 'package:flutter/widgets.dart';

import '../../../../core/design/colors.dart';
import '../../../../core/design/tokens.dart';
import '../../../../core/design/typography.dart';
import '../../../../core/ui/ui.dart';
import '../../../../i18n/strings.g.dart';
import '../../model/tool_receipts.dart';
import '../tool_card_skins.dart';
import 'stage_frame.dart';
import 'stage_scene.dart';

/// The SKILL stage (WRK-061 §7-9, W5 · reprose WRK-064) — a SKILL.md read as its two natural parts inside
/// ONE bordered prose card: a METADATA HEADER (what the skill can use — context inline|fork, allowedTools
/// as AMBER pills [activation pre-authorizes them past the danger gate, a power grant the user must see],
/// the accepted `arguments`, a «仅人可唤» seal) over a hairline divider, then the instruction body rendered
/// as REAL MARKDOWN ([AnMarkdown], FadeCollapse'd past a height) — the same typeset prose the transcript
/// tool card shows, never a raw `#`/`-` source wall. Streaming bounds to a plain tail (partial markdown
/// renders broken); the settled truth typesets in full.
///
/// skill 舞台(reprose)——SKILL.md 读成两部分、装进**一张**带边散文卡:元数据头(这技能能用什么:context
/// 徽、allowedTools 琥珀药丸[激活预授权免确认=权力让渡必须可见]、接受的 arguments、「仅人可唤」章)+ 细线
/// 分隔 + 指令体**真 markdown 排版**(AnMarkdown,超高 FadeCollapse)——与工具卡同款排版,绝不裸 `#`/`-` 源码墙。
/// 流式退到纯文本尾(半截 markdown 渲染会碎);落定真身全文排版。
class SkillStageBody extends StatelessWidget {
  const SkillStageBody({required this.scene, super.key});

  final StageScene scene;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final t = Translations.of(context);
    final session = scene.session;
    final ctx = session.closedStringAt(['context']);
    final allowed = session.arrayItemsAt(['allowedTools']);
    final args = session.arrayItemsAt(['arguments']);
    final noModel = session.closedValueAt(['disableModelInvocation']) == true;
    final body = session.liveStringNamed('body') ?? '';
    final hasHeader = ctx != null || allowed.isNotEmpty || args.isNotEmpty || noModel;

    return AnWindow(
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
        if (hasHeader) ...[
          // What the skill can use — the header the SKILL.md's frontmatter deserves. 技能能用什么。
          Wrap(spacing: AnSpace.s4, runSpacing: AnSpace.s4, crossAxisAlignment: WrapCrossAlignment.center, children: [
            if (ctx != null) AnChip(ctx == 'fork' ? t.chat.tool.skillFork : t.chat.tool.skillInline, tone: AnTone.none),
            if (noModel) AnChip(t.chat.stage.humanOnly, tone: AnTone.none),
          ]),
          if (allowed.isNotEmpty) ...[
            const SizedBox(height: AnSpace.s6),
            _metaRow(c, t.chat.stage.skillTools, [
              // AMBER — activation pre-authorizes these tools past the danger gate. 琥珀:预授权免确认。
              for (final tool in allowed) AnChip('$tool', tone: AnTone.warn),
            ]),
            Padding(
              padding: const EdgeInsets.only(top: AnSpace.s2),
              child: Text(t.chat.tool.skillPreauth, style: AnText.meta.copyWith(color: c.warn)),
            ),
          ],
          if (args.isNotEmpty) ...[
            const SizedBox(height: AnSpace.s6),
            _metaRow(c, t.chat.stage.skillArgs, [
              for (final a in args) AnChip('\$$a', tone: AnTone.accent),
            ]),
          ],
          if (body.isNotEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: AnSpace.s8),
              child: AnDivider(),
            ),
        ],
        if (body.isNotEmpty)
          // Streaming shows the prose tail face BARE (this card IS the window — leaf law; the head
          // slices its own O(tail)); the settled truth typesets in full. 流式=prose 尾无框脸(本卡即窗,
          // 叶子律;O(tail) 族头内建);落定真 markdown 排版。
          scene.live
              ? AnLiveTail(body, style: AnLiveTailStyle.prose, bare: true)
              : (body.length > AnCap.proseFoldChars || '\n'.allMatches(body).length > AnCap.proseFoldLines)
                  ? AnFadeCollapse(
                      collapsible: true,
                      collapsedHeight: AnSize.proseViewport,
                      expandLabel: t.chat.tool.proseExpand,
                      collapseLabel: t.chat.tool.proseCollapse,
                      fadeColor: c.surface,
                      child: AnMarkdown(body),
                    )
                  : AnMarkdown(body),
      ]),
    );
  }

  // A labelled metadata row: a muted label leading the wrapping chips (tools / arguments). Inline (not a
  // fixed-width column) so a long EN label never mid-word wraps and a short CN one leaves no dead gap.
  // 一行元数据:muted 标签领起换行芯片;内联(非定宽列)——长英文标签不断词、短中文不留空。
  Widget _metaRow(AnColors c, String label, List<Widget> chips) => Wrap(
        spacing: AnSpace.s6,
        runSpacing: AnSpace.s4,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          Text(label, style: AnText.meta.copyWith(color: c.inkFaint)),
          ...chips,
        ],
      );
}

/// The MEMORY stage (WRK-061 §7-10, W5) — the memo slip: a light note card with the slug in its
/// corner, the content filling the slip word by word. The pin is the USER's privilege (REST-only —
/// the stage never renders a pin control; «AI 动不了你的图钉» is the brand). Settle: the closed
/// content rests on the slip + the result bar.
///
/// memory 舞台(W5)——记忆笺:便笺小卡+slug 笺角,content 逐词长满。图钉是用户特权(REST-only,舞台不渲
/// pin 控件——「AI 动不了你的图钉」)。落定:闭合 content 静置+结果条(runStatBarOf)。
class MemoryStageBody extends StatelessWidget {
  const MemoryStageBody({required this.scene, super.key});

  final StageScene scene;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final session = scene.session;
    final slug = session.liveStringNamed('name') ?? session.liveStringNamed('slug') ?? '';
    final content = session.liveStringNamed('content');

    return Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
      AnWindow(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
          if (slug.isNotEmpty)
            Align(
              alignment: Alignment.topRight,
              child: Text(slug, style: AnText.meta.copyWith(color: c.inkFaint)),
            ),
          if (content != null && content.isNotEmpty)
            Text(
              scene.live ? tailLines(content, 12) : content,
              style: AnText.reading.copyWith(color: c.inkMuted),
            ),
        ]),
      ),
      if (!scene.live && !scene.failed) ...[
        const SizedBox(height: AnSpace.s6),
        runStatBarOf(context, scene.state),
      ],
    ]);
  }
}

/// The MCP stage (WRK-061 §7-11, W5) — the wiring site: the nameplate + env KEY pills (values ALWAYS
/// masked ••••), the install's progress rolling in a terminal tail, and the settle payoff — the TOOL
/// SHELF: every discovered tool as a row + «发现 N 个工具» counting up. A failure shows the last
/// error plainly (the stage exhibits; reconnect controls live on the entity page).
///
/// mcp 舞台(W5)——接线现场:铭牌+env **键名**药丸(值恒 ••••)+安装 progress 终端尾;落定=工具货架逐行+
/// 「发现 N 个工具」计数——接驳成功的 payoff。失败如实渲 lastError(操作归实体页)。
class McpStageBody extends StatelessWidget {
  const McpStageBody({required this.scene, super.key});

  final StageScene scene;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final t = Translations.of(context);
    final session = scene.session;
    final name = session.liveStringNamed('name') ?? '';
    final env = session.closedValueAt(['env']);
    final tools = _resultTools();

    return Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
      // icon 沟文法:铭牌·工具行·计数句共用一条 icon 沟(iconSm/iconXs 字形同心)+一条文字列——铭牌名与
      // 工具名落同起点。The icon-gutter grammar: the nameplate, tool rows and count line share ONE gutter
      // (iconSm/iconXs glyphs centred) + ONE text column — nameplate name and tool names start on the同一列。
      stageGutterRow(
        lead: Icon(AnIcons.mcp, size: AnSize.iconSm, color: c.inkMuted),
        child: Text(name,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: AnText.label.weight(AnText.emphasisWeight).copyWith(color: c.ink)),
      ),
      if (env is Map && env.isNotEmpty) ...[
        const SizedBox(height: AnSpace.s4),
        // 假想框律:env 键药丸(裸 chips)归假想框,左缘对齐上方铭牌沟行(X=8)。The imaginary-frame law:
        // the env-key chips (bare chips) join the frame (X=8), aligned under the nameplate gutter row above.
        stageFramed(Wrap(spacing: AnSpace.s4, runSpacing: AnSpace.s4, children: [
          for (final k in env.keys) AnChip('$k ••••', tone: AnTone.none),
        ])),
      ],
      if (scene.live && scene.state.progressText.isNotEmpty) ...[
        const SizedBox(height: AnSpace.s6),
        AnLiveTail(scene.state.progressText),
      ],
      if (!scene.live && !scene.failed) ...[
        if (tools.isNotEmpty) ...[
          const SizedBox(height: AnSpace.s6),
          // No-icon line → the text still lands on the shared text column (empty gutter). 无 icon 行文字落同列。
          stageGutterRow(
            child: Row(children: [
              AnCountUp(tools.length, style: AnText.meta.copyWith(color: c.ok)),
              Text(' ${t.chat.stage.toolsDiscovered}', style: AnText.meta.copyWith(color: c.ok)),
            ]),
          ),
          const SizedBox(height: AnSpace.s2),
          for (final tool in tools.take(12))
            Padding(
              padding: const EdgeInsets.only(bottom: AnSpace.s2),
              child: stageGutterRow(
                lead: Icon(AnIcons.tool, size: AnSize.iconXs, color: c.inkFaint),
                child: Text(tool,
                    maxLines: 1, overflow: TextOverflow.ellipsis, style: AnText.meta.copyWith(color: c.inkMuted)),
              ),
            ),
        ],
        const SizedBox(height: AnSpace.s4),
        runStatBarOf(context, scene.state),
      ],
      if (scene.failed && scene.state.errorText.isNotEmpty) ...[
        const SizedBox(height: AnSpace.s6),
        // No-icon line → the text lands on the shared column (empty gutter), aligned with the shelf. 落同列。
        stageGutterRow(
          child: Text(scene.state.errorText,
              maxLines: 3, overflow: TextOverflow.ellipsis, style: AnText.meta.copyWith(color: c.danger)),
        ),
      ],
    ]);
  }

  List<String> _resultTools() {
    final r = scene.state.resultText;
    final out = <String>[];
    for (final m in RegExp(r'"name"\s*:\s*"([^"]{1,64})"').allMatches(r)) {
      final v = m.group(1)!;
      if (!out.contains(v)) out.add(v);
    }
    // A settled truth render (sceneFromTruth, toolName `create_mcp`) has no tool_result — fall back to the
    // shelf carried in its args session (`tools: [name…]`). GATE on `create_mcp` so a live `mcp__srv__tool`
    // EXECUTION call (same McpStageBody, held live ~1.8s past close) whose own args happen to declare a
    // top-level `tools` param is never mislabelled as「发现的工具」; the live install/reconnect path has no
    // top-level `tools` key and reads its shelf from the result, so neither needs this fallback.
    // 仅 create_mcp 真身渲染走回退(它无 tool_result);活 mcp__ 执行调用的 tools 入参不误标为「发现的工具」。
    if (out.isEmpty && scene.subject.toolName == 'create_mcp') {
      for (final t in scene.session.arrayItemsAt(['tools'])) {
        out.add('$t');
      }
    }
    return out;
  }
}
