# Forgify · 前端设计文档

> 客户端（Wails 桌面 app）的视觉系统 + IA + 交互契约的事实源。
> 后端契约见 `backend-design.md` / `event-log-protocol.md` / `service-contract-documents/*`。
>
> 本文档面向"以后接手前端的人"——含未来的自己。

---

## 0. 设计原则（按优先级）

1. **Notion 级 UI · 生产工具** — 不是 SaaS demo，每个像素为日常持续使用服务。
2. **Chat 与其他面板同级、可并排** — chat 不是唯一入口；7 个 pane (chat / forge / execute / documents / observe / skills / mcp / memory / config) 任意 toggle。
3. **每个域有专属 UI** — 不要套统一表格视图。Function 看代码+版本+diff；Handler 看 class+config+calls；Workflow 看可视化 DAG；Document 看 Notion 式正文；MCP 看 server health；Memory 看 pin 列表。
4. **AI 编辑入口无处不在** — 任何实体的详情页右上有 `✨ 让 AI 修改`，触发产生一个 pending 版本。
5. **无营销腔** — 副标题只说"这是什么"，不说"它有多好"。无 emoji、无渐变、无液态玻璃。
6. **本地优先 affordance** — 不暗示云端、协作、分享；用户的工具/对话/数据全在他自己电脑上。
7. **键盘优先** — ⌘K 命令面板、⌘B 折叠侧栏、⌘1-9 切对话；主要动作 < 2 次点击。

---

## 1. 视觉系统

### 1.1 颜色（CSS 变量）

| Token | Light | Dark |
|---|---|---|
| `--bg-window` / `--bg-paper` | `#FFFFFF` | `#191919` |
| `--bg-sidebar` / `--bg-elev-2` | `#F7F7F5` | `#202020` / `#2C2C2C` |
| `--bg-elev` | `#FFFFFF` | `#252525` |
| `--bg-hover` | `rgba(55,53,47,.06)` | `rgba(255,255,255,.055)` |
| `--bg-active` | `rgba(55,53,47,.10)` | `rgba(255,255,255,.10)` |
| `--fg-strong` / `--fg-body` | `#37352F` | `rgba(255,255,255,.95/.81)` |
| `--fg-muted` / `--fg-faint` | `rgba(55,53,47,.65/.45)` | `rgba(255,255,255,.56/.35)` |
| `--border` / `--border-soft` | `rgba(55,53,47,.16/.09)` | `rgba(255,255,255,.13/.07)` |
| `--accent` (Claude) | `#D97757` | `#E08967` |
| `--accent-soft` | `rgba(217,119,87,.12)` | `rgba(224,137,103,.16)` |
| `--status-success` | `#0F7B6C` | 同 |
| `--status-error` | `#E03E3E` | 同 |
| `--status-warn` | `#B25E10` | 同 |
| `--status-info` | `#2383E2` | 同 |

**Accent 可切换**（设置 popover）：`claude` / `blue` / `ink` / `green` / `purple`。

### 1.2 字体

- `--font-sans`: `"Inter", "Noto Sans SC", -apple-system, "PingFang SC", sans-serif`
- `--font-mono`: `"JetBrains Mono", "SF Mono", Menlo, monospace`
- 不用 serif（保留 token 不使用，避免类型多样性）

行高：正文 1.55、标题 1.3、紧凑场景 1.5。字重：400/500/600/700。

### 1.3 密度

`[data-density]` on `<html>`：`compact` / `cozy` (默认) / `comfortable`。控制 `--row-h` / `--pad-x` / `--pad-y` / 间距 token 阶梯。

### 1.4 状态色规范

| 状态 | 颜色 |
|---|---|
| streaming / pending | `--accent` (橙) + pulse 动画 |
| success / completed / ok | `--status-success` (青绿) |
| error / failed / fail | `--status-error` (赭红) |
| warn / approval / wait | `--status-warn` (赭橙) |
| info / running | `--status-info` (蓝) |

**badge** 三件套：`background: status 8-12% alpha`, `color: status`, `border: status 18-22% alpha`。

### 1.5 图标

