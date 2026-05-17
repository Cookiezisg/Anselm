# Forgify · 前端设计文档

> **定位**：本文档是 Forgify 客户端（桌面 Wails 应用形态）的前端设计事实源。所有视觉系统、IA 模型、交互模式、状态语义、响应式策略的决策原因都在这里。
>
> **关联**：
> - 后端架构与契约 → `backend-design.md`
> - 三条 SSE 协议 → `event-log-protocol.md`
> - 调试控制台（V2 testend）→ `testend-design.md`
>
> 本文档面向"以后接手前端的人"——包括未来的自己。

---

## 0. 设计原则（按优先级）

1. **Notion 级 UI · 生产工具感** — 不是 SaaS demo，不是玩具。每个像素都为日常持续使用服务。
2. **Chat 是常驻工作区，不是页面** — 用户从 chat 召唤一切（forge / workflow / doc）；chat 与其他面板同级、可并排。
3. **每个域有专属 UI** — function 看代码 + 版本 + diff，handler 看 class + config + calls，workflow 看可视化画布，doc 看 Notion 式正文。不要套统一表格视图。
4. **AI 编辑入口无处不在** — 锻造 / 执行 / 文档里所有可编辑的实体都能"让 AI 修改"，触发产生一个 pending 版本。
5. **没有花哨渐变、emoji、液态玻璃** — Notion 真·白 + 中性灰 + 一个 Claude 橙 accent。
6. **本地优先的所有 affordance** — 不要暗示云端、协作者、分享；用户的工具、对话、数据全在他自己电脑上。
7. **键盘优先** — ⌘K 命令面板、⌘B 折叠、⌘1-9 切对话；任何主要动作 < 2 次点击。

---

## 1. 视觉系统

### 1.1 颜色（CSS 变量）

| 用途 | Light | Dark |
|---|---|---|
| `--bg-window` | `#FFFFFF` | `#191919` |
| `--bg-sidebar` | `#F7F7F5` | `#202020` |
| `--bg-paper` | `#FFFFFF` | `#191919` |
| `--bg-elev` | `#FFFFFF` | `#252525` |
| `--bg-elev-2` | `#F7F7F5` | `#2C2C2C` |
| `--bg-hover` | `rgba(55,53,47,.06)` | `rgba(255,255,255,.055)` |
| `--bg-active` | `rgba(55,53,47,.10)` | `rgba(255,255,255,.10)` |
| `--fg-strong` | `#37352F` | `rgba(255,255,255,.95)` |
| `--fg-body` | `#37352F` | `rgba(255,255,255,.81)` |
| `--fg-muted` | `rgba(55,53,47,.65)` | `rgba(255,255,255,.56)` |
| `--fg-faint` | `rgba(55,53,47,.45)` | `rgba(255,255,255,.35)` |
| `--border` | `rgba(55,53,47,.16)` | `rgba(255,255,255,.13)` |
| `--border-soft` | `rgba(55,53,47,.09)` | `rgba(255,255,255,.07)` |
| `--accent` (Claude) | `#D97757` | `#E08967` |
| `--accent-soft` | `rgba(217,119,87,.12)` | `rgba(224,137,103,.16)` |
| `--status-success` | `#0F7B6C` | 同 |
| `--status-error` | `#E03E3E` | 同 |
| `--status-warn` | `#B25E10` | 同 |
| `--status-info` | `#2383E2` | 同 |

**Accent 可切换**：`claude` / `blue` / `ink` / `green` / `purple`，用户在侧栏齿轮的小 popover 里选。

### 1.2 字体

- `--font-sans`: `"Inter", "Noto Sans SC", -apple-system, BlinkMacSystemFont, "PingFang SC", sans-serif`
- `--font-mono`: `"JetBrains Mono", "SF Mono", "Menlo", monospace`
- `--font-serif`: 同 sans（保留 token 但不使用，避免类型多样性）

行高：正文 1.55, 标题 1.3, 紧凑场景 1.5。
字重：400 普通正文，500 强调，600 标题/重要按钮，700 H1。

### 1.3 间距与密度

