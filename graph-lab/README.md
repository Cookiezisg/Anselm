# Anselm flow-graph · 工作流图模块（生产级 demo）

Anselm 的 **workflow 编辑器 + scheduler 运行态**那张图的参考实现：自动布局 / 浮动正交连线 / 可视化编辑 / 运行态叠加。纯 vanilla（无构建、无外网依赖），逃生舱：自绘 SVG + 吃 Anselm token。

> 本目录独立，**不属于即将废弃的 `design/`**。方案细节见 [`SOLUTION.md`](SOLUTION.md)。

## 跑

```bash
python3 -m http.server 4193 --directory graph-lab
# 打开 http://localhost:4193/index.html
```
（已在 `.claude/launch.json` 注册 `graph-lab`，端口 4193。）

## 能干什么

**编辑器**：悬停节点露四向连接桩拖拽连线（即时校验回边规则）· ＋节点（5 类型菜单，加孤立节点自连）· 点节点/边在右侧改定义（kind / ref / 输入接线 CEL / retry / 端口）· 拖动改位 · 删除（级联）· 撤销/重做（⌘Z）· 自动规范化（重排）· 横/竖 · 缩放/平移/适应 · 小地图 · **ops 日志**（实时显示生成的后端 `workflow :edit` op 流）。

**运行态**：节点状态色 + 迭代 ×N（重影栈=每轮一行记忆化）+ retry 子徽（与迭代物理分离）+ 已走/未来/实时导电边（彗星）· 点节点看记忆化 result / 迭代时间线 · parked 节点决策（通过/驳回，即时推进）。

5 个示例：有循环 / 等审批 / 失败 / 多分支双循环 / 空白从零搭。

## 结构

```
index.html · styles.css
src/model.js       模型 + 纯图算法 + 后端 ops 生成（无 DOM）
src/flowgraph.js   视图组件：布局 + 浮动正交路由 + 渲染 + 交互（window.FlowGraph）
src/app.js         演示外壳：工具栏 + 检查器 + 撤销 + 小地图 + ops 日志
```

## 与后端对齐

图 = **可归约控制流图**（DAG + 回边；回边只能 control/approval 出）。节点 5 类，字段对齐 `domain/workflow.Node`。执行按 `(node, iteration)` 展开循环。编辑动作 1:1 生成后端图 ops。详见 [`SOLUTION.md`](SOLUTION.md)。
