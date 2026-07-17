import 'package:flutter/widgets.dart';

import '../../core/design/colors.dart';
import '../../core/design/tokens.dart';
import '../../core/design/typography.dart';
import '../../core/ui/ui.dart';
import '../../features/chat/ui/chat_turn.dart';
import 'specimen.dart';

// AnMarkdown — the chat text-block markdown renderer, on the gallery's white cell (= the real ocean).
// dev-only strings, i18n-exempt. Chinese/emoji inside markdown samples is model CONTENT, not UI labels.
// No animation → matrix reduced axis passes trivially. The injection battery is the load-bearing one:
// every payload must render INERT (literal text / dead link / no fetch).
//
// AnMarkdown——chat 文本块 markdown 渲染器,衬白 cell。dev 串豁免 i18n(样本里的中文是模型内容非 UI 标签)。
// 无动画。注入电池是承重的:每个载荷必须惰性渲染(字面/死链/不取网)。

const double _mdW = 620;

Widget _md(String s) => AnMarkdown(s);

final GalleryItem anMarkdownGalleryItem = GalleryItem(
  'AnMarkdown 渲染器',
  'chat 文本块 markdown:阅读档 22/18/15 · 粗体 w400 · 围栏→AnCodeEditor · 表→AnThinTable · 链接闸 · 图不取网',
  [
    GallerySpecimen('段落 + 行内混排', (_) => _md(
      '把 **sync_inventory** 的重试改成了*指数退避*,细节见 [PR #42](https://example.com/pr/42)。'
      '失败会抛 `SyncError`,由上游 workflow 决定是否降级——~~静默吞掉~~不再发生。',
    ), span: true, maxWidth: _mdW),
    GallerySpecimen('标题阶梯(阅读档 22/18/15)', (_) => _md(
      '# 一级 · 22\n\n正文一段。\n\n## 二级 · 18\n\n正文一段。\n\n### 三级 · 15 加粗\n\n#### 四级并入 13 档\n\n正文一段。',
    ), span: true, maxWidth: _mdW),
    GallerySpecimen('列表(有序/无序/任务)', (_) => _md(
      '1. 拉取 line items\n2. 按季度聚合\n3. 标出超 10% 波动\n\n- 跨年边界:Q4 与次年 Q1 不混\n- 退款行计入当季\n\n'
      '- [x] 已加重试\n- [ ] 待开 issue',
    ), span: true, maxWidth: _mdW),
    GallerySpecimen('引用(静默旁白)', (_) => _md(
      '用户的原话是:\n\n> 第 3 次还失败的话,能不能自动开个 issue?\n> 我早上想直接看到,不想翻日志。\n\n所以我在失败分支上挂了 create_issue。',
    ), span: true, maxWidth: _mdW),
    GallerySpecimen('内联 code 密排', (_) => _md(
      '把 `retries` 从 `0` 提到 `3`,间隔走 `1s→2s→4s`,超限抛 `SyncError`;配置键是 `sync.retry.max`。',
    ), span: true, maxWidth: _mdW),
    GallerySpecimen('围栏代码(py / json / 无语言)', (_) => _md(
      '```py\ndef retry(fn, times=3):\n    for i in range(times):\n        if fn():\n            return True\n    return False\n```\n\n'
      '```json\n{"retries": 3, "backoff": [1, 2, 4]}\n```\n\n```\nplain block, no language\n```',
    ), span: true, maxWidth: _mdW),
    GallerySpecimen('表格(左/中/右对齐)', (_) => _md(
      '| 季度 | 金额 | 环比 |\n|:-----|:----:|-----:|\n| Q1 | 120k | +4% |\n| Q2 | 98k | -18% |\n| Q3 | 143k | +46% |',
    ), span: true, maxWidth: _mdW),
    GallerySpecimen('分割线 + 真实混合样本', (_) => _md(
      '查完了,两个发现\n\n---\n\n**根因**:`issue_date` 没做时区归一。修法:\n\n```py\ndate.astimezone(tz)\n```\n\n详见 [文档](https://example.com/tz)。',
    ), span: true, maxWidth: _mdW),
    GallerySpecimen('组装:助手回合(裸全宽) + 用户泡', (c) => Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ChatTurn(
          role: ChatRole.user,
          child: Text('帮我看下为什么失败', style: AnText.body.copyWith(color: c.colors.ink)),
        ),
        const SizedBox(height: AnSpace.s24),
        ChatTurn(role: ChatRole.assistant, child: _md('**根因**是时区没归一:\n\n```py\ndate.astimezone(tz)\n```')),
      ],
    ), span: true, maxWidth: _mdW),
    // ── 五电池 five-battery ──
    GallerySpecimen('空', (_) => Padding(padding: const EdgeInsets.all(1), child: _md('')),
        stress: true, span: true, maxWidth: _mdW),
    GallerySpecimen('超长(长词 + 长 URL 不撑破)', (_) => _md(
      'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa'
      'bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb\n\n'
      '[一条很长的链接](https://example.com/a/really/really/long/path/that/goes/on/and/on/and/on/and/on/and/on/and/on?x=1&y=2&z=3&w=4)',
    ), stress: true, span: true, maxWidth: _mdW),
    GallerySpecimen('海量(混合长文档)', (_) => _md([
      for (var i = 1; i <= 12; i++)
        '## 段落 $i\n\n第 $i 段正文,带 `code_$i` 与 **加粗**。\n\n- 点一\n- 点二\n\n```py\nprint($i)\n```\n',
    ].join('\n')), stress: true, span: true, maxWidth: _mdW),
    GallerySpecimen('极值(未闭合围栏/半截语法/深嵌套)', (_) => _md(
      '> 引用里\n> - 嵌套列表\n> - **加粗**\n\n半截加粗 **bo\n\n半截链接 [text](htt\n\n```py\nprint("未闭合围栏,流式中间态"',
    ), stress: true, span: true, maxWidth: _mdW),
    GallerySpecimen('注入(script/js 链接/远程图/HTML → 全部惰性)', (_) => _md(
      '<script>alert(1)</script> 与 <b>not bold</b> 与 <u>not underline</u>\n\n'
      '[点我](javascript:alert(1)) · [data 链](data:text/html,<script>x</script>)\n\n'
      '![外部图](https://evil.example/track.png?q=secret) ![本机图](http://127.0.0.1:9999/api/v1/health)\n\n'
      '模板字面 \$'
      '{raw} 与 {{cel}} 与 ](碎片',
    ), stress: true, span: true, maxWidth: _mdW),
  ],
);