三档密度（`[data-density]` on `<html>`）：

| token | compact | cozy (默认) | comfortable |
|---|---|---|---|
| `--row-h` | 28 | 32 | 38 |
| `--pad-x` | 12 | 16 | 20 |
| `--pad-y` | 8 | 12 | 16 |

圆角：`--radius-sm: 4px`, `--radius-md: 6px`, `--radius-lg: 8px`, `--radius-xl: 12px`。

阴影：`--shadow-sm/md/lg/popover`，低饱和、低对比，Notion 风格。

### 1.4 状态色规范

| 状态 | 用 | 不用 |
|---|---|---|
| streaming | `--accent`（橙） + pulse 动画 | 蓝 |
| success / completed | `--status-success`（青绿） | 翠绿（太鲜艳） |
| error / failed | `--status-error`（赭红） | 纯红 |
| warn / pending / approval | `--status-warn`（赭橙） | 黄 |
| info | `--status-info`（蓝） | — |

**badge** 三件套：`background: <status> 8-12% alpha`, `color: <status>`, `border: <status> 18-22% alpha`。
小圆点用 5-6px，badge 高度统一 20px / 18px。

### 1.5 图标

自绘 lucide-style 内联 SVG，统一 stroke 1.7、round-cap/join，14px 标准尺寸（窄场景 11-13px）。
所有图标在 `src/icons.jsx` 一个 `Icon` 对象里。增改图标只这一个文件。

**不用 emoji**，唯一例外是 `documents` 文档树里用户自己给页面起的图标（mock 数据里的 📊 / 📓 / 🏗️ 等）。

### 1.6 应用图标

`Forgify Icon.html` 是品牌 mark 的设计文件。
方向 A：**砧面 + 火星**——抽象的"锻造瞬间"，避免画工具/锤子/齿轮。
基本要素：橙色 squircle 底（圆角 224 @ 1024）、白色 mark、四角星 spark 在矩形砧面上方留 36px 空隙。
小尺寸（16/22）下 spark 收成一个点、anvil 收成一条横线，仍然辨识。

---

## 2. Shell 架构

### 2.1 整体布局

```
┌──────────┬────────────────────────────────────────┐
│ sidebar  │             main (panes container)     │
│ 248px    │  [pane 1]  ⟷  [pane 2]                 │
│          │  ↑ pane-resize divider, draggable      │
│          │                                        │
│  …       │  panes max 2，> 2 时挤掉最旧的         │
│          │                                        │
│ footer   │                                        │
└──────────┴────────────────────────────────────────┘
```

**没有顶部 titlebar**——Notion 没有，我们也没有。窗口控制交给 Wails 包装层。

### 2.2 Pane 模型

- **panes 是开关**：点 sidebar 项目 → 在 main 末尾 push 一个 pane；再点 → 关掉那个 pane。
- **最多 2 个并排**。开第 3 个时挤掉最旧的（FIFO）。
- **拖动**：两个 pane 之间有 4px 的 `.pane-resize`，可拖拽改变左右比例（20%-80%），状态记到 `leftPct`。
- **关闭**：每个 pane 右上角有 ✕ 关闭。
- **空状态**：0 个 pane 时显示 `Dashboard`（每日工作面，见 §4.1）。

```jsx
// app.jsx
const [openPanes, setOpenPanes] = useState(["chat"]);

const togglePane = (k) => setOpenPanes(curr => {
  if (curr.includes(k)) return curr.filter(x => x !== k);
  if (curr.length >= 2) return [curr[1], k];       // FIFO 挤掉
  return [...curr, k];
});
```

### 2.3 全局 Shell API

任何组件（block 渲染器、通知、dashboard 卡片、AskAI 完成回调）可通过 `window.Shell` 操作 shell：

```js
window.Shell = {
  openPane(k),       // 如果未开则开（不切换）
  closePane(k),
  togglePane(k),
  setActiveConv(id),
  openConv(id),      // 打开 chat pane 并切到该 conv
  toast(t),          // { kind, title, desc, undo, duration }
};
```