自绘 lucide-style 内联 SVG，统一 stroke 1.7、round cap/join、14px 标准尺寸。所有图标在 `src/icons.jsx` 一个 `Icon` 对象里。增改图标只这一个文件。

**无 emoji** — UI chrome 一律不用。用户内容里的 emoji（自定义文档 icon）也已清除——文档树和大标题统一用 `<Icon.FileText>` / `<Icon.Folder>`。

### 1.6 应用图标

`Forgify Icon.html` — 品牌 mark 的设计文件。
方向：**砧面 + 火星**（spark r=224, 4 角星）。
品牌色：石墨 + 火 — `#2C2C2C` 底 + `#E08862` spark + `#FFFFFF` 砧面（橙色仅用在 spark 上）。
双色版（dark/light）spark 永远是 `#E08862`，背景 + 砧面在黑/白之间切换。

---

## 2. Shell 架构

### 2.1 整体布局

```
┌──────────┬────────────────────────────────────────┐
│ sidebar  │  main (panes container, max 2 panes)   │
│ 248px    │  [pane 1]  ⟷  [pane 2]                 │
│          │  ↑ 1px draggable resize divider        │
│          │                                        │
│ footer   │                                        │
└──────────┴────────────────────────────────────────┘
```

**没有顶部 titlebar**——Notion 没有，我们也没有。窗口控制交给 Wails 包装层。

### 2.2 Pane 模型

- **panes 是开关**：点 sidebar 项 → push pane；再点 → 关闭。
- **最多 2 个并排**。开第 3 个时 FIFO 挤掉最旧的。
- **拖动**：两个 pane 之间 1px 实线 `.pane-resize`，hover 变 accent；可拖拽改比例 (20%-80%)，状态记到 `leftPct`。
- **关闭**：右上 ✕。chat pane 例外 — 没有 pane-bar，关闭按钮在 chat-header 右侧。
- **空状态**：0 个 pane 时显示 `Dashboard`（每日工作面，见 §4.1）。

```jsx
const togglePane = (k) => setOpenPanes(curr => {
  if (curr.includes(k)) return curr.filter(x => x !== k);
  if (curr.length >= 2) return [curr[1], k];       // FIFO
  return [...curr, k];
});
```

### 2.3 全局 Shell API

任何组件可通过 `window.Shell` 操作 shell：

```js
window.Shell = {
  openPane(k),            // 已开则忽略
  closePane(k),
  togglePane(k),
  openEntity(pane, id),   // 打开 pane 并预选某实体（detail 视图）
  openConv(id),           // 打开 chat 并切到该 conv
  setActiveConv(id),
  toast(t),               // { kind, title, desc, undo, duration }
  focusEntity,            // 当前每 pane 的 focused entity id（用于 detail view）
};
```

组件不直接 setState；都通过 `Shell`。便于将来抽离。

### 2.4 响应式

- **Container queries** on each `.pane` (`container-type: inline-size`)：pane 宽度 < 720px 时：
  - 文档树 / Handler methods 列表 / Workflow palette+props 折成抽屉
  - Function/Handler/Skill 详情右侧 aside 折到正文下方
  - FlowRun DAG + inspector 上下堆叠
  - Dashboard KPI 4→2 列；<480px → 1 列
- **JS narrow mode**：ResizeObserver 监听 main 宽度，< 1000px 时强制单 pane + 底部胶囊切换器。

### 2.5 Sidebar 结构

```
sidebar/
├── workspace pill (FG · Forgify · sun@laptop) — 点击折叠
├── ⌘K cmdk-trigger
├── nav section (顶级)
│   ├── 对话
│   ├── 锻造
│   ├── 执行
│   ├── 文档
│   └── 洞察
├── nav section · 资源库
│   ├── Skills
│   ├── MCP
│   └── Memory
├── (对话列表 · pinned / 最近 / 归档可折叠)
└── footer
    ├── ▶ N · ⏸ M  系统忙度胶囊（streaming 时显示）
    └── user-pill (avatar · 名字 · 圆点)
        + Ask / Bell / Settings ⚙ 三个 icon-btn 在同一行
```

