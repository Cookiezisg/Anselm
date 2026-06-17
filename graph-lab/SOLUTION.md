# Anselm flow-graph 模块 · 方案文档

> 工作流图（workflow 编辑器 + scheduler 运行态）那张图的**生产级方案**：自动布局 / 浮动正交连线 / 可视化编辑 / 运行态叠加。
> **参考实现**：同目录 [`index.html`](index.html) + [`src/`](src)（纯 vanilla，无构建、无外网依赖；逃生舱：自绘 SVG + 吃 Anselm token）。
> **路由 / 交互算法**经核对 React Flow / `@xyflow` 内部源（见 §11）。

⚠️ `graph-lab/` 是独立工作区，**不属于 `design/`**（design 即将废弃）。这里只放参考实现 + 本文档。

---

## 0. 怎么跑

```
python3 -m http.server 4193 --directory graph-lab   # 已在 .claude/launch.json 注册 graph-lab
# 打开 http://localhost:4193/index.html
```
工具栏：示例图 · 模式（编辑器/运行态）· 方向（横/竖）· ＋节点（类型菜单）· 删除 · ↻规范化 · 撤销/重做 · ops 日志 · 主题。
5 个示例：有循环 / 等审批(parked) / 失败 / 多分支双循环 / 空白从零搭。

---

## 1. 图模型（与后端逐字对齐）

**它不是 DAG，是带回边的「可归约控制流图」（reducible control-flow graph）。** 事实源：`backend/internal/domain/workflow/{graph.go,workflow.go,ops.go}`、`internal/app/scheduler/walk.go`、`internal/domain/flowrun/flowrun.go`。

- **节点 5 类**：`trigger`(trg_) / `action`(fn_·hd_.method·mcp:) / `agent`(ag_) / `control`(ctl_，选一个具名 **port**) / `approval`(apf_，port = `yes`/`no`)。
- **节点字段**（`domain/workflow.Node`）：`{id, kind, ref, input(field→CEL), retry?{maxAttempts,backoff,delayMs}, pos?}`。`id` **不可变**（= 下游 Input CEL 的引用名）。
- **边** `From→To`，`FromPort` 只在 control/approval 源上有值。
- **回边只能从 control/approval 发出**（`graph.go` 环纪律），目标是**祖先**，**无自环**。回边判定 = DFS 指向递归栈上节点（`BackEdges`，校验/执行/本 demo 同一定义）。
- **执行展开循环**：解释器按 `(node, iteration)` 调度 + 记忆化；走一次回边 `iteration+1`（`walk.go` 的 `nodeKey{id,iter}`），封顶 1000。一个静态节点 → N 个运行时实例，每个一行 `flowrun_nodes`（record-once，`UNIQUE(flowrun_id,node_id,iteration)`）。
- **`Node.Pos` 是编排元数据、执行忽略** → 坐标自动算（"自动规范化"）。
- **`Retry`（action 同一轮失败重试）≠ 循环 `iteration`（再过一遍循环体）**——可视化物理分离（见 §6）。
- **编辑 = 图 ops**（`ops.go`）：`add_node / update_node(RFC7396 merge, id 不可变) / delete_node(级联删边) / add_edge / update_edge / delete_edge / set_meta`。本 demo 每个编辑动作即生成对应 op（右上「ops」面板可见）。

---

## 2. 两视图，一套拓扑

| | 编辑器（workflow） | 运行态（flowrun / scheduler） |
|---|---|---|
| 性质 | 静态、可编辑 | 只读、状态叠加 |
| 能力 | 加节点 / 连线 / 改定义 / 删 / 自动规范化 / 横竖 / 缩放 / 撤销 | 状态色 + 迭代 ×N + 已走/未来/实时边 + 点节点看 result + parked 决策 |
| 数据 | `{nodes, edges}` | + `{state, iters, taken, live, memo}` |

---

## 3. 架构（文件 = 职责）

```
graph-lab/
├── index.html          # 外壳 + 工具栏
├── styles.css          # 令牌 + 组件样式（暗色仅换值）
└── src/
    ├── model.js        # 模型层：节点类型 / 示例 / 纯图算法(回边·可达·校验) / 后端 ops 生成。无 DOM。
    ├── flowgraph.js    # 视图组件：分层布局 + 浮动正交路由 + 渲染 + 画布交互。window.FlowGraph.mount()→handle。
    └── app.js          # 演示外壳：工具栏 + 检查器(可编辑) + 撤销/重做 + 小地图 + ops 日志。
```

