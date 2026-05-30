# 08 — 编排 UI

脑爆结论笔记(2026-05-27)。

> **本 doc 不细抠视觉**——直接沿用 Forgify 现有 `frontend/src/features/workflow-edit/ui/WorkflowEditor.tsx` + `pages/forge/ui/WorkflowDetail.tsx` 的形态。
> 只列**新设计对画布的功能性影响**(node palette / inspector / 触发入口 / 运行时滴答 / chat 协作)。
> UI 细节后续优化。

---

## 现状直接复用的部分

frontend FSD 已有:

| 既有 | 复用 |
|---|---|
| `features/workflow-edit/ui/WorkflowEditor.tsx` | 画布 + palette + pan/zoom/drag + 4-handle 连边 + 自动布局 + 2s autosave + inspector | ✅ 直接用 |
| `pages/forge/ui/WorkflowDetail.tsx` | 详情页框 + VersionRail + AskAiTrigger + RunDrawer + CapabilityCheckPanel | ✅ 直接用 |
| `entities/workflow/api/workflow.ts` + `model/types.ts` | API hooks + TS 类型 | ✅ 适配新 schema |
| `features/forge-iterate` / `forge-review` | AI 帮造 / accept-pending 流程 | ✅ 直接用 |
| `widgets/version-rail` | 版本历史 + diff 视图 | ✅ 直接用 |

**核心交互形态全部已经在了**:用户在画布上看(只读 + 跑时滴答),AI 在 chat 里改(`edit_workflow` 工具),画布实时刷新,VersionRail 看版本 / 一键 accept。

---

## 跟新设计的对接清单

### 1. Node palette 改 14 → 5

现 `NODE_KINDS` 数组(14 个)改成 5 个 + 表达更精确:

```typescript
const NODE_KINDS = [
  { kind: "trigger",  label: "Trigger",  icon: "Zap",   desc: "workflow 入口(cron / webhook / fsnotify / polling / manual)" },
  { kind: "agent",    label: "Agent",    icon: "Bot",   desc: "LLM 节点(prompt + skill + knowledge + tool)" },
  { kind: "tool",     label: "Tool",     icon: "Code",  desc: "调 forge 出来的 callable(function / handler / mcp)" },
  { kind: "case",     label: "Case",     icon: "GitBranch", desc: "switch 路由 + 回边形成 loop" },
  { kind: "approval", label: "Approval", icon: "Pause", desc: "等用户 yes/no" },
];
```

砍 9 个 kind(llm / function / handler / mcp / skill / condition / loop / variable / parallel / wait / http)的 palette 项。

### 2. Inspector 字段跟新 node config schema

每个 kind 的 inspector 字段:

| 节点 | inspector 字段 |
|---|---|
| **trigger** | `kind`(cron/webhook/fsnotify/polling/manual)+ kind-specific config(cron expression / webhook path 等)+ `payloadSchema` |
| **agent** | `prompt` 段 + `skill` 单挂下拉 + `knowledge` 多挂列表 + `tool` 多挂列表 + `outputSchema` + `model`((apikey, modelId) 二元组)|
| **tool** | `callable` ref + `args`(JSON / key-value)+ `retry`(可选)+ `onInfraCrash`(retry/dead_letter)+ `timeout`(可选)|
| **case** | `expression`(CEL,带 lint)+ `branches`(N 路命名,每个 `to` + 可选 `emit` CEL 对象)|
| **approval** | `prompt`(markdown,可插值)+ `timeout`(可选)+ `timeoutBehavior` + `allowReason` |

所有"平台默认值"字段一律改 placeholder("AI 编排时拍" / "不填 = ..."),**没有 hardcoded 默认值**。

### 3. 顶部加 Workflow lifecycle 开关

WorkflowDetail 头部加 **Active toggle**:

```
┌─ workflow X [v3 active] ────────── [○ Inactive] [▶ 试触发] [AI iterate] [Run] ─┐
│                                                                                  │
│  [画布]                                                  [VersionRail]            │
│                                                                                  │
└──────────────────────────────────────────────────────────────────────────────────┘
```

Toggle 调 `:activate` / `:deactivate` HTTP action(详 06-workflow-lifecycle.md)。

### 4. Trigger 节点上的 ▶ 触发按钮

画布上每个 trigger 节点角上加 `▶` 按钮(只在 trigger 节点)。点开弹 modal,按节点的 `payloadSchema` 渲染表单。