**没有"其他"section**。**没有 settings pane** — 设置通过 sidebar footer 齿轮按钮弹 popover 处理（主题 / accent / 密度 / 语言 / 账号切换 / 进阶设置入口）。

⌘B 切换 sidebar 折叠成 56px 窄条；折叠后只剩 icon。

---

## 3. 各 pane 的设计契约

每个 pane 是一个 React component，从 `window.Forgify` (mock data) 拉数据；真后端接入时换 SSE/REST。

**通用结构**：`pane-bar`（chat 例外）→ `page-header` (icon + title + 简短 subtitle + actions) → `page-tabs?` → `page-toolbar?` → `page-body`。

### 3.1 Chat (`chat.jsx`)

**结构**：`chat-header` (标题 + EntityRelMeta + actions + 关闭) → `chat-stream`（递归 block list）→ `composer`。

**消息块**：6 种 type 递归渲染 = text / reasoning / tool_call / tool_result / progress / message。

**Composer 关键交互**：
- `/` 第一字符 → slash 菜单（`/skill /forge /file /run /doc /memory /clear /compact`）
- `@` 任意位置 → mention 弹窗（function/handler/workflow/skill/doc）
- 拖拽附件
- 上一条消息 hover：复制 / 重新生成 / 编辑并重发 / 分叉
- Enter 发送、⇧+Enter 换行、Esc 停止 streaming

**EntityLink**：`renderInline()` 识别 `fn_/hd_/wf_/sk_/mcp_/mem_/cv_/fr_` 前缀的 ID → 可点 chip，点击调 `Shell.openEntity` 跳具体实体（不是 list）。

**Streaming 状态**：右上 streaming badge；composer placeholder 变"Agent 正在执行…(Esc 停止)"；sidebar 顶部 sticky bar 显示 "Agent 正在 X…"（chat pane 关闭时）。

### 3.2 Forge (`forge.jsx` / `function-detail.jsx` / `handler-detail.jsx`)

**列表**：tabs 全部 / Functions / Handlers / Workflows + 搜索 + 表格。每行 hover 出复选框（批量操作）+ ActionMenu (`…` 真正的实体操作，**不是关系图**)。

**状态徽章**：ready / pending / draft / failed。**pending 和 draft** 自动挂 `✨ AI` 角标。

**Function 详情**（见 §5 详细）：
- 主区：current = 完整信息（说明 / 输入 / 输出 / 沙箱 / 代码 / 试跑历史）；其他版本 = 字段级 diff（说明 / 契约 / 代码 split diff）
- 右侧 VersionRail (320px)

**Handler 详情**（见 §5 详细）：
- 主区：current = 3 tab (Class / Config / Call 历史)；其他版本 = 字段级 diff（说明 / 方法变更 / Config 变更）
- 方法变更卡可展开看 body 的 split diff
- 右侧 VersionRail

**Workflow 详情**（见 §5 详细）：
- 主区：current = 可拖拽 DAG 编辑器 (palette 240px + canvas + props 240px)；其他版本 = DAG diff 视图（节点合并 + 颜色 overlay + 变更清单 240px 左侧）
- 右侧 VersionRail + Deploy 区块（区分 accepted vs deployed）

### 3.3 Execute (`execute.jsx`)

**列表**：
- 顶部 4 KPI + sparkline
- **Workflow Heatmap**：每行一个 workflow × 30 列状态格子
- 搜索 + 状态段控（全部 / 运行中 / 待批准 / 失败 / 完成）
- tabs：FlowRuns / 待批准 / 触发器

**FlowRun 详情**：
- 左侧 DAG（非线性，节点状态色，并行分支可见）
- 右侧节点 inspector（input/output/log/重试）
- 底部 Gantt 时间线（并行节点同时段显示）
- 失败 run 顶部出现 AI 排查面板（问题 / 根因 / 三条修复建议）
- `与历史 diff` 按钮 → RunDiff 面板（同 workflow 两个 run 节点级状态/耗时对比）

### 3.4 Documents (`documents.jsx`)

Notion 完整复刻：左侧文件树（可展开折叠嵌套）+ 右侧文档视图。

