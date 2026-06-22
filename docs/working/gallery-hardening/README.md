---
id: WRK-036
type: working
status: active
owner: @weilin
created: 2026-06-21
reviewed: 2026-06-21
review-due: 2026-09-19
audience: [human, ai]
landed-into:
---

# demo 组件库硬化 —— web 建设事实源

> 来源：7 路并行审计 + 反核验（1 内化审 + 6 组件健壮性/覆盖 → 综合 master 计划，含自我勘误）。完整 synth 见 workflow 输出 `wlclvulq4`。
> 目标：每件**模块化**（在册原语、无散落 bespoke）+ **任意数据填充不破** + **画廊全覆盖** + **Playwright 逐件验**。达标后据此直接推 web 端。
> 总评：渲染骨架成型、典型态扎实；差两道坎——**P0 真破洞**（XSS/撑破/冻结/崩溃）让「不破」不成立；**画廊是 happy-path 展柜非压力床**（空/超长/海量/极值/注入「五电池」近全空 + 11 处登记漂移）。

## 执行顺序（批次）

- **批 1 · P0 真破洞**（源码先修，最高优先）— ✅ 已修验（field/kv wrap · thin-table minmax · json-tree 环+cap · model-picker escape · dialog 转义；block-tree/doc-editor 经核验 text 路径本就转义、html 是信任契约，inject 对照 specimen 留批 4）
- **批 2 · 内化 3 原语 + feature 迁移 + 登记** — ✅（2a 建 an-card/an-brand-icon/an-stepper + 画廊 16 specimen · 2b onboarding 迁移[逮到 an-card 宿主监听真 bug] · 2c settings 迁移[mk-*/mcp-* 卡框→an-card、图标→an-brand-icon，删 ensureSettingsStyle 卡/图标 CSS] + PATTERNS 登记 3 原语 + 清 an-segmented 漂移；.mk-add 虚线钮 + .an-pp provider 浮层留作 feature 专属，未迁）
- **批 3 · P1 批量**（截断簇 CSS + 逻辑簇）— ✅ ~25 修（4 agent 并行 + 手修 badge/json-tree）：截断簇(badge/ref-pill/tags/composer-chip/menu/dropdown/toast/block-tree/doc-editor) · 逻辑簇(input 保留正敲/button disabled+aria/node-gantt clamp+滚/run-board 空态/skeleton clamp/callout tone/outline null/section actions/row-detail 冒泡/typewriter 字素/approval-gate options+ddl/wire-list/graph-canvas id) · **json-tree 真 bug:value justify-self:start 致超长值撑破轨道(2880px)→ 去掉+网格 minmax(0,auto)**。Playwright p1-stress 全绿(超长截断/越界 pct/空态/disabled 键盘/emoji/海量/null)+ 画廊 0 回归。
- **批 4 · 画廊补全**（五电池 specimen + 登记缺口）— ✅ 新建 `features/reference/catalog-stress.js`：4 压力类目（控件/容器/数据/执行）共 **178 specimen**，每件覆盖 空/超长/海量/极值注入 + 登记缺口变体（button outline · row emphatic/mono · right-island headless · action-group footer · kind-legend divided）。4 agent 并行读真 API 生成 + 主控拼装（修 exec 组 string-attrs→对象）。**压力床逮到 4 个真 bug**：tabs `.strip` 40 tab 撑破页→`overflow-x:auto`+tab `flex:none`；action-group 24 钮撑破→`flex-wrap:wrap`+`max-width:100%`；button 超长 label 溢出→`.lbl` 省略号+inner `max-width:100%`（仅受限宽时截断、行内钮不变）；pill 族(badge/tags/ref-pill) `max-width:var(--w-block)`>窄容器→`min(--w-block,100%)`。全 12 类目 Playwright：0 console 错 / 0 页面溢出 / 0 回归。命令式(model-picker/graph-run/doc-editor 注入)转批 5 harness。
- **批 5 · P2 毛刺 + Playwright 全矩阵 + 对抗复审**— ✅
  - **P2 毛刺**：6 真修（info-card title+meta 挤压 · status-dot/badge 枚举 case 归一 · field/kv select 重入+null 崩 · code-editor wrap 行号 · version-diff LCS cap），3 审计误报正确不动（ocean-header/mention/del 行号）。
  - **全矩阵 harness `make demo-test`**：新建 tools/matrix.mjs，自起隔离端口、遍历全 12 类目 385 specimen 5 道断言（console 错/页溢出/**格内盒溢出**/XSS 逃逸[on*·script·srcdoc·js-url]/已渲染）+ app/settings/onboarding 活页冒烟 + disabled/dialog 专项；package.json(playwright dev-only)+Makefile demo-test。
  - **对抗复审**：4 独立视角(健壮性再攻/内化纪律/harness 可信度/一致性)实证挖出 18 finding，修真者修 12+：**node-gantt 语义反转(失败→绿)** · run-board/callout/ref-pill/graph-canvas 枚举 case(全走 state-model anState) · AnFloating 监听泄漏 + AnDialog 遮罩堆叠(同帧重 open) · stepper count 封顶 · field churn 泄漏 · **settings 全页手搓下拉→an-dropdown variant=ghost(消 HIGH 造轮子)** · onboarding 英雄 logo→brand-icon elevated · harness 自身盲点(格内溢出漏检/SCROLLABLE 死代码/XSS 正则过窄/活页未覆盖)全补。误报(empty-state 三标准/graph 第三表)记录不强改。
  - 验证：lint EXIT 0 · 强化版 make demo-test 全绿(385 specimen / 0 console 错 / 0 页溢出 / 0 格内溢 / 0 越界 / 0 XSS / 活页冒烟过 / disabled+dialog 守住) · 各 finding agent 逐个 playwright/CDP 复现前后对比。