**核心心法（逃生舱）**：把**布局**和**渲染**拆开。布局是确定性算法（只算坐标）；节点卡片自绘、吃 token——既解决"自动规范化 + 丑"，又不被框架节点样式绑架，且 Flutter 能照搬同一套坐标/路由结果。

---

## 4. 连线方案（核心：修掉"边很丑/箭头怪"）

**根因**：旧版从**卡片中心→中心**画对称 bezier，端口固定一侧，任意摆位就斜穿/倒灌。

**方案 = 浮动正交边**（floating orthogonal），与 React Flow 内部一致：

1. **浮动锚点**：每条边按两端**中心向量**决定各连哪一面（朝向对方的那面），边随节点移动滑到合适的边——任意相对位置都顺。（`facing()`；React Flow 用单位菱形归一 `getNodeIntersection`，本 demo 用长宽比归一的等价判定。）
2. **正交 smoothstep**：从节点面**垂直出线**一段（`STUB`），再按「同向/反向/垂直」三类落拐点；圆角用 **getBend**（`L 到拐点前 → Q 拐点 → 继续`），半径 `min(段长/2, CORNER)` 防过冲。横/竖 = 默认出/入面在 右/左 ↔ 下/上 之间切换。
3. **回边/循环 = 返回弧**：绕到主带外侧通道（横向走底、竖向走右），**多条各占一条错开通道**（staggered），虚线 + accent + 箭头落循环头 + 端口标签——与前向边一眼区分。
4. **箭头 marker**：`orient='auto-start-reverse'` + `markerUnits='userSpaceOnUse'`（缩放不变形）；运行态分 base/taken/future/live 四档色。
5. **端口标签**落在路径中点（`pointAtMid`）。

---

## 5. 编辑交互（生产级）

- **连接桩**：每节点四向小圈，**悬停节点即现**（0ms，Anselm 铁律）；**命中区与可视区解耦**（透明 r=11 命中 + 可视 r=4.5）——研究证实这是"不卡手"的最大单点收益。
- **拖拽连线**：从桩拖出预览线 → 落到目标节点成边。**即时校验**（`isValidConnection`，对齐后端铁律）：无自环 / 无重复 / **回边只能 control·approval 出** / approval 仅 yes·no；control·approval 出口自动命名端口。非法即拒 + toast。
- **加节点 = 孤立节点**（类型菜单选 5 类之一），落在视口中心、自动选中；用户自己连。**不自动接线、不自动重排**。
- **改定义**：点节点 → 右侧检查器编辑 `kind / ref / 输入接线(field→CEL 增删) / retry`（action）；点边 → 编辑端口 / 删边。每次改动生成 `update_node`/`update_edge` op。
- **删 / 拖 / 撤销**：`Del` 删选中（节点级联删边）；拖节点改位（floating 边跟随）；**撤销/重做**（图快照栈，⌘Z / ⌘⇧Z，每次交互一步）。
- **缩放/平移**：滚轮**缩放到光标**、拖空白平移、适应。**小地图**（概览 + 视口框 + 点击导航）。
- **ops 日志**：实时显示生成的后端 `workflow :edit` op 流（教学 + 验证后端契约）。

## 6. 运行态叠加

- **状态色**：completed（中性）/ running（accent 呼吸环 + 蓝点）/ failed（danger）/ parked（warn）/ future（虚边、淡）。
- **迭代 ×N**：循环跑过的节点出**重影栈 + ×N 徽**（rolled 单节点）——对应 `(node,iteration)` 每轮一行记忆化；检查器列出**每轮 result 时间线**。
- **retry 与 iteration 物理分离**：retry 是右上 `↻` 子徽（同一轮重试），iteration 是左下 `×N` + 重影栈（新一轮）——绝不混淆（研究强调）。
- **边分档**：已走（实墨线）/ 未来（淡虚线，control 选定后未走分支即降级）/ **实时导电**（accent + 彗星）。
- **点节点**看记忆化 result（control 的 `__port`、approval 的 `decision`、迭代时间线、失败 error）。
- **parked = 审批门**：检查器渲 prompt + 截止 + first-wins + **通过/驳回**按钮；决策即推进下游（轻量模拟 `ResolveParkedNode`）。