**文档视图**：大图标（Icon.FileText, 不是 emoji）+ 巨标题（可 contentEditable）+ 元信息条（编辑时间 / 作者 / EntityRelMeta）+ 正文（自研 markdown：标题/列表/表格/blockquote/code-block/inline code/bold）。

**反向链接抽屉**：「引用 (N)」点开列出哪些 workflow / function / 对话引用了本文档。

**Ask AI** (xs)：扩写 / 翻译 / 提炼摘要。

### 3.5 Skills / MCP / Memory

**Skills (`skills.jsx`)**：
- 列表：行 + ActionMenu（打开文件夹 / 复制路径 / 重新扫描 / 禁用 / 删除）
- 详情：左 SKILL.md 正文预览（`$1` / `$ARGUMENTS` / `${CLAUDE_*}` 占位高亮）+ 右 frontmatter + 最近调用

**MCP (`mcp.jsx`)**：
- 卡片：server icon + 名字 + 24h 健康 sparkline + tools 数 + ActionMenu（重连 / 编辑配置 / 查看日志 / 停用 / 删除）
- 详情：启动命令 + env (masked) + 24h 健康 + tabs (Tools / 安装日志 / Raw JSON)

**Memory (`memory.jsx`)**：
- 4 种类型 tabs（用户偏好 / 项目事实 / 反馈 / 参考）
- 行：pin 切换 + 类型 chip + 文本 + ActionMenu (Pin / 编辑 / 删除)

### 3.6 Workflow Editor 细节

**可拖拽画布**：
- 左侧 240px palette：13 种节点（trigger / function / handler / mcp / skill / llm / http / condition / loop / parallel / approval / wait / variable）
- 中间 canvas：grid 点阵 + 节点可拖、节点 4 个 handle（上下左右）任意连线、空白处拖动 = 平移、滚轮缩放
- 右侧 240px props：标签 / 引用 / 重试 / 超时 / onError
- toolbar 6 按钮：自动垂直排列 / 自动水平排列 / 放大 / 缩小 / 适配画面 / 复位 + 缩放百分比
- ResizeObserver：pane 宽变化自动 fitToContent

**版本不一致告警**：节点引用的 forge 已升级时角上挂 `⚠ v 过时`，hover 提示。

### 3.7 Dashboard (`dashboard.jsx`)

空状态——0 个 pane 时显示。
- 问候 + 当日日期
- 4 KPI 卡（今日运行 / 运行中 / 等待审批 / 需关注）
- **等待审批 / 最近失败 / 正在跑** section（带 inline 动作按钮）
- 底部 2 列：继续对话 + 快捷新建

### 3.8 Observe & Settings popover

**Observe (`config.jsx::ObserveView`)**：
- tabs：关系图（默认）/ 用量
- 关系图 → §6
- 用量 → 4 KPI + **GitHub 风格贡献热力图**（53 周 × 7 天 + 月份标签 + 5 级 accent 渐变）

**Settings**：**不是 pane**，是 sidebar footer ⚙ 按钮弹的 popover。包含：
- 账号切换 / 添加（顶部头像 + 名字 + 列表 + 新建输入框）
- 主题（系统 / 明 / 暗）
- Accent (5 个色板)
- 密度（紧凑 / 适中 / 舒展）
- 语言（中文 / English）
- 「API Keys / Model / Sandbox…」链接 → 打开 config pane

---

## 4. 跨域交互模式

### 4.1 AskAI Popover

任何"AI 可改"的实体挂 `<AskAiTrigger>` 按钮（橙底，✨ 图标）：

```jsx
<AskAiTrigger
  context="Function · aggregate_week v1"
  suggestions={["把超时改成 60 秒", "失败重试 3 次"]}
/>
```

- popover **挂在 pane 内**（不是 viewport），两 pane 各有自己的
- 顶部显示 context；多行 textarea + 预设建议 chip
- 提交 → 模拟"锻造中…" 1.4s → toast "锻造已启动 · 已产生 pending 版本"

### 4.2 ActionMenu vs RelMore