**约束**：组件不直接 import App 的 setState；都通过 `Shell`。便于将来抽离/重构。

### 2.4 响应式

- **Container queries** on each `.pane` (`container-type: inline-size`)：当 pane 自身宽度 < 720px：
  - 文档树 / Handler methods 列表 / Workflow palette+props 全部折成抽屉，左上角浮 toggle 按钮召唤
  - Function/Handler/Skill 详情右侧 aside 改成正文下方
  - FlowRun DAG + inspector 改上下堆叠
  - Dashboard KPI 4列 → 2列；< 480px → 1 列
- **JS narrow mode** on main：`ResizeObserver` 监听 main 宽度，< 1000px 时：
  - 强制只渲染一个 pane（隐藏第二个）
  - 底部居中弹出胶囊切换器 `[对话] [锻造]` 选当前可见的

### 2.5 Sidebar 折叠

- **⌘B** 或点 workspace pill → `is-collapsed`：sidebar 变 56px，所有 label 隐藏只剩 icon
- 状态记到 `collapsed`

---

## 3. 各 pane 的设计契约

> 每个 pane 是一个 React component，从 `window.Forgify`（mock data）拉数据；真后端接入时换成 SSE/REST 调用。
> **每个 pane 必须包含的元素**：
> - `pane-bar`（顶部，主框架给的）：icon + crumbs + 关闭按钮
> - 内部自管的 page-header + page-tabs（如果需要） + page-toolbar（搜索/筛选） + page-body

### 3.1 Chat (`chat.jsx`)

**结构**：`<chat-header>` (model selector + 图标按钮) + `<chat-stream>` (消息列表) + `<composer>`。

**消息块**：递归渲染，6 种类型 = text / reasoning / tool_call / tool_result / progress / message。详 `event-log-protocol.md` §2。

**Composer 关键交互**：
- `/` 第一字符 → slash 菜单：`/skill /forge /file /run /doc /memory /clear /compact`
- `@` 任意位置 → mention 弹窗：列 function / handler / workflow / skill / doc，选中固化成 chip 进入下次 prompt
- **拖拽附件**：composer 区域是 drop target，文件直接 attach
- 上一条消息 hover 出现：复制 / 重新生成 / 编辑并重发 / 分叉
- `Enter` 发送，`⇧+Enter` 换行，`Esc` 停止 streaming

**EntityLink**：`renderInline()` 自动识别 `fn_xxx` / `hd_xxx` / `wf_xxx` / `sk_xxx` / `mcp_xxx` / `mem_xxx` / `cv_xxx` / `fr_xxx`，渲染成可点 chip，点击调 `Shell.openPane` 跳转。

**Streaming 状态**：消息右上挂 `streaming` badge；composer placeholder 变 "Agent 正在执行… (Esc 停止)"；侧栏 footer 多一个 `▶ N · ⏸ M` 胶囊；如果 chat pane 关闭了，sidebar 顶部出现"Agent 正在 X…" sticky bar。

### 3.2 Forge (`forge.jsx` / `function-detail.jsx` / `handler-detail.jsx`)

**列表**：tabs 全部 / Functions / Handlers / Workflows + 搜索 + 筛选 + 表格。每行 hover 出复选框，勾选后顶部出现批量操作条（批量试跑 / 导出 / 归档 / 删除 / 批量 Accept pending）。

**状态徽章**：ready / pending / draft / failed。**pending 和 draft 状态自动挂 `✨ AI` 角标**，表示"由 AI 锻造产生"。

**Function 详情**：
- 顶部：版本下拉 + 版本徽章。如果是 pending，副标题挂"由对话 X 锻造产生"可点跳到 chat。
- 左：版本列 + 可展开 diff（pending vs current） + 代码视图（Python 语法高亮）
- 右 aside：契约（输入 / 输出 / sandbox）+ 最近试跑（成功/失败小圆点）+ 被引用列表
- pending 时动作区：Revert / 显示 diff / Accept（都触发 toast 带 undo）
- non-pending 动作区：试跑 / `✨ 让 AI 修改`（AskAI popover）/ 更多

