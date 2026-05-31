# widgets/sidebar — 前端 slice 详细设计

**所属层**：widgets（聚合 entities/conversation + entities/user + app/model/paneStore）
**状态**：✅ 已实现（FSD Revamp 阶段 0–4 完成）
**职责**：Gemini-style 左侧导航栏。展开 260px / 收起 64px。包含 logo、主导航、工具分组、最近对话列表、底部用户区。所有状态通过 props 传入，组件本身无 app 层依赖。

---

## 1. 职责边界

| 子职责 | 说明 |
|---|---|
| 折叠/展开动画 | Framer Motion spring（stiffness 280, damping 28），width 64 ↔ 260 |
| 导航项渲染 | 每个 NavItem 按 `openPanes` 高亮活跃状态，点击 onTogglePane / onOpenPane |
| 最近对话列表 | `useConversations()` 分 pinned / recent / archived 三段；collapsed 时隐藏 |
| 底部用户区 | 头像角红点 = Help+Bell 合并未读；hover 浮出 ⚙ 设置按钮；SSE 健康点 |
| 新建对话 | 调 `useCreateConversation().mutateAsync({})` → onSetActiveConv + onOpenPane("chat") |

---

## 2. Props 接口

```ts
interface SidebarProps {
  openPanes: string[];
  activeConv: string | null;
  collapsed: boolean;
  toolsExpanded: boolean;
  recentExpanded: boolean;
  archivedExpanded: boolean;
  sseHealth?: {
    overall: string;       // "ok" | "warn" | "err" | "unknown"
    eventlog: string;
    notifs: string;
    forge: string;
    unread: number;
    clearUnread: () => void;
  };
  onTogglePane: (pane: string) => void;
  onOpenPane: (pane: string) => void;
  onSetActiveConv: (id: string | null) => void;
  onSetCollapsed: (v: boolean) => void;
  onSetToolsExpanded: (v: boolean) => void;
  onSetRecentExpanded: (v: boolean) => void;
  onSetArchivedExpanded: (v: boolean) => void;
  onOpenCmdk: () => void;
  onOpenNotifs: () => void;
  onOpenSettings: () => void;
}
```

所有回调由 AppShell 从 paneStore / sidebarStore / overlayStore 提取后传入。

---

## 3. 子组件

| 组件 | 文件 | 职责 |
|---|---|---|
| `NavItem` | 内联 | 单个导航按钮；collapsed 时只显示图标 + title tooltip |
| `SidebarSection` | `SidebarSection.tsx` | 可折叠分组（"工具"/"最近"/"归档"）；内部用 details/summary 或 state 控制展开 |
| `ChatListItem` | `ChatListItem.tsx` | 单条对话行；active 高亮 + status dot（streaming 脉动 / 普通） |
| `ForgifyLogo` | 内联 SVG | 铁砧 + 火花 mark；collapsed 时 logo 区 hover 变 PanelLeftOpen 切换图标 |

---

## 4. 数据流

```
AppShell → Sidebar (props)
  ├─ useConversations()          (entities/conversation)
  ├─ useCreateConversation()     (entities/conversation)
  ├─ useDisplayName()            (entities/user)
  └─ sseHealth                   (app/sse SSEProvider 通过 props 向下)
```

对话列表按 `pinned → recent → archived` 分组显示；archived 有条数才出现分组。

---

## 5. 实现清单

| 文件 | 说明 |
|---|---|
| `frontend/src/widgets/sidebar/Sidebar.tsx` | 主组件 + NavItem + ForgifyLogo |
| `frontend/src/widgets/sidebar/SidebarSection.tsx` | 可折叠分组 |
| `frontend/src/widgets/sidebar/ChatListItem.tsx` | 单条对话行 |
| `frontend/src/widgets/sidebar/index.ts` | public API export |