**列表里的 `...` = ActionMenu**（实体操作 — 试跑 / 复制 / 归档 / 删除 / 重命名等）。挂 floating popover via `ReactDOM.createPortal(body, document.body)` 逃逸所有 overflow。点击按 button rect 定位，scroll / resize 自动收起。

**详情页的 `...` = RelMore**（关系图 popover）。也用 createPortal 到该 pane 元素，居中 fade-in。

**默认不混用**：list 视图永远是 ActionMenu，detail 标题旁永远是 RelMore（在 EntityRelMeta 末尾）。

### 4.3 EntityRelMeta

任何实体的详情副标题尾巴自动拼一条关系信息，比如「· 由对话锻造 cv_a1」「· 引用文档 d_strava」「· 属于工作流 wf_weekly_training」。

边 kind → verb 映射：
- forged_from → 由对话锻造
- discussed_in → 在对话中讨论
- uses / uses_doc → 使用 / 引用文档
- referenced_in → 被引用于
- instance_of → 属于工作流
- about → 被记忆关联

末尾跟一个 `...` 看完整关系图。

### 4.4 Toast (`Shell.toast`)

底部居中 toast tray，3 种 kind（success/error/warn），≤5 秒，可选 `undo` 按钮。Accept / Revert / AI 锻造完成都走 toast。

### 4.5 Notifications Drawer

右侧抽屉，按时间分组。同实体连续通知合并 (`×N` 角标)。点击按 type 路由到目标 pane。

### 4.6 Command Palette ⌘K

全局搜索：导航命令 + 实体（最近对话 / forge / skill 等）。分组渲染，键盘导航。

### 4.7 Cross-pane 链接

`renderInline()` 在 chat block 文本里识别 `fn_/hd_/wf_/sk_/mcp_/mem_/cv_/fr_` 前缀的 ID → 可点 chip：
- 带域 icon + accent 软底 + 边
- 点击 → `Shell.openEntity` 在右侧 pane **打开对应实体的详情**，不是 list 视图

---

## 5. 版本管理（Function / Handler / Workflow 三者统一）

### 5.1 状态机

```
   draft (锻造中) ──┐
                    ↓
        pending (AI 产出, 待 Accept)
                    ↓ accept
       ┌── current (当前编辑版本) ──┐
       │                            │ 新 pending Accept
       │ rollback                   ↓
       └── archived ← ── ─ ← ── archived

   workflow 额外有 deployed (生产中真在跑的版本)
   accepted ≠ deployed: Accept 是认可，Deploy 才切换调度器
```

**最多 1 个 pending** — AI 一次只能改一版，你不 accept 之前不让它再改。

### 5.2 版本元数据

每个版本：
```ts
{
  id, label,       // "v3"
  state,           // "pending" | "current" | "deployed" | "archived"
  at,              // "3 分钟前"
  author,          // "ai · CSV → Notion 对话" / "user · 手动"
  summary,         // 一句话自动摘要（accept 时让 LLM 写）
  description,     // 多行说明
  // 实体特有字段:
  code,            // function
  schema,          // function: { inputs, outputs }
  methods, config, // handler
  nodes, edges,    // workflow
}
```

### 5.3 VersionRail（`src/version-rail.jsx`）

**所有三种实体共用此组件**，位置：详情页右侧 320px (collapsed 44px)。

- 顶部 collapse 按钮 + 版本计数
- pending banner：当存在 pending 时，橙色框顶在最上，自带 Revert / 查看 diff / Accept 三按钮
- 版本列表：每条 = 状态点（绿 current / 橙 pending / 蓝 deployed / 灰 archived）+ 版号 + 一句话摘要 + 作者 + 时间
- 折叠态：垂直点 + 小版号
- workflow 额外底部 Deploy 区块（仅当 deployed ≠ current）

**选择规则**：
- 默认选中：有 pending 选 pending；否则选 current
- 点 current → 主区显示完整信息（不是 diff）
- 点其他版本（pending / deployed / archived）→ 与 current 的 diff 视图

### 5.4 Diff 视图

**对比基准永远是 current**。没有自由选择左右两边的 picker。

