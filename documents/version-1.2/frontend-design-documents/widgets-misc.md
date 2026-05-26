# widgets/misc — 简单 widget 合并设计文档

**所属层**：widgets
**状态**：✅ 均已实现（FSD Revamp 阶段 0–4 完成）
**覆盖**：ActionMenu / AskAiTrigger / EntityLink / EntityRelMeta / ToastTray / VersionRail（含 SplitDiff / CodeView）

---

## ActionMenu

**职责**：floating-ui 自动定位 + FloatingPortal 渲染的下拉菜单。支持自定义 trigger；外部点击 / Escape 关闭。

```ts
interface ActionMenuProps {
  items: (ActionMenuItem | "divider")[];
  renderTrigger?: (props: ...) => React.ReactNode;  // 缺省 = MoreHorizontal icon-btn
  placement?: Placement;                            // 缺省 = "bottom-end"
}
interface ActionMenuItem {
  label: string;
  icon?: React.ComponentType;
  danger?: boolean;
  shortcut?: string;
  onClick?: () => void;
}
```

文件：`widgets/action-menu/ActionMenu.tsx`

---

## AskAiTrigger

**职责**：forge 实体详情头部的「AI · 迭代」按钮。点击弹出 fixed 底右 popover（textarea + suggestion chips）。提交后调 `useForgeIterate` → `POST /<kind>s/{id}:iterate` → 跳 chat pane。

```ts
interface AskAiTriggerProps {
  kind: string;         // "function" | "handler" | "workflow" | "document"
  entityId: string;
  context?: string;     // popover 头部说明文字
  suggestions?: string[];  // 快捷建议 chips
}
```

**数据流**：`useForgeIterate`（features/forge-iterate）→ POST `:iterate` → 返 `{ conversationId }` → `navigate.openConv(cid)`

文件：`widgets/ask-ai-trigger/AskAiTrigger.tsx`

---

## EntityLink

**职责**：可点击实体 ID chip。按 ID 前缀推断 pane，调 `navigate.openConv` 或 `navigate.openEntity`。显示名称从 `useEntityName(id)`（本地查询缓存联合聚合）解析。

```ts
interface EntityLinkProps {
  id: string;   // 带前缀的实体 ID，如 fn_xxx / cv_xxx
}
```

**前缀 → pane 映射**（完整表见源码 `PREFIX_META`）：`fn_/f_` → forge，`hd_/h_` → forge，`wf_/w_` → forge，`cv_` → chat（openConv），`fr_` → execute，`doc_/d_` → documents，`skill/s_` → skills，`mcp` → mcp，`mem_/m_` → memory。

文件：`widgets/entity-link/EntityLink.tsx`，`useEntityName.ts`

---

## EntityRelMeta

**职责**：实体头部的引用条（"· 与 X · Y 相关 …"）。调 `useEntityNeighborhood(entityId, kind, limit)` → `GET /relations/neighborhood?kind=&id=&depth=1`。零关联时整条不渲染（孤岛静默）。末尾挂 `RelMore` 触发器打开完整图谱 popover。

```ts
interface EntityRelMetaProps {
  entityId?: string;
  kind?: string;
  limit?: number;   // 缺省 3；显示前 N 个邻居
}
```

**注意**：使用 `/relations/neighborhood` 而非 `/relations?entityId=`，后者后端 filter 有 bug 会泄漏无关边。

文件：`widgets/entity-rel-meta/EntityRelMeta.tsx`

---

## ToastTray

**职责**：右下角 toast 队列。从 `shared/ui/toastStore` 读 toasts；AnimatePresence + layout transition（slide up + fade）；支持 undo 按钮。

自身无 props，直接消费 store：
```ts
const toasts = useToastStore((s) => s.toasts);
const dismiss = useToastStore((s) => s.dismissToast);
```

文件：`widgets/toaster/ToastTray.tsx`

---

## VersionRail

**职责**：function / handler / workflow 详情右侧共用版本栏。展示 pending（warn 色高亮）/ current（success）/ deployed（accent）状态。pending 时顶部 banner 提供 Accept / Revert / Diff 三个快捷操作。可折叠为 dot 列。

```ts
interface VersionRailProps {
  versions: VersionItem[];
  currentId?: string;
  pendingId?: string;
  deployedId?: string;
  selectedId?: string;
  onSelect?: (id: string) => void;
  onAccept?: () => void;
  onRevert?: () => void;
  onRollback?: () => void;
  onDeploy?: () => void;
  showDeploy?: boolean;
}
```

同文件额外导出 `SplitDiff`（LCS 行级 diff，左右并排）和 `CodeView`（Python-ish 语法高亮，state machine 分词防 quote 内误匹配）。

文件：`widgets/version-rail/VersionRail.tsx`