**Handler 详情**：
- tabs：Class / Config / Call 历史 / 版本
- **Class**：左侧方法列表（class 大括号外观）+ 右侧选中方法的签名 / 描述 / 行为 / 示例代码
- **Config**：加密字段编辑（masked + Eye 切换 + Copy）
- **Calls**：4 个 KPI 卡（成功率 / p50 / p95 / p99） + 调用历史表
- **版本**：列出 4 行（current / archived 3 条）+ 查看 / 切到此版本

**Workflow 详情** → 跳到 §3.6

### 3.3 Execute (`execute.jsx`)

**列表**：
- 顶部 4 KPI（今日运行 / 成功率 / 中位耗时 / 待批准）+ sparkline
- **Workflow Heatmap**：每行一个 workflow × 30 列最近运行的状态格子；点 workflow 名过滤；自带 max-height 200 滚动
- 搜索框（按 workflow / run id / 触发源）+ 状态段控（全部 / 运行中 / 待批准 / 失败 / 完成）
- tabs：FlowRuns / 待批准 / 触发器

**FlowRun 详情**：
- 三件套：**左侧 DAG**（非线性、并行分支可见、状态色染节点）+ **右侧节点 inspector**（input / output / log / 重试） + **底部 Gantt 时间线**（横轴时间，并行节点同时段显示）
- 失败 run 顶部出现 **AI 排查面板**：问题 / 根因 / 三条修复建议（每条带"Accept 修改"或"让 AI 锻造"） / 下一步动作（用相同输入重跑 / 改输入重跑 / 从这节点继续 / 加到 memory）
- `与历史 diff` 按钮 → 弹 **RunDiff 面板**：选另一个同 workflow run，表格列各节点的状态/耗时对比 + verdict（一致 / 有差异 / 单边）

### 3.4 Documents (`documents.jsx`)

**Notion 完整复刻**：左侧文件树（可展开 / 折叠 / 嵌套）+ 右侧文档视图。

**文档视图**：大 emoji icon + 巨标题（可 contentEditable）+ 元信息条（编辑时间 / 作者 / 挂在哪个 workflow） + 正文（自研 markdown 渲染：标题 / 列表 / 表格 / blockquote / code-block / inline code / bold）

**反向链接**：右上角 `引用 (3)` → 抽屉弹出，列出哪些 workflow / function / 对话引用了本文档，点击直接跳转。

**Ask AI**：xs 尺寸的 ✨ 按钮，预设建议是文档操作（扩写到 500 字 / 转成 bullet / 翻译 / 提炼摘要）。

### 3.5 Skills / MCP / Memory（资源库 三件套）

**Skills (`skills.jsx`)**：
- 列表：左 icon + 名字 + 描述 + active badge
- 详情：左侧 SKILL.md 正文预览（`$1` / `$ARGUMENTS` / `${CLAUDE_*}` 占位高亮）+ 右侧 frontmatter 表单 + 占位符说明 + 最近调用

**MCP (`mcp.jsx`)**：
- 列表：卡片式，每卡含 server icon + 名字 + 健康 sparkline（24 小时）+ tools 数量
- 详情：启动命令 + 环境变量 (masked) + 24h 健康曲线 + tabs（Tools / 安装日志 / Raw JSON）

**Memory (`memory.jsx`)**：
- 4 种类型 tabs（用户偏好 / 项目事实 / 反馈 / 参考）
- 行：pin 切换 + 类型 chip + 文本 + AI 来源
- 底部说明：LLM 自管的 3 个 system tools（read / write / forget_memory）

### 3.6 Workflow (`workflow.jsx`)

**可拖拽画布**（Dify 风）：
- 左侧 **palette**：13 种节点类型，可拖入画布或点击添加
- 中间 **canvas**：grid 点阵背景，节点可拖拽，从节点底圆点拖到另一节点顶圆点连线，`Backspace` 删除选中
- 右侧 **properties**：选中节点的属性面板（标签 / 引用 / 重试 / 超时 / onError）
- 顶部：保存指示（`● 已保存` / `● 未保存的改动`，节点动作后 1.5s 自动回到已保存）+ Capability check + 试跑 + AskAI + 部署