| 实体 | Diff 形态 |
|---|---|
| **Function** | 字段级：说明（并排）/ 契约（变化字段高亮）/ 代码（SplitDiff — LCS 行级，绿增红删，行号 + 代码） |
| **Handler** | 字段级：说明 / 方法变更（按 method name 配对，新增/删除/修改，可折叠展开看 body 的 SplitDiff）/ Config 变更（表格） |
| **Workflow** | DAG 视觉 overlay（节点合并：🟢 added / 🔴 removed 虚线半透明 / 🟡 changed）+ 左侧 240px 变更清单（点击高亮画布对应节点 + 列出每个改动字段「red 删除线 → green」）+ 连线增删 |

### 5.5 Accept / Revert / Deploy

- **Accept**：pending → current（旧 current → archived）。toast 提示，5 秒 undo。
- **Revert**：丢弃 pending。toast 提示，5 秒 undo。
- **Rollback**：把某 archived 版本设为新 current。
- **Deploy**（仅 workflow）：把 current 版本部署到调度器 → deployed 状态切换。

---

## 6. 实体关系图（Obsidian-style，`src/relgraph.jsx`）

### 6.1 实体范围

7 种实体可参与关系图：
- function / handler / workflow （锻造三件套）
- skill / mcp / memory / conversation / document

每种一个颜色（节点 fill），通过 `KIND_COLOR` 表统一。

### 6.2 关系边

`Forgify.relations` 是边数组，每条 `{ from, to, kind }`：

| kind | 语义 |
|---|---|
| uses | workflow / function 使用 forge / mcp / skill |
| uses_doc | workflow / function 引用文档 |
| forged_from | 对话锻造产生 forge |
| discussed_in | 对话中讨论 forge |
| attached_to | 文档附在对话 |
| referenced_in | 实体在文档/对话中被提到 |
| instance_of | flowrun 属于 workflow（图谱外） |
| about | memory 关于某 forge |
| produced | 对话产出 memory |

### 6.3 RelGraph (Observe pane)

- **力导向布局**：requestAnimationFrame tick 持续模拟（repulsion + spring + damping + 中心拉力）
- **拖任意节点**：被拖节点 pin 在鼠标位置，其他节点持续受力推挤（物理感）
- **释放节点**：以拖动末端速度抛出
- **空白拖**：平移；**滚轮**：围绕鼠标缩放（0.25-3×）
- **节点视觉**：小圆点（半径 3-8px 按连接数），默认无文字标签；hover 才浮出 tooltip 显示完整名字；hover 时其他节点+边淡化
- **右上 toolbar**：放大 / 缩小 / 适配画面 / 复位 + 实时缩放百分比
- **顶部 filter chips**：按实体类型过滤（点首次只看那一类，再点叠加）
- **右侧 detail 面板**：选中节点的 incoming / outgoing 关系列表 + 「打开」按钮（调 `Shell.openEntity`）

### 6.4 RelGraphPopover (mini)

- 通过任何 `RelMore` `...` 按钮触发
- 用 `ReactDOM.createPortal(body, paneEl)` 渲染到触发它的 `.pane` 容器里 → 自动居中在该 pane 内
- 740px 宽，max 92% pane 宽；max-height 跟 pane（不溢出）
- focusId = 该实体；2 跳邻居 subgraph
- 顶部有「完整图谱 →」按钮跳 Observe pane

---

## 7. 文件清单