## 7. 视觉 / 几何规约

- **节点卡**：`188×60`，圆角 14，浮起阴影；左 `26×26` 类型 chip（tinted bg + 类型色描边图标）。
- **类型色**：trigger=violet · action=accent · agent=teal · control=warn · approval=danger（仅类型 chip / 细描边，正文克制）。
- **间距**：层间 `GAPX=84`、跨轴 `GAPY=44`、画布 `PAD=48`、出线段 `STUB=22`、圆角 `CORNER=12`、回边通道 `16+i*26`。
- 取自 Anselm token（密度=2 的幂 / 布局=谐波 2:3:6 / 字阶=模数）；落地原语时改 `var(--…)`。

## 8. 原语 API（落地 `fy-flow-graph`）

```js
FlowGraph.mount(host, {
  graph,                    // {nodes:[{id,kind,ref,input,retry?,pos?}], edges:[{id,from,to,port?}]}
  mode, dir, run,           // 'edit'|'run' · 'LR'|'TB' · 运行态数据
  onSelect(sel),            // {type:'node'|'edge', id} | null
  onChange({ops, label}),   // 每次变更：后端 ops 流（上层落 workflow :edit / 入撤销栈）
  onToast(msg), onView(v),
}) // → handle
// handle: setMode/setDir/setRun/setGraph/getGraph/getRun/relayout/fit/zoomBy/panTo/getView
//         /addNode/addEdge/updateNode/updateEdge/deleteSelected/resolveApproval/select/isBack
```
- `onChange` 抛后端 ops；上层映射到 workflow `:edit`。校验在原语内先做（即时反馈），后端 `ValidateGraph` 为最终权威。

## 9. Flutter 映射（最终目标）

- **自绘**：`CustomPainter` 画边（同款浮动 smoothstep / 返回弧）+ 任意 **Widget 当节点**（token→`ThemeExtension`）+ `InteractiveViewer`（缩放/平移）。
- **布局复用**：分层算法用 Dart 重写一份（小、确定性），或直接复用 Web/后端算好的坐标——保证 Web 与 Flutter 像素级一致。
- `graphview` 包可兜底（Sugiyama 分层），但对环/自定义箭头一般，不做主力。

## 10. 不做 / 边界

- ❌ 引入 ELK/dagre 等外部布局库（团队明确：理解成本高 + 依赖）。本 demo 内置分层 Sugiyama-lite，离线可跑。
- ❌ 多连线风格开关（统一浮动 smoothstep + 循环返回弧）。
- ❌ 把节点交给框架渲染（保持自绘 + 吃 token = 逃生舱铁律）。

## 11. 路由 / 交互算法来源（已核对）

经 web 调研核对 React Flow / `@xyflow` `main` 源（v12 同源）：浮动边 `getNodeIntersection`+`getEdgePosition`、`getSmoothStepPath`（gap-offset → 同向/反向/垂直拐点）、`getBend` 圆角、marker `auto-start-reverse`、回边错开通道——本 demo 实现与之一致。运行态分档/彗星 = React Flow `AnimatedSvgEdge` 标准做法。

## 12. 路线（研究建议的增强，按价值排序）

- **迭代 scrubber/strip**：rolled 循环节点下放一条 `#0..#N` 迭代条（点击切换驱动节点皮肤 + 检查器）——直接吃 Anselm 的 record-once 行，研究列为最高价值升级。
- **磁吸 + 合法桩高亮**：连线时吸附最近合法桩（半径 ~20px），实时 glow 合法 / dim 非法。
- **拖到空白 → 建节点器**（n8n 式一手势建出 + 连）。
- **框选 / 多选 / 复制粘贴 / 对齐辅助线**。
- **action retry 的 `attempt k/max` 子徽 + 独立重试列表**（与迭代栈物理隔离）。
- 已做并经研究确认的：浮动 smoothstep、getBend 圆角、回边错开通道、连接桩命中区解耦、彗星、taken/future/live 三档、parked 决策。