**版本不一致告警**：节点引用的 forge 已升级到新版本时，节点头部挂 `⚠ v 过时` 小角标，hover 提示"点击同步"。

### 3.7 Dashboard (`dashboard.jsx`)

**空状态**——0 个 pane 时显示。
- 大问候 + 当日日期
- 4 KPI 卡（今日运行 / 运行中 / 等待审批 / 需关注，分别用 active/warn/error 着色 + 副标题给最近一条）
- **等待审批** section：每条带 拒绝 / 暂存 / 批准并继续 三按钮（inline 操作不必跳转）
- **最近的失败** section：每条带 查看日志 / AI 排查 / 从失败处重跑
- **正在跑** section：带 progress-bar
- 底部 2 列：继续对话 + 开始新的（4 个快捷动作）

### 3.8 Observe / Config

**Observe**：4 个用量 KPI + 7 天活动热点矩阵（24×7 格子，颜色按 intensity 染色）
**Config**：API Keys / Model / Sandbox / 外观 / 数据 五个 tab。外观 tab 提供完整主题/Accent/密度切换（侧栏齿轮 popover 是它的快捷入口）。

---

## 4. 跨域交互模式

### 4.1 AskAI Popover（`ask-ai.jsx`）

**约定**：任何"AI 可改"的实体都挂一个 `<AskAiTrigger>` 按钮（橙色软底，✨ 图标）。

```jsx
<AskAiTrigger
  context="Function · aggregate_week v1"
  suggestions={["把超时改成 60 秒", "失败重试 3 次", "加单元测试"]}
/>
```

- 点击 → 弹 popover **挂在 pane 内**（不是 viewport，因此两个 pane 各自有自己的 popover）
- 顶部显示 context（哪个实体）
- 中间多行 textarea + 预设建议 chip（点击填入）
- 提交 → 模拟"锻造中…" 1.4s → 发 toast "锻造已启动 · 已产生 pending 版本"

**位置**：`position: absolute; right: 18px; bottom: 18px;`，pane 设了 `position: relative`，所以挂在 pane 右下角。

### 4.2 Toast（`window.Shell.toast`）

底部居中 toast tray，3 种 kind（success / error / warn），每条最多 5 秒，带可选 `undo` 按钮。

Accept / Revert / AI 锻造完成都走 toast。

### 4.3 Notifications Drawer

右侧抽屉，按时间分组（现在 / 今天稍早 / 更早）。**同实体连续通知合并成一条**（带 `×N` 角标），展开看"已合并 N 条 · 最新：xxx · 最早：N 天前"。
点击 → 按 type 映射到目标 pane（approval/flowrun → execute，forge → forge，mcp → mcp …）打开。

### 4.4 AskUserQuestion Modal

Agent 在 `AskUserQuestion` 工具暂停时调起。卡片型 modal，4 选项 + 自由输入兜底。`1-4` 数字键选项，`Enter` 提交。

### 4.5 Command Palette ⌘K

全局搜索 + 跳转：导航命令 + 实体（最近对话 / forge / skill 等）。
分组渲染，箭头键导航，`Enter` 选中，`Esc` 关闭。

### 4.6 Cross-pane 链接

`renderInline()` 在 chat block 文本里识别实体 ID（fn_/hd_/wf_/sk_/mcp_/mem_/cv_/fr_ 前缀），渲染成可点 chip：
- 带域 icon
- accent 软底 + 边
- 点击 → 在右侧 pane 打开（不会替换当前 chat pane）

---

## 5. 文件清单