```
src/
├── app.jsx                  shell, 多 pane state, Shell API, 键盘快捷键, toast tray, Settings popover, NoApiKeyGate
├── sidebar.jsx              workspace pill, cmdk 入口, 顶级 nav, 资源库, 对话列表(置顶/最近/归档), footer (running pill + user pill + ask/bell/settings)
├── chat.jsx                 ChatHeader (title + EntityRelMeta + actions + 关闭), Composer (slash/@/drop), MessageView, RelTime
├── blocks.jsx               BlockList recursive renderer, EntityLink (现 cross-pane 跳具体实体), markdown inline
├── ask-ai.jsx               AskAiTrigger, AskAiPopover (per-pane)
├── dashboard.jsx            空状态主页（KPI / 待审批 / 失败 / 在跑 / 继续对话 / 快捷新建）
├── forge.jsx                ForgeList (含批量操作), KindChip, StatusBadge, dispatch 到 detail
├── function-detail.jsx      FunctionDetail + CodeView + FullView + DiffView (字段级)
├── handler-detail.jsx       HandlerDetail + FullView (Class/Config/Calls tabs) + DiffView + MethodDiffCard (可展开 body diff)
├── workflow.jsx             WorkflowView + WorkflowEditor (palette + canvas + props, 4-handle, 自动布局) + WorkflowDiffView (左侧变更清单 + DAG overlay)
├── execute.jsx              ExecuteView (KPI + heatmap + table), FlowRunDetail (DAG + inspector + Gantt), TriagePanel, RunDiffPanel
├── documents.jsx            DocumentsView (tree + page + backlinks 抽屉), MD renderer
├── skills.jsx               SkillsView (list + SKILL.md preview + frontmatter)
├── mcp.jsx                  McpView (cards + detail with health sparkline + install log)
├── memory.jsx               MemoryView (kinds + pin + list)
├── config.jsx               ConfigView (API keys / models / sandbox / 外观 / 数据), ObserveView (关系图 + 用量 / ContribHeatmap), Onboarding splash
├── overlays.jsx             CommandPalette, AskUserModal, NotificationsDrawer (aggregated), ApprovalBanner
├── relgraph.jsx             entityDirectory, GraphCanvas (force sim), NodeDetail, RelGraph (Observe), RelGraphPopover (mini), RelMore, EntityRelMeta, ActionMenu
├── version-rail.jsx         VersionRail (统一), VersionRow, SplitDiff (LCS), splitDiff
├── icons.jsx                Icon 对象
├── data.jsx                 Mock data (window.Forgify): conversations, messages, forges, flowruns, documents, skills, mcpServers, memories, relations, functionDetails, handlerDetails, workflowDetails (含多版本数据)
├── tweaks-panel.jsx         starter component（不直接使用，settings popover 取代）
└── styles.css               设计 tokens + 所有组件 CSS

Forgify Desktop.html         主应用入口
Forgify Onboarding.html      首跑流程（独立 HTML, 5 步: 欢迎 / 账号 / 外观 / API Key / 就绪）
Forgify Icon.html            品牌 mark 设计文件
```

---

## 8. 状态机与生命周期

### 8.1 Forge 状态机 — 见 §5.1

### 8.2 FlowRun 状态机

```
[running] ──┬──→ [completed]
            ├──→ [failed]
            ├──→ [cancelled]
            └──→ [waiting_approval] ── 批准 ──→ [running]
                                    └─ 拒绝 ─→ [cancelled]
```

UI 表达：色带映射 §1.4。Workflow heatmap 用 30 列状态格子可视化历史。

### 8.3 Conversation 状态

```
[idle] ── 用户发消息 ──→ [streaming] ── 完成 ──→ [idle]
                                    ├ 取消 ─→ [idle]
                                    └ ask 工具暂停 ─→ [waiting_user_input]
```

UI 表达：sidebar 对话列表的小圆点。streaming 是脉冲橙；approval 是黄；idle 是灰。

---

## 9. 键盘绑定

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
| Onboarding `←/→` | 上一步/下一步 |

**约束**：所有快捷键在 input/textarea/contentEditable 中失效（除 composer 的 Enter）。

---

## 10. Onboarding（独立 HTML）

`Forgify Onboarding.html` — 首跑流程，5 步：

1. **欢迎** — Forgify mark + 价值说明
2. **创建账号** — 名字输入（本地账号，支持多账号）+ 实时头像预览
3. **外观** — accent 色板 + 主题模式 + 实时预览区
4. **API Key** — Provider 卡（DeepSeek / Anthropic / Qwen / Ollama）+ key 输入 + 可跳过
5. **就绪** — 总结卡 + ⌘K 提示

左侧轨道显示进度（已完成绿勾、当前橙圈、未到灰）；右侧大区当前 step 内容；底部进度条 + 上一步/继续按钮；回车 / ←/→ 都能切。

