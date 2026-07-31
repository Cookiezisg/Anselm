# Web Demo Primitive Inventory

本页是 `demo/core/primitives/` 的静态资产地图，只约束 web demo。Flutter 当前
`An*` 原语与使用纪律见
[`docs/references/frontend/design-system.md`](../docs/references/frontend/design-system.md)。

## 当前库存

| 类别 | 文件（省略 `.js`） |
|---|---|
| 基础输入与动作 | `button` · `input` · `field` · `edit-affordance` · `action-group` · `toolbar` · `menu` · `dropdown` · `model-picker` |
| 状态与反馈 | `status-dot` · `badge` · `callout` · `state` · `skeleton` · `toast` · `dialog` · `stepper` |
| 布局与导航 | `page` · `section` · `group-label` · `row` · `row-detail` · `tabs` · `sidebar-list` · `right-island` · `ocean-header` · `card` · `info-card` |
| 浮层与引用 | `floating` · `mention` · `ref-pill` · `tags` · `brand-icon` |
| 内容与数据 | `code-editor` · `json-tree` · `thin-table` · `version-diff` · `outline` · `doc-editor` · `typewriter` |
| 对话与执行 | `block-tree` · `composer` · `approval-gate` · `run-terminal` · `entity-workspace` |
| 图与调度 | `graph-canvas` · `kind-legend` · `wire-list` · `node-gantt` · `run-board` |

共 50 个 JavaScript 文件。实际加载顺序由 `app.html` 与 `reference.html` 决定；
specimen 和压力态由 `features/reference/` 决定。两处 HTML 的集合并不完全相同：
例如 `model-picker` 当前只由 app 入口加载，因此不要用本表推断 reference 覆盖率。

## 复用规则

- 修改已有原型时，优先复用这里的 primitive，不在 feature 内复制同类壳。
- token 只从 `core/tokens.css` 读取；demo lint 负责检查本目录的 web 规则。
- 新增 primitive 必须同时接入需要它的 HTML、补 reference specimen 或说明为何只在
  app 中使用，并更新本表。
- 删除 primitive 必须先清理 HTML、feature 和 reference catalog 的全部引用。
- Flutter 不直接复制这里的 API 或 CSS；相同名字也不构成跨实现兼容承诺。
