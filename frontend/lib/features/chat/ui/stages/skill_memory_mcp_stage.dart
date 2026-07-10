import 'package:flutter/widgets.dart';

import '../../../../core/design/colors.dart';
import '../../../../core/design/tokens.dart';
import '../../../../core/design/typography.dart';
import '../../../../core/ui/ui.dart';
import '../../../../i18n/strings.g.dart';
import '../../model/tool_receipts.dart';
import '../tool_card_skins.dart';
import 'stage_scene.dart';

/// The SKILL stage (WRK-061 §7-9, W5) — the binding bench: the nameplate zone (the slug in mono — the
/// ONE ceremonial letter-by-letter spot in the system, identity itself), context inline|fork badge,
/// allowedTools as AMBER-EDGED pills (activation pre-authorizes them past the danger gate — a power
/// grant the user must see), disableModelInvocation as a «仅人可唤» micro-seal, then the body prose
/// with `$ARGUMENTS`/`$1`/`${…}` placeholders as accent slots (the template's bloodline visible).
/// Settle: the slug seal — a name IS the identity, no vN.
///
/// skill 舞台(W5)——装订台:铭牌区(slug mono=全系统唯一逐字仪式处)、context 徽、allowedTools **琥珀细边**
/// 药丸(预授权免确认=权力让渡必须可见)、disableModelInvocation「仅人可唤」微章;body 散文,$ 占位渲
/// accent 空槽(模板血统可见)。落定:slug 印章——名即身份,无 vN。
class SkillStageBody extends StatelessWidget {
  const SkillStageBody({required this.scene, super.key});

  final StageScene scene;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final t = Translations.of(context);
    final session = scene.session;
    final name = session.liveStringNamed('name') ?? '';
    final ctx = session.closedStringAt(['context']);
    final allowed = session.arrayItemsAt(['allowedTools']);
    final noModel = session.closedValueAt(['disableModelInvocation']) == true;
    final body = session.liveStringNamed('body');

    return Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
      AnSunkenPanel(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
          if (name.isNotEmpty)
            Text(name, style: AnText.mono.copyWith(color: c.ink)),
          const SizedBox(height: AnSpace.s4),
          Wrap(spacing: AnSpace.s4, runSpacing: AnSpace.s4, children: [
            if (ctx != null) AnBadge(ctx == 'fork' ? t.chat.tool.skillFork : t.chat.tool.skillInline, tone: AnTone.none),
            for (final tool in allowed)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: AnSpace.s6, vertical: AnSpace.s2),
                decoration: BoxDecoration(
                  border: Border.all(color: c.warn, width: AnSize.hairline),
                  borderRadius: BorderRadius.circular(AnRadius.chip),
                ),
                child: Text('$tool', style: AnText.meta.copyWith(color: c.warn)),
              ),
            if (noModel) AnBadge(t.chat.stage.humanOnly, tone: AnTone.none),
          ]),
        ]),
      ),
      if (body != null && body.isNotEmpty) ...[
        const SizedBox(height: AnSpace.s6),
        AnSunkenPanel(
          child: Align(
            alignment: Alignment.bottomLeft,
            // Live streaming bounds to the tail; a settled truth render shows the FULL body. 落定显全文。
            child: _placeholderText(c, scene.live ? tailLines(body, 12) : body),
          ),
        ),
      ],
      if (!scene.live && !scene.failed) ...[
        const SizedBox(height: AnSpace.s6),
        RunStatBar(state: scene.state),
      ],
    ]);
  }

  // $ARGUMENTS / $1 / ${VAR} placeholders as accent slots. $ 占位渲 accent 槽。
  Widget _placeholderText(AnColors c, String text) {
    final spans = <InlineSpan>[];
    final re = RegExp(r'\$(?:\{[^}]{1,48}\}|[A-Z_]{2,}|\d)');
    var last = 0;
    for (final m in re.allMatches(text)) {
      if (m.start > last) {
        spans.add(TextSpan(text: text.substring(last, m.start), style: AnText.reading.copyWith(color: c.inkMuted)));
      }
      spans.add(WidgetSpan(
        alignment: PlaceholderAlignment.middle,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: AnSpace.s4, vertical: 1),
          decoration: BoxDecoration(color: c.accentSoft, borderRadius: BorderRadius.circular(AnRadius.tag)),
          child: Text(m.group(0)!, style: AnText.meta.copyWith(color: c.accent)),
        ),
      ));
      last = m.end;
    }
    if (last < text.length) {
      spans.add(TextSpan(text: text.substring(last), style: AnText.reading.copyWith(color: c.inkMuted)));
    }
    return Text.rich(TextSpan(children: spans));
  }
}