**收尾**：5 批全完成。demo 组件库已达「模块化在册 + 任意填充不破 + 画廊全覆盖 + make demo-test 逐件机器断言」，可据此直接推 web 端。

## 批 1 — P0 真破洞（破，必先修）

| # | 组件 | 失败填充态 | 行号 | 修法 | 状态 |
|---|---|---|---|---|---|
| 1 | field/kv | `wrap` 在 observed 但无 `[wrap]` CSS，`.v` 恒 nowrap → 长值不换行 | field.js:90,102,147,157 | 加 `[wrap]/.wrap` 下 `.v` white-space:normal+overflow-wrap | ☐ |
| 2 | thin-table | 非首列 `auto` 轨无下限 → 超长值撑破整表、ellipsis 失效 | thin-table.js:57 | 非首列 `minmax(0, auto)` | ☐ |
| 3 | json-tree | 数百 KB/数千节点 → 主线程冻结 + DOM 爆 + 折叠子树全建 + 循环引用栈溢出 | json-tree.js:32-37,113 | 节点上限 + 折叠不建 DOM + 环检测 | ☐ |
| 4 | model-picker | `cur.model` 原值拼 querySelector → 特殊字符崩；`e(id)` 写入但裸值查 → 当前行不高亮 | model-picker.js:36 vs 83 | `CSS.escape` 或 JS 遍历比对 | ☐ |
| 5 | dialog | `content` 串经 innerHTML 不转义（确认弹窗必嵌实体名）→ XSS | dialog.js:97 | 串走 `e()`（Node 照常 append）+ 注入 specimen | ☐ |
| 6 | doc-editor / block-tree | `b.html`/callout html/spansHtml/text 路径原样 innerHTML | doc-editor.js:28,36 · block-tree.js:223 | 固化契约「html=信任、text=转义」+ 确保 text 走 `e()` + 注入对照 specimen | ☐ |

## 批 2 — 内化 3 原语 + AnMenu 强化

| 原语 | 文件 | API | 替换 bespoke |
|---|---|---|---|
| **an-card** ★★★ | core/primitives/card.js | variant(bordered/accent) · selectable · selected · row · pad(default/tight) · slot=actions · 事件 an-card-select | settings `.mk-card/.mk-scn/.mk-form/.mcp-card/.mcp-inst` + onboarding `.ob-choice`（8 处同皮肤） |
| **an-brand-icon** ★★★ | core/primitives/brand-icon.js | src(img)/svg(html)/glyph · size(sm/md/lg) · managed | settings `.mk-ico/.an-pp-ico/.mcp-ico` + onboarding `.ob-mcp-ico`（4 处）+ 灭 brandIcoHtml | 
| **an-stepper** ★★ | core/primitives/stepper.js | count · active（done/accent/待激活）| onboarding `.ob-dots/dots()` |
| AnMenu 强化 | menu.js | item 加 leading/iconHtml 槽 | settings addKeySlot 的 `.an-pp*` 自绘浮层 |