```
src/
├── app.jsx                  shell, 多 pane state, Shell API, keyboard shortcuts, toast tray, settings popover
├── sidebar.jsx              workspace pill, 命令面板入口, 顶级 nav, 资源库 + 其他 sections, 对话列表(置顶/最近/归档), 底部 footer
├── chat.jsx                 ChatHeader, Composer (slash/@/drop), MessageView, RelTime
├── blocks.jsx               BlockList recursive renderer, 6 block types, EntityLink, markdown inline
├── ask-ai.jsx               AskAiTrigger, AskAiPopover (per-pane)
├── dashboard.jsx            空状态主页（KPI / 待审批 / 失败 / 在跑 / 继续对话 / 快捷新建）
├── forge.jsx                ForgeList (含批量操作), KindChip, StatusBadge, dispatch 到 detail
├── function-detail.jsx      FunctionDetail (versions + diff + code view + runs aside)
├── handler-detail.jsx       HandlerDetail (class / config / calls / versions tabs)
├── workflow.jsx             WorkflowView, WorkflowEditor (palette + canvas + props), CanvasNode (含 version mismatch)
├── execute.jsx              ExecuteView (KPI + heatmap + table), FlowRunDetail (DAG + inspector + Gantt), TriagePanel, RunDiffPanel
├── documents.jsx            DocumentsView (tree + page + backlinks), MD renderer
├── skills.jsx               SkillsView (list + SKILL.md preview + frontmatter)
├── mcp.jsx                  McpView (cards + detail with health sparkline + install log)
├── memory.jsx               MemoryView (kinds + pin + list)
├── config.jsx               ConfigView (API keys / models / sandbox / appearance / data), ObserveView, Onboarding
├── overlays.jsx             CommandPalette, AskUserModal, NotificationsDrawer (aggregated), ApprovalBanner
├── icons.jsx                Icon 对象，所有 inline SVG
├── data.jsx                 Mock data (window.Forgify): conversations, messages, forges, flowruns w/ node details, workflow history heatmap, docs, skills bodies, mcp details, etc.
├── tweaks-panel.jsx         starter component, 已不直接使用（侧栏齿轮 popover 替代）
└── styles.css               设计 tokens + 所有组件 CSS
```

入口文件：`Forgify Desktop.html` — 加载所有 jsx + styles.css。

品牌资源：`Forgify Icon.html` — app icon 设计文件。

---

## 6. 实体生命周期与状态

### 6.1 Forge（Function / Handler / Workflow）状态机

```
   ┌──────── ⚙ 由对话锻造 / 用户新建 ────────┐
   ↓                                          │
[draft / pending] ── Accept ──→ [ready] ──┐  │
   │                                       │  │
   │ Revert / iterate                      │  │
   │                                       │  │
   ↓                                       │  │
[archived] ←─── 升级覆盖 ──────────────────┘  │
                                              │
            (workflow 引用过时 → version mismatch 角标)
```

UI 表达：
- **pending / draft** → warn badge + `✨ AI` 角标（标识来源）
- **ready / current** → success badge
- **archived** → muted badge + 历史区灰显
- **failed** → error badge

### 6.2 FlowRun 状态机

```
[running] ──┬──→ [completed]
            ├──→ [failed]
            ├──→ [cancelled]
            └──→ [waiting_approval] ── 用户批准 ──→ [running]
                                    └─ 拒绝 ─────→ [cancelled]
```

UI 表达：色带映射 §1.4。Workflow heatmap 用 30 列状态格子可视化历史。

### 6.3 Conversation 状态

```
[idle] ── 用户发消息 ──→ [streaming] ── 完成 ──→ [idle]
                                    ├ 取消 ─→ [idle]
                                    └ ask 工具暂停 ─→ [waiting_user_input]
```

UI 表达：sidebar 对话列表的小圆点。streaming 是脉冲橙；approval 是黄；idle 是灰。

---

## 7. 键盘绑定

| 快捷键 | 行为 |
|---|---|
| `⌘K` / `Ctrl+K` | 打开/关闭命令面板 |
| `⌘B` / `Ctrl+B` | 折叠/展开 sidebar |
| `⌘1` … `⌘9` | 切换到最近 9 个对话 |
| `Esc` | 按优先级关：cmdk → settings → ask → notifs → 取消 streaming |
| `Enter` (composer) | 发送 |
| `⇧+Enter` (composer) | 换行 |
| `Backspace` / `Delete` (workflow editor) | 删除选中节点 |
| `↑` / `↓` (slash/mention menu) | 导航 |
| `Enter` / `Tab` (slash/mention menu) | 选中 |

