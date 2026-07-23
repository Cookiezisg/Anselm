import 'package:flutter/widgets.dart';

import '../../../../core/design/colors.dart';
import '../../../../core/design/tokens.dart';
import '../../../../core/design/typography.dart';
import '../../../../core/ui/ui.dart';
import '../../../../i18n/strings.g.dart';
import '../tool_card_control_approval.dart';
import 'stage_frame.dart';
import 'stage_scene.dart';

/// The APPROVAL stage (WRK-061 §7-7, W3) — the letter being written: the template's markdown prose
/// grows in a paper card while `{{ input.* }}` interpolations CONDENSE INTO AMBER CAPSULES the moment
/// they stream in (prose and discriminant bilingually mixed — approval's signature). The three-axis
/// meta lights as its keys close: allowReason → the reason-slot window, timeout → the humane sentence
/// («30d 后自动拒绝», '' = 永不超时). A ghost «预览 · 尚未寄出» seal frames the live act. Settle
/// delegates to the B2 form-preview body (the rehearsal frame: what the approver WILL see).
///
/// approval 舞台(W3)——正在写的信笺:template 散文在纸质卡里生长,{{ input.* }} 流中即凝琥珀插值药囊
/// (散文与判别式双语混排——approval 独有)。三轴随键闭合点亮:allowReason→理由栏窗,timeout→人话
/// (「30d 后自动拒绝」,空=永不超时)。live 盖幽灵「预览·尚未寄出」章。落定复用 B2 表单预览(预演帧)。
class ApprovalStageBody extends StatelessWidget {
  const ApprovalStageBody({required this.scene, super.key});

  final StageScene scene;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final t = Translations.of(context);
    final session = scene.session;

    if (!scene.live && !scene.failed) {
      // Settle: the rehearsal frame — B2's form preview IS what the approver will see. 落定=预演帧。
      return approvalFormBody(context, scene.state);
    }

    final template = session.liveStringNamed('template') ?? '';
    final allowReason = session.closedValueAt(['allowReason']);
    final timeout = session.closedStringAt(['timeout']);
    final behavior = session.closedStringAt(['timeoutBehavior']);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        // icon 沟文法:「预览·尚未寄出」标识行的字形坐进沟格、文字落文字列;信笺 AnWindow(真框)满宽贴 X=0。
        // The icon-gutter grammar: the「预览·尚未寄出」identity row's glyph sits in the gutter; the letter
        // window (a real frame) fills the body width at X=0.
        if (scene.live)
          stageGutterRow(
            lead: Icon(
              AnIcons.approval,
              size: AnSize.iconSm,
              color: c.inkFaint,
            ),
            child: Text(
              t.chat.stage.previewUnsent,
              style: AnText.meta.copyWith(color: c.inkFaint),
            ),
          )
        else
          // G10/A3-21 — a FAILED create is not a «preview about to be sent»: it will never be sent.
          // 失败的创建不是「即将寄出的预览」——它永远寄不出去。
          stageGutterRow(
            lead: Icon(AnIcons.error, size: AnSize.iconSm, color: c.danger),
            child: Text(
              t.chat.stage.draftFailed,
              style: AnText.meta.copyWith(color: c.danger),
            ),
          ),
        const SizedBox(height: AnSpace.s4),
        if (template.isNotEmpty) AnWindow(child: _letter(context, c, template)),
        if (timeout != null)
          // 假想框律:timeout 句(裸文字)归假想框,左缘对齐 KV 键(X=8);信笺/理由窗=真框贴 X=0。The
          // imaginary-frame law: the timeout sentence (bare text) sits in the imaginary frame (X=8, the KV-key
          // line); the letter / reason windows are real frames at X=0.
          stageFramed(
            Text(
              timeout.isEmpty
                  ? t.chat.stage.neverTimeout
                  : switch (behavior) {
                      'approve' => t.chat.stage.timeoutApprove(d: timeout),
                      'fail' => t.chat.stage.timeoutFail(d: timeout),
                      _ => t.chat.stage.timeoutReject(d: timeout),
                    },
              style: AnText.meta.copyWith(color: c.inkMuted),
            ),
            top: AnSpace.s6,
          ),
        if (allowReason == true) ...[
          const SizedBox(height: AnSpace.s4),
          // A sibling window, not the letter's footer: the reason slot may close before the
          // template's first character (stream key order is free — a footer would vanish with its
          // window), and it must stay BELOW the timeout sentence. 同胞窗而非信笺 footer:流式键序不定
          // (理由可先于信笺首字闭合,挂 footer 会随窗消失),且须排在 timeout 句之下。
          AnWindow(
            child: Text(
              t.chat.stage.allowReason,
              style: AnText.meta.copyWith(color: c.inkFaint),
            ),
          ),
        ],
      ],
    );
  }

  // The letter: markdown-ish prose with {{ CEL }} condensed into amber capsules. 信笺:{{ }} 凝琥珀药囊。
  Widget _letter(BuildContext context, AnColors c, String template) {
    final spans = <InlineSpan>[];
    final re = RegExp(r'\{\{\s*([^}]{1,120}?)\s*\}\}');
    var last = 0;
    for (final m in re.allMatches(template)) {
      if (m.start > last) {
        spans.add(
          TextSpan(
            text: template.substring(last, m.start),
            style: AnText.reading.copyWith(color: c.inkMuted),
          ),
        );
      }
      spans.add(
        WidgetSpan(
          alignment: PlaceholderAlignment.middle,
          // The ONE inline-capsule shell (批5 A-041 — the hand-rolled amber pill retires). 唯一行内壳。
          child: AnInlineCapsule(m.group(1)!, tone: AnTone.warn),
        ),
      );
      last = m.end;
    }
    if (last < template.length) {
      spans.add(
        TextSpan(
          text: template.substring(last),
          style: AnText.reading.copyWith(color: c.inkMuted),
        ),
      );
    }
    return Text.rich(TextSpan(children: spans));
  }
}