- Feature 改：settings/sea.js 删 ensureSettingsStyle；onboarding 删 ob-* 卡/点；卡→an-card、图标→an-brand-icon、provider 浮层→AnMenu、虚线钮→an-button[dashed]、向导点→an-stepper、nav→an-action-group[footer]。
- 登记：PATTERNS.md（an-card 与 info-card「有边/无边」对偶、an-brand-icon、an-stepper ⬚→✅、改 MCP/模型 compose 行）+ catalog.js（an-card 6 / an-brand-icon 5 / an-stepper 3 specimen）。

## 批 3 — P1 掉链

**截断簇（纯 CSS 批量，加 max-width+ellipsis/overflow-wrap）**：badge(:14) · menu-meta(:38) · dropdown-meta(:30) · ref-pill(:13-19) · tags(:19-25) · composer-chip(:33-37) · toast(:16-20 栈高限) · doc-editor `.b`(:57-62 overflow-wrap) · block-tree `.text`(:63,218 wrap+unknown 兜底)。

**逻辑簇**：an-input 重渲抹活值(input.js:7,31-40)·an-button disabled 透传原生+icon aria(:40,42)·node-gantt pct clamp+滚(:43,48,12)·run-board 空态+gantt 滚(:29-40,16)·entity-workspace 空态+active 越界+revert(:73-90,87,11)·wire-list observed+滚(:10)·typewriter 字素切(:43,48)·approval-gate options 分隔+ddl observed(:110,17,154)·callout 非法 tone 回写(:40)·outline null 过滤(:27,34)·section actions-无-label head(:28)·row-detail 嵌套冒泡(:22)·graph-canvas id 截断+layout 尊重 pos(:171,111)·doc-editor 依赖守卫(:148,167,240)·skeleton count clamp(:54-63)。

## 批 4 — 画廊覆盖（五电池 + 登记缺口 + 命令式）

- **登记缺口（PATTERNS 在册 catalog 没建）**：an-row emphatic/mono · right-island headless · action-group footer · button outline · kind-legend divided · stepper active=1/2/3 · entity-workspace handler/agent/trigger + config/mounts/firings facet。
- **五电池**：① 空（block-tree/run-board/entity-workspace/sidebar-list/thin-table/kv/tabs/typewriter）④ 超长（badge/ref-pill/tags/chip/toast/menu/dropdown/section/info-card/ocean-crumb/tabs/row-meta/gantt/group-label/code）⑤ 海量（json-tree 大/thin-table 50/kv 50/gantt 50/run-board 60/sidebar 50/skeleton 60/block-tree todo 60/toast 12）⑦ 极值注入（status-dot/badge 非法 state/json 环/NaN/越界 pct/options `|`/emoji/未知 icon/各 HTML 注入对照）⑧ 全态（tabs pane/row-detail toggle/ocean editable）。
- **命令式黑洞（转 Playwright）**：composer 演变 · typewriter 帧 · run-terminal run() · entity-workspace ensure/setActive · block-tree poke · approval-gate settle · 各弹层 open。
- **P0 覆盖补**：model-picker（0 specimen 孤儿）· graph-canvas run 全态 · doc-editor 注入对照。

## 批 5 — P2 + Playwright 全矩阵

P2 毛刺（节选）：code-editor wrap 行号错位 · version-diff 删行号空白+LCS 无上限 · graph-canvas 拖拽全量重绘 · info-card title 无截断 · toolbar 长 meta 挤 title · field/kv select 重入叠 dropdown · status-dot/badge 大小写敏感 · mention caret 非 text 节点。

Playwright harness（独立 `make demo-test`、不入 fe-verify）：驱 reference.html，(a) 五电池矩阵每态 4 通用断言（无 console 错/无横向溢出/无塌陷/截断正确）(b) 命令式专项（XSS 注入断言 `window.__xss===undefined`+shadow 无 img · disabled 键盘 · 越界 pct · 大 JSON 性能+环 · 态丢失 · 命令驱动 · 滚动契约）。

## 勘误（审计自纠，执行勿误修）
- **outline `set active` 实际写 `_active`、active 高亮正常**——该路「setter 不写」断言不成立。outline 真问题只 null 元素崩 + l1/l4 越界无样式。