/// The MEMORY stage (WRK-061 §7-10, W5) — the memo slip: a light note card with the slug in its
/// corner, the content filling the slip word by word. The pin is the USER's privilege (REST-only —
/// the stage never renders a pin control; «AI 动不了你的图钉» is the brand). Settle: the closed
/// content rests on the slip + RunStatBar.
///
/// memory 舞台(W5)——记忆笺:便笺小卡+slug 笺角,content 逐词长满。图钉是用户特权(REST-only,舞台不渲
/// pin 控件——「AI 动不了你的图钉」)。落定:闭合 content 静置+RunStatBar。
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
      Container(
        width: double.infinity,
        padding: const EdgeInsets.all(AnSpace.s12),
        decoration: BoxDecoration(
          color: c.surface,
          border: Border.all(color: c.line, width: AnSize.hairline),
          borderRadius: BorderRadius.circular(AnRadius.button),
        ),
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
        RunStatBar(state: scene.state),
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
      Row(children: [
        Icon(AnIcons.mcp, size: AnSize.iconSm, color: c.inkMuted),
        const SizedBox(width: AnSpace.s4),
        Text(name, style: AnText.label.weight(AnText.emphasisWeight).copyWith(color: c.ink)),
      ]),
      if (env is Map && env.isNotEmpty) ...[
        const SizedBox(height: AnSpace.s4),
        Wrap(spacing: AnSpace.s4, runSpacing: AnSpace.s4, children: [
          for (final k in env.keys) AnBadge('$k ••••', tone: AnTone.none),
        ]),
      ],
      if (scene.live && scene.state.progressText.isNotEmpty) ...[
        const SizedBox(height: AnSpace.s6),
        AnTermTail(text: scene.state.progressText),
      ],
      if (!scene.live && !scene.failed) ...[
        if (tools.isNotEmpty) ...[
          const SizedBox(height: AnSpace.s6),
          Row(children: [
            AnCountUp(tools.length, style: AnText.meta.copyWith(color: c.ok)),
            Text(' ${t.chat.stage.toolsDiscovered}', style: AnText.meta.copyWith(color: c.ok)),
          ]),
          const SizedBox(height: AnSpace.s2),
          for (final tool in tools.take(12))
            Padding(
              padding: const EdgeInsets.only(bottom: AnSpace.s2),
              child: Row(children: [
                Icon(AnIcons.tool, size: AnSize.iconSm - 4, color: c.inkFaint),
                const SizedBox(width: AnSpace.s4),
                Expanded(
                  child: Text(tool,
                      maxLines: 1, overflow: TextOverflow.ellipsis, style: AnText.meta.copyWith(color: c.inkMuted)),
                ),
              ]),
            ),
        ],
        const SizedBox(height: AnSpace.s4),
        RunStatBar(state: scene.state),
      ],
      if (scene.failed && scene.state.errorText.isNotEmpty) ...[
        const SizedBox(height: AnSpace.s6),
        Text(scene.state.errorText,
            maxLines: 3, overflow: TextOverflow.ellipsis, style: AnText.meta.copyWith(color: c.danger)),
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