**约束**：所有快捷键在 input/textarea/contentEditable 中失效（除 composer 的 Enter）。

---

## 8. 数据 / 协议适配

> 当前是 mock data。接入真后端时按下方对照：

| Mock 路径 | 后端来源 |
|---|---|
| `Forgify.activeMessages` | `GET /api/v1/conversations/{id}/messages` + eventlog SSE 增量 |
| `Forgify.conversations` | `GET /api/v1/conversations` |
| `Forgify.forges` | `GET /api/v1/functions` + `/handlers` + `/workflows` |
| `Forgify.flowruns` | `GET /api/v1/flowruns` |
| `Forgify.flowrunDetails[id]` | `GET /api/v1/flowruns/{id}` 含 nodes / edges / nodeDetails |
| `Forgify.workflowHistory[wf]` | `GET /api/v1/workflows/{name}/run-history` |
| `Forgify.notifications` | notifications SSE 流 |
| `streaming` state | eventlog SSE 流的 `message_start` / `message_stop` |
| AskAI 提交 | `POST /api/v1/conversations/{id}/messages`（chat domain）|
| Accept / Revert | `POST /api/v1/functions/{id}:accept` 等 |

详细 wire shape 在 `event-log-protocol.md` / `service-contract-documents/api-design.md`。

---

## 9. 演进规则

1. **加新 pane**：
   - `app.jsx` 的 `PANE_META` 加一行
   - `sidebar.jsx` 加一个 `<SideNavItem>` 触发 `togglePane`
   - 新建 `src/<pane>.jsx`，导出到 `window.<PaneName>View`
   - `Forgify Desktop.html` 加 `<script>` 引用
2. **加新 block type**：先改 `event-log-protocol.md`（封闭枚举）→ `blocks.jsx` 加 case
3. **加新 tweak**：在 settings popover 而不是把 Tweaks 面板复活；config pane 的"外观"tab 也跟着加
4. **加新 entity ID 前缀**：`blocks.jsx::EntityLink` 的 meta map 加一行
5. **加新 status**：颜色加到 `--status-*`；badge 类加进 `styles.css`
6. **不加第二个 titlebar / 顶栏**：所有全局状态走 sidebar footer 或 toast
7. **不加 emoji 装饰**：用户内容里的 emoji（文档 icon、自定义）可保留，UI chrome 不可用

---

## 10. 已知坑 / 演化债

- 当前 mock data 写死在 `data.jsx`；接 SSE 后需要按 conversation/workflow 分片懒加载
- Workflow 编辑器的拖拽是 `mousedown + window mousemove`——未来 touch 屏要补 pointer events
- markdown 渲染是 minimal 自研（h1-3 / 列表 / 表格 / code / blockquote / inline code / bold），缺：图片 / 链接 / 嵌套列表 / 任务列表。换为 marked.js 或 remark 时要注意 EntityLink 仍能识别。
- Container queries 需要 Chromium 105+ / Safari 16+。Wails embed 的 WebKit 在老 macOS 上可能不支持，要 fallback。
- RelTime 不自动刷新（"3 分钟前"不会变 "4 分钟前"）。如需，加个 useEffect setInterval。
- 接入真后端时，注意 `EntityLink` 跳转的 pane 要把对应 entity 的 detail view 滚到那个实体，而不是 list 顶——目前 list 视图无 "highlight this id" 能力。

---

## 11. 未来可探索（V1.2 后）

- **Cmd palette 加 fuzzy + 历史**：现在是 substring 匹配
- **Workflow editor 撤销栈**（⌘Z / ⌘⇧Z）
- **Conversation diff**：两个对话之间的差异
- **Run replay**：FlowRun 的 input 回放 + breakpoint
- **Inline markdown 在 chat 直接编辑**：双击 assistant message 直接修改 + 重新生成
- **Skill marketplace UI**：从远端拉 skills
- **触摸优化**：pane resize / workflow canvas 改 pointer events
- **国际化**：所有中文 copy 走 i18n 表

---

*本文档跟代码同步。代码改了请回头改这里。*