---

## 11. 数据 / 协议适配

当前是 mock data。接真后端时按下方对照：

| Mock | 后端来源 |
|---|---|
| `Forgify.activeMessages` | `GET /api/v1/conversations/{id}/messages` + eventlog SSE |
| `Forgify.conversations` | `GET /api/v1/conversations` |
| `Forgify.forges` | `GET /api/v1/functions` + `/handlers` + `/workflows` |
| `Forgify.functionDetails[id]` | `GET /api/v1/functions/{id}?includeVersions=true` |
| `Forgify.handlerDetails[id]` | 同上 |
| `Forgify.workflowDetails[id]` | 同上 |
| `Forgify.flowruns` | `GET /api/v1/flowruns` |
| `Forgify.flowrunDetails[id]` | `GET /api/v1/flowruns/{id}` |
| `Forgify.workflowHistory[wf]` | `GET /api/v1/workflows/{name}/run-history` |
| `Forgify.notifications` | notifications SSE |
| `Forgify.relations` | `GET /api/v1/relations` |
| `streaming` state | eventlog SSE `message_start` / `message_stop` |
| AskAI 提交 | chat domain |
| Accept / Revert / Deploy | `POST /api/v1/functions/{id}:accept` 等 |

---

## 12. 演进规则

1. **加新 pane**：
   - `app.jsx::PANE_META` 加一行
   - `sidebar.jsx` 加 `<SideNavItem>` 触发 `togglePane`
   - 新建 `src/<pane>.jsx`，导出到 `window.<PaneName>View`
   - `Forgify Desktop.html` 加 `<script>` 引用
2. **加新 block type**：先改 `event-log-protocol.md` → `blocks.jsx` 加 case
3. **加新 entity 类型**（参与关系图）：
   - `relgraph.jsx::entityDirectory` 加构造代码
   - `KIND_COLOR` / `KIND_ICON` / `KIND_LABEL` 各加一行
   - `blocks.jsx::EntityLink` meta map 加前缀
4. **加新关系 kind**：`VERB_TEMPLATE` (EntityRelMeta) + `EDGE_KIND_LABEL` (NodeDetail) 各加一行
5. **不加第二个 titlebar / 顶栏**：全局状态走 sidebar footer 或 toast
6. **不加 emoji 装饰**：用户内容里的 emoji 可保留，UI chrome 不可用
7. **不加 settings pane**：设置一律走 footer 齿轮 popover 或 config pane 的 tabs
8. **不加 ActionMenu / RelMore 混用**：list 永远是 ActionMenu (实体操作)，detail 标题永远是 RelMore (关系图)

---

## 13. 已知坑 / 演化债

- mock data 写死在 `data.jsx`；接 SSE 后需要按 conversation/workflow 分片懒加载
- Workflow 编辑器拖拽用 mousedown + window mousemove——未来 touch 屏要补 pointer events
- markdown 渲染是 minimal 自研，缺：图片 / 链接 / 嵌套列表 / 任务列表
- Container queries 需要 Chromium 105+ / Safari 16+
- RelTime 不自动刷新（"3 分钟前"不会变 "4 分钟前"）；如需加 useEffect setInterval
- 接真后端时 EntityLink 跳转的 detail view 还要支持 "highlight this id" + scroll-into-view
- 多账号目前只是切换显示，未持久化每账号独立的 conversations / forges / 数据目录
- 关系图力模拟在节点数 > 50 时可能掉帧；未来用 Worker 跑模拟

---

## 14. 未来可探索

- Cmd palette fuzzy 匹配 + 历史
- Workflow editor 撤销栈（⌘Z / ⌘⇧Z）
- Conversation diff（两个对话之间的差异）
- Run replay（FlowRun 的 input 回放 + breakpoint）
- Inline markdown 在 chat 直接编辑：双击 assistant message 修改 + 重新生成
- Skill marketplace UI（从远端拉）
- 触摸优化（pointer events）
- i18n（所有中文 copy 走 i18n 表，配合 settings 的语言切换真正生效）

---

*本文档跟代码同步。代码改了请回头改这里。*