```
[trigger cron] ▶
                ↓ 点开
            ┌─ 触发 ────────────────────┐
            │ payload(按 schema 填):    │
            │   firedAt: [_____now_____]│
            │                            │
            │       [ 取消 ]  [ 触发 ]   │
            └────────────────────────────┘
```

提交 → `POST /workflows/{id}:trigger { triggerNodeId, payload }`(详 01-triggers.md 触发统一抽象段)。

### 5. 运行时滴答可视化(新功能,核心)

flowrun 跑起来时,画布实时显示:

| 视觉 | 含义 |
|---|---|
| 节点 spinning border | 正在处理 message |
| 节点绿色 ✓ | 已 emit 完下游 |
| 节点红色 | 失败 / 进死信 |
| 节点黄色 + ⏸ | approval 暂停 |
| **edge 上有"流动球"** | message 正在传递 |
| 节点角标"× N" | 已激活 N 次(case 回边时) |

数据源:新加第 4 条 SSE `flowrun-progress`(按需订阅,详 00 待办里我提过)— 这是后端的事,前端订阅 + 画布消费。

跟现有 `useForgeProgress`(锻造进度)同模式,新加个 `useFlowrunProgress`。

### 6. 节点详情 inline diagnostic

用户/AI 点节点 → 右侧 FloatingInspector 显示:

- 节点 config(只读 + "在 chat 里改这个节点" 按钮)
- 节点的运行时状态(消息流入数 / 失败数 / 平均耗时)
- 最近 N 条 message(payload + ctx + 结果)

数据源:`GET /flowruns/{id}/trace?nodeId=X`。

---

## chat-画布双 pane 协作

**chat-first 编辑**(现状已有,沿用):

```
用户在 chat:"帮我加个判断,字数 < 100 就不推 Slack"
   ↓
AI 调 edit_workflow + apply 2 ops(在 agent 和 tool 之间插 case)
   ↓
画布自动刷新(react-query invalidate)
   ↓
新 case 节点显示成黄色"待 accept"
   ↓
用户在 chat / VersionRail 点 accept → 落 active
```

**画布点节点 → chat 聚焦**:

```
用户在画布上点 agent 节点 → 节点上的"在 chat 里改"按钮
   ↓
chat 自动起话题:"想改这个 agent 节点的什么?prompt / outputSchema / model / 挂载的 tool?"
   ↓
用户聊几句 → AI 改 → 画布刷新
```

**实现**:画布节点上的按钮发送一个 intent 给 chat(用现有 `Shell.openConv` + 预填 prompt 模式)。

---

## 现状 → 新设计 改动量

| 改 | 代码量 |
|---|---|
| `features/workflow-edit/ui/WorkflowEditor.tsx` 的 `NODE_KINDS` 14→5 | 删 9 条加 3 条改 2 条 |
| 各 kind inspector 字段(替换现有) | per kind 一个组件,约 50-100 行 |
| WorkflowDetail 顶部 Active toggle | ~20 行 |
| Trigger 节点 ▶ 触发按钮 + payloadSchema 表单 | ~50 行 |
| 滴答动画(`useFlowrunProgress` + 节点状态映射) | ~80 行(订 SSE + state machine) |
| FloatingInspector 加运行时状态 + recent messages | ~50 行 |
| **总** | **~300-400 行,2-3 天** |

加上后端 SSE `flowrun-progress` + Trace API(~200 行),整套 UI 落地估**4-5 天**。

---

## 决策总览

```
1. 画布主体(palette + canvas + connect + inspector + autosave)  → 沿用现有 WorkflowEditor 形态
2. Node palette                                                 → 14 → 5(改 NODE_KINDS 数组)
3. Inspector 字段                                                → 跟新 node config schema(无 hardcoded 默认值)
4. Workflow Active 开关                                          → 顶部 toggle,调 :activate / :deactivate
5. Trigger 节点 ▶ 触发                                           → 每个 trigger 节点角上一个按钮 + payloadSchema 表单
6. 运行时画布滴答                                                → 新加 useFlowrunProgress(订 SSE,实时映射节点状态)
7. chat-画布协作                                                 → 双向(画布点节点 → chat 起话题;chat 改 → 画布刷新)
8. AI 帮造 / iterate / accept-pending                            → 沿用现有 forge-iterate + forge-review + VersionRail
```

UI 视觉细节(色板 / 间距 / 文案 / 动效)留下次优化,**功能层已覆盖**。
